import Foundation
import Testing
import XCTest
@testable import StatJack

final class UpdateSecurityTests: XCTestCase {
    func testManifestVersionMustMatchSelectedRelease() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: false)
        defer { try? FileManager.default.removeItem(at: directory) }
        let artifact = directory.appendingPathComponent("StatJack.dmg")
        try Data("abc".utf8).write(to: artifact)
        let manifest = UpdateManifest(
            version: "9.9.9",
            asset: "StatJack.dmg",
            sha256: "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
            bundleIdentifier: "com.statjack.app",
            teamIdentifier: "66K3EFBVB6"
        )

        XCTAssertThrowsError(
            try UpdateSecurity.verify(
                manifest: manifest,
                artifactURL: artifact,
                expectedVersion: "1.0.0",
                expectedAsset: "StatJack.dmg",
                expectedBundleIdentifier: "com.statjack.app"
            )
        ) {
            XCTAssertEqual($0 as? UpdateSecurityError, .versionMismatch)
        }
    }
}
@MainActor
struct UpdateDownloadTests {
    @Test
    func completedDownloadSurvivesCallbackCleanup() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try Data([1, 2, 3]).write(to: url)
        defer { try? FileManager.default.removeItem(at: url) }
        let response = try #require(HTTPURLResponse(url: URL(string: "https://example.test")!,
                                                    statusCode: 200, httpVersion: nil, headerFields: nil))
        let saved = try UpdateChecker.retainDownload(at: url, response: response, error: nil)
        defer { try? FileManager.default.removeItem(at: saved.deletingLastPathComponent()) }
        #expect(FileManager.default.fileExists(atPath: url.path) == false)
        #expect(try Data(contentsOf: saved) == Data([1, 2, 3]))
    }

    @Test
    func errorResponseIsNotRetained() throws {
        let url = URL(fileURLWithPath: "/unused")
        let http = try #require(HTTPURLResponse(url: url, statusCode: 404, httpVersion: nil, headerFields: nil))
        #expect(throws: UpdateError.badResponse) {
            try UpdateChecker.retainDownload(at: url, response: http, error: nil)
        }
    }

    @Test
    func localBuildCannotInstallIntoApplications() {
        UpdateChecker.shared.downloadAndInstall()
        #expect(UpdateChecker.shared.lastError == "Updates are disabled for local builds.")
        #expect(UpdateChecker.shared.isDownloading == false)
    }

    @Test
    func releaseRedirectUsesOnlyTheExpectedTagPath() throws {
        let base = "https://github.com/burakereno/statjack/releases/"
        let valid = try #require(URL(string: base + "tag/v1.0.44"))
        let release = try UpdateChecker.releaseInfo(fromResolvedLatestURL: valid)
        #expect(release.version == "1.0.44")
        #expect(release.downloadURL.lastPathComponent == "StatJack.dmg")
        let invalid = try #require(URL(string: base + "latest"))
        #expect(throws: UpdateError.missingVersion) {
            try UpdateChecker.releaseInfo(fromResolvedLatestURL: invalid)
        }
    }
}
