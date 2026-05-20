import SwiftUI
import AppKit

// MARK: - Panel model

/// Observable state for the floating suggestion panel.
@MainActor
final class PanelModel: ObservableObject {
    enum Phase: Equatable {
        case capturing
        case running
        case finished
        case failed(String)
        case needsPermission
        case empty
    }

    @Published var task: TextTask = .proofread
    @Published var phase: Phase = .capturing
    @Published var sourceText = ""
    @Published var output = ""

    func reset(task: TextTask) {
        self.task = task
        phase = .capturing
        sourceText = ""
        output = ""
    }
}

// MARK: - Panel controller

/// Manages the borderless floating panel and its lifecycle.
@MainActor
final class SuggestionPanelController {

    let model = PanelModel()
    var onAccept: (() -> Void)?
    var onDismiss: (() -> Void)?
    var onOpenAccessibility: (() -> Void)?

    private var panel: NSPanel?
    private var clickMonitor: Any?
    private let panelSize = NSSize(width: 372, height: 300)

    func show(near point: NSPoint) {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        position(panel, near: point)
        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.16
            panel.animator().alphaValue = 1
        }
        installClickMonitor()
    }

    func hide() {
        removeClickMonitor()
        panel?.orderOut(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.isMovableByWindowBackground = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let host = NSHostingView(rootView: SuggestionPanelView(
            model: model,
            onAccept: { [weak self] in self?.onAccept?() },
            onDismiss: { [weak self] in self?.onDismiss?() },
            onOpenAccessibility: { [weak self] in self?.onOpenAccessibility?() }
        ))
        host.frame = NSRect(origin: .zero, size: panelSize)
        panel.contentView = host
        return panel
    }

    private func position(_ panel: NSPanel, near point: NSPoint) {
        let screen = NSScreen.screens.first { $0.frame.contains(point) } ?? NSScreen.main
        var origin = NSPoint(x: point.x + 14, y: point.y - 14)
        if let visible = screen?.visibleFrame {
            origin.x = min(max(origin.x, visible.minX + 8), visible.maxX - panelSize.width - 8)
            if origin.y - panelSize.height < visible.minY + 8 {
                origin.y = visible.minY + 8 + panelSize.height
            }
            origin.y = min(origin.y, visible.maxY - 8)
        }
        panel.setFrameTopLeftPoint(origin)
    }

    private func installClickMonitor() {
        removeClickMonitor()
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.onDismiss?()
        }
    }

    private func removeClickMonitor() {
        if let clickMonitor {
            NSEvent.removeMonitor(clickMonitor)
            self.clickMonitor = nil
        }
    }
}

// MARK: - Panel view

struct SuggestionPanelView: View {
    @ObservedObject var model: PanelModel
    let onAccept: () -> Void
    let onDismiss: () -> Void
    let onOpenAccessibility: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            header
            Divider().opacity(0.5)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            footer
        }
        .padding(Theme.Spacing.md)
        .frame(width: 372, height: 300)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .fill(.regularMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                .stroke(Theme.hairline, lineWidth: 1)
        )
        .animation(Theme.Motion.spring, value: model.phase)
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ZStack {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Theme.brandGradient)
                    .frame(width: 26, height: 26)
                Image(systemName: model.task.systemImage)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(model.task.title)
                    .font(.system(size: 13, weight: .semibold))
                Text("Nikud")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            IconButton(systemName: "xmark", help: "Dismiss", action: onDismiss)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.phase {
        case .capturing:
            statusView(icon: "doc.text.magnifyingglass", text: "Reading your selection…", animated: true)
        case .running, .finished:
            resultView
        case .failed(let message):
            statusView(icon: "exclamationmark.triangle.fill", text: message, tint: .orange)
        case .needsPermission:
            statusView(
                icon: "lock.shield",
                text: "Nikud needs Accessibility access to read selected text.",
                tint: .orange
            )
        case .empty:
            statusView(
                icon: "text.cursor",
                text: "Select some text first, then press the shortcut.",
                tint: .secondary
            )
        }
    }

    private var resultView: some View {
        let hebrew = LanguageDetector.detect(model.output) == .hebrew
        return ScrollView {
            Text(model.output.isEmpty ? "…" : model.output)
                .font(.system(size: 13))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: hebrew ? .trailing : .leading)
                .environment(\.layoutDirection, hebrew ? .rightToLeft : .leftToRight)
        }
        .overlay(alignment: .bottomTrailing) {
            if model.phase == .running {
                ThinkingDots()
                    .padding(6)
                    .background(.thinMaterial, in: Capsule())
            }
        }
    }

    private func statusView(icon: String, text: String, tint: Color = .secondary, animated: Bool = false) -> some View {
        VStack(spacing: Theme.Spacing.sm) {
            Spacer()
            Image(systemName: icon)
                .font(.system(size: 22))
                .foregroundStyle(tint)
                .symbolEffect(.pulse, isActive: animated)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private var footer: some View {
        switch model.phase {
        case .finished:
            HStack(spacing: Theme.Spacing.sm) {
                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.nikudSecondary(fullWidth: true))
                Button(model.task == .complete ? "Insert" : "Replace", action: onAccept)
                    .buttonStyle(.nikudPrimary(fullWidth: true))
            }
        case .needsPermission:
            HStack(spacing: Theme.Spacing.sm) {
                Button("Not now", action: onDismiss)
                    .buttonStyle(.nikudSecondary(fullWidth: true))
                Button("Open Settings", action: onOpenAccessibility)
                    .buttonStyle(.nikudPrimary(fullWidth: true))
            }
        case .failed, .empty:
            Button("Dismiss", action: onDismiss)
                .buttonStyle(.nikudSecondary(fullWidth: true))
        case .capturing, .running:
            Button("Cancel", action: onDismiss)
                .buttonStyle(.nikudSecondary(fullWidth: true))
        }
    }
}
