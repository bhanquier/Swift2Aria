import Foundation
import Combine

/// Manages rclone remotes, transfers, and mounts
@MainActor
class RcloneManager: ObservableObject {
    @Published var remotes: [CloudRemote] = []
    @Published var transfers: [CloudTransfer] = []
    @Published var mounts: [CloudRemote] = []
    @Published var isConnected = false
    @Published var error: String?
    @Published var globalSpeed: Int64 = 0

    let daemon = RcloneDaemon()
    private(set) var rc: RcloneRC?
    private var pollTimer: Timer?

    init() {}

    // MARK: - Lifecycle

    func start() {
        // rclone is optional — don't fail if not found
        guard daemon.findRcloneBinary() != nil else {
            error = "rclone not found (brew install rclone)"
            return
        }

        do {
            try daemon.start()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.connect()
            }
        } catch {
            self.error = error.localizedDescription
        }
    }

    func stop() {
        pollTimer?.invalidate()
        pollTimer = nil
        daemon.stop()
        isConnected = false
    }

    private func connect() {
        rc = RcloneRC(port: daemon.rcPort, user: daemon.rcUser, pass: daemon.rcPass)
        startPolling()

        Task {
            do {
                let version = try await rc?.getVersion()
                daemon.version = version
                isConnected = true
                error = nil
                await refreshRemotes()
            } catch {
                isConnected = false
                self.error = "Cannot connect to rclone: \(error.localizedDescription)"
            }
        }
    }

    // MARK: - Polling

    private func startPolling() {
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.refreshTransfers()
            }
        }
    }

    // MARK: - Remotes

    func refreshRemotes() async {
        guard let rc else { return }
        do {
            let names = try await rc.listRemotes()
            var newRemotes: [CloudRemote] = []

            for name in names {
                let config = try await rc.getRemote(name)
                let type = config["type"] as? String ?? "unknown"
                var remote = CloudRemote(id: name, name: name, type: type)

                // Check if mounted
                if let mount = mounts.first(where: { $0.name == name }) {
                    remote.isMounted = true
                    remote.mountPoint = mount.mountPoint
                }

                // Get space info (best-effort)
                if let about = try? await rc.about(fs: remote.fs) {
                    remote.spaceTotal = about["total"] as? Int64 ?? 0
                    remote.spaceUsed = about["used"] as? Int64 ?? 0
                    remote.spaceFree = about["free"] as? Int64 ?? 0
                }

                newRemotes.append(remote)
            }

            remotes = newRemotes
            await refreshMounts()
        } catch {
            // Silently ignore
        }
    }

    func refreshMounts() async {
        guard let rc else { return }
        do {
            let mountList = try await rc.listMounts()
            for mount in mountList {
                let mountPoint = mount["MountPoint"] as? String ?? ""
                let fs = mount["Fs"] as? String ?? ""
                let name = fs.replacingOccurrences(of: ":", with: "")
                if let idx = remotes.firstIndex(where: { $0.name == name }) {
                    remotes[idx].isMounted = true
                    remotes[idx].mountPoint = mountPoint
                }
            }
        } catch {
            // Silently ignore
        }
    }

    func refreshTransfers() async {
        guard let rc else { return }
        do {
            let stats = try await rc.coreStats()
            globalSpeed = stats["speed"] as? Int64 ?? 0

            if let transferring = stats["transferring"] as? [[String: Any]] {
                transfers = transferring.enumerated().map { idx, dict in
                    CloudTransfer.fromStats(dict, jobID: idx)
                }
            } else {
                transfers = []
            }
        } catch {
            // Silently ignore
        }
    }

    // MARK: - Actions

    func copyToCloud(localPath: String, remote: CloudRemote, remotePath: String) async throws {
        guard let rc else { throw RcloneError.notRunning }
        _ = try await rc.copyDir(
            srcFs: localPath,
            dstFs: "\(remote.fs)\(remotePath)"
        )
    }

    func copyFromCloud(remote: CloudRemote, remotePath: String, localPath: String) async throws {
        guard let rc else { throw RcloneError.notRunning }
        _ = try await rc.copyDir(
            srcFs: "\(remote.fs)\(remotePath)",
            dstFs: localPath
        )
    }

    func syncToCloud(localPath: String, remote: CloudRemote, remotePath: String) async throws {
        guard let rc else { throw RcloneError.notRunning }
        _ = try await rc.sync(
            srcFs: localPath,
            dstFs: "\(remote.fs)\(remotePath)"
        )
    }

    func mountRemote(_ remote: CloudRemote) async throws {
        guard let rc else { throw RcloneError.notRunning }
        let mountPoint = "/tmp/aria2mac-mount-\(remote.name)"

        // Create mount point directory
        try FileManager.default.createDirectory(atPath: mountPoint, withIntermediateDirectories: true)

        try await rc.mount(fs: remote.fs, mountPoint: mountPoint)

        if let idx = remotes.firstIndex(where: { $0.id == remote.id }) {
            remotes[idx].isMounted = true
            remotes[idx].mountPoint = mountPoint
        }
    }

    func unmountRemote(_ remote: CloudRemote) async throws {
        guard let rc else { throw RcloneError.notRunning }
        try await rc.unmount(mountPoint: remote.mountPoint)

        if let idx = remotes.firstIndex(where: { $0.id == remote.id }) {
            remotes[idx].isMounted = false
            remotes[idx].mountPoint = ""
        }
    }

    func addRemote(name: String, type: String, parameters: [String: String]) async throws {
        guard let rc else { throw RcloneError.notRunning }
        try await rc.createRemote(name: name, type: type, parameters: parameters)
        await refreshRemotes()
    }

    func removeRemote(_ remote: CloudRemote) async throws {
        guard let rc else { throw RcloneError.notRunning }
        if remote.isMounted {
            try await unmountRemote(remote)
        }
        try await rc.deleteRemote(name: remote.name)
        await refreshRemotes()
    }

    func listDirectory(remote: CloudRemote, path: String) async throws -> [[String: Any]] {
        guard let rc else { throw RcloneError.notRunning }
        return try await rc.listDir(fs: remote.fs, remote: path)
    }
}
