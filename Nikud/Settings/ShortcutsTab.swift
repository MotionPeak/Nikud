import SwiftUI
import ApplicationServices

struct ShortcutsTab: View {
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var env: AppEnvironment
    @State private var accessibilityTrusted = AXIsProcessTrusted()

    private let pollTimer = Timer.publish(every: 1.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                shortcutGroup
                permissionGroup
                explainer
            }
            .padding(Theme.Spacing.lg)
        }
        .onReceive(pollTimer) { _ in
            accessibilityTrusted = AXIsProcessTrusted()
        }
    }

    // MARK: Shortcut

    private var shortcutGroup: some View {
        SettingsGroup(title: "Global Shortcut") {
            SettingRow(
                title: "Enable shortcut",
                subtitle: "Use Nikud on selected text in any app."
            ) {
                Toggle("", isOn: $preferences.hotkeyEnabled)
                    .toggleStyle(.switch)
                    .tint(Theme.accent)
                    .labelsHidden()
            }

            RowDivider()

            SettingRow(
                title: "Shortcut",
                subtitle: "Click to record a new combination, then press it."
            ) {
                ShortcutRecorder()
                    .disabled(!preferences.hotkeyEnabled)
                    .opacity(preferences.hotkeyEnabled ? 1 : 0.4)
            }
        }
        .onChange(of: preferences.hotkeyEnabled) { _, _ in
            env.applyHotkeySettings()
        }
    }

    // MARK: Accessibility permission

    private var permissionGroup: some View {
        SettingsGroup(title: "Permission") {
            HStack(spacing: Theme.Spacing.md) {
                ZStack {
                    Circle()
                        .fill((accessibilityTrusted ? Color.green : Color.orange).opacity(0.16))
                        .frame(width: 38, height: 38)
                    Image(systemName: accessibilityTrusted ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(accessibilityTrusted ? .green : .orange)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(accessibilityTrusted ? "Accessibility access granted" : "Accessibility access needed")
                        .font(.system(size: 13, weight: .medium))
                    Text(accessibilityTrusted
                         ? "Nikud can read and replace selected text."
                         : "Grant access so the shortcut can read your selection.")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: Theme.Spacing.sm)
                if !accessibilityTrusted {
                    Button("Open Settings") { openAccessibilitySettings() }
                        .buttonStyle(.nikudSecondary)
                }
            }
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.sm + 1)
        }
    }

    private var explainer: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            SectionLabel(text: "How it works").padding(.leading, 4)
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                explainRow(number: "1", text: "Select text in any app — Mail, Notes, Pages, anywhere.")
                explainRow(number: "2", text: "Press your shortcut. Nikud reads the selection.")
                explainRow(number: "3", text: "Review the suggestion, or let it replace the text directly.")
            }
            .padding(Theme.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .fill(.ultraThinMaterial)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.lg, style: .continuous)
                    .stroke(Theme.hairline, lineWidth: 1)
            )
        }
    }

    private func explainRow(number: String, text: String) -> some View {
        HStack(alignment: .top, spacing: Theme.Spacing.sm) {
            Text(number)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 18, height: 18)
                .background(Circle().fill(Theme.brandGradient))
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else { return }
        NSWorkspace.shared.open(url)
    }
}

/// Renders shortcut symbols as individual key caps.
struct KeyCapsView: View {
    let symbols: [String]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(symbols.enumerated()), id: \.offset) { _, symbol in
                Text(symbol)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .frame(minWidth: 24, minHeight: 24)
                    .padding(.horizontal, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .fill(Theme.softFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .stroke(Theme.hairline, lineWidth: 1)
                    )
            }
        }
    }
}

/// A click-to-record control for choosing the global shortcut.
struct ShortcutRecorder: View {
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var env: AppEnvironment
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording ? stopRecording() : startRecording()
        } label: {
            Group {
                if recording {
                    Text("Press keys…")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.accent)
                } else {
                    KeyCapsView(symbols: KeyCombo.symbols(
                        keyCode: preferences.hotkeyKeyCode,
                        modifiers: preferences.hotkeyModifiers
                    ))
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .fill(recording ? Theme.accent.opacity(0.12) : Theme.softFill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.sm, style: .continuous)
                    .stroke(recording ? Theme.accent : Theme.hairline, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onDisappear(perform: stopRecording)
    }

    private func startRecording() {
        recording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            handle(event)
            return nil
        }
    }

    private func stopRecording() {
        recording = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func handle(_ event: NSEvent) {
        if event.keyCode == 53 { // Escape cancels
            stopRecording()
            return
        }
        let modifiers = carbonModifiers(from: event.modifierFlags)
        let keyCode = Int(event.keyCode)
        guard modifiers != 0, KeyCombo.keyCodeNames[keyCode] != nil else { return }

        preferences.hotkeyKeyCode = keyCode
        preferences.hotkeyModifiers = modifiers
        env.applyHotkeySettings()
        stopRecording()
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> Int {
        var result = 0
        if flags.contains(.command) { result |= KeyCombo.commandMask }
        if flags.contains(.option)  { result |= KeyCombo.optionMask }
        if flags.contains(.shift)   { result |= KeyCombo.shiftMask }
        if flags.contains(.control) { result |= KeyCombo.controlMask }
        return result
    }
}
