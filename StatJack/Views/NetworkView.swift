import SwiftUI

/// Network usage view (system-wide upload/download speeds)
struct NetworkView: View {
    let monitor: SystemMonitor

    private var net: NetworkMonitor { monitor.networkMonitor }
    private var usage: NetworkUsage { net.networkUsage }

    var body: some View {
        VStack(spacing: 12) {
            // Upload speed
            MetricCardView(title: "Upload", systemImage: "arrow.up.circle") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(usage.uploadFormatted)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.blue)
                            .contentTransition(.numericText())
                            .animation(.easeInOut, value: usage.uploadFormatted)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.blue.opacity(0.3))
                }
            }

            // Download speed
            MetricCardView(title: "Download", systemImage: "arrow.down.circle") {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(usage.downloadFormatted)
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundStyle(.green)
                            .contentTransition(.numericText())
                            .animation(.easeInOut, value: usage.downloadFormatted)
                    }
                    Spacer()
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(.green.opacity(0.3))
                }
            }

            // Total transferred
            MetricCardView(title: "Session Total", systemImage: AppIcons.network) {
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sent")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                        Text(Formatters.formatBytes(usage.totalUploaded))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Received")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.tertiary)
                        Text(Formatters.formatBytes(usage.totalDownloaded))
                            .font(.system(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                }
            }
        }
    }
}
