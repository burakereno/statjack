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
    private static let minimumManualCheckInterval: TimeInterval = 30 * 60
    private static let minimumVisibleCheckDuration: UInt64 = 500_000_000

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

    var isUpToDate: Bool {
        latestVersion != nil && !updateAvailable && lastError == nil
    }

    private var timer: Timer?
    private(set) var lastCheckedAt: Date?
    private(set) var lastCheckCompletedAt: Date?

    private init() {}

    func start() {
        Task { await checkForUpdates(force: true) }
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: Self.checkInterval, repeats: true) { _ in
            Task { @MainActor in await UpdateChecker.shared.checkForUpdates(force: true) }
        }
    }

    func checkForUpdates(force: Bool = false) async {
        guard !isChecking else { return }
        let now = Date()
        if !force,
           let lastCheckedAt,
           now.timeIntervalSince(lastCheckedAt) < Self.minimumManualCheckInterval
        {
            return
        }
        lastCheckedAt = now
        isChecking = true
        lastError = nil

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

        let elapsed = Date().timeIntervalSince(now)
        if elapsed < 0.5 {
            let remaining = Self.minimumVisibleCheckDuration - UInt64(elapsed * 1_000_000_000)
            try? await Task.sleep(nanoseconds: remaining)
        }
        lastCheckCompletedAt = Date()
        isChecking = false
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
                    self.installUpdate(dmgURL: dest)
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

    // MARK: - Install

    private func installUpdate(dmgURL: URL) {
        let currentBundle = URL(fileURLWithPath: Bundle.main.bundlePath)
        let targetBundle = currentBundle.path.hasPrefix("/Applications/")
            ? currentBundle
            : URL(fileURLWithPath: "/Applications/StatJack.app")

        let scriptURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("statjack-install-\(UUID().uuidString).sh")
        let logURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("statjack-install.log")

        let script = """
        #!/bin/bash
        set -u
        exec >"\(logURL.path)" 2>&1

        PARENT_PID="$1"
        DMG="$2"
        TARGET="\(targetBundle.path)"

        echo "[install] waiting for parent $PARENT_PID to exit"
        for _ in $(seq 1 50); do
            kill -0 "$PARENT_PID" 2>/dev/null || break
            sleep 0.1
        done
        kill -0 "$PARENT_PID" 2>/dev/null && kill "$PARENT_PID" 2>/dev/null
        sleep 0.5

        echo "[install] mounting $DMG"
        MOUNT_OUT=$(/usr/bin/hdiutil attach -nobrowse -noautoopen -quiet "$DMG" | tail -1)
        MOUNT_POINT=$(echo "$MOUNT_OUT" | awk -F'\\t' '{print $NF}')
        if [ -z "$MOUNT_POINT" ] || [ ! -d "$MOUNT_POINT" ]; then
            MOUNT_POINT="/Volumes/StatJack"
        fi
        echo "[install] mount point: $MOUNT_POINT"

        SRC="$MOUNT_POINT/StatJack.app"
        if [ ! -d "$SRC" ]; then
            echo "[install] source app not found at $SRC — aborting"
            /usr/bin/hdiutil detach "$MOUNT_POINT" -quiet -force 2>/dev/null
            /usr/bin/open "$DMG"
            exit 1
        fi

        echo "[install] removing old app at $TARGET"
        /bin/rm -rf "$TARGET"

        echo "[install] copying new app"
        /usr/bin/ditto "$SRC" "$TARGET"

        echo "[install] stripping quarantine"
        /usr/bin/xattr -cr "$TARGET"

        echo "[install] detaching dmg"
        /usr/bin/hdiutil detach "$MOUNT_POINT" -quiet -force 2>/dev/null

        echo "[install] removing downloaded dmg"
        rm -f "$DMG"

        echo "[install] launching new app"
        /usr/bin/open "$TARGET"

        rm -f "\(scriptURL.path)"
        echo "[install] done"
        """

        do {
            try script.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o755],
                ofItemAtPath: scriptURL.path
            )
        } catch {
            lastError = "Could not write installer script: \(error.localizedDescription)"
            NSWorkspace.shared.open(dmgURL)
            return
        }

        let pid = ProcessInfo.processInfo.processIdentifier
        let task = Process()
        task.executableURL = scriptURL
        task.arguments = ["\(pid)", dmgURL.path]
        do {
            try task.run()
        } catch {
            lastError = "Could not launch installer: \(error.localizedDescription)"
            NSWorkspace.shared.open(dmgURL)
            return
        }

        // Give the helper a moment to detach, then quit so it can replace the bundle.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 300_000_000)
            NSApp.terminate(nil)
        }
    }

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
