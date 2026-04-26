import SwiftUI

/// Popover shown from the menu bar icon
struct MenuBarView: View {
    @EnvironmentObject var aria2: Aria2Manager
    @EnvironmentObject var rclone: RcloneManager
    @EnvironmentObject var settings: AppSettings
    @Environment(\.openWindow) private var openWindow
    @State private var showAddSheet = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            if aria2.downloads.isEmpty && rclone.transfers.isEmpty {
                emptyState
            } else {
                downloadList

                if !rclone.transfers.isEmpty {
                    Divider()
                    cloudSection
                }
            }

            Divider()
            footer
        }
        .frame(width: 480, height: 480)
        .sheet(isPresented: $showAddSheet) {
            AddDownloadView()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                Text("Swift2Aria")
                    .font(.system(size: 20, weight: .semibold))
                HStack(spacing: 20) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.blue)
                        Text(formatSpeed(aria2.globalDownloadSpeed))
                            .font(.system(size: 16, design: .monospaced))
                    }
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.orange)
                        Text(formatSpeed(aria2.globalUploadSpeed))
                            .font(.system(size: 16, design: .monospaced))
                    }
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            Button { showAddSheet = true } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 28))
            }
            .buttonStyle(.borderless)
        }
        .padding(20)
    }

    // MARK: - Download List

    private var downloadList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(aria2.downloads.prefix(15)) { download in
                    CompactDownloadRow(download: download)
                    if download.id != aria2.downloads.prefix(15).last?.id {
                        Divider().padding(.leading, 52)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundStyle(.tertiary)
            Text("No active downloads")
                .font(.system(size: 18))
                .foregroundStyle(.secondary)
            Text("Click + to add a download")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Cloud

    private var cloudSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CLOUD TRANSFERS")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 20)
                .padding(.top, 12)
            ForEach(rclone.transfers.prefix(5)) { transfer in
                HStack(spacing: 10) {
                    Image(systemName: "cloud.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.cyan)
                    Text(transfer.name)
                        .font(.system(size: 15))
                        .lineLimit(1)
                    Spacer()
                    Text(formatSpeed(transfer.speed))
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 6)
            }
            .padding(.bottom, 4)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Button {
                openWindow(id: "main")
                NSApp.activate(ignoringOtherApps: true)
            } label: {
                Label("Open Window", systemImage: "macwindow")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderless)

            Spacer()

            HStack(spacing: 20) {
                Button {
                    Task { try? await aria2.clearCompleted() }
                } label: {
                    Label("Clear Done", systemImage: "xmark.circle")
                        .font(.system(size: 14))
                }
                .buttonStyle(.borderless)
                .disabled(aria2.downloads.filter { $0.status == .complete }.isEmpty)

                Button("Quit") {
                    aria2.stop()
                    NSApp.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.red)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 14)
    }
}

// MARK: - Compact Row for Menu Bar

struct CompactDownloadRow: View {
    let download: Download
    @EnvironmentObject var aria2: Aria2Manager

    var body: some View {
        HStack(spacing: 12) {
            // Status icon
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: statusIcon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(statusColor)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(download.name)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(.quaternary)
                        RoundedRectangle(cornerRadius: 2.5)
                            .fill(statusColor.gradient)
                            .frame(width: max(0, geo.size.width * download.progress))
                    }
                }
                .frame(height: 5)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                if download.isActive {
                    Text(formatSpeed(download.downloadSpeed))
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                if download.totalLength > 0 {
                    Text("\(Int(download.progress * 100))%")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 80, alignment: .trailing)

            // Quick action
            actionButton
                .frame(width: 28)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var actionButton: some View {
        if download.isActive || download.status == .waiting {
            Button {
                Task { try? await aria2.pauseDownload(download) }
            } label: {
                Image(systemName: "pause.fill")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        } else if download.status == .paused {
            Button {
                Task { try? await aria2.resumeDownload(download) }
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 14))
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.secondary)
        } else if download.status == .complete {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.green)
        } else if download.status == .error {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(.red)
        } else {
            Color.clear
        }
    }

    private var statusIcon: String {
        switch download.status {
        case .active: return "arrow.down"
        case .waiting: return "clock"
        case .paused: return "pause"
        case .complete: return "checkmark"
        case .error: return "exclamationmark"
        case .removed: return "minus"
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
}
