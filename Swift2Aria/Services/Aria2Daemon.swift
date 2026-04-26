import Foundation

/// Manages the aria2c subprocess lifecycle
class Aria2Daemon: ObservableObject {
    @Published var isRunning = false
    @Published var version: String?

    private var process: Process?

    var settings: AppSettings { AppSettings.shared }

    init() {}

    var secret: String { settings.rpcSecret }

    func start() throws {
        guard !isRunning else { return }

        let binaryPath = findAria2cBinary()
        guard let binary = binaryPath else {
            print("[Aria2Daemon] Binary not found!")
            throw Aria2Error.binaryNotFound
        }
        print("[Aria2Daemon] Using binary: \(binary)")

        // Ensure Application Support directory exists
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("Swift2Aria")
        let sessionFile = appSupport.appendingPathComponent("aria2.session")
        try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        // aria2c --input-file requires the file to exist (even if empty)
        if !FileManager.default.fileExists(atPath: sessionFile.path) {
            FileManager.default.createFile(atPath: sessionFile.path, contents: nil, attributes: nil)
        }

        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: binary)

        var args = [
            "--enable-rpc",
            "--rpc-listen-port=\(settings.rpcPort)",
            "--rpc-secret=\(settings.rpcSecret)",
            "--rpc-listen-all=false",
            "--dir=\(settings.downloadDirectory)",
            "--max-concurrent-downloads=\(settings.maxConcurrentDownloads)",
            "--max-connection-per-server=\(settings.maxConnectionsPerServer)",
            "--split=4",
            "--min-split-size=1M",
            "--continue=true",
            "--auto-file-renaming=true",
            "--file-allocation=\(settings.fileAllocation.rawValue)",
            "--summary-interval=0",
            "--console-log-level=warn",
            "--bt-enable-lpd=true",
            "--dht-listen-port=6881-6999",
            "--seed-ratio=0",
            "--user-agent=Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
            "--retry-wait=3",
            "--timeout=60",
            "--connect-timeout=60",
            "--save-session=\(sessionFile.path)",
            "--input-file=\(sessionFile.path)",
            "--save-session-interval=60",
        ]

        if settings.globalDownloadLimit > 0 {
            args.append("--max-overall-download-limit=\(settings.globalDownloadLimit)K")
        }
        if settings.globalUploadLimit > 0 {
            args.append("--max-overall-upload-limit=\(settings.globalUploadLimit)K")
        }
        if !settings.proxyURL.isEmpty {
            args.append("--all-proxy=\(settings.proxyURL)")
        }

        // Extra user arguments (basic shell-like parsing respecting quotes)
        let extra = settings.extraArguments.trimmingCharacters(in: .whitespaces)
        if !extra.isEmpty {
            args.append(contentsOf: parseArguments(extra))
        }

        proc.arguments = args

        let stderrPipe = Pipe()
        proc.standardOutput = FileHandle.nullDevice
        proc.standardError = stderrPipe

        // Log stderr output
        stderrPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                print("[aria2c] \(str)")
            }
        }

        proc.terminationHandler = { [weak self] proc in
            print("[Aria2Daemon] aria2c exited with code \(proc.terminationStatus)")
            DispatchQueue.main.async {
                self?.isRunning = false
            }
        }

        print("[Aria2Daemon] Launching: \(binary) \(args.joined(separator: " "))")
        try proc.run()
        process = proc
        isRunning = true
        print("[Aria2Daemon] PID: \(proc.processIdentifier)")
    }

    func stop() {
        process?.terminate()
        process = nil
        isRunning = false
    }

    func findAria2cBinary() -> String? {
        // 0. User-specified path
        let custom = settings.aria2cPath
        if !custom.isEmpty, FileManager.default.fileExists(atPath: custom) {
            return custom
        }

        // 1. Bundled binary (in Resources/Binaries/)
        if let resourceURL = Bundle.main.resourceURL {
            let bundled = resourceURL.appendingPathComponent("Binaries/aria2c").path
            if FileManager.default.isExecutableFile(atPath: bundled) {
                return bundled
            }
        }
        // Flat bundle resource fallback
        if let bundled = Bundle.main.path(forResource: "aria2c", ofType: nil) {
            return bundled
        }

        // 2. Homebrew (Apple Silicon)
        let homebrewArm = "/opt/homebrew/bin/aria2c"
        if FileManager.default.fileExists(atPath: homebrewArm) {
            return homebrewArm
        }

        // 3. Homebrew (Intel)
        let homebrewIntel = "/usr/local/bin/aria2c"
        if FileManager.default.fileExists(atPath: homebrewIntel) {
            return homebrewIntel
        }

        // 4. PATH lookup
        let whichProc = Process()
        whichProc.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProc.arguments = ["aria2c"]
        let pipe = Pipe()
        whichProc.standardOutput = pipe
        try? whichProc.run()
        whichProc.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let path, !path.isEmpty, FileManager.default.fileExists(atPath: path) {
            return path
        }

        return nil
    }
}

// MARK: - Argument Parsing

private func parseArguments(_ input: String) -> [String] {
    var result: [String] = []
    var current = ""
    var inQuotes = false
    var quoteChar: Character?

    for char in input {
        if char == "\"" || char == "'" {
            if inQuotes && quoteChar == char {
                inQuotes = false
                quoteChar = nil
            } else if !inQuotes {
                inQuotes = true
                quoteChar = char
            } else {
                current.append(char)
            }
        } else if char.isWhitespace && !inQuotes {
            if !current.isEmpty {
                result.append(current)
                current = ""
            }
        } else {
            current.append(char)
        }
    }

    if !current.isEmpty {
        result.append(current)
    }
    return result
}
