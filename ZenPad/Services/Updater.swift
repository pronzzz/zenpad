import AppKit
import Combine
import CryptoKit

/// A release published on GitHub.
struct ReleaseInfo: Equatable {
    var version: String
    var name: String
    var notes: String
    var pageURL: URL
    var zipURL: URL?
    var signatureURL: URL?
    var dmgURL: URL?
    var publishedAt: Date?
    var isPrerelease: Bool
}

/// Keeps ZenPad current from GitHub Releases.
///
/// Each release carries `ZenPad-<version>.zip` and `ZenPad-<version>.zip.sig`, an Ed25519 signature made
/// by `scripts/release.sh` with a key that never leaves the maintainer's Mac or CI secrets. The app only
/// installs an update whose signature matches the public key in its Info.plist.
final class Updater: ObservableObject {
    static let shared = Updater()

    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(ReleaseInfo)
        case downloading(ReleaseInfo, Double)
        case installing(ReleaseInfo)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var latest: ReleaseInfo?

    let repository = Bundle.main.object(forInfoDictionaryKey: "ZPUpdateRepository") as? String ?? "pronzzz/zenpad"
    private let publicKey = Bundle.main.object(forInfoDictionaryKey: "ZPUpdatePublicKey") as? String ?? ""
    private var timer: Timer?
    private var downloadTask: Task<Void, Never>?

    var releasesPage: URL { URL(string: "https://github.com/\(repository)/releases")! }

    // MARK: Checking

