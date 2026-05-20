import SwiftUI

// MARK: - Button styles

struct NikudPrimaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, fullWidth: fullWidth)
    }

    private struct StyleBody: View {
        let configuration: ButtonStyleConfiguration
        let fullWidth: Bool
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 9)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .fill(Theme.brandGradient)
                        .brightness(hovering && isEnabled ? 0.05 : 0)
                        .saturation(isEnabled ? 1 : 0)
                )
                .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.45)
                .scaleEffect(configuration.isPressed ? 0.975 : 1)
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
                .animation(Theme.Motion.snappy, value: hovering)
                .animation(Theme.Motion.snappy, value: configuration.isPressed)
        }
    }
}

struct NikudSecondaryButtonStyle: ButtonStyle {
    var fullWidth: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        StyleBody(configuration: configuration, fullWidth: fullWidth)
    }

    private struct StyleBody: View {
        let configuration: ButtonStyleConfiguration
        let fullWidth: Bool
        @State private var hovering = false
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            configuration.label
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.primary)
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, 9)
                .frame(maxWidth: fullWidth ? .infinity : nil)
                .background(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .fill(hovering ? Theme.hoverFill : Theme.softFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                        .stroke(Theme.hairline, lineWidth: 1)
                )
                .opacity(isEnabled ? (configuration.isPressed ? 0.7 : 1) : 0.45)
                .scaleEffect(configuration.isPressed ? 0.975 : 1)
                .contentShape(Rectangle())
                .onHover { hovering = $0 }
                .animation(Theme.Motion.snappy, value: hovering)
                .animation(Theme.Motion.snappy, value: configuration.isPressed)
        }
    }
}

extension ButtonStyle where Self == NikudPrimaryButtonStyle {
    static var nikudPrimary: NikudPrimaryButtonStyle { .init() }
    static func nikudPrimary(fullWidth: Bool) -> NikudPrimaryButtonStyle { .init(fullWidth: fullWidth) }
}

extension ButtonStyle where Self == NikudSecondaryButtonStyle {
    static var nikudSecondary: NikudSecondaryButtonStyle { .init() }
    static func nikudSecondary(fullWidth: Bool) -> NikudSecondaryButtonStyle { .init(fullWidth: fullWidth) }
}

// MARK: - Icon button

struct IconButton: View {
    let systemName: String
    var help: String = ""
    var tint: Color = .secondary
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(hovering ? Color.primary : tint)
                .frame(width: 28, height: 28)
                .background(Circle().fill(hovering ? Theme.hoverFill : Color.clear))
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .animation(Theme.Motion.snappy, value: hovering)
        .help(help)
    }
}

// MARK: - Surfaces

struct CardModifier: ViewModifier {
    var padding: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
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

extension View {
    func card(padding: CGFloat = Theme.Spacing.md) -> some View {
        modifier(CardModifier(padding: padding))
    }
}

struct HoverRowModifier: ViewModifier {
    @State private var hovering = false

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.md, style: .continuous)
                    .fill(hovering ? Theme.hoverFill : Color.clear)
            )
            .onHover { hovering = $0 }
            .animation(Theme.Motion.snappy, value: hovering)
    }
}

extension View {
    func hoverRow() -> some View { modifier(HoverRowModifier()) }
}

// MARK: - Small components

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 10.5, weight: .semibold))
            .tracking(0.6)
            .foregroundStyle(.tertiary)
    }
}

struct Chip: View {
    let text: String
    var systemImage: String? = nil
    var tint: Color = .secondary

    var body: some View {
        HStack(spacing: 3) {
            if let systemImage {
                Image(systemName: systemImage).font(.system(size: 9, weight: .bold))
            }
            Text(text).font(.system(size: 10, weight: .semibold))
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(Capsule().fill(tint.opacity(0.14)))
    }
}

struct ProgressRing: View {
    var progress: Double
    var size: CGFloat = 20
    var lineWidth: CGFloat = 2.6

    var body: some View {
        ZStack {
            Circle().stroke(Theme.hairline, lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: max(0.001, min(progress, 1)))
                .stroke(Theme.brandGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(Theme.Motion.gentle, value: progress)
        }
        .frame(width: size, height: size)
    }
}

struct AnimatedCheck: View {
    var size: CGFloat = 20
    var tint: Color = .green
    @State private var shown = false

    var body: some View {
        Image(systemName: "checkmark.circle.fill")
            .font(.system(size: size))
            .foregroundStyle(tint)
            .scaleEffect(shown ? 1 : 0.3)
            .opacity(shown ? 1 : 0)
            .onAppear { withAnimation(Theme.Motion.pop) { shown = true } }
    }
}

/// Three pulsing dots used to signal that the model is generating.
struct ThinkingDots: View {
    var tint: Color = Theme.accent
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.26, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(tint)
                    .frame(width: 5, height: 5)
                    .opacity(phase == index ? 1 : 0.25)
                    .scaleEffect(phase == index ? 1 : 0.7)
            }
        }
        .onReceive(timer) { _ in
            withAnimation(Theme.Motion.gentle) { phase = (phase + 1) % 3 }
        }
    }
}
