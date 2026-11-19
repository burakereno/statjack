import AppKit
import Foundation
import Observation

@MainActor
@Observable
final class UpdateChecker {
    static let shared = UpdateChecker()

    private static let owner = "burakereno"
    private static let repo = "statjack"
    nonisolated private static let assetName = "StatJack.dmg"
    private static let manifestName = "StatJack.dmg.update.json"
    private static let productionBundleIdentifier = "com.statjack.app"
    private static let appBundleName = "StatJack.app"
    private static let executableName = "StatJack"
    private static let checkInterval: TimeInterval = 2 * 60 * 60
    private static let minimumManualCheckInterval: TimeInterval = 30 * 60
    private var lastCheckInstant: ContinuousClock.Instant?

    private(set) var latestVersion: String?
    private(set) var downloadURL: URL?
    private var manifestURL: URL?
    private(set) var isChecking = false
    private(set) var isDownloading = false
    private(set) var downloadProgress: Double = 0
    private(set) var lastError: String?
    private(set) var lastCheckedAt: Date?
    private(set) var lastCheckCompletedAt: Date?

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    var updateAvailable: Bool {
        guard isProductionBuild else { return false }
        guard let latestVersion else { return false }
        return Self.compare(latestVersion, isNewerThan: currentVersion)
    }

    var isUpToDate: Bool {
        guard let latestVersion, lastError == nil else { return false }
        return !Self.compare(latestVersion, isNewerThan: currentVersion)
    }

    private var timer: Timer?
    private var progressObservation: NSKeyValueObservation?

    private var isProductionBuild: Bool {
        Bundle.main.bundleIdentifier == Self.productionBundleIdentifier
            && Bundle.main.object(forInfoDictionaryKey: "StatJackDistribution") as? Bool == true
    }

    private init() {}

