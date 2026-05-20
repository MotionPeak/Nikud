import Foundation

/// The four things Nikud can do to a piece of text.
enum TextTask: String, CaseIterable, Identifiable, Hashable {
    case complete
    case proofread
    case polish
    case punctuate

    var id: String { rawValue }

    var title: String {
        switch self {
        case .complete:  return "Complete"
        case .proofread: return "Proofread"
        case .polish:    return "Polish"
        case .punctuate: return "Punctuation"
        }
    }

    var subtitle: String {
        switch self {
        case .complete:  return "Finish the sentence naturally"
        case .proofread: return "Fix grammar, spelling, and punctuation"
        case .polish:    return "Rewrite it clearly and professionally"
        case .punctuate: return "Correct punctuation and spacing only"
        }
    }

    var systemImage: String {
        switch self {
        case .complete:  return "text.append"
        case .proofread: return "checkmark.seal"
        case .polish:    return "wand.and.stars"
        case .punctuate: return "textformat.abc.dottedunderline"
        }
    }

    /// Short label for buttons and the floating panel.
    var actionVerb: String {
        switch self {
        case .complete:  return "Complete"
        case .proofread: return "Proofread"
        case .polish:    return "Polish"
        case .punctuate: return "Fix"
        }
    }

    /// Whether the result is best shown as a diff highlighting what changed.
    var showsDiff: Bool {
        switch self {
        case .proofread, .punctuate: return true
        case .polish, .complete:     return false
        }
    }
}

/// Tone applied when polishing text.
enum Tone: String, CaseIterable, Identifiable, Hashable {
    case professional
    case friendly
    case concise

    var id: String { rawValue }

    var title: String {
        switch self {
        case .professional: return "Professional"
        case .friendly:     return "Friendly"
        case .concise:      return "Concise"
        }
    }

    var systemImage: String {
        switch self {
        case .professional: return "briefcase"
        case .friendly:     return "bubble.left.and.bubble.right"
        case .concise:      return "scissors"
        }
    }
}
