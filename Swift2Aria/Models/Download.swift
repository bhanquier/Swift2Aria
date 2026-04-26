import Foundation

struct Download: Identifiable {
    let id: String // aria2 GID
    var name: String
    var url: String
    var totalLength: Int64
    var completedLength: Int64
    var downloadSpeed: Int64
    var uploadSpeed: Int64
    var status: Status
    var connections: Int
    var dir: String
    var numPieces: Int
    var pieceLength: Int

    enum Status: String, Codable {
        case active, waiting, paused, error, complete, removed
    }

    var progress: Double {
        guard totalLength > 0 else { return 0 }
        return Double(completedLength) / Double(totalLength)
    }

    var isActive: Bool { status == .active }

    static func fromRPC(_ dict: [String: Any]) -> Download {
        let gid = dict["gid"] as? String ?? ""
        let totalLength = Int64(dict["totalLength"] as? String ?? "0") ?? 0
        let completedLength = Int64(dict["completedLength"] as? String ?? "0") ?? 0
        let downloadSpeed = Int64(dict["downloadSpeed"] as? String ?? "0") ?? 0
        let uploadSpeed = Int64(dict["uploadSpeed"] as? String ?? "0") ?? 0
        let statusStr = dict["status"] as? String ?? "waiting"
        let connections = Int(dict["connections"] as? String ?? "0") ?? 0
        let dir = dict["dir"] as? String ?? ""
        let numPieces = Int(dict["numPieces"] as? String ?? "0") ?? 0
        let pieceLength = Int(dict["pieceLength"] as? String ?? "0") ?? 0

        // Extract filename from bittorrent info or files
        var name = ""
        if let bt = dict["bittorrent"] as? [String: Any],
           let info = bt["info"] as? [String: Any],
           let btName = info["name"] as? String {
            name = btName
        } else if let files = dict["files"] as? [[String: Any]],
                  let first = files.first,
                  let path = first["path"] as? String, !path.isEmpty {
            name = (path as NSString).lastPathComponent
        }

        // Extract first URI
        var url = ""
        if let files = dict["files"] as? [[String: Any]],
           let first = files.first,
           let uris = first["uris"] as? [[String: Any]],
           let firstUri = uris.first,
           let uri = firstUri["uri"] as? String {
            url = uri
        }

        if name.isEmpty {
            name = (URL(string: url)?.lastPathComponent) ?? gid
        }

        return Download(
            id: gid,
            name: name,
            url: url,
            totalLength: totalLength,
            completedLength: completedLength,
            downloadSpeed: downloadSpeed,
            uploadSpeed: uploadSpeed,
            status: Status(rawValue: statusStr) ?? .waiting,
            connections: connections,
            dir: dir,
            numPieces: numPieces,
            pieceLength: pieceLength
        )
    }
}

extension Download: Hashable {
    static func == (lhs: Download, rhs: Download) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

extension Download {
    static let preview = Download(
        id: "abc123",
        name: "example-file.zip",
        url: "https://example.com/file.zip",
        totalLength: 104_857_600,
        completedLength: 52_428_800,
        downloadSpeed: 1_048_576,
        uploadSpeed: 0,
        status: .active,
        connections: 4,
        dir: "~/Downloads",
        numPieces: 100,
        pieceLength: 1_048_576
    )
}
