import Foundation
import Observation
import ServiceManagement
import UserNotifications

extension Notification.Name {
    /// Posted whenever an app setting changes. AppDelegate
    /// listens for this so the status item updates immediately instead of
    /// waiting for the next monitoring tick.
    static let statJackSettingsChanged = Notification.Name("StatJackSettingsChanged")
}

/// Persistent app settings with native toggle support
@Observable
final class AppSettings {
    static let shared = AppSettings()

    /// If true, show only the gauge icon — all other toggles disabled
    var iconOnly: Bool {
        didSet {
            UserDefaults.standard.set(iconOnly, forKey: "iconOnly")
            notifyChanged()
        }
    }

    /// Show CPU percentage in menu bar
    var showCPU: Bool {
        didSet {
            UserDefaults.standard.set(showCPU, forKey: "showCPU")
            notifyChanged()
        }
    }

    /// Show RAM percentage in menu bar
    var showRAM: Bool {
        didSet {
            UserDefaults.standard.set(showRAM, forKey: "showRAM")
            notifyChanged()
        }
    }

    /// Show network speed in menu bar
    var showNetwork: Bool {
        didSet {
            UserDefaults.standard.set(showNetwork, forKey: "showNetwork")
            notifyChanged()
        }
    }

    /// Show GPU usage in menu bar
    var showGPU: Bool {
        didSet {
            UserDefaults.standard.set(showGPU, forKey: "showGPU")
            notifyChanged()
        }
    }

    /// Show CPU/SoC temperature in menu bar
    var showTemperature: Bool {
        didSet {
            UserDefaults.standard.set(showTemperature, forKey: "showTemperature")
            notifyChanged()
        }
    }

    /// Show StatJack in the Dock
    var showDockIcon: Bool {
        didSet {
            UserDefaults.standard.set(showDockIcon, forKey: "showDockIcon")
            notifyChanged()
        }
    }

    /// Show CPU percentage as the Dock icon badge
    var showDockBadge: Bool {
        didSet {
            UserDefaults.standard.set(showDockBadge, forKey: "showDockBadge")
            notifyChanged()
        }
    }

    /// Launch StatJack automatically when you log in
    var launchAtLogin: Bool {
        didSet {
            UserDefaults.standard.set(launchAtLogin, forKey: "launchAtLogin")
            applyLaunchAtLogin()
        }
    }

    /// Notify when CPU usage exceeds threshold
    var cpuAlertEnabled: Bool {
        didSet {
            UserDefaults.standard.set(cpuAlertEnabled, forKey: "cpuAlertEnabled")
            if cpuAlertEnabled { Self.requestNotificationAuth() }
        }
    }

    /// CPU alert threshold (percentage 0-100)
    var cpuAlertThreshold: Double {
        didSet { UserDefaults.standard.set(cpuAlertThreshold, forKey: "cpuAlertThreshold") }
    }

    /// Notify when memory usage exceeds threshold
    var ramAlertEnabled: Bool {
        didSet {
            UserDefaults.standard.set(ramAlertEnabled, forKey: "ramAlertEnabled")
            if ramAlertEnabled { Self.requestNotificationAuth() }
        }
    }

    /// RAM alert threshold (percentage 0-100)
    var ramAlertThreshold: Double {
        didSet { UserDefaults.standard.set(ramAlertThreshold, forKey: "ramAlertThreshold") }
    }

    private static func requestNotificationAuth() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    private func applyLaunchAtLogin() {
        let service = SMAppService.mainApp
        do {
            if launchAtLogin {
                if service.status != .enabled {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
        } catch {
            NSLog("StatJack: launch-at-login update failed: \(error.localizedDescription)")
        }
    }

    private func notifyChanged() {
        NotificationCenter.default.post(name: .statJackSettingsChanged, object: self)
    }

    private init() {
        let defaults = UserDefaults.standard

        // Default: icon only OFF, CPU ON, others OFF
        self.iconOnly = defaults.object(forKey: "iconOnly") as? Bool ?? false
        self.showCPU = defaults.object(forKey: "showCPU") as? Bool ?? true
        self.showRAM = defaults.object(forKey: "showRAM") as? Bool ?? false
        self.showNetwork = defaults.object(forKey: "showNetwork") as? Bool ?? false
        self.showGPU = defaults.object(forKey: "showGPU") as? Bool ?? false
        self.showTemperature = defaults.object(forKey: "showTemperature") as? Bool ?? false
        self.showDockIcon = defaults.object(forKey: "showDockIcon") as? Bool ?? false
        self.showDockBadge = defaults.object(forKey: "showDockBadge") as? Bool ?? false
        self.launchAtLogin = SMAppService.mainApp.status == .enabled
        self.cpuAlertEnabled = defaults.object(forKey: "cpuAlertEnabled") as? Bool ?? false
        self.cpuAlertThreshold = defaults.object(forKey: "cpuAlertThreshold") as? Double ?? 90
        self.ramAlertEnabled = defaults.object(forKey: "ramAlertEnabled") as? Bool ?? false
        self.ramAlertThreshold = defaults.object(forKey: "ramAlertThreshold") as? Double ?? 85
    }
}
