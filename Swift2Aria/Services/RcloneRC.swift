import Foundation

/// REST API client for rclone's remote control interface
actor RcloneRC {
    private let baseURL: URL
    private let session: URLSession
    private let user: String
    private let pass: String

    init(host: String = "localhost", port: Int = 5572, user: String = "aria2mac", pass: String = "aria2mac") {
        self.baseURL = URL(string: "http://\(host):\(port)")!
        self.user = user
        self.pass = pass

        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
    }

    // MARK: - Remotes

    func listRemotes() async throws -> [String] {
        let result = try await call("config/listremotes")
        return result["remotes"] as? [String] ?? []
    }

    func getRemote(_ name: String) async throws -> [String: Any] {
        let result = try await call("config/get", params: ["name": name])
        return result
    }

    func createRemote(name: String, type: String, parameters: [String: String]) async throws {
        var params: [String: Any] = ["name": name, "type": type, "parameters": parameters]
        params["obscure"] = true
        _ = try await call("config/create", params: params)
    }

    func deleteRemote(name: String) async throws {
        _ = try await call("config/delete", params: ["name": name])
    }

    // MARK: - Operations

    func copyFile(srcFs: String, srcRemote: String, dstFs: String, dstRemote: String) async throws {
        _ = try await call("operations/copyfile", params: [
            "srcFs": srcFs,
            "srcRemote": srcRemote,
            "dstFs": dstFs,
            "dstRemote": dstRemote,
            "_async": true,
        ])
    }

    func sync(srcFs: String, dstFs: String) async throws -> Int {
        let result = try await call("sync/sync", params: [
            "srcFs": srcFs,
            "dstFs": dstFs,
            "_async": true,
        ])
        return result["jobid"] as? Int ?? 0
    }

    func copyDir(srcFs: String, dstFs: String) async throws -> Int {
        let result = try await call("sync/copy", params: [
            "srcFs": srcFs,
            "dstFs": dstFs,
            "_async": true,
        ])
        return result["jobid"] as? Int ?? 0
    }

    func moveDir(srcFs: String, dstFs: String) async throws -> Int {
        let result = try await call("sync/move", params: [
            "srcFs": srcFs,
            "dstFs": dstFs,
            "_async": true,
        ])
        return result["jobid"] as? Int ?? 0
    }

    func listDir(fs: String, remote: String) async throws -> [[String: Any]] {
        let result = try await call("operations/list", params: [
            "fs": fs,
            "remote": remote,
        ])
        return result["list"] as? [[String: Any]] ?? []
    }

    func about(fs: String) async throws -> [String: Any] {
        return try await call("operations/about", params: ["fs": fs])
    }

    func deleteFile(fs: String, remote: String) async throws {
        _ = try await call("operations/deletefile", params: [
            "fs": fs,
            "remote": remote,
        ])
    }

    // MARK: - Mounts

    func mount(fs: String, mountPoint: String) async throws {
        _ = try await call("mount/mount", params: [
            "fs": fs,
            "mountPoint": mountPoint,
            "mountOpt": ["AllowOther": true],
            "vfsOpt": ["CacheMode": "full"],
        ])
    }

    func unmount(mountPoint: String) async throws {
        _ = try await call("mount/unmount", params: ["mountPoint": mountPoint])
    }

    func listMounts() async throws -> [[String: Any]] {
        let result = try await call("mount/listmounts")
        return result["mountPoints"] as? [[String: Any]] ?? []
    }

    // MARK: - Jobs / Transfers

    func jobStatus(jobID: Int) async throws -> [String: Any] {
        return try await call("job/status", params: ["jobid": jobID])
    }

    func jobList() async throws -> [[String: Any]] {
        let result = try await call("job/list")
        return result["jobids"] as? [[String: Any]] ?? []
    }

    func jobStop(jobID: Int) async throws {
        _ = try await call("job/stop", params: ["jobid": jobID])
    }

    func coreStats() async throws -> [String: Any] {
        return try await call("core/stats")
    }

    func coreTransferring() async throws -> [[String: Any]] {
        let result = try await call("core/stats")
        return result["transferring"] as? [[String: Any]] ?? []
    }

    func getVersion() async throws -> String {
        let result = try await call("core/version")
        return result["version"] as? String ?? "unknown"
    }

    // MARK: - HTTP

    private func call(_ endpoint: String, params: [String: Any] = [:]) async throws -> [String: Any] {
        let url = baseURL.appendingPathComponent(endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Basic auth
        let credentials = "\(user):\(pass)"
        if let data = credentials.data(using: .utf8) {
            request.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
        }

        if !params.isEmpty {
            request.httpBody = try JSONSerialization.data(withJSONObject: params)
        } else {
            request.httpBody = "{}".data(using: .utf8)
        }

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw RcloneError.apiError(body)
        }

        if data.isEmpty { return [:] }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return [:]
        }

        return json
    }
}

enum RcloneError: LocalizedError {
    case apiError(String)
    case notRunning
    case binaryNotFound
    case mountFailed(String)

    var errorDescription: String? {
        switch self {
        case .apiError(let msg): return "rclone: \(msg)"
        case .notRunning: return "rclone daemon is not running"
        case .binaryNotFound: return "rclone binary not found"
        case .mountFailed(let msg): return "Mount failed: \(msg)"
        }
    }
}
