import AppKit
import ApplicationServices

/// Watches the focused text field across all apps and reports when the user
/// pauses while typing. Polls with a timer — simpler and more reliable across
/// apps than AX notifications. Logs its state with the "Nikud/auto:" prefix.
final class SystemTextMonitor {

    struct Context {
        /// The text before the caret.
        let text: String
        /// Where to anchor the suggestion, in Cocoa screen coordinates.
        let caretRect: CGRect
    }

    /// Called on the main thread when the user pauses with completable text.
    var onPause: ((Context) -> Void)?
    /// Called when the text changes or focus moves — any suggestion is stale.
    var onInvalidate: (() -> Void)?

    private var timer: Timer?
    private var lastText = ""
    private var lastChange = Date()
    private var firedText = ""
    private var suspended = false
    private var wasActive = false

    private let pollInterval: TimeInterval = 0.25
    private let pauseInterval: TimeInterval = 0.6
    private let minimumCharacters = 12
    private let excludedApps: Set<String> = [
        "com.apple.dt.Xcode", "com.apple.Terminal", "com.googlecode.iterm2"
    ]

    func start() {
        guard timer == nil else { return }
        NSLog("Nikud/auto: monitor started")
        let timer = Timer(timeInterval: pollInterval, repeats: true) { [weak self] _ in
            self?.poll()
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func stop() {
        NSLog("Nikud/auto: monitor stopped")
        timer?.invalidate()
        timer = nil
        lastText = ""
        firedText = ""
        suspended = false
        wasActive = false
    }

    func suspend() { suspended = true }
    func resume() { suspended = false }

    /// Treats `text` as the already-seen baseline so a self-made change
    /// (an accepted word) does not invalidate the remaining suggestion.
    func acknowledge(_ text: String) {
        lastText = text
        firedText = text
        lastChange = Date()
    }

    /// Reads the focused field's caret rect on demand, in Cocoa screen coords.
    func caretRectNow() -> CGRect? {
        guard let element = focusedTextElement(),
              let fullText = stringValue(element, kAXValueAttribute),
              let range = selectedRange(element) else { return nil }
        let length = (fullText as NSString).length
        let caret = min(max(range.location + range.length, 0), length)
        return caretRect(element, caret: caret, caretAtEnd: caret == length)
    }

    // MARK: - Polling

    private func poll() {
        guard !suspended else { return }

        guard let element = focusedTextElement() else {
            reportIdle("no focused element")
            return
        }
        guard let fullText = stringValue(element, kAXValueAttribute) else {
            reportIdle("focused element exposes no text value")
            return
        }
        guard let range = selectedRange(element) else {
            reportIdle("focused element exposes no caret")
            return
        }
        guard range.length == 0 else {
            reportIdle("text is selected")
            return
        }

        let nsText = fullText as NSString
        let caret = min(max(range.location, 0), nsText.length)
        let text = nsText.substring(to: caret)

        if !wasActive {
            wasActive = true
            let role = stringValue(element, kAXRoleAttribute) ?? "?"
            NSLog("Nikud/auto: tracking a text field (role=\(role), \(nsText.length) chars)")
        }

        if text != lastText {
            lastText = text
            lastChange = Date()
            firedText = ""
            onInvalidate?()
            return
        }

        guard text != firedText,
              Date().timeIntervalSince(lastChange) >= pauseInterval,
              text.trimmingCharacters(in: .whitespacesAndNewlines).count >= minimumCharacters else {
            return
        }

        firedText = text
        guard let rect = caretRect(element, caret: caret, caretAtEnd: caret == nsText.length) else {
            NSLog("Nikud/auto: paused — this app doesn't report the caret, so autocomplete stays off here")
            return
        }
        guard NSScreen.screens.contains(where: { $0.frame.intersects(rect) }) else {
            NSLog("Nikud/auto: caret rect \(rect) is off-screen — skipping")
            return
        }
        NSLog("Nikud/auto: paused — \(text.count) chars, caret at \(rect)")
        onPause?(Context(text: text, caretRect: rect))
    }

    private func reportIdle(_ reason: String) {
        guard wasActive else { return }
        wasActive = false
        lastText = ""
        firedText = ""
        NSLog("Nikud/auto: idle — \(reason)")
        onInvalidate?()
    }

    // MARK: - Accessibility

    private func focusedTextElement() -> AXUIElement? {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let raw = focused, CFGetTypeID(raw) == AXUIElementGetTypeID() else { return nil }
        let element = raw as! AXUIElement

        // Never monitor Nikud's own windows, or dev consoles (Xcode/Terminal).
        var pid: pid_t = 0
        if AXUIElementGetPid(element, &pid) == .success {
            if pid == getpid() { return nil }
            if let bundleID = NSRunningApplication(processIdentifier: pid)?.bundleIdentifier,
               excludedApps.contains(bundleID) { return nil }
        }

        // Never read secure (password) fields.
        if let subrole = stringValue(element, kAXSubroleAttribute),
           subrole == (kAXSecureTextFieldSubrole as String) { return nil }

        // Any element that exposes a string value + a caret is treated as text;
        // those checks happen in poll(), so no role whitelist here.
        return element
    }

    private func stringValue(_ element: AXUIElement, _ attribute: String) -> String? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success else { return nil }
        return value as? String
    }

    private func selectedRange(_ element: AXUIElement) -> CFRange? {
        var value: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &value) == .success,
              let raw = value, CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var range = CFRange()
        guard AXValueGetValue(raw as! AXValue, .cfRange, &range) else { return nil }
        return range
    }

