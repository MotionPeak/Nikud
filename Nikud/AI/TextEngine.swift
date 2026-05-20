import Foundation

/// A single text-improvement request handed to an engine.
struct EngineRequest {
    var task: TextTask
    var text: String
    var language: DetectedLanguage
    var tone: Tone
    var creativity: Double

    init(
        task: TextTask,
        text: String,
        language: DetectedLanguage,
        tone: Tone = .professional,
        creativity: Double = 0.35
    ) {
        self.task = task
        self.text = text
        self.language = language
        self.tone = tone
        self.creativity = creativity
    }
}

enum EngineError: LocalizedError {
    case emptyInput
    case noModelLoaded
    case modelLoadFailed(String)
    case generationFailed(String)
    case cancelled

    var errorDescription: String? {
        switch self {
        case .emptyInput:              return "There is no text to work with."
        case .noModelLoaded:           return "This needs a language model. Open Models to download one."
        case .modelLoadFailed(let m):  return "The model could not be loaded: \(m)"
        case .generationFailed(let m): return "Generation failed: \(m)"
        case .cancelled:               return "Cancelled."
        }
    }
}

/// An engine turns an `EngineRequest` into improved text, streamed in chunks.
protocol TextEngine {
    /// Human-readable name shown in the UI.
    var displayName: String { get }
    /// Whether this engine runs a downloaded model rather than built-in rules.
    var usesModel: Bool { get }
    /// Streams the result. Each element is a chunk to append to the output.
    func run(_ request: EngineRequest) -> AsyncThrowingStream<String, Error>
}
