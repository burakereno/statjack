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
            MetricCardView(title: "App Behavior", systemImage: AppIcons.dock, showIcon: false) {
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
                .controlSize(.regular)
                .labelsHidden()
                .disabled(disabled)
        }
        .padding(.vertical, 4)
    }

}
