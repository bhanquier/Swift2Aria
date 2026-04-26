import Foundation

/// Represents a configured rclone remote (GDrive, S3, Dropbox, etc.)
struct CloudRemote: Identifiable, Hashable {
    let id: String // same as name
    let name: String
    let type: String
    var isMounted: Bool = false
    var mountPoint: String = ""
    var spaceTotal: Int64 = 0
    var spaceUsed: Int64 = 0
    var spaceFree: Int64 = 0

    var icon: String {
        switch type {
        case "drive": return "externaldrive.fill.badge.icloud"
        case "s3": return "cloud.fill"
        case "dropbox": return "shippingbox.fill"
        case "onedrive": return "cloud.fill"
        case "b2": return "externaldrive.fill"
        case "sftp", "ftp": return "server.rack"
        case "local": return "folder.fill"
        case "mega": return "cloud.fill"
        case "box": return "archivebox.fill"
        case "swift": return "cloud.fill"
        case "azureblob": return "cloud.fill"
        case "gcs": return "cloud.fill"
        case "pcloud": return "cloud.fill"
        default: return "externaldrive.connected.to.line.below.fill"
        }
    }

    var typeLabel: String {
        switch type {
        case "drive": return "Google Drive"
        case "s3": return "Amazon S3"
        case "dropbox": return "Dropbox"
        case "onedrive": return "OneDrive"
        case "b2": return "Backblaze B2"
        case "sftp": return "SFTP"
        case "ftp": return "FTP"
        case "local": return "Local"
        case "mega": return "MEGA"
        case "box": return "Box"
        case "swift": return "OpenStack Swift"
        case "azureblob": return "Azure Blob"
        case "gcs": return "Google Cloud Storage"
        case "pcloud": return "pCloud"
        case "webdav": return "WebDAV"
        case "smb": return "SMB"
        default: return type.capitalized
        }
    }

    /// fs string for rclone API calls
    var fs: String { "\(name):" }

    /// Known remote types for the "Add Remote" picker
    static let supportedTypes: [(type: String, label: String)] = [
        ("drive", "Google Drive"),
        ("s3", "Amazon S3"),
        ("dropbox", "Dropbox"),
        ("onedrive", "OneDrive"),
        ("b2", "Backblaze B2"),
        ("sftp", "SFTP"),
        ("ftp", "FTP"),
        ("mega", "MEGA"),
        ("box", "Box"),
        ("webdav", "WebDAV"),
        ("azureblob", "Azure Blob"),
        ("gcs", "Google Cloud Storage"),
        ("pcloud", "pCloud"),
        ("smb", "SMB / CIFS"),
    ]
}

/// A cloud transfer (copy, sync, move) tracked by job ID
struct CloudTransfer: Identifiable {
    let id: Int // rclone job ID
    var name: String
    var srcFs: String
    var dstFs: String
    var operation: Operation
    var bytesTotal: Int64
    var bytesTransferred: Int64
    var speed: Int64
    var isFinished: Bool
    var error: String?
    var eta: Double // seconds

    enum Operation: String {
        case copy, sync, move
        var label: String { rawValue.capitalized }
        var icon: String {
            switch self {
            case .copy: return "doc.on.doc"
            case .sync: return "arrow.triangle.2.circlepath"
            case .move: return "arrow.right.doc.on.clipboard"
            }
        }
    }

    var progress: Double {
        guard bytesTotal > 0 else { return 0 }
        return Double(bytesTransferred) / Double(bytesTotal)
    }

    static func fromStats(_ dict: [String: Any], jobID: Int) -> CloudTransfer {
        CloudTransfer(
            id: jobID,
            name: dict["name"] as? String ?? "Transfer",
            srcFs: "",
            dstFs: "",
            operation: .copy,
            bytesTotal: dict["size"] as? Int64 ?? (dict["bytes"] as? Int64 ?? 0),
            bytesTransferred: dict["bytes"] as? Int64 ?? 0,
            speed: dict["speed"] as? Int64 ?? (dict["speedAvg"] as? Int64 ?? 0),
            isFinished: false,
            error: nil,
            eta: dict["eta"] as? Double ?? 0
        )
    }
}
