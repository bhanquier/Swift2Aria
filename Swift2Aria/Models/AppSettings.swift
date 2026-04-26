import Foundation
import ServiceManagement

/// Centralized settings — backed by UserDefaults with App Group support
class AppSettings: ObservableObject {
    static let shared = AppSettings()
    static let suiteName = "group.com.trustakt.aria2mac"
    private let defaults: UserDefaults
    private var isLoading = false

    init() {
        // Use App Group UserDefaults when signing is configured, standard otherwise
        defaults = UserDefaults(suiteName: Self.suiteName) ?? .standard
        load()
    }

    // MARK: - General

    @Published var launchAtLogin: Bool = false {
        didSet {
            defaults.set(launchAtLogin, forKey: "launchAtLogin")
            updateLoginItem()
        }
    }

    @Published var showInDock: Bool = false {
        didSet { defaults.set(showInDock, forKey: "showInDock") }
    }

    @Published var downloadDirectory: String = NSString("~/Downloads").expandingTildeInPath {
        didSet { defaults.set(downloadDirectory, forKey: "downloadDirectory") }
    }

    @Published var notifyOnComplete: Bool = true {
        didSet { defaults.set(notifyOnComplete, forKey: "notifyOnComplete") }
    }

    // MARK: - Network

    @Published var maxConcurrentDownloads: Int = 5 {
        didSet { defaults.set(maxConcurrentDownloads, forKey: "maxConcurrentDownloads") }
    }

    @Published var maxConnectionsPerServer: Int = 16 {
        didSet { defaults.set(maxConnectionsPerServer, forKey: "maxConnectionsPerServer") }
    }

    @Published var globalDownloadLimit: Int = 0 {
        didSet { defaults.set(globalDownloadLimit, forKey: "globalDownloadLimit") }
    }

    @Published var globalUploadLimit: Int = 0 {
        didSet { defaults.set(globalUploadLimit, forKey: "globalUploadLimit") }
    }

    @Published var proxyURL: String = "" {
        didSet { defaults.set(proxyURL, forKey: "proxyURL") }
    }

    // MARK: - Advanced

    @Published var rpcPort: Int = 6800 {
        didSet { defaults.set(rpcPort, forKey: "rpcPort") }
    }

    @Published var rpcSecret: String = "" {
        didSet {
            if !isLoading {
                SecretsStore.saveSecret(rpcSecret)
            }
        }
    }

    @Published var aria2cPath: String = "" {
        didSet { defaults.set(aria2cPath, forKey: "aria2cPath") }
    }

    @Published var rclonePath: String = "" {
        didSet { defaults.set(rclonePath, forKey: "rclonePath") }
    }

    @Published var fileAllocation: FileAllocation = .falloc {
        didSet { defaults.set(fileAllocation.rawValue, forKey: "fileAllocation") }
    }

    @Published var extraArguments: String = "" {
        didSet { defaults.set(extraArguments, forKey: "extraArguments") }
    }

    // MARK: - Download Rules

    @Published var downloadRules: [DownloadRule] = DownloadRule.defaults {
        didSet { saveRules() }
    }

    // MARK: - Enums

    enum FileAllocation: String, CaseIterable, Identifiable {
        case none, prealloc, trunc, falloc
        var id: String { rawValue }
        var label: String {
            switch self {
            case .none: return "None"
            case .prealloc: return "Prealloc"
            case .trunc: return "Trunc"
            case .falloc: return "Falloc (recommended)"
            }
        }
    }

    // MARK: - Persistence

    private func load() {
        isLoading = true
        defer { isLoading = false }

        launchAtLogin = defaults.bool(forKey: "launchAtLogin")
        showInDock = defaults.bool(forKey: "showInDock")
        downloadDirectory = defaults.string(forKey: "downloadDirectory")
            ?? NSString("~/Downloads").expandingTildeInPath
        notifyOnComplete = defaults.object(forKey: "notifyOnComplete") as? Bool ?? true
        maxConcurrentDownloads = defaults.object(forKey: "maxConcurrentDownloads") as? Int ?? 5
        maxConnectionsPerServer = defaults.object(forKey: "maxConnectionsPerServer") as? Int ?? 16
        globalDownloadLimit = defaults.integer(forKey: "globalDownloadLimit")
        globalUploadLimit = defaults.integer(forKey: "globalUploadLimit")
        proxyURL = defaults.string(forKey: "proxyURL") ?? ""
        rpcPort = defaults.object(forKey: "rpcPort") as? Int ?? 6800
        rpcSecret = SecretsStore.loadSecret() ?? generateRandomSecret()
        aria2cPath = defaults.string(forKey: "aria2cPath") ?? ""
        rclonePath = defaults.string(forKey: "rclonePath") ?? ""
        fileAllocation = FileAllocation(rawValue: defaults.string(forKey: "fileAllocation") ?? "") ?? .falloc
        extraArguments = defaults.string(forKey: "extraArguments") ?? ""
        loadRules()
    }

    private func loadRules() {
        guard let data = defaults.data(forKey: "downloadRules"),
              let rules = try? JSONDecoder().decode([DownloadRule].self, from: data) else {
            downloadRules = DownloadRule.defaults
            return
        }
        downloadRules = rules
    }

    private func saveRules() {
        if let data = try? JSONEncoder().encode(downloadRules) {
            defaults.set(data, forKey: "downloadRules")
        }
    }

    /// Get the effective options for a given URL
    func options(for url: String) -> [String: String] {
        let cat = DownloadRule.category(for: url)
        let rule = downloadRules.first { $0.category == cat } ?? downloadRules.last!
        var opts: [String: String] = [:]

        let dir = rule.directory.isEmpty ? downloadDirectory : rule.directory
        opts["dir"] = dir
        opts["max-connection-per-server"] = "\(rule.maxConnections)"
        opts["split"] = "\(rule.maxConnections)"

        if rule.speedLimit > 0 {
            opts["max-download-limit"] = "\(rule.speedLimit)K"
        }
        if !rule.autoStart {
            opts["pause"] = "true"
        }
        return opts
    }

    private func generateRandomSecret() -> String {
        let length = 32
        let characters = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
        return String((0..<length).map { _ in characters.randomElement()! })
    }

    private func updateLoginItem() {
        if #available(macOS 13.0, *) {
            do {
                if launchAtLogin {
                    try SMAppService.mainApp.register()
                } else {
                    try SMAppService.mainApp.unregister()
                }
            } catch {
                print("Login item error: \(error)")
            }
        }
    }
}
