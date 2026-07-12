import Foundation
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
