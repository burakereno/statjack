import SwiftUI

struct GPUView: View {
    let monitor: SystemMonitor

    private var gpu: GPUMonitor { monitor.gpuMonitor }

    var body: some View {
        if let usage = gpu.utilization {
            MetricCardView(title: "GPU", systemImage: "cpu", showIcon: false) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("\(Int(usage))")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(AppColors.usageColor(for: usage))
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.3), value: Int(usage))
                        Text("%")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    UsageBarView(percentage: usage, height: 7)

                    SparklineView(
                        values: monitor.gpuHistory,
                        color: AppColors.usageColor(for: usage),
                        maxValue: 100
                    )
                }
            }
        }
    }
}
