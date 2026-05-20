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
    case oldWorld
    case playful

    var id: String { rawValue }

    var title: String {
        switch self {
        case .professional: return "Professional"
        case .friendly:     return "Friendly"
        case .concise:      return "Concise"
        case .oldWorld:     return "Old-World"
        case .playful:      return "Playful"
        }
    }

    var systemImage: String {
        switch self {
        case .professional: return "briefcase"
        case .friendly:     return "bubble.left.and.bubble.right"
        case .concise:      return "scissors"
        case .oldWorld:     return "crown"
        case .playful:      return "party.popper"
        }
    }

    /// English style directive — slots in after "Rewrite the text ".
    var styleEN: String {
        switch self {
        case .professional:
            return "in a clear, fluent, and professional style"
        case .friendly:
            return "in a clear, warm, and friendly style"
        case .concise:
            return "as concisely as possible, keeping only what is essential"
        case .oldWorld:
            return "in an elaborate, old-fashioned, and highly courtly style — ornate, "
                + "grand, and exceedingly well-mannered, as if penned in a bygone era"
        case .playful:
            return "in a fun, playful, and light-hearted style, with a dash of wit and personality"
        }
    }

    /// Hebrew style directive — slots in after "נסח מחדש את הטקסט ".
    var styleHE: String {
        switch self {
        case .professional:
            return "בסגנון ברור, רהוט ומקצועי"
        case .friendly:
            return "בסגנון ברור, חם וידידותי"
        case .concise:
            return "בצורה תמציתית ככל האפשר, תוך השמטת כל מה שאינו הכרחי"
        case .oldWorld:
            return "בסגנון מליצי, ארכאי ומכובד במיוחד — מהודר, רב-רושם ורב-נימוסים, כלשון ימים עברו"
        case .playful:
            return "בסגנון שובב, קליל ומשועשע, עם קורטוב של הומור ואופי"
        }
    }
}
