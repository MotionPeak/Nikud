import AppKit

/// Orchestrates the global-hotkey flow: capture the selection, run the engine,
/// show the floating panel, and replace the text when the user accepts.
@MainActor
final class QuickAssist {

    private unowned let environment: AppEnvironment
    private let hotkey = HotkeyCenter()
    private let panel = SuggestionPanelController()
    private var job: Task<Void, Never>?
    private var capturedText = ""
    private var targetApp: NSRunningApplication?

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func start() {
        hotkey.onPressed = { [weak self] in self?.trigger() }
        panel.onAccept = { [weak self] in self?.acceptResult() }
        panel.onDismiss = { [weak self] in self?.dismiss() }
        panel.onSelectTask = { [weak self] task in self?.rerun(task: task) }
        panel.onSelectTone = { [weak self] tone in self?.rerunTone(tone) }
        panel.onOpenAccessibility = {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
                NSWorkspace.shared.open(url)
            }
        }
        applyHotkeyPreference()
    }

    /// Re-registers the hotkey from the current preferences.
    func applyHotkeyPreference() {
        let prefs = environment.preferences
        hotkey.update(
            keyCode: prefs.hotkeyKeyCode,
            modifiers: prefs.hotkeyModifiers,
            enabled: prefs.hotkeyEnabled
        )
    }

    // MARK: - Flow

    private func trigger() {
        job?.cancel()
        let model = panel.model

        guard TextGrabber.isTrusted else {
            model.reset(task: environment.preferences.defaultTask, tone: environment.preferences.proofreadTone)
            model.phase = .needsPermission
            panel.show(near: NSEvent.mouseLocation)
            return
        }

        // Remember which app to paste back into.
        targetApp = NSWorkspace.shared.frontmostApplication
        model.reset(task: environment.preferences.defaultTask, tone: environment.preferences.proofreadTone)
        panel.show(near: NSEvent.mouseLocation)

        job = Task { [weak self] in
            guard let self else { return }
            let captured = await Task.detached(priority: .userInitiated) {
                TextGrabber.captureSelection()
            }.value
            if Task.isCancelled { return }

            guard let text = captured,
                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                model.phase = .empty
                return
            }
            self.capturedText = text
            model.sourceText = text
            await self.generate(task: model.task)
        }
    }

    /// Re-runs on the already-captured text with a different task.
    private func rerun(task: TextTask) {
        panel.model.task = task
        guard !capturedText.isEmpty else { return }
        job?.cancel()
        job = Task { [weak self] in
            await self?.generate(task: task)
        }
    }

    /// Changes the polish tone and re-runs if a polish result is in play.
    private func rerunTone(_ tone: Tone) {
        panel.model.tone = tone
        guard panel.model.task == .polish, !capturedText.isEmpty else { return }
        job?.cancel()
        job = Task { [weak self] in
            await self?.generate(task: .polish)
        }
    }

    /// Runs one generation pass on the captured text. Call inside a Task.
    private func generate(task: TextTask) async {
        let model = panel.model
        model.task = task
        model.output = ""
        model.phase = .running

        var request = environment.makeRequest(task: task, text: capturedText)
        request.tone = panel.model.tone
        do {
            for try await chunk in environment.run(request) {
                if Task.isCancelled { return }
                model.output += chunk
            }
            if Task.isCancelled { return }
            model.phase = .finished
            if environment.preferences.replaceSelectionDirectly {
                try? await Task.sleep(for: .milliseconds(350))
                if !Task.isCancelled { acceptResult() }
            }
        } catch is CancellationError {
            // Stopped by the user — leave the panel as it is.
        } catch {
            model.phase = .failed(error.localizedDescription)
        }
    }

    private func acceptResult() {
        let result = panel.model.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let task = panel.model.task
        let source = capturedText
        let app = targetApp
        job?.cancel()
        panel.hide()
        guard !result.isEmpty else { return }

        let replacement = (task == .complete) ? source + result : result
        // Bring the user's app back to the front, then paste into it.
        app?.activate()
        Task.detached(priority: .userInitiated) {
            try? await Task.sleep(for: .milliseconds(150))
            TextGrabber.replaceSelection(with: replacement)
        }
    }

    private func dismiss() {
        job?.cancel()
        panel.hide()
    }
}
