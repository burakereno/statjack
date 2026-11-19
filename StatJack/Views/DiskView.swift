import SwiftUI

struct DiskView: View {
    let monitor: SystemMonitor

    private var disk: DiskMonitor { monitor.diskMonitor }
    private var usage: DiskUsage { disk.diskUsage }

    var body: some View {
        MetricCardView(title: "Disk", systemImage: AppIcons.disk) {
            if usage.total > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(Formatters.formatDiskCapacity(usage.used))
                            .font(.system(size: 18, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppColors.usageColor(for: usage.usedPercentage))
                            .contentTransition(.numericText())
                        Text("/ \(Formatters.formatDiskCapacity(usage.total))")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    UsageBarView(percentage: usage.usedPercentage, height: 7)

                    HStack(spacing: 12) {
                        diskLegend("USED", value: Formatters.formatDiskCapacity(usage.used), color: .orange)
                        diskLegend("FREE", value: Formatters.formatDiskCapacity(usage.available), color: .green)
                        Spacer()
                    }
                }
            } else {
                Text("Disk space unavailable")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func diskLegend(_ label: String, value: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color.opacity(0.8))
                .frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}
