import Foundation

/// Emits one alert per high-usage episode, with a five-minute cooldown.
struct DiskAlertState {
    private var lastAlert: Date?
    private var isSnoozed = false

    mutating func shouldNotify(
        usage: DiskUsage,
        enabled: Bool,
        threshold: Double,
        now: Date
    ) -> Bool {
        guard enabled else {
            isSnoozed = false
            return false
        }
        guard usage.total > 0 else { return false }

        if usage.usedPercentage < max(0, threshold - 5) {
            isSnoozed = false
            return false
        }
        guard usage.usedPercentage >= threshold, !isSnoozed else { return false }
        if let lastAlert, now.timeIntervalSince(lastAlert) < 300 { return false }

        lastAlert = now
        isSnoozed = true
        return true
    }
}
