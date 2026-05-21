import SwiftUI

/// Drives a single composer session: input, the chosen task, and the result.
@MainActor
final class ComposerModel: ObservableObject {

    enum Phase: Equatable {
        case idle
        case running
        case finished
        case failed(message: String, needsModel: Bool)
    }

    @Published var input = ""
    @Published var task: TextTask = .proofread
    @Published var tone: Tone = .professional
    @Published var output = ""
    @Published var phase: Phase = .idle
    @Published var suggestion = ""

    private var job: Task<Void, Never>?
    private var suggestionJob: Task<Void, Never>?
    private var suppressInputChange = false

    var canRun: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isRunning: Bool { phase == .running }

    func run(using env: AppEnvironment) {
        guard canRun else { return }
        job?.cancel()
        suggestionJob?.cancel()
        suggestion = ""
        output = ""
        phase = .running

        var request = env.makeRequest(task: task, text: input)
        request.tone = tone
        let stream = env.run(request)

        job = Task { [weak self] in
            do {
                for try await chunk in stream {
                    guard let self, !Task.isCancelled else { return }
                    self.output += chunk
                }
                guard let self, !Task.isCancelled else { return }
                self.phase = .finished
            } catch is CancellationError {
                self?.phase = .idle
            } catch {
                let needsModel: Bool
                if let engineError = error as? EngineError, case .noModelLoaded = engineError {
                    needsModel = true
                } else {
                    needsModel = false
                }
                self?.phase = .failed(message: error.localizedDescription, needsModel: needsModel)
            }
        }
    }

    func cancel() {
        job?.cancel()
        job = nil
        if phase == .running {
            phase = output.isEmpty ? .idle : .finished
        }
    }

    func clearResult() {
        job?.cancel()
        job = nil
        output = ""
        phase = .idle
    }

    func clearAll() {
        clearResult()
        input = ""
    }

    /// Moves the result back into the input field for further editing.
    func useResult() {
        guard !output.isEmpty else { return }
        if task == .complete {
            input += output
        } else {
            input = output
        }
        clearResult()
    }

    // MARK: - Autocomplete

    /// Clears any stale suggestion and schedules a fresh one after a brief pause.
    func inputChanged(using env: AppEnvironment) {
        if suppressInputChange {
            suppressInputChange = false
            return
        }
        if !suggestion.isEmpty { suggestion = "" }
        suggestionJob?.cancel()
        guard env.preferences.autocompleteEnabled, env.isModelReady else { return }
        let snapshot = input
        guard snapshot.trimmingCharacters(in: .whitespacesAndNewlines).count >= 8 else { return }
        suggestionJob = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(700))
            guard let self, !Task.isCancelled, self.input == snapshot else { return }
            await self.makeSuggestion(for: snapshot, using: env)
        }
    }

    /// Accepts the next word of the suggestion, keeping the rest showing.
    func acceptSuggestion() {
        guard !suggestion.isEmpty else { return }
        let (word, rest) = ComposerModel.splitFirstWord(suggestion)
        suppressInputChange = !rest.isEmpty
        suggestion = rest
        if rest.isEmpty { suggestionJob?.cancel() }
        input += word
    }

    /// Splits off the first word (with its trailing spaces) from the rest.
    private static func splitFirstWord(_ text: String) -> (word: String, rest: String) {
        var index = text.startIndex
        while index < text.endIndex, text[index] == " " { index = text.index(after: index) }
        while index < text.endIndex, text[index] != " " { index = text.index(after: index) }
        while index < text.endIndex, text[index] == " " { index = text.index(after: index) }
        return (String(text[..<index]), String(text[index...]))
    }

    private func makeSuggestion(for text: String, using env: AppEnvironment) async {
        let request = env.makeRequest(task: .complete, text: text)
        var produced = ""
        do {
            for try await chunk in env.run(request) {
                if Task.isCancelled { return }
                produced += chunk
            }
        } catch {
            return
        }
        guard !Task.isCancelled, input == text else { return }
        let cleaned = Self.cleanSuggestion(produced)
        if !cleaned.isEmpty { suggestion = cleaned }
    }

    /// Trims a raw completion down to a single, reasonably short line.
    private static func cleanSuggestion(_ raw: String) -> String {
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
        if text.count > 140 {
            let capped = text.prefix(140)
            if let lastSpace = capped.lastIndex(of: " ") {
                text = String(capped[..<lastSpace])
            } else {
                text = String(capped)
            }
        }
        return text
    }
}
