import SwiftUI

/// Main content view — single scrollable dashboard, no tabs
struct ContentView: View {
    let monitor: SystemMonitor
    @State private var showSettings = false
    @Bindable private var updater = UpdateChecker.shared

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider().opacity(0.5)

            ZStack {
                if showSettings {
                    ScrollView {
                        SettingsView(monitor: monitor)
                            .padding(.horizontal, 12)
                            .padding(.top, 10)
                            .padding(.bottom, 12)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                } else {
                    // All stats in one scroll
                    ScrollView {
                        VStack(spacing: 10) {
                            PublicIPRow()
                            SummaryRibbonView(monitor: monitor)
                            CPUView(monitor: monitor)
                            MemoryView(monitor: monitor)
                            NetworkView(monitor: monitor)
                            GPUView(monitor: monitor)
                            ThermalView(monitor: monitor)
                        }
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 12)
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .animation(.snappy(duration: 0.24), value: showSettings)

            Divider().opacity(0.5)

            // Footer
            footerView
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: AppIcons.app)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.primary)
                Text("StatJack")
                    .font(.system(size: 14, weight: .bold))
            }

            Spacer()

            HStack(spacing: 10) {
                Button(action: openActivityMonitor) {
                    Image(systemName: AppIcons.activityMonitor)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() }
                    else { NSCursor.pop() }
                }
                .help("Open Activity Monitor")

                Button(action: {
                    withAnimation(.snappy(duration: 0.24)) {
                        showSettings.toggle()
                    }
                }) {
                    Image(systemName: showSettings ? AppIcons.close : AppIcons.settings)
                        .font(.system(size: 14))
                        .foregroundStyle(showSettings ? .primary : .secondary)
                        .contentTransition(.symbolEffect(.replace))
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    if hovering { NSCursor.pointingHand.push() }
                    else { NSCursor.pop() }
                }
                .help(showSettings ? "Close Settings" : "Settings")
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private func openActivityMonitor() {
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        NSWorkspace.shared.open(url)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            Image(systemName: AppIcons.clock)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
            Text("Uptime: \(Formatters.formatUptime(monitor.uptime))")
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.tertiary)

            Spacer()

            if updater.updateAvailable, let latest = updater.latestVersion {
                UpdateButton(version: latest)
            } else {
                Text("Version \(appVersion)")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Button(action: {
                NSApplication.shared.terminate(nil)
            }) {
                Text("Quit")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.06))
                    }
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() }
                else { NSCursor.pop() }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }
}

private struct SummaryRibbonView: View {
    let monitor: SystemMonitor

    private let columns = Array(
        repeating: GridItem(.flexible(minimum: 0), spacing: 5),
        count: 5
    )

    var body: some View {
        LazyVGrid(columns: columns, spacing: 5) {
            ForEach(metrics) { metric in
                SummaryMetricTile(metric: metric)
            }
        }
    }

    private var metrics: [SummaryMetric] {
        let cpuUsage = monitor.cpuMonitor.totalUsage
        let ramUsage = monitor.memoryMonitor.memoryUsage.usedPercentage
        let networkUsage = monitor.networkMonitor.networkUsage
        let gpuUsage = monitor.gpuMonitor.utilization
        let thermalReading = monitor.thermalMonitor.reading

        return [
            SummaryMetric(
                id: "cpu",
                label: "CPU",
                value: "\(Int(cpuUsage))%",
                systemImage: AppIcons.cpu,
                color: AppColors.usageColor(for: cpuUsage)
            ),
            SummaryMetric(
                id: "ram",
                label: "RAM",
                value: "\(Int(ramUsage))%",
                systemImage: AppIcons.ram,
                color: AppColors.usageColor(for: ramUsage)
            ),
            SummaryMetric(
                id: "network",
                label: "NET",
                value: "↑\(Formatters.formatSpeedCompact(networkUsage.uploadSpeed)) ↓\(Formatters.formatSpeedCompact(networkUsage.downloadSpeed))",
                systemImage: AppIcons.network,
                color: .cyan
            ),
            SummaryMetric(
                id: "gpu",
                label: "GPU",
                value: gpuUsage.map { "\(Int($0))%" } ?? "--",
                systemImage: AppIcons.gpu,
                color: gpuUsage.map(AppColors.usageColor(for:)) ?? .secondary
            ),
            SummaryMetric(
                id: "temp",
                label: "TEMP",
                value: thermalReading.map { "\(Int($0.average))°" } ?? "--",
                systemImage: AppIcons.temperature,
                color: thermalReading.map { tempColor($0.average) } ?? .secondary
            )
        ]
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

private struct SummaryMetric: Identifiable {
    let id: String
    let label: String
    let value: String
    let systemImage: String
    let color: Color
}

private struct SummaryMetricTile: View {
    let metric: SummaryMetric

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 3) {
                Image(systemName: metric.systemImage)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)

                Text(metric.label)
                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Text(metric.value)
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .foregroundStyle(metric.color)
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity)
        }
        .frame(height: 42)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .background {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.primary.opacity(0.035))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.primary.opacity(0.055), lineWidth: 1)
        }
    }
}
