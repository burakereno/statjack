import SwiftUI

/// Reusable progress bar with usage-based gradient coloring
struct UsageBarView: View {
    let percentage: Double
    let height: CGFloat
    let showLabel: Bool

    /// Animation is suppressed on the very first render so a freshly-appearing
    /// bar (e.g. GPU / Temp when the popover opens for the first time) doesn't
    /// slide in from 0 — we want it to appear at its real width instantly.
    @State private var enableAnimation = false

    init(percentage: Double, height: CGFloat = 8, showLabel: Bool = false) {
        self.percentage = min(max(percentage, 0), 100)
        self.height = height
        self.showLabel = showLabel
    }

    var body: some View {
        HStack(spacing: 8) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(Color.primary.opacity(0.08))

                    // Filled portion
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(AppColors.usageGradient(for: percentage))
                        .frame(width: max(0, geometry.size.width * percentage / 100))
                        .animation(enableAnimation ? .easeInOut(duration: 0.5) : nil, value: percentage)
                }
            }
            .frame(height: height)

            if showLabel {
                Text("\(Int(percentage))%")
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(AppColors.usageColor(for: percentage))
                    .frame(width: 40, alignment: .trailing)
                    .contentTransition(.numericText())
                    .animation(enableAnimation ? .easeInOut : nil, value: Int(percentage))
            }
        }
        .onAppear {
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(120))
                enableAnimation = true
            }
        }
    }
}
