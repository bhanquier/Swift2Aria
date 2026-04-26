import SwiftUI

/// Cloud transfers and remotes panel — shown in main content area
struct CloudView: View {
    @EnvironmentObject var rclone: RcloneManager
    @State private var selectedRemote: CloudRemote?
    @State private var showNewTransfer = false

    var body: some View {
        VStack(spacing: 0) {
            if !rclone.isConnected {
                rcloneNotConnected
            } else if rclone.remotes.isEmpty {
                noRemotes
            } else {
                cloudContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Not Connected

    private var rcloneNotConnected: some View {
        VStack(spacing: 16) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)
            Text("rclone not connected")
                .font(.title3)
                .foregroundStyle(.secondary)
            if let error = rclone.error {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.red)
                Text("brew install rclone")
                    .font(.system(.callout, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
            }
        }
    }

    // MARK: - No Remotes

    private var noRemotes: some View {
        VStack(spacing: 16) {
            Image(systemName: "cloud.fill")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No Cloud Accounts")
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Add a remote in Preferences → Cloud Accounts")
                .font(.callout)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Cloud Content

    private var cloudContent: some View {
        VStack(spacing: 0) {
            // Remotes grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200, maximum: 280))], spacing: 12) {
                    ForEach(rclone.remotes) { remote in
                        RemoteCard(remote: remote)
                    }
                }
                .padding(16)

                // Active transfers
                if !rclone.transfers.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Active Transfers")
                                .font(.headline)
                            Spacer()
                            if rclone.globalSpeed > 0 {
                                Text(formatSpeed(rclone.globalSpeed))
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        ForEach(rclone.transfers) { transfer in
                            CloudTransferRow(transfer: transfer)
                        }
                    }
                    .padding(16)
                }
            }
        }
    }
}

// MARK: - Remote Card

struct RemoteCard: View {
    let remote: CloudRemote
    @EnvironmentObject var rclone: RcloneManager

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: remote.icon)
                    .font(.title2)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 1) {
                    Text(remote.name)
                        .font(.headline)
                    Text(remote.typeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()

                if remote.isMounted {
                    Image(systemName: "externaldrive.fill.badge.checkmark")
                        .font(.caption)
                        .foregroundStyle(.green)
                }
            }

            // Space bar
            if remote.spaceTotal > 0 {
                VStack(alignment: .leading, spacing: 3) {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(.quaternary)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(spaceColor.gradient)
                                .frame(width: max(0, geo.size.width * Double(remote.spaceUsed) / Double(remote.spaceTotal)))
                        }
                    }
                    .frame(height: 4)

                    HStack {
                        Text("\(formatBytes(remote.spaceUsed)) / \(formatBytes(remote.spaceTotal))")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(formatBytes(remote.spaceFree)) free")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            // Actions
            HStack(spacing: 8) {
                if remote.isMounted {
                    Button {
                        Task { try? await rclone.unmountRemote(remote) }
                    } label: {
                        Label("Unmount", systemImage: "eject.fill")
                    }
                    .controlSize(.small)

                    Button {
                        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: remote.mountPoint)
                    } label: {
                        Label("Finder", systemImage: "folder")
                    }
                    .controlSize(.small)
                } else {
                    Button {
                        Task { try? await rclone.mountRemote(remote) }
                    } label: {
                        Label("Mount", systemImage: "externaldrive.badge.plus")
                    }
                    .controlSize(.small)
                }
            }
        }
        .padding(12)
        .background(.background, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(.quaternary)
        )
    }

    private var spaceColor: Color {
        let ratio = Double(remote.spaceUsed) / Double(max(1, remote.spaceTotal))
        if ratio > 0.9 { return .red }
        if ratio > 0.7 { return .orange }
        return .blue
    }
}

// MARK: - Cloud Transfer Row

struct CloudTransferRow: View {
    let transfer: CloudTransfer

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: transfer.operation.icon)
                .foregroundStyle(.blue)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                Text(transfer.name)
                    .font(.callout)
                    .lineLimit(1)

                ProgressView(value: transfer.progress)
                    .tint(.blue)
            }

            VStack(alignment: .trailing, spacing: 2) {
                Text(formatSpeed(transfer.speed))
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(.secondary)
                if transfer.bytesTotal > 0 {
                    Text("\(formatBytes(transfer.bytesTransferred)) / \(formatBytes(transfer.bytesTotal))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 100, alignment: .trailing)
        }
        .padding(8)
        .background(.quaternary.opacity(0.3), in: RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    CloudView()
        .environmentObject(RcloneManager())
        .frame(width: 600, height: 500)
}
