import SwiftUI

/// Color system for StatJack — usage-based gradient colors
enum AppColors {
    /// Returns color based on usage percentage (0-100)
    static func usageColor(for percentage: Double) -> Color {
        switch percentage {
        case 0..<50:
            return .green
        case 50..<80:
            return .orange
        default:
            return .red
        }
    }

    /// Gradient for usage bars
    static func usageGradient(for percentage: Double) -> LinearGradient {
        let color = usageColor(for: percentage)
        return LinearGradient(
            colors: [color.opacity(0.8), color],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// Subtle background for cards
    static let cardBackground = Color(nsColor: .controlBackgroundColor)

    /// Separator color
    static let separator = Color(nsColor: .separatorColor)

    /// Tab bar colors
    static let tabActive = Color.accentColor
    static let tabInactive = Color.secondary.opacity(0.5)

    /// Process rank indicator colors
    static let rankColors: [Color] = [
        .green,
        .blue,
        .orange,
        .purple,
        Color(nsColor: .systemGray)
    ]
}
