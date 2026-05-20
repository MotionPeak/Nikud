import Foundation

/// A built-in, rules-based engine. It needs no model and runs instantly.
/// It handles spacing, punctuation, and capitalization; the deeper tasks
/// (polish and complete) require a downloaded language model.
struct HeuristicEngine: TextEngine {
    var displayName: String { "Built-in rules" }
    var usesModel: Bool { false }

    func run(_ request: EngineRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let trimmed = request.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else {
                continuation.finish(throwing: EngineError.emptyInput)
                return
            }
            switch request.task {
            case .punctuate, .proofread:
                continuation.yield(Self.tidy(request.text, language: request.language))
                continuation.finish()
            case .polish, .complete:
                continuation.finish(throwing: EngineError.noModelLoaded)
            }
        }
    }

    /// Normalizes whitespace, punctuation spacing, and capitalization.
    static func tidy(_ input: String, language: DetectedLanguage) -> String {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)

        // Collapse runs of spaces.
        while text.contains("  ") {
            text = text.replacingOccurrences(of: "  ", with: " ")
        }

        // Remove spaces before sentence punctuation.
        for mark in [",", ".", "!", "?", ";", ":"] {
            text = text.replacingOccurrences(of: " \(mark)", with: mark)
        }

        // Ensure a single space after sentence punctuation.
        text = spaceAfterPunctuation(text)

        if language != .hebrew {
            text = capitalizeSentences(text)
            text = fixStandalonePronoun(text)
        }

        // Ensure the text ends with terminal punctuation.
        if let last = text.last, !".!?…\"')".contains(last) {
            text += "."
        }
        return text
    }

    private static let sentenceMarks: Set<Character> = [",", ".", "!", "?", ";", ":"]

    private static func spaceAfterPunctuation(_ string: String) -> String {
        let chars = Array(string)
        var result = ""
        result.reserveCapacity(chars.count + 8)
        for (index, character) in chars.enumerated() {
            result.append(character)
            guard sentenceMarks.contains(character), index + 1 < chars.count else { continue }
            let next = chars[index + 1]
            let previous = index > 0 ? chars[index - 1] : " "
            // Keep decimals and thousands separators intact (3.14, 1,000).
            if (character == "." || character == ",") && previous.isNumber && next.isNumber {
                continue
            }
            if !next.isWhitespace && !sentenceMarks.contains(next)
                && next != ")" && next != "\"" && next != "'" {
                result.append(" ")
            }
        }
        return result
    }

    private static func capitalizeSentences(_ string: String) -> String {
        var chars = Array(string)
        var capitalizeNext = true
        for index in chars.indices {
            let character = chars[index]
            if capitalizeNext, character.isLetter {
                chars[index] = Character(character.uppercased())
                capitalizeNext = false
            } else if ".!?".contains(character) {
                capitalizeNext = true
            } else if character.isLetter || character.isNumber {
                capitalizeNext = false
            }
        }
        return String(chars)
    }

    private static func fixStandalonePronoun(_ string: String) -> String {
        var text = string
        text = text.replacingOccurrences(of: " i ", with: " I ")
        text = text.replacingOccurrences(of: " i'", with: " I'")
        if text.hasPrefix("i ") { text = "I " + text.dropFirst(2) }
        if text.hasPrefix("i'") { text = "I" + text.dropFirst(1) }
        return text
    }
}