    func start() {
        guard isProductionBuild else { return }
        timer?.invalidate()
        Task { @MainActor in
            await UpdateChecker.shared.checkForUpdates(force: false, reportsErrors: false)
        }
        timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { _ in
            Task { @MainActor in
                await UpdateChecker.shared.checkForUpdates(force: false, reportsErrors: false)
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        progressObservation?.invalidate()
        progressObservation = nil
    }

    func checkForUpdates(force: Bool = false) async {
        await checkForUpdates(force: force, reportsErrors: force)
    }

    private func checkForUpdates(force: Bool, reportsErrors: Bool) async {
        guard isProductionBuild, !isChecking else { return }

        let start = ContinuousClock.now
        if !force,
           let lastCheckInstant,
           lastCheckInstant.duration(to: start) < .seconds(Self.minimumManualCheckInterval)
        {
            return
        }

        lastCheckedAt = Date()
        lastCheckInstant = start
        isChecking = true
        if reportsErrors {
            lastError = nil
        }

        do {
            let releaseInfo = try await Self.fetchLatestReleaseInfo()
            latestVersion = releaseInfo.version
            downloadURL = releaseInfo.downloadURL
            manifestURL = releaseInfo.manifestURL
            lastError = nil
        } catch {
            if reportsErrors {
                lastError = error.localizedDescription
            }
        }

        try? await ContinuousClock().sleep(until: start.advanced(by: .milliseconds(500)))

        lastCheckCompletedAt = Date()
        isChecking = false
    }

    func downloadAndInstall() {
        guard isProductionBuild else {
            lastError = "Updates are disabled for local builds."
            return
        }

        guard Bundle.main.bundlePath.hasPrefix("/Applications/") else {
            lastError = UpdateError.notInstalled.localizedDescription
            return
        }
        guard !isDownloading else { return }

        guard let downloadURL, let manifestURL, let latestVersion else {
            lastError = "Update download is unavailable."
            return
        }

        isDownloading = true
        downloadProgress = 0
        lastError = nil

        let task = URLSession.shared.downloadTask(with: downloadURL) { [weak self] tmpURL, response, error in
            // URLSession owns tmpURL only until this callback returns.
            let retained = Result { try Self.retainDownload(at: tmpURL, response: response, error: error) }
            Task { @MainActor in
                guard let self else {
                    if case .success(let file) = retained {
                        try? FileManager.default.removeItem(at: file.deletingLastPathComponent())
                    }
                    return
                }
                defer {
                    self.isDownloading = false
                    self.downloadProgress = 0
                }

                let destination: URL
                do {
                    destination = try retained.get()
                } catch {
                    self.lastError = error.localizedDescription
                    return
                }

                do {
                    let manifest = try await Self.fetchManifest(at: manifestURL)
                    let assetName = Self.assetName
                    let bundleIdentifier = Self.productionBundleIdentifier
                    try await Task.detached {
                        try UpdateSecurity.verify(
                            manifest: manifest,
                            artifactURL: destination,
                            expectedVersion: latestVersion,
                            expectedAsset: assetName,
                            expectedBundleIdentifier: bundleIdentifier
                        )
                    }.value
                    try self.installUpdate(
                        dmgURL: destination,
                        expectedVersion: latestVersion,
                        expectedSHA256: manifest.sha256.lowercased()
                    )
                } catch {
                    try? FileManager.default.removeItem(at: destination.deletingLastPathComponent())
                    self.lastError = error.localizedDescription
                }
            }
        }

        progressObservation = task.progress.observe(\.fractionCompleted) { [weak self] progress, _ in
            Task { @MainActor in
                self?.downloadProgress = progress.fractionCompleted
            }
        }
        task.resume()
    }

    nonisolated static func retainDownload(at url: URL?, response: URLResponse?, error: Error?) throws -> URL {
        if let error { throw error }
        guard let url, let http = response as? HTTPURLResponse,
              (200..<300).contains(http.statusCode) else { throw UpdateError.badResponse }
        let fm = FileManager.default
        let directory = fm.temporaryDirectory.appendingPathComponent("statjack-update-\(UUID().uuidString)", isDirectory: true)
        try fm.createDirectory(at: directory, withIntermediateDirectories: false, attributes: [.posixPermissions: 0o700])
        do {
            let destination = directory.appendingPathComponent(assetName)
            try fm.moveItem(at: url, to: destination)
            return destination
        } catch {
            try? fm.removeItem(at: directory)
            throw error
        }
    }

    private func installUpdate(dmgURL: URL, expectedVersion: String, expectedSHA256: String) throws {
        let currentBundle = URL(fileURLWithPath: Bundle.main.bundlePath)
        guard currentBundle.path.hasPrefix("/Applications/") else { throw UpdateError.notInstalled }
        try UpdateSecurity.launchInstaller(
            parentPID: ProcessInfo.processInfo.processIdentifier, dmgURL: dmgURL, targetURL: currentBundle,
            expectedBundleIdentifier: Self.productionBundleIdentifier, expectedVersion: expectedVersion,
            appBundleName: Self.appBundleName, executableName: Self.executableName, expectedSHA256: expectedSHA256
        )

        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            NSApp.terminate(nil)
        }
    }

    static func compare(_ a: String, isNewerThan b: String) -> Bool {
        let parsedA = parse(a)
        let parsedB = parse(b)

        for index in 0..<max(parsedA.count, parsedB.count) {
            let valueA = index < parsedA.count ? parsedA[index] : 0
            let valueB = index < parsedB.count ? parsedB[index] : 0
            if valueA != valueB { return valueA > valueB }
        }

        return false
    }

    private static func fetchLatestReleaseInfo() async throws -> UpdateReleaseInfo {
        let latestURL = URL(string: "https://github.com/\(owner)/\(repo)/releases/latest")!
        var request = URLRequest(url: latestURL, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 12
        request.setValue("text/html", forHTTPHeaderField: "Accept")
        request.setValue("StatJack-UpdateChecker", forHTTPHeaderField: "User-Agent")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateError.badResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw UpdateError.badStatus(httpResponse.statusCode)
        }
        guard let resolvedURL = httpResponse.url else {
            throw UpdateError.missingVersion
        }

        let releaseInfo = try releaseInfo(fromResolvedLatestURL: resolvedURL)
        try await validateDownloadURL(releaseInfo.downloadURL, assetName: assetName)
        try await validateDownloadURL(releaseInfo.manifestURL, assetName: manifestName)
        return releaseInfo
    }

    static func releaseInfo(fromResolvedLatestURL url: URL) throws -> UpdateReleaseInfo {
        let path = url.pathComponents
        guard url.scheme == "https", url.host == "github.com", path.count == 6,
              Array(path.prefix(5)) == ["/", owner, repo, "releases", "tag"],
              let tag = path.last, tag.range(of: #"^v?[0-9]+\.[0-9]+\.[0-9]+$"#, options: .regularExpression) != nil else {
            throw UpdateError.missingVersion
        }

        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        guard !version.isEmpty else {
            throw UpdateError.missingVersion
        }

        let downloadURL = URL(string: "https://github.com/\(owner)/\(repo)/releases/download/\(tag)/\(assetName)")!
        let manifestURL = URL(string: "https://github.com/\(owner)/\(repo)/releases/download/\(tag)/\(manifestName)")!
        return UpdateReleaseInfo(version: version, downloadURL: downloadURL, manifestURL: manifestURL)
    }

    private static func fetchManifest(at url: URL) async throws -> UpdateManifest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        request.timeoutInterval = 15
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("StatJack-UpdateChecker", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode)
        else {
            throw UpdateError.badResponse
        }
        do {
            return try JSONDecoder().decode(UpdateManifest.self, from: data)
        } catch {
            throw UpdateError.invalidManifest
        }
    }

    private static func validateDownloadURL(_ url: URL, assetName: String) async throws {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 12
        request.setValue("StatJack-UpdateChecker", forHTTPHeaderField: "User-Agent")

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw UpdateError.badResponse
        }
        if httpResponse.statusCode == 404 {
            throw UpdateError.missingAsset(assetName)
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            throw UpdateError.badStatus(httpResponse.statusCode)
        }
    }

    private static func parse(_ value: String) -> [Int] {
        value
            .split(separator: ".")
            .map { Int($0) ?? 0 }
    }
}

enum UpdateError: LocalizedError, Equatable {
    case notInstalled
    case badResponse
    case badStatus(Int)
    case missingAsset(String)
    case missingVersion
    case invalidManifest

    var errorDescription: String? {
        switch self {
        case .notInstalled:
            return "Move StatJack to Applications before updating."
        case .badResponse:
            return "GitHub returned an invalid response"
        case .badStatus(let statusCode):
            return "GitHub returned HTTP \(statusCode)"
        case .missingAsset(let assetName):
            return "GitHub release is missing \(assetName)"
        case .missingVersion:
            return "GitHub release is missing a version tag"
        case .invalidManifest:
            return "GitHub release contains an invalid update manifest"
        }
    }
}

struct UpdateReleaseInfo: Equatable {
    let version: String
    let downloadURL: URL
    let manifestURL: URL
}
