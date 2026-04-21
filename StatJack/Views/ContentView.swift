import SwiftUI

/// Main content view — single scrollable dashboard, no tabs
struct ContentView: View {
    let monitor: SystemMonitor
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider().opacity(0.5)

            if showSettings {
                ScrollView {
                    SettingsView(monitor: monitor)
                        .padding(.horizontal, 12)
                        .padding(.top, 10)
                        .padding(.bottom, 12)
                }
            } else {
                // All stats in one scroll
                ScrollView {
                    VStack(spacing: 10) {
                        CPUView(monitor: monitor)
                        MemoryView(monitor: monitor)
                        NetworkView(monitor: monitor)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 10)
                    .padding(.bottom, 12)
                }
            }

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

            Button(action: {
                showSettings.toggle()
            }) {
                Image(systemName: showSettings ? AppIcons.close : AppIcons.settings)
                    .font(.system(size: 14))
                    .foregroundStyle(showSettings ? .primary : .secondary)
            }
            .buttonStyle(.plain)
            .onHover { hovering in
                if hovering { NSCursor.pointingHand.push() }
                else { NSCursor.pop() }
            }
            .help(showSettings ? "Close Settings" : "Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
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
