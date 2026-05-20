import AppKit
import ApplicationServices
import CoreGraphics

/// Reads and replaces the selected text in the frontmost application.
///
/// The Accessibility API is tried first; a clipboard-and-keystroke fallback
/// covers apps that do not expose their selection. These calls block briefly
/// and must be invoked off the main thread.
enum TextGrabber {

    /// Whether the app currently has Accessibility permission.
    static var isTrusted: Bool { AXIsProcessTrusted() }

    /// Asks macOS to show the Accessibility permission prompt.
    static func promptForAccess() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Captures the current selection of the frontmost app.
    static func captureSelection() -> String? {
        if let viaAX = selectedTextViaAX(),
           !viaAX.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return viaAX
        }
        return selectedTextViaCopy()
    }

    /// Replaces the current selection with `text`.
    static func replaceSelection(with text: String) {
        if setSelectedTextViaAX(text) { return }
        pasteViaClipboard(text)
    }

    // MARK: - Accessibility

    private static func focusedElement() -> AXUIElement? {
        let systemWide = AXUIElementCreateSystemWide()
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            systemWide, kAXFocusedUIElementAttribute as CFString, &value
        ) == .success else { return nil }
        guard let element = value, CFGetTypeID(element) == AXUIElementGetTypeID() else { return nil }
        return (element as! AXUIElement)
    }

    private static func selectedTextViaAX() -> String? {
        guard let element = focusedElement() else { return nil }
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(
            element, kAXSelectedTextAttribute as CFString, &value
        ) == .success else { return nil }
        return value as? String
    }

    private static func setSelectedTextViaAX(_ text: String) -> Bool {
        guard let element = focusedElement() else { return false }
        let status = AXUIElementSetAttributeValue(
            element, kAXSelectedTextAttribute as CFString, text as CFString
        )
        return status == .success
    }

    // MARK: - Clipboard fallback

    private static func selectedTextViaCopy() -> String? {
        let pasteboard = NSPasteboard.general
        let previousChangeCount = pasteboard.changeCount
        sendCommandKey(keyCode: 8) // C
        for _ in 0..<60 {
            if pasteboard.changeCount != previousChangeCount {
                return pasteboard.string(forType: .string)
            }
            usleep(10_000)
        }
        return nil
    }

    private static func pasteViaClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
        usleep(40_000)
        sendCommandKey(keyCode: 9) // V
    }

    private static func sendCommandKey(keyCode: CGKeyCode) {
        let source = CGEventSource(stateID: .combinedSessionState)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand
        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