    func startAutomaticChecks() {
        guard !Runtime.isDemo else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 6) { [weak self] in self?.automaticCheck() }
        timer = Timer.scheduledTimer(withTimeInterval: 3 * 3600, repeats: true) { _ in
            Task { @MainActor in Updater.shared.automaticCheck() }
        }
    }

    private func automaticCheck() {
        let prefs = Prefs.shared
        guard prefs.autoCheckUpdates else { return }
        if let last = prefs.lastUpdateCheck, Date().timeIntervalSince(last) < 20 * 3600 { return }
        Task { await check(userInitiated: false) }
    }

    func check(userInitiated: Bool) async {
        if case .downloading = state { return }
        if case .installing = state { return }
        state = .checking
        do {
            let release = try await fetchLatest()
            Prefs.shared.lastUpdateCheck = Date()
            latest = release
            if let release, Self.isNewer(release.version, than: Runtime.appVersion) {
                if !userInitiated && release.version == Prefs.shared.skippedVersion {
                    state = .idle
                    return
                }
                state = .available(release)
                UpdateWindowController.shared.show()
            } else {
                state = .upToDate
                if userInitiated { UpdateWindowController.shared.show() }
            }
        } catch {
            state = .failed("Couldn't check for updates: \(error.localizedDescription)")
            if userInitiated { UpdateWindowController.shared.show() }
        }
    }

    private struct GitHubRelease: Decodable {
        struct Asset: Decodable {
            let name: String
            let browser_download_url: URL
        }
        let tag_name: String
        let name: String?
        let body: String?
        let html_url: URL
        let draft: Bool
        let prerelease: Bool
        let published_at: Date?
        let assets: [Asset]
    }

    private func fetchLatest() async throws -> ReleaseInfo? {
        let includePre = Prefs.shared.includePrereleases
        let path = includePre ? "releases?per_page=15" : "releases/latest"
        var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository)/\(path)")!)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("ZenPad/\(Runtime.appVersion)", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 15
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, http.statusCode == 404 { return nil }
        if let http = response as? HTTPURLResponse, http.statusCode != 200 {
            throw NSError(domain: "GitHub", code: http.statusCode, userInfo: [NSLocalizedDescriptionKey: "GitHub returned HTTP \(http.statusCode)"])
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let release: GitHubRelease?
        if includePre {
            release = try decoder.decode([GitHubRelease].self, from: data).first { !$0.draft }
        } else {
            release = try decoder.decode(GitHubRelease.self, from: data)
        }
        guard let release else { return nil }
        let version = release.tag_name.trimmingCharacters(in: CharacterSet(charactersIn: "vV"))
        let zip = release.assets.first { $0.name.hasSuffix(".zip") && $0.name.lowercased().contains("zenpad") }
        let sig = zip.flatMap { z in release.assets.first { $0.name == z.name + ".sig" } }
        let dmg = release.assets.first { $0.name.hasSuffix(".dmg") }
        return ReleaseInfo(version: version, name: release.name ?? "ZenPad \(version)", notes: release.body ?? "",
                           pageURL: release.html_url, zipURL: zip?.browser_download_url, signatureURL: sig?.browser_download_url,
                           dmgURL: dmg?.browser_download_url, publishedAt: release.published_at, isPrerelease: release.prerelease)
    }

    // MARK: Versions

    /// Semantic version comparison; pre-releases (2.1.0-beta.1) sort before their release.
    nonisolated static func isNewer(_ candidate: String, than current: String) -> Bool {
        compare(candidate, current) == .orderedDescending
    }

    nonisolated static func compare(_ a: String, _ b: String) -> ComparisonResult {
        func split(_ v: String) -> ([Int], String?) {
            let trimmed = v.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
            let parts = trimmed.split(separator: "-", maxSplits: 1).map(String.init)
            let numbers = parts[0].split(separator: ".").map { Int($0) ?? 0 }
            return (numbers, parts.count > 1 ? parts[1] : nil)
        }
        let (na, pa) = split(a), (nb, pb) = split(b)
        for i in 0..<max(na.count, nb.count) {
            let x = i < na.count ? na[i] : 0, y = i < nb.count ? nb[i] : 0
            if x != y { return x < y ? .orderedAscending : .orderedDescending }
        }
        switch (pa, pb) {
        case (nil, nil): return .orderedSame
        case (nil, _): return .orderedDescending
        case (_, nil): return .orderedAscending
        case let (x?, y?): return x.compare(y, options: .numeric)
        }
    }

    // MARK: Installing

    var canInstallInPlace: Bool {
        let path = Bundle.main.bundlePath
        return !path.contains("/AppTranslocation/") && !path.hasPrefix("/Volumes/")
            && FileManager.default.isWritableFile(atPath: (path as NSString).deletingLastPathComponent)
    }

    /// Used by demo mode to show the update window without a network request.
    func setDemoState(_ newState: State) {
        state = newState
    }

    func skip(_ release: ReleaseInfo) {
        Prefs.shared.skippedVersion = release.version
        state = .idle
    }

    func cancelDownload() {
        downloadTask?.cancel()
        if let latest { state = .available(latest) }
    }

    func downloadAndInstall(_ release: ReleaseInfo) {
        guard let zipURL = release.zipURL, let sigURL = release.signatureURL, canInstallInPlace else {
            NSWorkspace.shared.open(release.dmgURL ?? release.pageURL)
            return
        }
        state = .downloading(release, 0)
        downloadTask = Task { [weak self] in
            guard let self else { return }
            do {
                let work = FileManager.default.temporaryDirectory.appendingPathComponent("ZenPadUpdate-\(UUID().uuidString)", isDirectory: true)
                try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
                let delegate = DownloadProgress { fraction in
                    Task { @MainActor in
                        if case .downloading = Updater.shared.state { Updater.shared.state = .downloading(release, fraction) }
                    }
                }
                let (tmp, _) = try await URLSession.shared.download(from: zipURL, delegate: delegate)
                let zip = work.appendingPathComponent(zipURL.lastPathComponent)
                try FileManager.default.moveItem(at: tmp, to: zip)
                let (sigData, _) = try await URLSession.shared.data(from: sigURL)
                try Task.checkCancellation()
                self.state = .installing(release)
                try self.verify(zip: zip, signature: sigData)
                let app = try await self.extract(zip: zip, into: work, expecting: release.version)
                try self.relaunch(into: app, work: work)
            } catch is CancellationError {
            } catch {
                self.state = .failed(error.localizedDescription)
            }
        }
    }

    private func verify(zip: URL, signature: Data) throws {
        let encoded = String(data: signature, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let keyData = Data(base64Encoded: publicKey),
              let key = try? Curve25519.Signing.PublicKey(rawRepresentation: keyData),
              let sig = Data(base64Encoded: encoded) else {
            throw UpdateError("The update's signature is missing or malformed.")
        }
        let data = try Data(contentsOf: zip, options: .mappedIfSafe)
        guard key.isValidSignature(sig, for: data) else {
            throw UpdateError("The update's signature doesn't match. It was not installed.")
        }
    }

    private func extract(zip: URL, into work: URL, expecting version: String) async throws -> URL {
        let out = work.appendingPathComponent("extracted", isDirectory: true)
        try await Self.runTool("/usr/bin/ditto", ["-x", "-k", zip.path, out.path])
        let items = try FileManager.default.contentsOfDirectory(at: out, includingPropertiesForKeys: nil)
        guard let app = items.first(where: { $0.pathExtension == "app" }), let bundle = Bundle(url: app) else {
            throw UpdateError("The update archive doesn't contain ZenPad.app.")
        }
        guard bundle.bundleIdentifier == Bundle.main.bundleIdentifier else {
            throw UpdateError("The update is for a different app.")
        }
        let newVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
        guard newVersion == version else {
            throw UpdateError("The update reports version \(newVersion), expected \(version).")
        }
        try await Self.runTool("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        return app
    }

    /// Hands off to a tiny shell script that waits for ZenPad to quit, swaps the bundle and relaunches.
    private func relaunch(into newApp: URL, work: URL) throws {
        func quote(_ s: String) -> String { "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'" }
        let target = Bundle.main.bundleURL.path
        let script = """
        #!/bin/sh
        PID=\(ProcessInfo.processInfo.processIdentifier)
        TARGET=\(quote(target))
        NEW=\(quote(newApp.path))
        BACKUP="$TARGET.previous"
        while kill -0 "$PID" 2>/dev/null; do sleep 0.2; done
        rm -rf "$BACKUP"
        if mv "$TARGET" "$BACKUP"; then
          if /usr/bin/ditto "$NEW" "$TARGET"; then rm -rf "$BACKUP"; else rm -rf "$TARGET"; mv "$BACKUP" "$TARGET"; fi
        fi
        /usr/bin/xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null
        /usr/bin/open "$TARGET"
        rm -rf \(quote(work.path))
        """
        let scriptURL = work.appendingPathComponent("install.sh")
        try script.write(to: scriptURL, atomically: true, encoding: .utf8)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [scriptURL.path]
        try process.run()
        EditorSession.shared.saveNow()
        QuickPadController.shared.saveScratch()
        NSApp.terminate(nil)
    }

    private nonisolated static func runTool(_ path: String, _ args: [String]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: path)
            process.arguments = args
            process.standardOutput = FileHandle.nullDevice
            process.standardError = FileHandle.nullDevice
            process.terminationHandler = { p in
                if p.terminationStatus == 0 { continuation.resume() }
                else { continuation.resume(throwing: UpdateError("\((path as NSString).lastPathComponent) failed (\(p.terminationStatus)).")) }
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }
}

nonisolated struct UpdateError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
}

/// Reports download progress from URLSession's background queue.
nonisolated final class DownloadProgress: NSObject, URLSessionTaskDelegate, @unchecked Sendable {
    private let onProgress: @Sendable (Double) -> Void
    private var observation: NSKeyValueObservation?

    init(onProgress: @escaping @Sendable (Double) -> Void) {
        self.onProgress = onProgress
    }

    func urlSession(_ session: URLSession, didCreateTask task: URLSessionTask) {
        observation = task.progress.observe(\.fractionCompleted) { [onProgress] progress, _ in
            onProgress(progress.fractionCompleted)
        }
    }
}
