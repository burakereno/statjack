import SwiftUI

/// Settings view with native Toggle switches
struct SettingsView: View {
    let monitor: SystemMonitor
    @Bindable var settings = AppSettings.shared

    var body: some View {
        VStack(spacing: 12) {
            // Menu Bar Display
            MetricCardView(title: "Menu Bar Display", systemImage: AppIcons.menuBar) {
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

            // Live Preview
            MetricCardView(title: "Preview", systemImage: AppIcons.preview) {
                HStack {
                    Spacer()
                    menuBarPreview
                        .padding(.vertical, 6)
                        .padding(.horizontal, 14)
                        .background {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.primary.opacity(0.08))
                        }
                    Spacer()
                }
            }

            // About
            MetricCardView(title: "About", systemImage: AppIcons.about) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("StatJack")
                                .font(.system(size: 13, weight: .bold))
                            Text("v1.0")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }
                        Text("Lightweight system monitor for macOS")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
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
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(disabled ? .tertiary : .secondary)
                .frame(width: 18, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(disabled ? .tertiary : .primary)
                Text(subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .controlSize(.small)
                .labelsHidden()
                .disabled(disabled)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Menu Bar Preview

    private var menuBarPreview: some View {
        Group {
            if settings.iconOnly || (!settings.showCPU && !settings.showRAM && !settings.showNetwork) {
                Image(systemName: AppIcons.app)
                    .font(.system(size: 13))
            } else {
                HStack(spacing: 8) {
                    if settings.showCPU {
                        HStack(spacing: 3) {
                            Image(systemName: AppIcons.cpu).font(.system(size: 10))
                            Text(monitor.menuBarCPU).font(.system(size: 11, weight: .medium, design: .monospaced))
                        }
                    }
                    if settings.showRAM {
                        HStack(spacing: 3) {
                            Image(systemName: AppIcons.ram).font(.system(size: 10))
                            Text(monitor.menuBarRAM).font(.system(size: 11, weight: .medium, design: .monospaced))
                        }
                    }
                    if settings.showNetwork {
                        HStack(spacing: 3) {
                            Image(systemName: AppIcons.network).font(.system(size: 10))
                            Text(monitor.menuBarNet).font(.system(size: 11, weight: .medium, design: .monospaced))
                        }
                    }
                }
            }
        }
        .foregroundStyle(.primary)
    }
}