    /// The caret rect, only when the app reports it exactly. Web apps that
    /// expose no caret geometry return nil here, so autocomplete does not run
    /// in them rather than show a guessed, misplaced suggestion.
    private func caretRect(_ element: AXUIElement, caret: Int, caretAtEnd: Bool) -> CGRect? {
        if let exact = exactCaretRect(element, caret: caret) { return exact }
        return textMarkerCaretRect(element, caretAtEnd: caretAtEnd)
    }

    /// Reads the caret rect from a web view's AXTextMarker attributes (Safari,
    /// Chrome, and Electron apps such as Claude, VS Code, Slack). Different web
    /// engines return bounds for different range shapes, so try the selection
    /// range first, then ranges derived from the text's end marker. The names
    /// are not in the public SDK, but are the ones WebKit and Chromium expose.
    private func textMarkerCaretRect(_ element: AXUIElement, caretAtEnd: Bool) -> CGRect? {
        if let selectionRange = attributeValue(element, "AXSelectedTextMarkerRange"),
           let rect = markerBounds(element, selectionRange), rect.height > 0 {
            return cocoaRect(fromAX: rect)
        }
        guard caretAtEnd, let caretMarker = attributeValue(element, "AXEndTextMarker") else {
            return nil
        }
        for attribute in ["AXLineTextMarkerRangeForTextMarker",
                          "AXLeftLineTextMarkerRangeForTextMarker",
                          "AXLeftWordTextMarkerRangeForTextMarker"] {
            guard let range = markerValue(element, attribute, caretMarker) else { continue }
            if let rect = markerBounds(element, range), rect.height > 0 {
                return cocoaRect(fromAX: rect)
            }
        }
        return nil
    }

    private func attributeValue(_ element: AXUIElement, _ attribute: String) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &result) == .success else { return nil }
        return result
    }

    private func markerValue(_ element: AXUIElement, _ attribute: String, _ parameter: CFTypeRef) -> CFTypeRef? {
        var result: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element, attribute as CFString, parameter, &result) == .success else { return nil }
        return result
    }

    private func markerBounds(_ element: AXUIElement, _ range: CFTypeRef) -> CGRect? {
        var result: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element, "AXBoundsForTextMarkerRange" as CFString, range, &result) == .success,
              let raw = result, CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var rect = CGRect.zero
        guard AXValueGetValue(raw as! AXValue, .cgRect, &rect) else { return nil }
        return rect
    }

    private func exactCaretRect(_ element: AXUIElement, caret: Int) -> CGRect? {
        var probe = CFRange(location: max(0, caret - 1), length: 1)
        guard let axRange = AXValueCreate(.cfRange, &probe) else { return nil }
        var result: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            element, kAXBoundsForRangeParameterizedAttribute as CFString, axRange, &result) == .success,
              let raw = result, CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        var axRect = CGRect.zero
        guard AXValueGetValue(raw as! AXValue, .cgRect, &axRect), axRect.height > 0 else { return nil }
        return cocoaRect(fromAX: axRect)
    }

    /// Converts an Accessibility rect (top-left origin on the primary display)
    /// to Cocoa screen coordinates (bottom-left origin).
    private func cocoaRect(fromAX rect: CGRect) -> CGRect {
        let primaryHeight = NSScreen.screens.first(where: { $0.frame.origin == .zero })?.frame.height
            ?? NSScreen.main?.frame.height
            ?? rect.maxY
        return CGRect(x: rect.minX, y: primaryHeight - rect.maxY, width: rect.width, height: rect.height)
    }
}
