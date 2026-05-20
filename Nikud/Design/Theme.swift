import SwiftUI

/// Central design tokens for Nikud: spacing, radii, motion, and color.
enum Theme {

    enum Spacing {
        static let xxs: CGFloat = 3
        static let xs: CGFloat = 6
        static let sm: CGFloat = 10
        static let md: CGFloat = 14
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
    }

    enum Radius {
        static let sm: CGFloat = 7
        static let md: CGFloat = 11
        static let lg: CGFloat = 16
        static let xl: CGFloat = 22
    }

    enum Motion {
        /// Standard transition for layout and state changes.
        static let spring = Animation.spring(response: 0.36, dampingFraction: 0.82)
        /// Quick feedback for hover and press.
        static let snappy = Animation.spring(response: 0.24, dampingFraction: 0.80)
        /// Lively spring with a touch of bounce for appearance.
        static let pop = Animation.spring(response: 0.34, dampingFraction: 0.64)
        /// Plain fade for subtle changes.
        static let gentle = Animation.easeInOut(duration: 0.20)
    }

    // MARK: Color

    static let accent = Color.accentColor

    static let brandGradient = LinearGradient(
        colors: [
            Color(red: 0.565, green: 0.502, blue: 0.965),
            Color(red: 0.404, green: 0.318, blue: 0.835)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Faint stroke separating surfaces.
    static let hairline = Color.primary.opacity(0.09)
    /// Faint fill for inset/track surfaces.
    static let softFill = Color.primary.opacity(0.055)
    /// Slightly stronger fill for hovered rows.
    static let hoverFill = Color.primary.opacity(0.085)
}
