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
                        title: "CPU Badge",
                        subtitle: "Show CPU percentage on the Dock icon",
                        icon: AppIcons.cpu,
                        isOn: $settings.showDockBadge,
                        disabled: !settings.showDockIcon
                    )
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

            // About
            MetricCardView(title: "About", systemImage: AppIcons.about, showIcon: false) {
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
                    }
                    Spacer()
                    if updater.updateAvailable, let latest = updater.latestVersion {
                        UpdateButton(version: latest)
                    }
                }
            }
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
        HStack(alignment: .center, spacing: 10) {
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
                .controlSize(.mini)
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
            HStack(alignment: .center, spacing: 10) {
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
                    .controlSize(.mini)
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
