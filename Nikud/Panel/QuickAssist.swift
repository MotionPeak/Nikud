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

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    func start() {
        hotkey.onPressed = { [weak self] in self?.trigger() }
        panel.onAccept = { [weak self] in self?.acceptResult() }
        panel.onDismiss = { [weak self] in self?.dismiss() }
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
            model.reset(task: environment.preferences.defaultTask)
            model.phase = .needsPermission
            panel.show(near: NSEvent.mouseLocation)
            return
        }

        model.reset(task: environment.preferences.defaultTask)
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
            model.phase = .running

            let request = self.environment.makeRequest(task: model.task, text: text)
            do {
                for try await chunk in self.environment.run(request) {
                    if Task.isCancelled { return }
                    model.output += chunk
                }
                if Task.isCancelled { return }
                model.phase = .finished
                if self.environment.preferences.replaceSelectionDirectly {
                    try? await Task.sleep(for: .milliseconds(350))
                    if !Task.isCancelled { self.acceptResult() }
                }
            } catch is CancellationError {
                // Stopped by the user — leave the panel as it is.
            } catch {
                model.phase = .failed(error.localizedDescription)
            }
        }
    }

    private func acceptResult() {
        let result = panel.model.output.trimmingCharacters(in: .whitespacesAndNewlines)
        let task = panel.model.task
        let source = capturedText
        job?.cancel()
        panel.hide()
        guard !result.isEmpty else { return }

        let replacement = (task == .complete) ? source + result : result
        Task.detached(priority: .userInitiated) {
            TextGrabber.replaceSelection(with: replacement)
        }
    }

    private func dismiss() {
        job?.cancel()
        panel.hide()
    }
}
