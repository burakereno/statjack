import SwiftUI

/// CPU usage view — overall percentage and user/system split
struct CPUView: View {
    let monitor: SystemMonitor

    private var cpu: CPUMonitor { monitor.cpuMonitor }

    var body: some View {
        MetricCardView(title: "Processor", systemImage: AppIcons.cpu) {
            SparklineView(
                values: monitor.cpuHistory,
                color: AppColors.usageColor(for: cpu.totalUsage),
                maxValue: 100,
                height: 18,
                showsFill: false
            )
            .frame(width: 110, height: 18)
            .opacity(0.9)
        } content: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .firstTextBaseline, spacing: 1) {
                    Text("\(Int(cpu.totalUsage))")
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundStyle(AppColors.usageColor(for: cpu.totalUsage))
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.3), value: Int(cpu.totalUsage))
                    Text("%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                UsageBarView(percentage: cpu.totalUsage, height: 7)

                HStack(spacing: 12) {
                    legendItem(color: .blue, label: "USR", value: cpu.userUsage)
                    legendItem(color: .red, label: "SYS", value: cpu.systemUsage)
                    Spacer()
                }
            }
        }
    }

    private func legendItem(color: Color, label: String, value: Double) -> some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color.opacity(0.8))
                .frame(width: 5, height: 5)
            Text(label)
                .font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(.tertiary)
                .tracking(0.5)
            Text(String(format: "%.1f%%", value))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.secondary)
        }
    }
}
