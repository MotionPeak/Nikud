import SwiftUI
import AppKit

/// Content of the menu-bar popover: a header, the composer, and a footer.
struct MenuBarView: View {
    @EnvironmentObject private var env: AppEnvironment
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.5)
            ComposerView()
            Divider().opacity(0.5)
            footer
        }
        .frame(width: 376)
        .background(.regularMaterial)
    }

    private var header: some View {
        HStack(spacing: Theme.Spacing.sm) {
            Wordmark()
            Spacer()
            EngineStatusChip()
            IconButton(systemName: "gearshape", help: "Settings") {
                NSApplication.shared.activate()
                openWindow(id: WindowID.settings)
            }
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }

    private var footer: some View {
        HStack {
            Text("Runs in your menu bar")
                .font(.system(size: 10.5))
                .foregroundStyle(.tertiary)
            Spacer()
            Button("Quit Nikud") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
            .font(.system(size: 10.5, weight: .medium))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
    }
}

/// The Nikud wordmark: a small gradient tile with an aleph, plus the name.
struct Wordmark: View {
    var body: some View {
        HStack(spacing: 7) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Theme.brandGradient)
                .frame(width: 20, height: 20)
                .overlay(
                    Text("א")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                )
            Text("Nikud")
                .font(.system(size: 14, weight: .semibold))
        }
    }
}

/// A small status dot showing which engine is active.
struct EngineStatusChip: View {
    @EnvironmentObject private var env: AppEnvironment

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(tint)
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .help(helpText)
    }

    private var label: String {
        switch env.engineStatus {
        case .builtin:                return "Built-in"
        case .loadingModel:           return "Loading…"
        case .modelReady(let name):   return name
        case .modelFailed:            return "Model error"
        }
    }

    private var tint: Color {
        switch env.engineStatus {
        case .builtin:      return .secondary
        case .loadingModel: return .orange
        case .modelReady:   return .green
        case .modelFailed:  return .red
        }
    }

    private var helpText: String {
        switch env.engineStatus {
        case .builtin:      return "Using built-in rules. Download a model for Polish and Complete."
        case .loadingModel: return "Loading the language model…"
        case .modelReady:   return "A local model is ready."
        case .modelFailed:  return "The model failed to load."
        }
    }
}
