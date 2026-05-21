import AppKit

/// Offers inline completions while the user types in any app: it watches the
/// focused text field, asks the model to continue the sentence, shows the
/// suggestion as ghost text at the caret, and inserts it word by word on Tab.
///
/// Diagnostic output is logged with the "Nikud/auto:" prefix.
@MainActor
final class SystemAutocomplete {

    private unowned let environment: AppEnvironment
    private let monitor = SystemTextMonitor()
    private let overlay = GhostOverlay()
    private let keyTap = KeyTap()

    private var job: Task<Void, Never>?
    private var suggestion = ""
    private var baseText = ""
    private var running = false

    init(environment: AppEnvironment) {
        self.environment = environment
        monitor.onPause = { [weak self] context in self?.handlePause(context) }
        monitor.onInvalidate = { [weak self] in self?.dismiss() }
        keyTap.onAccept = { [weak self] in self?.acceptWord() }
    }

    /// Starts or stops monitoring to match the user's preference.
    func sync() {
        let wanted = environment.preferences.systemAutocompleteEnabled
        guard wanted != running else { return }
        running = wanted
        if wanted {
            NSLog("Nikud/auto: enabling system-wide autocomplete")
            monitor.start()
            keyTap.start()
        } else {
            NSLog("Nikud/auto: disabling system-wide autocomplete")
            monitor.stop()
            keyTap.stop()
            dismiss()
        }
    }

    // MARK: - Flow

    private func handlePause(_ context: SystemTextMonitor.Context) {
        startCompletion(forText: context.text, caretRect: context.caretRect)
    }

    /// Generates a short completion for `text` and streams it into the overlay.
    private func startCompletion(forText text: String, caretRect: CGRect) {
        guard environment.isModelReady else {
            NSLog("Nikud/auto: skipped — no model is loaded (open Settings → Models)")
            return
        }
        job?.cancel()
        let recent = String(text.suffix(320))
        NSLog("Nikud/auto: generating a completion for \(recent.count) chars of context")
        let request = environment.makeRequest(task: .complete, text: recent)

        job = Task { [weak self] in
            guard let self else { return }
            var produced = ""
            var shown = ""
            do {
                for try await chunk in self.environment.run(request) {
                    if Task.isCancelled { return }
                    produced += chunk
                    // Show the suggestion as it streams in, so the first words
                    // appear without waiting for the whole completion.
                    let partial = SystemAutocomplete.clean(produced)
                    if !partial.isEmpty, partial != shown {
                        shown = partial
                        self.suggestion = partial
                        self.baseText = text
                        self.overlay.show(partial, at: caretRect)
                        self.keyTap.isArmed = true
                    }
                    if produced.contains("\n") { break }
                }
            } catch {
                NSLog("Nikud/auto: generation failed — \(error.localizedDescription)")
                if shown.isEmpty { return }
            }
            if Task.isCancelled { return }
            if shown.isEmpty {
                NSLog("Nikud/auto: the model returned nothing")
                return
            }
            NSLog("Nikud/auto: suggestion — \"\(shown)\"")
        }
    }

    private func dismiss() {
        job?.cancel()
        job = nil
        guard !suggestion.isEmpty || keyTap.isArmed else { return }
        suggestion = ""
        keyTap.isArmed = false
        overlay.hide()
    }

    /// Inserts the next word of the suggestion and re-anchors the remainder.
    private func acceptWord() {
        guard !suggestion.isEmpty else { return }
        job?.cancel()
        job = nil
        let (word, rest) = SystemAutocomplete.splitFirstWord(suggestion)
        let newBase = baseText + word
        NSLog("Nikud/auto: accepting word \"\(word)\"")

        keyTap.isArmed = false
        monitor.suspend()
        overlay.hide()
        TextInjector.insert(word)

        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            guard let self else { return }
            self.monitor.acknowledge(newBase)
            self.baseText = newBase
            self.suggestion = rest
            self.monitor.resume()
            guard let rect = self.monitor.caretRectNow() else { return }
            if rest.isEmpty {
                // The suggestion ran out — generate the next words so the user
                // can keep accepting with Tab without pausing to type.
                self.startCompletion(forText: newBase, caretRect: rect)
            } else {
                self.overlay.show(rest, at: rect)
                self.keyTap.isArmed = true
            }
        }
    }

    // MARK: - Helpers

    /// Splits off the first word (with its trailing spaces) from the rest.
    private static func splitFirstWord(_ text: String) -> (word: String, rest: String) {
        var index = text.startIndex
        while index < text.endIndex, text[index] == " " { index = text.index(after: index) }
        while index < text.endIndex, text[index] != " " { index = text.index(after: index) }
        while index < text.endIndex, text[index] == " " { index = text.index(after: index) }
        return (String(text[..<index]), String(text[index...]))
    }

    /// Trims a raw completion to a single, short line.
    private static func clean(_ raw: String) -> String {
        var text = raw
        // Drop blank lines the model may emit before the real continuation.
        while let first = text.first, first == "\n" || first == "\r" {
            text.removeFirst()
        }
        if let newline = text.firstIndex(of: "\n") {
            text = String(text[..<newline])
        }
        // Strip stray markdown the model sometimes wraps around the text.
        text = text.replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "`", with: "")
        while text.hasPrefix("  ") { text.removeFirst() }
        while let last = text.last, last == " " || last == "\t" {
            text.removeLast()
        }
        if text.count > 120 {
            let capped = text.prefix(120)
            if let space = capped.lastIndex(of: " ") {
                text = String(capped[..<space])
            } else {
                text = String(capped)
            }
        }
        return text
    }
}
