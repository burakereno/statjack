import SwiftUI

/// Network usage view (system-wide upload/download speeds)
struct NetworkView: View {
    let monitor: SystemMonitor

    private var net: NetworkMonitor { monitor.networkMonitor }
    private var usage: NetworkUsage { net.networkUsage }

    var body: some View {
        MetricCardView(title: "Network", systemImage: AppIcons.network) {
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    speedRow(
                        symbol: "arrow.up",
                        label: "UP",
                        value: usage.uploadFormatted,
                        color: .blue
                    )
                    speedRow(
                        symbol: "arrow.down",
                        label: "DOWN",
                        value: usage.downloadFormatted,
                        color: .green
                    )
                }

                ZStack {
                    SparklineView(
                        values: monitor.netDownloadHistory,
                        color: .green
                    )
                    SparklineView(
                        values: monitor.netUploadHistory,
                        color: .blue
                    )
                }
                .frame(height: 22)

                Divider().opacity(0.2)

                HStack(spacing: 12) {
                    totalRow(
                        label: "SENT",
                        value: Formatters.formatBytes(usage.totalUploaded)
                    )
                    totalRow(
                        label: "RECV",
                        value: Formatters.formatBytes(usage.totalDownloaded)
                    )
                }
            }
        }
    }

    private func speedRow(symbol: String, label: String, value: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol)
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .tracking(0.5)
                Text(value)
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(color)
                    .contentTransition(.numericText())
                    .animation(.easeInOut, value: value)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func totalRow(label: String, value: String) -> some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 11, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }
}
