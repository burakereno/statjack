import SwiftUI

struct ThermalView: View {
    let monitor: SystemMonitor

    private var thermal: ThermalMonitor { monitor.thermalMonitor }
    private var condition: ThermalCondition { thermal.condition }

    var body: some View {
        MetricCardView(title: "Thermal State", systemImage: "thermometer", showIcon: false) {
            SparklineView(
                values: monitor.thermalHistory,
                color: conditionColor,
                maxValue: 100,
                height: 18,
                showsFill: false
            )
            .frame(width: 110, height: 18)
            .opacity(0.9)
        } content: {
            VStack(alignment: .leading, spacing: 6) {
                Text(condition.title)
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundStyle(conditionColor)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: condition)

                UsageBarView(percentage: condition.level, height: 7)

                HStack(spacing: 12) {
                    thermalLegend(label: "STATE", value: condition.compactLabel, color: conditionColor)
                    thermalLegend(label: "IMPACT", value: condition.impact, color: conditionColor)
                    Spacer()
                }
            }
        }
    }

    private func thermalLegend(label: String, value: String, color: Color) -> some View {
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

    private var conditionColor: Color {
        switch condition {
        case .nominal: .green
        case .fair: .yellow
        case .serious: .orange
        case .critical: .red
        }
    }
}
