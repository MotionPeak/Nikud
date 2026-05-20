import SwiftUI

enum SettingsTab: String, CaseIterable, Identifiable {
    case general
    case models
    case shortcuts
    case about

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:   return "General"
        case .models:    return "Models"
        case .shortcuts: return "Shortcut"
        case .about:     return "About"
        }
    }

    var systemImage: String {
        switch self {
        case .general:   return "slider.horizontal.3"
        case .models:    return "internaldrive"
        case .shortcuts: return "keyboard"
        case .about:     return "info.circle"
        }
    }
}

/// The Nikud settings window: a custom tab bar over animated content.
struct SettingsWindow: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        VStack(spacing: 0) {
            SettingsTabBar(selection: $env.settingsTab)
                .padding(.top, 18)
                .padding(.bottom, 12)

            Divider().opacity(0.5)

            Group {
                switch env.settingsTab {
                case .general:   GeneralTab()
                case .models:    ModelsTab()
                case .shortcuts: ShortcutsTab()
                case .about:     AboutTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .id(env.settingsTab)
            .transition(.opacity.combined(with: .offset(y: 6)))
        }
        .frame(width: 580, height: 536)
        .background(.regularMaterial)
    }
}

// MARK: - Tab bar

private struct SettingsTabBar: View {
    @Binding var selection: SettingsTab
    @Namespace private var namespace

    var body: some View {
        HStack(spacing: 4) {
            ForEach(SettingsTab.allCases) { tab in
                button(for: tab)
            }
        }
        .padding(4)
        .background(Capsule().fill(Theme.softFill))
    }

    private func button(for tab: SettingsTab) -> some View {
        let selected = tab == selection
        return Button {
            withAnimation(Theme.Motion.spring) { selection = tab }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: tab.systemImage).font(.system(size: 12, weight: .medium))
                Text(tab.title).font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 7)
            .foregroundStyle(selected ? Color.white : Color.secondary)
            .background {
                if selected {
                    Capsule()
                        .fill(Theme.brandGradient)
                        .matchedGeometryEffect(id: "settingsTab", in: namespace)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reusable settings layout

/// A titled group of settings rows inside a single card.
struct SettingsGroup<Content: View>: View {
    let title: String
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            SectionLabel(text: title).padding(.leading, 4)
            VStack(spacing: 0) { content() }
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
}

/// A single labeled settings row with a trailing control.
struct SettingRow<Control: View>: View {
    let title: String
    var subtitle: String? = nil
    @ViewBuilder var control: () -> Control

    var body: some View {
        HStack(spacing: Theme.Spacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: Theme.Spacing.md)
            control()
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm + 1)
    }
}

/// A hairline divider sized for use between settings rows.
struct RowDivider: View {
    var body: some View {
        Divider()
            .overlay(Theme.hairline)
            .padding(.leading, Theme.Spacing.md)
    }
}
