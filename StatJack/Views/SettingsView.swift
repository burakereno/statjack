import SwiftUI

/// Settings view with native Toggle switches
struct SettingsView: View {
    let monitor: SystemMonitor
    @Bindable var settings = AppSettings.shared
    @Bindable private var updater = UpdateChecker.shared

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var body: some View {
        VStack(spacing: 12) {
            // App Behavior
            MetricCardView(title: "Startup", systemImage: "power", showIcon: false) {
                toggleRow(
                    title: "Launch at Login",
                    subtitle: "Start StatJack automatically when you log in",
                    icon: "power",
                    isOn: $settings.launchAtLogin
                )
            }

            MetricCardView(title: "Dock", systemImage: AppIcons.dock, showIcon: false) {
                VStack(spacing: 0) {
                    toggleRow(
                        title: "Dock Icon",
                        subtitle: "Show StatJack in the Dock",
                        icon: AppIcons.dock,
                        isOn: $settings.showDockIcon
                    )

                    Divider().opacity(0.2).padding(.vertical, 2)

                    toggleRow(
                        title: "Badge",
                        subtitle: "Show a metric on the Dock icon",
                        icon: AppIcons.cpu,
                        isOn: $settings.showDockBadge,
                        disabled: !settings.showDockIcon
                    )

                    Divider().opacity(0.2).padding(.vertical, 2)

                    dockBadgeMetricRow(disabled: !settings.showDockIcon || !settings.showDockBadge)
                }
            }

            // Menu Bar Display
            MetricCardView(title: "Menu Bar Display", systemImage: AppIcons.menuBar, showIcon: false) {
                VStack(spacing: 0) {
                    toggleRow(
                        title: "Icon Only",
                        subtitle: "Show only the app icon",
                        icon: AppIcons.iconOnly,
                        isOn: $settings.iconOnly
                    )

                    Divider().opacity(0.2).padding(.vertical, 2)

                    toggleRow(
                        title: "CPU Usage",
                        subtitle: "e.g. 23%",
                        icon: AppIcons.cpu,
                        isOn: $settings.showCPU,
                        disabled: settings.iconOnly
                    )

                    Divider().opacity(0.2).padding(.vertical, 2)

                    toggleRow(
                        title: "RAM Usage",
                        subtitle: "e.g. 67%",
                        icon: AppIcons.ram,
                        isOn: $settings.showRAM,
                        disabled: settings.iconOnly
                    )

                    Divider().opacity(0.2).padding(.vertical, 2)

                    toggleRow(
                        title: "Disk Usage",
                        subtitle: "e.g. 71%",
                        icon: AppIcons.disk,
                        isOn: $settings.showDisk,
                        disabled: settings.iconOnly
                    )

                    Divider().opacity(0.2).padding(.vertical, 2)

                    toggleRow(
                        title: "Network Speed",
                        subtitle: "e.g. ↑1.2 ↓3.5",
                        icon: AppIcons.network,
                        isOn: $settings.showNetwork,
                        disabled: settings.iconOnly
                    )

                    Divider().opacity(0.2).padding(.vertical, 2)

                    toggleRow(
                        title: "GPU Usage",
                        subtitle: "e.g. 35%",
                        icon: AppIcons.gpu,
                        isOn: $settings.showGPU,
                        disabled: settings.iconOnly
                    )

                    Divider().opacity(0.2).padding(.vertical, 2)

                    toggleRow(
                        title: "Temperature",
                        subtitle: "e.g. 52°C",
                        icon: AppIcons.temperature,
                        isOn: $settings.showTemperature,
                        disabled: settings.iconOnly
                    )
                }
            }

            // Alerts
            MetricCardView(title: "Alerts", systemImage: "bell", showIcon: false) {
                VStack(spacing: 0) {
                    alertRow(
                        title: "CPU Alert",
                        subtitle: "Notify when CPU exceeds threshold",
                        icon: AppIcons.cpu,
                        isOn: $settings.cpuAlertEnabled,
                        threshold: $settings.cpuAlertThreshold
                    )

                    Divider().opacity(0.2).padding(.vertical, 2)

                    alertRow(
                        title: "RAM Alert",
                        subtitle: "Notify when memory exceeds threshold",
                        icon: AppIcons.ram,
                        isOn: $settings.ramAlertEnabled,
                        threshold: $settings.ramAlertThreshold
                    )
                }
            }

            // Refresh
            MetricCardView(title: "Refresh", systemImage: "timer", showIcon: false) {
                refreshIntervalRow()
            }

            // About
            MetricCardView(
                title: "About",
                systemImage: AppIcons.about,
                showIcon: false,
                headerAccessory: {
                    updateCheckButton
                }
            ) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("StatJack")
                                .font(.system(size: 13, weight: .bold))
                            Text("Version \(appVersion)")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                        Text("Lightweight system monitor for macOS")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        updateStatusText
                    }
                    Spacer()
                    if updater.updateAvailable, let latest = updater.latestVersion {
                        UpdateButton(version: latest)
                    }
                }
            }
        }
    }

    private var updateCheckButton: some View {
        Button {
            Task { await updater.checkForUpdates(force: true) }
        } label: {
            Text(updater.isChecking ? "Checking" : "Check")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(updater.isChecking ? .tertiary : .secondary)
                .frame(width: 74, height: 24)
                .background {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.primary.opacity(updater.isChecking ? 0.035 : 0.06))
                }
        }
        .buttonStyle(.plain)
        .frame(width: 74, height: 24)
        .contentShape(Rectangle())
        .disabled(updater.isChecking)
        .help(updater.isChecking ? "Checking for Updates" : "Check for Updates")
        .onHover { hovering in
            if hovering && !updater.isChecking { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
    }

    @ViewBuilder
    private var updateStatusText: some View {
        if updater.isChecking {
            Text("Checking for updates...")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        } else if updater.updateAvailable, let latest = updater.latestVersion {
            Text("Version \(latest) available")
                .font(.system(size: 10))
                .foregroundStyle(.orange)
        } else if updater.lastError != nil {
            Text("Update check failed")
                .font(.system(size: 10))
                .foregroundStyle(.red)
        } else if updater.lastCheckedAt != nil {
            Text("Up to date")
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Refresh Interval Row

    private func refreshIntervalRow() -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "timer")
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(.secondary)
                .frame(width: 20, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text("Menu Bar Refresh")
                    .font(.system(size: 12, weight: .medium))
                Text("Update visible menu bar metrics when StatJack is closed")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Picker("", selection: $settings.menuBarRefreshInterval) {
                ForEach(MenuBarRefreshInterval.allCases) { interval in
                    Text(interval.title).tag(interval)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .frame(width: 86)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Dock Badge Metric Row

    private func dockBadgeMetricRow(disabled: Bool = false) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon(for: settings.dockBadgeMetric))
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(disabled ? .tertiary : .secondary)
                .frame(width: 20, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text("Badge Metric")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(disabled ? .tertiary : .primary)
                Text("CPU, RAM, Temp, or GPU")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Picker("", selection: $settings.dockBadgeMetric) {
                ForEach(DockBadgeMetric.allCases) { metric in
                    Text(metric.title).tag(metric)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .controlSize(.small)
            .frame(width: 86)
            .disabled(disabled)
        }
        .padding(.vertical, 4)
    }

    private func icon(for metric: DockBadgeMetric) -> String {
        switch metric {
        case .cpu:
            AppIcons.cpu
        case .ram:
            AppIcons.ram
        case .temperature:
            AppIcons.temperature
        case .gpu:
            AppIcons.gpu
        }
    }

    // MARK: - Toggle Row

    private func toggleRow(
        title: String,
        subtitle: String,
        icon: String,
        isOn: Binding<Bool>,
        disabled: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .regular))
                .foregroundStyle(disabled ? .tertiary : .secondary)
                .frame(width: 20, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(disabled ? .tertiary : .primary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .disabled(disabled)
                .allowsHitTesting(false)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onTapGesture {
            guard !disabled else { return }
            isOn.wrappedValue.toggle()
        }
        .onHover { hovering in
            if hovering && !disabled { NSCursor.pointingHand.push() }
            else { NSCursor.pop() }
        }
    }

    // MARK: - Alert Row

    private func alertRow(
        title: String,
        subtitle: String,
        icon: String,
        isOn: Binding<Bool>,
        threshold: Binding<Double>
    ) -> some View {
        VStack(spacing: 4) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: 20, alignment: .center)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 12, weight: .medium))
                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)

                Toggle("", isOn: isOn)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .labelsHidden()
                    .allowsHitTesting(false)
            }
            .contentShape(Rectangle())
            .onTapGesture { isOn.wrappedValue.toggle() }

            if isOn.wrappedValue {
                HStack(spacing: 8) {
                    Slider(value: threshold, in: 0...100, step: 5)
                        .controlSize(.small)
                    Text("\(Int(threshold.wrappedValue))%")
                        .font(.system(size: 11, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 32, alignment: .trailing)
                }
                .padding(.leading, 30)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.vertical, 4)
        .animation(.snappy(duration: 0.18), value: isOn.wrappedValue)
    }

}
