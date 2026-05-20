import SwiftUI
import ServiceManagement

struct GeneralTab: View {
    @EnvironmentObject private var preferences: Preferences

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                writingGroup
                behaviorGroup
            }
            .padding(Theme.Spacing.lg)
        }
    }

    // MARK: Writing

    private var writingGroup: some View {
        SettingsGroup(title: "Writing") {
            SettingRow(
                title: "Default task",
                subtitle: "The task selected when you open Nikud."
            ) {
                Picker("", selection: $preferences.defaultTask) {
                    ForEach(TextTask.allCases) { task in
                        Text(task.title).tag(task)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            }

            RowDivider()

            SettingRow(
                title: "Language",
                subtitle: "Automatic detects Hebrew or English from your text."
            ) {
                Picker("", selection: $preferences.languageMode) {
                    ForEach(LanguageMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
                .fixedSize()
            }

            RowDivider()

            creativityRow
        }
    }

    private var creativityRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Creativity")
                    .font(.system(size: 13, weight: .medium))
                Text("Lower keeps edits faithful to your text; higher allows bolder rewrites.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: Theme.Spacing.sm) {
                Text("Precise")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                Slider(value: $preferences.creativity, in: 0...1)
                    .tint(Theme.accent)
                Text("Creative")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm + 1)
    }

    // MARK: Behavior

    private var behaviorGroup: some View {
        SettingsGroup(title: "Behavior") {
            SettingRow(
                title: "Launch at login",
                subtitle: "Start Nikud automatically when you sign in."
            ) {
                Toggle("", isOn: $preferences.launchAtLogin)
                    .toggleStyle(.switch)
                    .tint(Theme.accent)
                    .labelsHidden()
            }

            RowDivider()

            SettingRow(
                title: "Replace selection directly",
                subtitle: "With the hotkey, swap the selected text immediately instead of showing a panel."
            ) {
                Toggle("", isOn: $preferences.replaceSelectionDirectly)
                    .toggleStyle(.switch)
                    .tint(Theme.accent)
                    .labelsHidden()
            }
        }
        .onChange(of: preferences.launchAtLogin) { _, enabled in
            updateLoginItem(enabled)
        }
    }

    private func updateLoginItem(_ enabled: Bool) {
        do {
            if enabled {
                if SMAppService.mainApp.status != .enabled {
                    try SMAppService.mainApp.register()
                }
            } else {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                }
            }
        } catch {
            NSLog("Nikud: login item update failed — \(error.localizedDescription)")
        }
    }
}
