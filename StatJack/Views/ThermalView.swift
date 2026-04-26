import SwiftUI

struct ThermalView: View {
    let monitor: SystemMonitor

    private var thermal: ThermalMonitor { monitor.thermalMonitor }

    /// Visual temperature scale runs 30°C → 100°C.
    private let tempMin: Double = 30
    private let tempMax: Double = 100

    var body: some View {
        if let reading = thermal.reading {
            MetricCardView(title: "Temperature", systemImage: "thermometer", showIcon: false) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .firstTextBaseline, spacing: 1) {
                        Text("\(Int(reading.average))")
                            .font(.system(size: 22, weight: .bold, design: .monospaced))
                            .foregroundStyle(tempColor(reading.average))
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.3), value: Int(reading.average))
                        Text("°C")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }

                    TemperatureBar(
                        average: reading.average,
                        peak: reading.peak,
                        min: tempMin,
                        max: tempMax
                    )

                    SparklineView(
                        values: monitor.tempHistory,
                        color: tempColor(reading.average),
                        maxValue: tempMax
                    )

                    HStack(spacing: 12) {
                        thermalLegend(label: "AVG", value: "\(Int(reading.average))°", color: tempColor(reading.average))
                        thermalLegend(label: "PEAK", value: "\(Int(reading.peak))°", color: tempColor(reading.peak))
                        thermalLegend(label: "SENSORS", value: "\(reading.count)", color: .gray)
                        Spacer()
                    }
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

    private func tempColor(_ celsius: Double) -> Color {
        switch celsius {
        case ..<60:   return .green
        case 60..<75: return .yellow
        case 75..<90: return .orange
        default:      return .red
        }
    }
}

private struct TemperatureBar: View {
    let average: Double
    let peak: Double
    let min: Double
    let max: Double

    var body: some View {
        GeometryReader { geo in
            let avgRatio = ratio(average, in: geo.size.width)
            let peakRatio = ratio(peak, in: geo.size.width)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.green, .yellow, .orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 7)
                    .opacity(0.25)

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [.green, .yellow, .orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: avgRatio, height: 7)

                if peak > average {
                    Rectangle()
                        .fill(Color.white.opacity(0.85))
                        .frame(width: 2, height: 11)
                        .offset(x: peakRatio - 1)
                }
            }
        }
        .frame(height: 11)
    }

    private func ratio(_ value: Double, in width: CGFloat) -> CGFloat {
        let clamped = Swift.min(Swift.max(value, min), max)
        let normalized = (clamped - min) / (max - min)
        return CGFloat(normalized) * width
    }
}
