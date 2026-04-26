import Foundation

/// JSON-RPC 2.0 client for aria2c daemon
actor Aria2RPC {
    private let url: URL
    private let secret: String
    private let session: URLSession
    private var requestId = 0

    init(host: String = "localhost", port: Int = 6800, secret: String = "") {
        self.url = URL(string: "http://\(host):\(port)/jsonrpc")!
        self.secret = secret
        self.session = URLSession(configuration: .default)
    }

    // MARK: - Download Management

    func addUri(_ uris: [String], options: [String: String] = [:]) async throws -> String {
        let params: [Any] = [uris, options]
        let result = try await call("aria2.addUri", params: params)
        guard let gid = result as? String else {
            throw Aria2Error.invalidResponse
        }
        return gid
    }

    func addTorrent(data: Data, options: [String: String] = [:]) async throws -> String {
        let base64 = data.base64EncodedString()
        let params: [Any] = [base64, [], options]
        let result = try await call("aria2.addTorrent", params: params)
        guard let gid = result as? String else {
            throw Aria2Error.invalidResponse
        }
        return gid
    }

    func addMetalink(data: Data, options: [String: String] = [:]) async throws -> String {
        let base64 = data.base64EncodedString()
        let params: [Any] = [base64, options]
        let result = try await call("aria2.addMetalink", params: params)
        guard let gid = result as? String else {
            throw Aria2Error.invalidResponse
        }
        return gid
    }

    func remove(gid: String) async throws -> String {
        let result = try await call("aria2.remove", params: [gid])
        return result as? String ?? gid
    }

    func forceRemove(gid: String) async throws -> String {
        let result = try await call("aria2.forceRemove", params: [gid])
        return result as? String ?? gid
    }

    func pause(gid: String) async throws -> String {
        let result = try await call("aria2.pause", params: [gid])
        return result as? String ?? gid
    }

    func unpause(gid: String) async throws -> String {
        let result = try await call("aria2.unpause", params: [gid])
        return result as? String ?? gid
    }

    func pauseAll() async throws {
        _ = try await call("aria2.pauseAll", params: [])
    }

    func unpauseAll() async throws {
        _ = try await call("aria2.unpauseAll", params: [])
    }

    // MARK: - Status

    func tellStatus(gid: String) async throws -> [String: Any] {
        let result = try await call("aria2.tellStatus", params: [gid])
        guard let dict = result as? [String: Any] else {
            throw Aria2Error.invalidResponse
        }
        return dict
    }

    func tellActive() async throws -> [[String: Any]] {
        let result = try await call("aria2.tellActive", params: [])
        return result as? [[String: Any]] ?? []
    }

    func tellWaiting(offset: Int, num: Int) async throws -> [[String: Any]] {
        let result = try await call("aria2.tellWaiting", params: [offset, num])
        return result as? [[String: Any]] ?? []
    }

    func tellStopped(offset: Int, num: Int) async throws -> [[String: Any]] {
        let result = try await call("aria2.tellStopped", params: [offset, num])
        return result as? [[String: Any]] ?? []
    }

    func getGlobalStat() async throws -> [String: Any] {
        let result = try await call("aria2.getGlobalStat", params: [])
        guard let dict = result as? [String: Any] else {
            throw Aria2Error.invalidResponse
        }
        return dict
    }

    func getVersion() async throws -> String {
        let result = try await call("aria2.getVersion", params: [])
        guard let dict = result as? [String: Any],
              let version = dict["version"] as? String else {
            throw Aria2Error.invalidResponse
        }
        return version
    }

    func purgeDownloadResult() async throws {
        _ = try await call("aria2.purgeDownloadResult", params: [])
    }

    func shutdown() async throws {
        _ = try await call("aria2.shutdown", params: [])
    }

    // MARK: - JSON-RPC

    private func call(_ method: String, params: [Any]) async throws -> Any {
        requestId += 1
        var rpcParams: [Any] = []
        if !secret.isEmpty {
            rpcParams.append("token:\(secret)")
        }
        rpcParams.append(contentsOf: params)

        let body: [String: Any] = [
            "jsonrpc": "2.0",
            "id": requestId,
            "method": method,
            "params": rpcParams
        ]

        let jsonData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = jsonData
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 10

        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw Aria2Error.httpError
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Aria2Error.invalidResponse
        }

        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw Aria2Error.rpcError(message)
        }

        return json["result"] as Any
    }
}

enum Aria2Error: LocalizedError {
    case httpError
    case invalidResponse
    case rpcError(String)
    case daemonNotRunning
    case binaryNotFound

    var errorDescription: String? {
        switch self {
        case .httpError: return "HTTP request to aria2 failed"
        case .invalidResponse: return "Invalid response from aria2"
        case .rpcError(let msg): return "aria2 error: \(msg)"
        case .daemonNotRunning: return "aria2c daemon is not running"
        case .binaryNotFound: return "aria2c binary not found"
        }
    }
}
