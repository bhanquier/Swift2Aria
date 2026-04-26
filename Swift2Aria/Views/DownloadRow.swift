import SwiftUI

struct DownloadRow: View {
    let download: Download

    var body: some View {
        HStack(spacing: 14) {
            fileIcon
            details
        }
        .padding(.vertical, 8)
    }

    // MARK: - File Icon

    private var fileIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10)
                .fill(statusGradient)
                .frame(width: 48, height: 48)

            Image(systemName: fileIconName)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(.white)
        }
    }

    private var statusGradient: LinearGradient {
        switch download.status {
        case .active:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .waiting:
            return LinearGradient(colors: [.orange, .yellow], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .paused:
            return LinearGradient(colors: [.gray, .gray.opacity(0.7)], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .complete:
            return LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .error:
            return LinearGradient(colors: [.red, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        case .removed:
            return LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.3)], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
    }

    private var fileIconName: String {
        let ext = (download.name as NSString).pathExtension.lowercased()
        if download.url.hasPrefix("magnet:") || ext == "torrent" {
            return "arrow.triangle.2.circlepath"
        }
        switch ext {
        case "dmg", "pkg", "app": return "shippingbox.fill"
        case "zip", "tar", "gz", "bz2", "xz", "rar", "7z": return "doc.zipper"
        case "iso", "img": return "opticaldisc.fill"
        case "mp4", "mkv", "avi", "mov", "webm": return "film.fill"
        case "mp3", "flac", "aac", "ogg", "wav": return "music.note"
        case "pdf": return "doc.text.fill"
        case "jpg", "jpeg", "png", "gif", "webp", "svg": return "photo.fill"
        default: return "arrow.down.doc.fill"
        }
    }

    // MARK: - Details

    private var details: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Row 1: Name + size
            HStack(alignment: .firstTextBaseline) {
                Text(download.name)
                    .font(.system(.body, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer(minLength: 8)

                sizeLabel
            }

            // Row 2: Progress bar
            progressBar

            // Row 3: Status + speed
            HStack(spacing: 0) {
                statusBadge

                if download.isActive, download.totalLength > 0, download.downloadSpeed > 0 {
                    Text(" — ")
                        .foregroundStyle(.tertiary)
                    Text(etaText)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if download.isActive {
                    speedLabel
                }

                if download.status == .complete {
                    Button {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: download.dir)
                    } label: {
                        Image(systemName: "folder")
                            .font(.callout)
                    }
                    .buttonStyle(.borderless)
                    .help("Show in Finder")
                }
            }
            .font(.callout)
        }
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(.quaternary)
                    .frame(height: 6)

                RoundedRectangle(cornerRadius: 3)
                    .fill(progressGradient)
                    .frame(width: max(0, geo.size.width * download.progress), height: 6)
            }
        }
        .frame(height: 6)
    }

    private var progressGradient: LinearGradient {
        switch download.status {
        case .active:
            return LinearGradient(colors: [.blue, .cyan], startPoint: .leading, endPoint: .trailing)
        case .complete:
            return LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
        case .error:
            return LinearGradient(colors: [.red, .red], startPoint: .leading, endPoint: .trailing)
        case .paused:
            return LinearGradient(colors: [.gray, .gray], startPoint: .leading, endPoint: .trailing)
        default:
            return LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.5)], startPoint: .leading, endPoint: .trailing)
        }
    }

    // MARK: - Sub-components

    private var sizeLabel: some View {
        Group {
            if download.totalLength > 0 {
                HStack(spacing: 3) {
                    Text(formatBytes(download.completedLength))
                        .foregroundStyle(.primary)
                    Text("/")
                        .foregroundStyle(.tertiary)
                    Text(formatBytes(download.totalLength))
                        .foregroundStyle(.secondary)
                }
            } else if download.completedLength > 0 {
                Text(formatBytes(download.completedLength))
                    .foregroundStyle(.secondary)
            }
        }
        .font(.system(.callout, design: .monospaced))
    }

    private var statusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            Text(statusLabel)
                .foregroundStyle(.secondary)
        }
    }

    private var statusLabel: String {
        switch download.status {
        case .active:
            if download.completedLength == download.totalLength && download.totalLength > 0 {
                return "Finalizing"
            }
            return "Downloading"
        case .waiting: return "Queued"
        case .paused: return "Paused"
        case .complete: return "Complete"
        case .error: return "Failed"
        case .removed: return "Removed"
        }
    }

    private var statusColor: Color {
        switch download.status {
        case .active: return .blue
        case .waiting: return .orange
        case .paused: return .gray
        case .complete: return .green
        case .error: return .red
        case .removed: return .gray.opacity(0.5)
        }
    }

    private var etaText: String {
        let remaining = download.totalLength - download.completedLength
        let seconds = Double(remaining) / Double(download.downloadSpeed)
        return formatDuration(seconds) + " left"
    }

    private var speedLabel: some View {
        HStack(spacing: 12) {
            if download.connections > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.callout)
                    Text("\(download.connections)")
                }
                .foregroundStyle(.tertiary)
            }

            HStack(spacing: 4) {
                Image(systemName: "arrow.down")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(.blue)
                Text(formatSpeed(download.downloadSpeed))
                    .foregroundStyle(.secondary)
            }

            if download.uploadSpeed > 0 {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up")
                        .font(.callout.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text(formatSpeed(download.uploadSpeed))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.system(.callout, design: .monospaced))
    }
}

// MARK: - Previews

#Preview("All States") {
    List {
        DownloadRow(download: Download(
            id: "1", name: "ubuntu-24.04-desktop-amd64.iso", url: "https://releases.ubuntu.com/24.04/ubuntu-24.04-desktop-amd64.iso",
            totalLength: 6_300_000_000, completedLength: 2_100_000_000,
            downloadSpeed: 12_582_912, uploadSpeed: 0, status: .active,
            connections: 16, dir: "~/Downloads", numPieces: 6300, pieceLength: 1_048_576
        ))
        DownloadRow(download: Download(
            id: "2", name: "Xcode_15.4.xip", url: "",
            totalLength: 8_000_000_000, completedLength: 0,
            downloadSpeed: 0, uploadSpeed: 0, status: .waiting,
            connections: 0, dir: "~/Downloads", numPieces: 8000, pieceLength: 1_048_576
        ))
        DownloadRow(download: Download(
            id: "3", name: "macOS-Sequoia.dmg", url: "",
            totalLength: 14_000_000_000, completedLength: 7_800_000_000,
            downloadSpeed: 0, uploadSpeed: 0, status: .paused,
            connections: 0, dir: "~/Downloads", numPieces: 14000, pieceLength: 1_048_576
        ))
        DownloadRow(download: Download(
            id: "4", name: "node-v22.0.0.pkg", url: "",
            totalLength: 50_000_000, completedLength: 50_000_000,
            downloadSpeed: 0, uploadSpeed: 0, status: .complete,
            connections: 0, dir: "~/Downloads", numPieces: 50, pieceLength: 1_048_576
        ))
        DownloadRow(download: Download(
            id: "5", name: "broken-link.zip", url: "",
            totalLength: 100_000_000, completedLength: 12_000_000,
            downloadSpeed: 0, uploadSpeed: 0, status: .error,
            connections: 0, dir: "~/Downloads", numPieces: 100, pieceLength: 1_048_576
        ))
    }
    .listStyle(.inset(alternatesRowBackgrounds: true))
    .frame(width: 700, height: 500)
}
