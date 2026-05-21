import AppKit

/// A borderless, click-through overlay that shows grey suggestion text
/// anchored at the caret position inside another app.
@MainActor
final class GhostOverlay {

    private var panel: NSPanel?
    private let label = NSTextField(labelWithString: "")
    private let maxWidth: CGFloat = 520

    func show(_ text: String, at caretRect: CGRect) {
        let panel = self.panel ?? makePanel()
        self.panel = panel

        let rightToLeft = GhostOverlay.isRightToLeft(text)
        let fontSize = max(11, min(28, caretRect.height * 0.82))
        label.font = .systemFont(ofSize: fontSize)
        label.alignment = rightToLeft ? .right : .left
        label.stringValue = text
        label.sizeToFit()

        var size = label.frame.size
        size.width = min(size.width, maxWidth)
        label.frame = NSRect(origin: .zero, size: size)

        // Hebrew continues leftward from the caret; English continues rightward.
        var origin = NSPoint(
            x: rightToLeft ? caretRect.minX - size.width : caretRect.maxX,
            y: caretRect.minY
        )
        let caretCenter = NSPoint(x: caretRect.midX, y: caretRect.midY)
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(caretCenter) }) {
            let bounds = screen.visibleFrame
            origin.x = min(max(origin.x, bounds.minX + 4), bounds.maxX - size.width - 4)
        }

        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.orderFrontRegardless()
    }

    /// True when the text is in a right-to-left script (Hebrew or Arabic).
    private static func isRightToLeft(_ text: String) -> Bool {
        text.unicodeScalars.contains { (0x0590...0x08FF).contains($0.value) }
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.level = .popUpMenu
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        label.isBezeled = false
        label.isEditable = false
        label.isSelectable = false
        label.drawsBackground = false
        label.textColor = .tertiaryLabelColor
        label.maximumNumberOfLines = 1
        label.lineBreakMode = .byTruncatingTail
        panel.contentView = label
        return panel
    }
}
