import Foundation

/// Tracks one CPU, RAM or disk episode. Only an accepted notification consumes it.
@MainActor
final class UsageAlert {
    private var lastDelivered: TimeInterval?
    private var snoozed = false
    private var pending: UUID?

    func reset() {
        lastDelivered = nil
        snoozed = false
        pending = nil
    }

    func evaluate(value: Double, threshold: Double, authorized: Bool,
                  now: TimeInterval = ProcessInfo.processInfo.systemUptime,
                  deliver: () async throws -> Void) async {
        if value < threshold && (value < threshold - 5 || value == 0) {
            snoozed = false
            return
        }
        guard authorized, value >= threshold, !snoozed, pending == nil,
              lastDelivered.map({ now - $0 >= 300 }) ?? true else { return }
        let id = UUID()
        pending = id
        defer { if pending == id { pending = nil } }
        do {
            try await deliver()
            guard pending == id else { return }
            lastDelivered = now
            snoozed = true
        } catch {
            // Retry a still-high metric on a later sample.
        }
    }
}
