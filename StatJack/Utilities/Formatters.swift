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

    private static let bytesPerDiskGB: UInt64 = 1_000_000_000

    /// Disk capacity uses decimal GB; memory and transfer rates use binary units.
    static func formatDiskFreeSpace(_ bytes: UInt64) -> String {
        String(format: "%.1f GB", Double(bytes) / Double(bytesPerDiskGB))
    }

    static func menuBarDiskFreeSpace(_ bytes: UInt64) -> String {
        "\(bytes / bytesPerDiskGB)GB"
    }

    static func formatDiskCapacity(_ bytes: UInt64) -> String {
        String(format: "%.1fG", Double(bytes) / Double(bytesPerDiskGB))
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

    /// Use the actual rounded rate; 500K and 500M must not both saturate at 99.
    static func formatSpeedCompact(_ bytesPerSecond: Double) -> String {
        let units: [(Double, String)] = [(1_073_741_824, "G"), (1_048_576, "M"), (1_024, "K")]
        for (divisor, suffix) in units where bytesPerSecond >= divisor {
            return String(format: "%.0f", bytesPerSecond / divisor) + suffix
        }
        return "0K"
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
