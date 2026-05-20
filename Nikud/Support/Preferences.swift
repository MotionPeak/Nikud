import Foundation

/// User-facing settings, persisted to `UserDefaults` and observed by the UI.
final class Preferences: ObservableObject {

    private enum Keys {
        static let launchAtLogin = "launchAtLogin"
        static let activeModelID = "activeModelID"
        static let defaultTask = "defaultTask"
        static let languageMode = "languageMode"
        static let hotkeyEnabled = "hotkeyEnabled"
        static let hotkeyKeyCode = "hotkeyKeyCode"
        static let hotkeyModifiers = "hotkeyModifiers"
        static let creativity = "creativity"
        static let proofreadTone = "proofreadTone"
        static let replaceSelectionDirectly = "replaceSelectionDirectly"
    }

    /// Default hotkey is Option-Command-P. Carbon virtual key 35 is the "P" key.
    static let defaultHotkeyKeyCode = 35
    /// Carbon modifier mask for Option + Command (optionKey | cmdKey).
    static let defaultHotkeyModifiers = 0x0800 | 0x0100

    private let store = UserDefaults.standard

    @Published var launchAtLogin: Bool {
        didSet { store.set(launchAtLogin, forKey: Keys.launchAtLogin) }
    }
    @Published var activeModelID: String {
        didSet { store.set(activeModelID, forKey: Keys.activeModelID) }
    }
    @Published var defaultTask: TextTask {
        didSet { store.set(defaultTask.rawValue, forKey: Keys.defaultTask) }
    }
    @Published var languageMode: LanguageMode {
        didSet { store.set(languageMode.rawValue, forKey: Keys.languageMode) }
    }
    @Published var hotkeyEnabled: Bool {
        didSet { store.set(hotkeyEnabled, forKey: Keys.hotkeyEnabled) }
    }
    @Published var hotkeyKeyCode: Int {
        didSet { store.set(hotkeyKeyCode, forKey: Keys.hotkeyKeyCode) }
    }
    @Published var hotkeyModifiers: Int {
        didSet { store.set(hotkeyModifiers, forKey: Keys.hotkeyModifiers) }
    }
    @Published var creativity: Double {
        didSet { store.set(creativity, forKey: Keys.creativity) }
    }
    @Published var proofreadTone: Tone {
        didSet { store.set(proofreadTone.rawValue, forKey: Keys.proofreadTone) }
    }
    @Published var replaceSelectionDirectly: Bool {
        didSet { store.set(replaceSelectionDirectly, forKey: Keys.replaceSelectionDirectly) }
    }

    init() {
        let d = UserDefaults.standard
        launchAtLogin = d.bool(forKey: Keys.launchAtLogin)
        activeModelID = d.string(forKey: Keys.activeModelID) ?? ""
        defaultTask = TextTask(rawValue: d.string(forKey: Keys.defaultTask) ?? "") ?? .proofread
        languageMode = LanguageMode(rawValue: d.string(forKey: Keys.languageMode) ?? "") ?? .auto
        hotkeyEnabled = (d.object(forKey: Keys.hotkeyEnabled) as? Bool) ?? true
        hotkeyKeyCode = (d.object(forKey: Keys.hotkeyKeyCode) as? Int) ?? Preferences.defaultHotkeyKeyCode
        hotkeyModifiers = (d.object(forKey: Keys.hotkeyModifiers) as? Int) ?? Preferences.defaultHotkeyModifiers
        creativity = (d.object(forKey: Keys.creativity) as? Double) ?? 0.35
        proofreadTone = Tone(rawValue: d.string(forKey: Keys.proofreadTone) ?? "") ?? .professional
        replaceSelectionDirectly = (d.object(forKey: Keys.replaceSelectionDirectly) as? Bool) ?? false
    }
}
