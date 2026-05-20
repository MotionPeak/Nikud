import Foundation

/// Formats Carbon key codes and modifier masks into readable shortcut text.
enum KeyCombo {

    // Carbon modifier masks.
    static let controlMask = 0x1000
    static let optionMask  = 0x0800
    static let shiftMask   = 0x0200
    static let commandMask = 0x0100

    static func modifierSymbols(_ modifiers: Int) -> [String] {
        var symbols: [String] = []
        if modifiers & controlMask != 0 { symbols.append("⌃") }
        if modifiers & optionMask  != 0 { symbols.append("⌥") }
        if modifiers & shiftMask   != 0 { symbols.append("⇧") }
        if modifiers & commandMask != 0 { symbols.append("⌘") }
        return symbols
    }

    static func keySymbol(_ keyCode: Int) -> String {
        keyCodeNames[keyCode] ?? "?"
    }

    /// The full set of cap symbols, modifiers first, e.g. ["⌥", "⌘", "P"].
    static func symbols(keyCode: Int, modifiers: Int) -> [String] {
        modifierSymbols(modifiers) + [keySymbol(keyCode)]
    }

    static func display(keyCode: Int, modifiers: Int) -> String {
        symbols(keyCode: keyCode, modifiers: modifiers).joined()
    }

    /// A combination is valid only with at least one modifier plus a key.
    static func isValid(keyCode: Int, modifiers: Int) -> Bool {
        !modifierSymbols(modifiers).isEmpty && keyCodeNames[keyCode] != nil
    }

    static let keyCodeNames: [Int: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X",
        8: "C", 9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R",
        16: "Y", 17: "T", 31: "O", 32: "U", 34: "I", 35: "P", 37: "L",
        38: "J", 40: "K", 45: "N", 46: "M",
        18: "1", 19: "2", 20: "3", 21: "4", 23: "5", 22: "6", 26: "7",
        28: "8", 25: "9", 29: "0",
        49: "Space", 36: "↩", 48: "⇥", 53: "⎋", 51: "⌫",
        123: "←", 124: "→", 125: "↓", 126: "↑",
        27: "-", 24: "=", 33: "[", 30: "]", 41: ";", 39: "'",
        43: ",", 47: ".", 44: "/", 42: "\\", 50: "`"
    ]
}
