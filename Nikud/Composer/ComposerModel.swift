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

    private var job: Task<Void, Never>?

    var canRun: Bool {
        !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isRunning: Bool { phase == .running }

    func run(using env: AppEnvironment) {
        guard canRun else { return }
        job?.cancel()
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
}
