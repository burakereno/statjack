import SwiftUI

/// A card showing a metric with title, value, and usage bar
struct MetricCardView<Content: View>: View {
    let title: String
    let systemImage: String
    let showIcon: Bool
    let content: () -> Content
    @Environment(\.colorScheme) private var colorScheme

    init(title: String, systemImage: String, showIcon: Bool = true, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.showIcon = showIcon
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                if showIcon {
                    Image(systemName: systemImage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(headerForeground)
                        .frame(width: 14, alignment: .center)
                }
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(headerForeground)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            content()
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(cardFill)
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(cardHighlight, lineWidth: 0.5)
                }
                .shadow(color: cardShadow, radius: 8, y: 2)
        }
    }

    private var cardFill: Color {
        if colorScheme == .dark {
            return Color.black.opacity(0.16)
        }
        return Color.black.opacity(0.03)
    }

    private var cardHighlight: Color {
        if colorScheme == .dark {
            return Color.white.opacity(0.07)
        }
        return Color.black.opacity(0.045)
    }

    private var cardShadow: Color {
        colorScheme == .dark ? Color.black.opacity(0.32) : Color.black.opacity(0.065)
    }

    private var headerForeground: Color {
        if colorScheme == .dark {
            return Color(nsColor: .secondaryLabelColor)
        }
        return Color(nsColor: .tertiaryLabelColor)
    }

}
