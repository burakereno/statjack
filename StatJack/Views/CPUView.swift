import SwiftUI

/// CPU usage view — overall percentage and user/system split
struct CPUView: View {
    let monitor: SystemMonitor

    private var cpu: CPUMonitor { monitor.cpuMonitor }

    var body: some View {
        MetricCardView(title: "Processor", systemImage: AppIcons.cpu) {
            VStack(spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text("\(Int(cpu.totalUsage))")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundStyle(AppColors.usageColor(for: cpu.totalUsage))
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.3), value: Int(cpu.totalUsage))
                    Text("%")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundStyle(.secondary)
                }

                UsageBarView(percentage: cpu.totalUsage, height: 6)

                HStack(spacing: 16) {
                    Label {
                        Text("User: \(String(format: "%.1f%%", cpu.userUsage))")
                    } icon: {
                        Circle()
                            .fill(.blue.opacity(0.7))
                            .frame(width: 6, height: 6)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                    Label {
                        Text("System: \(String(format: "%.1f%%", cpu.systemUsage))")
                    } icon: {
                        Circle()
                            .fill(.red.opacity(0.7))
                            .frame(width: 6, height: 6)
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)

                    Spacer()
                }
            }
        }
    }
}
