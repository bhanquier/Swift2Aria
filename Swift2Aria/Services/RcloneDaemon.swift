import Foundation

/// Manages the rclone rcd (remote control daemon) subprocess
class RcloneDaemon: ObservableObject {
    @Published var isRunning = false
    @Published var version: String?

    private var process: Process?

    let rcPort: Int
    let rcUser: String
    let rcPass: String

    init(port: Int = 5572) {
        self.rcPort = port
        self.rcUser = "swift2aria"
        self.rcPass = AppSettings.shared.rpcSecret
    }

    func start() throws {
        guard !isRunning else { return }

        guard let binary = findRcloneBinary() else {
            throw RcloneError.binaryNotFound
        }

        // Clean up stale mount directories from previous runs
        cleanupStaleMounts()

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binary)
        proc.arguments = [
            "rcd",
            "--rc-addr=127.0.0.1:\(rcPort)",
            "--rc-user=\(rcUser)",
            "--rc-pass=\(rcPass)",
            "--rc-no-auth=false",
            "--rc-serve",
            "--log-level=NOTICE",
        ]

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        proc.standardOutput = stdoutPipe
        proc.standardError = stderrPipe

        // Log stderr output
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                print("[rclone] \(str)")
            }
        }

        proc.terminationHandler = { [weak self] _ in
            DispatchQueue.main.async {
                self?.isRunning = false
            }
        }

        try proc.run()
        process = proc
        isRunning = true
    }

    func stop() {
        process?.terminate()
        process = nil
        isRunning = false
        // Clean up any leftover mount directories
        cleanupStaleMounts()
    }

    private func cleanupStaleMounts() {
        let tmpDir = "/tmp"
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: tmpDir) else { return }
        for item in contents where item.hasPrefix("aria2mac-mount-") {
            let path = "\(tmpDir)/\(item)"
            try? fm.removeItem(atPath: path)
        }
    }

    func findRcloneBinary() -> String? {
        let custom = AppSettings.shared.rclonePath
        if !custom.isEmpty, FileManager.default.fileExists(atPath: custom) {
            return custom
        }

        // Bundled (in Resources/Binaries/)
        if let resourceURL = Bundle.main.resourceURL {
            let bundled = resourceURL.appendingPathComponent("Binaries/rclone").path
            if FileManager.default.isExecutableFile(atPath: bundled) {
                return bundled
            }
        }
        if let bundled = Bundle.main.path(forResource: "rclone", ofType: nil) {
            return bundled
        }

        // Homebrew (Apple Silicon)
        let arm = "/opt/homebrew/bin/rclone"
        if FileManager.default.fileExists(atPath: arm) { return arm }

        // Homebrew (Intel)
        let intel = "/usr/local/bin/rclone"
        if FileManager.default.fileExists(atPath: intel) { return intel }

        // PATH
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        proc.arguments = ["rclone"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        try? proc.run()
        proc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let path, !path.isEmpty, FileManager.default.fileExists(atPath: path) {
            return path
        }

        return nil
    }
}
