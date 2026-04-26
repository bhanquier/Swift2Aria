import Foundation

/// Per-file-type download rules
struct DownloadRule: Identifiable, Codable, Hashable {
    var id: String { category.rawValue }
    var category: Category
    var enabled: Bool = true
    var directory: String = ""       // empty = use global default
    var maxConnections: Int = 4
    var speedLimit: Int = 0          // KB/s, 0 = unlimited
    var autoStart: Bool = true

    enum Category: String, Codable, CaseIterable, Identifiable {
        case video, audio, archives, diskImages, documents, torrents, other

        var id: String { rawValue }

        var label: String {
            switch self {
            case .video: return "Video"
            case .audio: return "Audio"
            case .archives: return "Archives"
            case .diskImages: return "Disk Images"
            case .documents: return "Documents"
            case .torrents: return "Torrents"
            case .other: return "Other"
            }
        }

        var icon: String {
            switch self {
            case .video: return "film.fill"
            case .audio: return "music.note"
            case .archives: return "doc.zipper"
            case .diskImages: return "opticaldisc.fill"
            case .documents: return "doc.text.fill"
            case .torrents: return "arrow.triangle.2.circlepath"
            case .other: return "doc.fill"
            }
        }

        var extensions: [String] {
            switch self {
            case .video: return ["mp4", "mkv", "avi", "mov", "webm", "flv", "wmv", "m4v", "ts"]
            case .audio: return ["mp3", "flac", "aac", "ogg", "wav", "m4a", "wma", "opus", "alac"]
            case .archives: return ["zip", "tar", "gz", "bz2", "xz", "rar", "7z", "zst", "lz4"]
            case .diskImages: return ["dmg", "iso", "img", "pkg", "app", "deb", "rpm"]
            case .documents: return ["pdf", "doc", "docx", "xls", "xlsx", "ppt", "pptx", "txt", "rtf", "csv"]
            case .torrents: return ["torrent", "metalink"]
            case .other: return []
            }
        }
    }

    /// Match a URL or filename to a category
    static func category(for urlString: String) -> Category {
        if urlString.hasPrefix("magnet:") { return .torrents }

        let ext = (URL(string: urlString)?.pathExtension
                   ?? (urlString as NSString).pathExtension).lowercased()
        if ext.isEmpty { return .other }

        for cat in Category.allCases where cat != .other {
            if cat.extensions.contains(ext) { return cat }
        }
        return .other
    }

    static var defaults: [DownloadRule] {
        Category.allCases.map { DownloadRule(category: $0) }
    }
}
