import SwiftUI

/// A card showing a metric with title, value, and usage bar
struct MetricCardView<Content: View>: View {
    let title: String
    let systemImage: String
    let content: () -> Content

    init(title: String, systemImage: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .frame(width: 14, alignment: .center)
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.tertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            content()
        }
        .padding(12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(AppColors.cardBackground.opacity(0.5))
        }
    }
}
