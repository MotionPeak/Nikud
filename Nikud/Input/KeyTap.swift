import Foundation
import CoreGraphics

/// A system-wide event tap that consumes the Tab key while a suggestion is
/// showing, so Tab accepts the suggestion instead of inserting a tab character.
final class KeyTap {

    /// Called on the main thread when Tab is pressed while armed.
    var onAccept: (() -> Void)?

    /// When true, Tab is consumed and reported as an accept.
    var isArmed = false

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    private static let tabKeyCode: Int64 = 48

    func start() {
        guard tap == nil else { return }

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else { return Unmanaged.passUnretained(event) }
            let keyTap = Unmanaged<KeyTap>.fromOpaque(userInfo).takeUnretainedValue()
            return keyTap.handle(type: type, event: event)
        }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            NSLog("Nikud/auto: key tap could not be created — Accessibility permission may be missing")
            return
        }

        self.tap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    func stop() {
        if let tap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        tap = nil
        runLoopSource = nil
        isArmed = false
    }

    private func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable the tap if the system disabled it.
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type == .keyDown, isArmed else {
            return Unmanaged.passUnretained(event)
        }
        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == KeyTap.tabKeyCode else {
            return Unmanaged.passUnretained(event)
        }
        // Consume Tab and report the accept once the tap callback has returned.
        DispatchQueue.main.async { [weak self] in self?.onAccept?() }
        return nil
    }

    deinit {
        stop()
    }
}
