import SwiftUI

/// Word-level diff between an original and a corrected string.
enum TextDiff {

    struct Segment {
        let text: String
        let changed: Bool
    }

    /// Splits text into tokens: maximal runs of whitespace or non-whitespace.
    private static func tokenize(_ text: String) -> [String] {
        var tokens: [String] = []
        var current = ""
        var currentIsSpace: Bool?
        for character in text {
            let isSpace = character.isWhitespace
            if currentIsSpace == nil || currentIsSpace == isSpace {
                current.append(character)
                currentIsSpace = isSpace
            } else {
                tokens.append(current)
                current = String(character)
                currentIsSpace = isSpace
            }
        }
        if !current.isEmpty { tokens.append(current) }
        return tokens
    }

    /// Returns the corrected text split into changed / unchanged segments.
    static func segments(original: String, corrected: String) -> [Segment] {
        let source = tokenize(original)
        let target = tokenize(corrected)
        guard !target.isEmpty else { return [] }
        guard !source.isEmpty else { return [Segment(text: corrected, changed: true)] }
        // Skip the diff for very large inputs to keep it instant.
        guard source.count <= 2000, target.count <= 2000 else {
            return [Segment(text: corrected, changed: false)]
        }

        let n = source.count
        let m = target.count
        var dp = [[Int]](repeating: [Int](repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                if source[i] == target[j] {
                    dp[i][j] = dp[i + 1][j + 1] + 1
                } else {
                    dp[i][j] = max(dp[i + 1][j], dp[i][j + 1])
                }
            }
        }

        var keep = [Bool](repeating: false, count: m)
        var i = 0
        var j = 0
        while i < n && j < m {
            if source[i] == target[j] {
                keep[j] = true
                i += 1
                j += 1
            } else if dp[i + 1][j] >= dp[i][j + 1] {
                i += 1
            } else {
                j += 1
            }
        }

        var segments: [Segment] = []
        for (index, token) in target.enumerated() {
            let changed = !keep[index]
            if let last = segments.last, last.changed == changed {
                segments[segments.count - 1] = Segment(text: last.text + token, changed: changed)
            } else {
                segments.append(Segment(text: token, changed: changed))
            }
        }
        return segments
    }

    /// Counts the distinct changed runs that contain visible characters.
    static func changeCount(original: String, corrected: String) -> Int {
        segments(original: original, corrected: corrected)
            .filter { $0.changed && $0.text.contains { !$0.isWhitespace } }
            .count
    }
}

/// Renders corrected text with changed words highlighted in the accent color.
struct DiffText: View {
    let original: String
    let corrected: String

    var body: some View {
        let segments = TextDiff.segments(original: original, corrected: corrected)
        return segments.reduce(Text(verbatim: "")) { result, segment in
            result + Text(verbatim: segment.text)
                .foregroundColor(segment.changed ? Theme.accent : .primary)
                .fontWeight(segment.changed ? .semibold : .regular)
        }
    }
}
