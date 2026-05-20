import Foundation

/// How Nikud decides which language a request is in.
enum LanguageMode: String, CaseIterable, Identifiable, Hashable {
    case auto
    case hebrew
    case english

    var id: String { rawValue }

    var title: String {
        switch self {
        case .auto:    return "Automatic"
        case .hebrew:  return "Hebrew"
        case .english: return "English"
        }
    }

    var shortTitle: String {
        switch self {
        case .auto:    return "Auto"
        case .hebrew:  return "עברית"
        case .english: return "English"
        }
    }
}

/// The dominant script detected in a piece of text.
enum DetectedLanguage: String {
    case hebrew
    case english
    case mixed

    var displayName: String {
        switch self {
        case .hebrew:  return "Hebrew"
        case .english: return "English"
        case .mixed:   return "Mixed"
        }
    }

    var isRTL: Bool { self == .hebrew }
}

enum LanguageDetector {
    /// Detects the dominant script of a piece of text.
    static func detect(_ text: String) -> DetectedLanguage {
        var hebrew = 0
        var latin = 0
        for scalar in text.unicodeScalars {
            let value = scalar.value
            if (0x0590...0x05FF).contains(value) || (0xFB1D...0xFB4F).contains(value) {
                hebrew += 1
            } else if (0x0041...0x005A).contains(value) || (0x0061...0x007A).contains(value) {
                latin += 1
            }
        }
        let total = hebrew + latin
        guard total > 0 else { return .english }
        let hebrewShare = Double(hebrew) / Double(total)
        if hebrewShare > 0.65 { return .hebrew }
        if hebrewShare < 0.20 { return .english }
        return .mixed
    }

    /// Resolves the working language given the user's mode and the input text.
    static func resolve(mode: LanguageMode, text: String) -> DetectedLanguage {
        switch mode {
        case .auto:    return detect(text)
        case .hebrew:  return .hebrew
        case .english: return .english
        }
    }
}
