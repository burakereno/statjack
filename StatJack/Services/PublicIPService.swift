import Foundation
import Observation

@MainActor
@Observable
final class PublicIPService {
    static let shared = PublicIPService()

    private(set) var publicIP: String?
    private(set) var isFetching = false
    private(set) var lastError: String?

    private static let endpoint = URL(string: "https://api.ipify.org")!

    private init() {}

    func fetchIfNeeded() {
        guard publicIP == nil, !isFetching else { return }
        Task { await fetch() }
    }

    func refresh() {
        Task { await fetch() }
    }

    private func fetch() async {
        guard !isFetching else { return }
        isFetching = true
        lastError = nil
        defer { isFetching = false }

        var request = URLRequest(url: Self.endpoint, timeoutInterval: 10)
        request.setValue("StatJack", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            if let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !text.isEmpty
            {
                publicIP = text
            } else {
                lastError = "Empty response"
            }
        } catch {
            lastError = error.localizedDescription
        }
    }
}
