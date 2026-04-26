import Foundation
import Combine

/// Central manager: owns the daemon + RPC client, polls for updates
@MainActor
class Aria2Manager: ObservableObject {
    @Published var downloads: [Download] = []
    @Published var globalDownloadSpeed: Int64 = 0
    @Published var globalUploadSpeed: Int64 = 0
    @Published var isConnected = false
    @Published var error: String?

    let daemon = Aria2Daemon()
    private(set) var rpc: Aria2RPC?
    var rpcClient: Aria2RPC? { rpc }
    private var pollTimer: Timer?
    private var consecutiveErrors = 0
    private let maxConsecutiveErrors = 3

    private var settings: AppSettings { AppSettings.shared }

    init() {}

    // MARK: - Lifecycle

    func start() {
        do {
            try daemon.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.connect()
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        Task {
            try? await rpc?.shutdown()
        }
        daemon.stop()
        isConnected = false
    }

    private func connect() {
        rpc = Aria2RPC(port: settings.rpcPort, secret: daemon.secret)
        startPolling()

        Task {
            do {
                let version = try await rpc?.getVersion()
                daemon.version = version
                isConnected = true
                error = nil
            } catch {
                isConnected = false
                self.error = "Cannot connect to aria2c: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Polling

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
    }

    func refresh() async {
        guard let rpc else { return }

        do {
            async let activeResult = rpc.tellActive()
            async let waitingResult = rpc.tellWaiting(offset: 0, num: 100)
            async let stoppedResult = rpc.tellStopped(offset: 0, num: 50)
            async let statsResult = rpc.getGlobalStat()

            let (active, waiting, stopped, stats) = try await (
                activeResult, waitingResult, stoppedResult, statsResult
            )

            var all: [Download] = []
            all.append(contentsOf: active.map(Download.fromRPC))
            all.append(contentsOf: waiting.map(Download.fromRPC))
            all.append(contentsOf: stopped.map(Download.fromRPC))
            downloads = all

            globalDownloadSpeed = Int64(stats["downloadSpeed"] as? String ?? "0") ?? 0
            globalUploadSpeed = Int64(stats["uploadSpeed"] as? String ?? "0") ?? 0

            updateDockBadge()

            consecutiveErrors = 0
            if !isConnected {
                isConnected = true
                error = nil
            }
        } catch {
            consecutiveErrors += 1
            if consecutiveErrors >= maxConsecutiveErrors {
                isConnected = false
                self.error = "Connection to aria2c lost"
                pollTimer?.invalidate()
                pollTimer = nil
                attemptReconnect()
            }
        }
    }

    private func attemptReconnect() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) { [weak self] in
            guard let self else { return }
            if !self.isConnected {
                self.connect()
            }
        }
    }

    private func updateDockBadge() {
        let activeCount = downloads.filter { $0.status == .active || $0.status == .waiting }.count
        NSApp.dockTile.badgeLabel = activeCount > 0 ? "\(activeCount)" : nil
    }

    // MARK: - Actions

    func addDownload(url: String, options: [String: String] = [:]) async throws {
        guard let rpc else { throw Aria2Error.daemonNotRunning }

        // Merge user options over rule-based defaults
        var mergedOptions = settings.options(for: url)
        for (k, v) in options { mergedOptions[k] = v }

        _ = try await rpc.addUri([url], options: mergedOptions)
        await refresh()
    }

    func addTorrent(fileURL: URL, options: [String: String] = [:]) async throws {
        guard let rpc else { throw Aria2Error.daemonNotRunning }
        let data = try Data(contentsOf: fileURL)

        var mergedOptions = settings.options(for: fileURL.path)
        for (k, v) in options { mergedOptions[k] = v }

        _ = try await rpc.addTorrent(data: data, options: mergedOptions)
        await refresh()
    }

    func pauseDownload(_ download: Download) async throws {
        guard let rpc else { return }
        _ = try await rpc.pause(gid: download.id)
        await refresh()
    }

    func resumeDownload(_ download: Download) async throws {
        guard let rpc else { return }
        _ = try await rpc.unpause(gid: download.id)
        await refresh()
    }

    func removeDownload(_ download: Download) async throws {
        guard let rpc else { return }
        if download.isActive {
            _ = try await rpc.forceRemove(gid: download.id)
        } else {
            _ = try await rpc.remove(gid: download.id)
        }
        await refresh()
    }

    func clearCompleted() async throws {
        guard let rpc else { return }
        try await rpc.purgeDownloadResult()
        await refresh()
    }

    // MARK: - URL Scheme Handler

    /// Handle aria2mac://add?url=<encoded_url>
    func handleURL(_ url: URL) {
        guard url.scheme == "swift2aria",
              url.host == "add",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let downloadURL = components.queryItems?.first(where: { $0.name == "url" })?.value else {
            return
        }
        Task {
            try? await addDownload(url: downloadURL)
        }
    }
}
