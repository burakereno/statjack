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

    /// Format speed for menu bar (compact). Always returns 2–4 characters so the
    /// status item width stays stable between updates.
    static func formatSpeedCompact(_ bytesPerSecond: Double) -> String {
        let kbps = bytesPerSecond / 1_024
        let mbps = kbps / 1_024

        if mbps >= 10 {
            return String(format: "%.0fM", mbps)
        } else if mbps >= 1 {
            return String(format: "%.1fM", mbps)
        } else if kbps >= 1 {
            return String(format: "%.0fK", kbps)
        }
        return "0K"
    }

    // MARK: - Time Formatting

    /// Format seconds to uptime string
    static func formatUptime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60

        var parts: [String] = []
        if days > 0 { parts.append("\(days)d") }
        if hours > 0 { parts.append("\(hours)h") }
        parts.append("\(minutes)m")

        return parts.joined(separator: " ")
    }
}
