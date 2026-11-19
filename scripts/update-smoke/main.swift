import AppKit
import Foundation

// Exercise the shipping installer on the disposable CI runner, never in /Applications.
let fm = FileManager.default
guard ProcessInfo.processInfo.environment["GITHUB_ACTIONS"] == "true",
      let scratch = ProcessInfo.processInfo.environment["RUNNER_TEMP"],
      CommandLine.arguments.count == 5 else { exit(2) }
let root = URL(fileURLWithPath: scratch).appendingPathComponent("update-smoke-\(UUID().uuidString)")
let download = root.appendingPathComponent("download")
let installed = root.appendingPathComponent("StatJack.app")
try fm.createDirectory(at: download, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
let dmg = download.appendingPathComponent("StatJack.dmg")
try fm.copyItem(at: URL(fileURLWithPath: CommandLine.arguments[1]), to: dmg)
let manifest = try JSONDecoder().decode(UpdateManifest.self, from: Data(contentsOf: URL(fileURLWithPath: CommandLine.arguments[2])))
let version = CommandLine.arguments[3]
let bundleID = "com.statjack.app"
try UpdateSecurity.verify(manifest: manifest, artifactURL: dmg, expectedVersion: version,
                          expectedAsset: "StatJack.dmg", expectedBundleIdentifier: bundleID)
// An existing target exercises the backup/replacement path.
try fm.copyItem(at: URL(fileURLWithPath: CommandLine.arguments[4]), to: installed)
let parent = Process()
parent.executableURL = URL(fileURLWithPath: "/bin/sleep")
parent.arguments = ["0.2"]
try parent.run()
let helper = try UpdateSecurity.launchInstaller(parentPID: parent.processIdentifier, dmgURL: dmg,
    targetURL: installed, expectedBundleIdentifier: bundleID, expectedVersion: version,
    appBundleName: "StatJack.app", executableName: "StatJack", expectedSHA256: manifest.sha256)
parent.waitUntilExit()
helper.waitUntilExit()
if helper.terminationStatus != 0 {
    let log = download.appendingPathComponent("install.log")
    print((try? String(contentsOf: log, encoding: .utf8)) ?? "Installer log unavailable")
    exit(1)
}
let target = installed.resolvingSymlinksInPath().standardizedFileURL.path
let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).filter {
    $0.bundleURL?.resolvingSymlinksInPath().standardizedFileURL.path == target
}
guard !running.isEmpty, !fm.fileExists(atPath: download.path),
      let plist = NSDictionary(contentsOf: installed.appendingPathComponent("Contents/Info.plist")),
      plist["CFBundleShortVersionString"] as? String == version,
      plist["StatJackDistribution"] as? Bool == true else { exit(1) }
for app in running { app.terminate() }
print("Installed and launched StatJack \(version) from the temporary target.")
