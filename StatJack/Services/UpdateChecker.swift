import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class UpdateChecker {
    static let shared = UpdateChecker()

    private static let owner = "burakereno"
    private static let repo = "statjack"
    private static let assetName = "StatJack.dmg"
    private static let checkInterval: TimeInterval = 2 * 60 * 60

    private(set) var latestVersion: String?
    private(set) var downloadURL: URL?
    private(set) var isChecking = false
    private(set) var isDownloading = false
    private(set) var downloadProgress: Double = 0
    private(set) var lastError: String?

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    var updateAvailable: Bool {
        guard let latest = latestVersion else { return false }
        return Self.compare(latest, isNewerThan: currentVersion)
    }

    private var timer: Timer?

    private init() {}

    func start() {
        Task { await checkForUpdates() }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { _ in
            Task { @MainActor in await UpdateChecker.shared.checkForUpdates() }
        }
    }

    func checkForUpdates() async {
        guard !isChecking else { return }
        isChecking = true
        lastError = nil
        defer { isChecking = false }

        let url = URL(string: "https://api.github.com/repos/\(Self.owner)/\(Self.repo)/releases/latest")!
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("StatJack-UpdateChecker", forHTTPHeaderField: "User-Agent")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
            let tag = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName
            latestVersion = tag
            downloadURL = release.assets.first(where: { $0.name == Self.assetName })?.browserDownloadURL
        } catch {
            lastError = error.localizedDescription
        }
    }

    func downloadAndInstall() {
        guard let url = downloadURL, !isDownloading else { return }
        isDownloading = true
        downloadProgress = 0
        lastError = nil

        let task = URLSession.shared.downloadTask(with: url) { [weak self] tmpURL, _, error in
            Task { @MainActor in
                guard let self else { return }
                defer {
                    self.isDownloading = false
                    self.downloadProgress = 0
                }
                if let error {
                    self.lastError = error.localizedDescription
                    return
                }
                guard let tmpURL else {
                    self.lastError = "Download failed"
                    return
                }

                let downloads = try? FileManager.default.url(
                    for: .downloadsDirectory,
                    in: .userDomainMask,
                    appropriateFor: nil,
                    create: true
                )
                let fileName = "StatJack-\(self.latestVersion ?? "latest").dmg"
                let dest = (downloads ?? FileManager.default.temporaryDirectory)
                    .appendingPathComponent(fileName)

                try? FileManager.default.removeItem(at: dest)
                do {
                    try FileManager.default.moveItem(at: tmpURL, to: dest)
                    NSWorkspace.shared.open(dest)
                } catch {
                    self.lastError = error.localizedDescription
                }
            }
        }

        let observation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            Task { @MainActor in
                self?.downloadProgress = progress.fractionCompleted
            }
        }
        progressObservation = observation
        task.resume()
    }

    private var progressObservation: NSKeyValueObservation?

    // MARK: - Semver compare

    static func compare(_ a: String, isNewerThan b: String) -> Bool {
        let pa = parse(a)
        let pb = parse(b)
        for i in 0..<max(pa.count, pb.count) {
            let ai = i < pa.count ? pa[i] : 0
            let bi = i < pb.count ? pb[i] : 0
            if ai != bi { return ai > bi }
        }
        return false
    }

    private static func parse(_ s: String) -> [Int] {
        s.split(separator: ".").map { Int($0) ?? 0 }
    }
}

private struct GitHubRelease: Decodable {
    let tagName: String
    let assets: [Asset]

    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: URL

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case assets
    }
}
