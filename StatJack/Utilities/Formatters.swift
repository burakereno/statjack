import Foundation

/// Formatting utilities for bytes, speed, and time
enum Formatters {

    // MARK: - Bytes Formatting

    /// Format bytes to human-readable string (KB, MB, GB)
    static func formatBytes(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1_024
        let mb = kb / 1_024
        let gb = mb / 1_024

        if gb >= 1 {
            return String(format: "%.1f GB", gb)
        } else if mb >= 1 {
            return String(format: "%.1f MB", mb)
        } else if kb >= 1 {
            return String(format: "%.0f KB", kb)
        }
        return "\(bytes) B"
    }

    /// Format bytes to compact string (for tight spaces)
    static func formatBytesCompact(_ bytes: UInt64) -> String {
        let kb = Double(bytes) / 1_024
        let mb = kb / 1_024
        let gb = mb / 1_024

        if gb >= 100 {
            return String(format: "%.0fG", gb)
        } else if gb >= 1 {
            return String(format: "%.1fG", gb)
        } else if mb >= 100 {
            return String(format: "%.0fM", mb)
        } else if mb >= 1 {
            return String(format: "%.1fM", mb)
        } else {
            return String(format: "%.0fK", kb)
        }
    }

    // MARK: - Speed Formatting

    /// Format bytes per second to human-readable speed
    static func formatBytesPerSecond(_ bytesPerSecond: Double) -> String {
        let kbps = bytesPerSecond / 1_024
        let mbps = kbps / 1_024

        if mbps >= 1 {
            return String(format: "%.1f MB/s", mbps)
        } else if kbps >= 1 {
            return String(format: "%.1f KB/s", kbps)
        }
        return String(format: "%.0f B/s", bytesPerSecond)
    }

    /// Format speed for menu bar (compact). The numeric part is capped at two
    /// digits per unit so network segments stay readable in tight menu-bar space.
    static func formatSpeedCompact(_ bytesPerSecond: Double) -> String {
        let kbps = bytesPerSecond / 1_024
        let mbps = kbps / 1_024
        let gbps = mbps / 1_024

        if gbps >= 1 {
            return "\(cappedTwoDigitSpeed(gbps))G"
        } else if mbps >= 1 {
            return "\(cappedTwoDigitSpeed(mbps))M"
        } else if kbps >= 1 {
            return "\(cappedTwoDigitSpeed(kbps))K"
        }
        return "0K"
    }

    private static func cappedTwoDigitSpeed(_ value: Double) -> Int {
        min(99, max(1, Int(value.rounded())))
    }

    // MARK: - Time Formatting

    /// Format seconds to uptime string
    static func formatUptime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600

        if days > 0 {
            return "\(days)d \(hours)h"
        }
        return "\(hours)h"
    }
}
