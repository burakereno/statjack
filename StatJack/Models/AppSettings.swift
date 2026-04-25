import Foundation
import Observation

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
        self.showDockIcon = defaults.object(forKey: "showDockIcon") as? Bool ?? false
        self.showDockBadge = defaults.object(forKey: "showDockBadge") as? Bool ?? false
    }
}
