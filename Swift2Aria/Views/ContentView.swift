import SwiftUI

struct ContentView: View {
    @EnvironmentObject var aria2: Aria2Manager
    @EnvironmentObject var rclone: RcloneManager
    @State private var showAddSheet = false
    @State private var selectedFilter: SidebarFilter = .all
    @State private var selection = Set<String>()
    @State private var isDragOver = false
    @State private var searchText = ""

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 220, ideal: 240, max: 280)
        } detail: {
            mainContent
        }
        .navigationTitle("")
        .toolbar { toolbarContent }
        .sheet(isPresented: $showAddSheet) {
            AddDownloadView()
        }
        .onReceive(NotificationCenter.default.publisher(for: .showAddDownload)) { _ in
            showAddSheet = true
        }
        .onAppear {
            // Services started from MenuBarExtra.onAppear in Swift2AriaApp
        }
        .overlay { dropOverlay }
        .onDrop(of: [.url, .fileURL, .text], isTargeted: $isDragOver) { providers in
            handleDrop(providers)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        List(selection: $selectedFilter) {
            Section("Downloads") {
                SidebarItem(
                    filter: .all,
                    icon: "arrow.down.circle.fill",
                    color: .blue,
                    count: aria2.downloads.count
                )
                SidebarItem(
                    filter: .active,
                    icon: "play.circle.fill",
                    color: .green,
                    count: aria2.downloads.filter { $0.status == .active }.count
                )
                SidebarItem(
                    filter: .waiting,
                    icon: "clock.fill",
                    color: .orange,
                    count: aria2.downloads.filter { $0.status == .waiting || $0.status == .paused }.count
                )
                SidebarItem(
                    filter: .completed,
                    icon: "checkmark.circle.fill",
                    color: .secondary,
                    count: aria2.downloads.filter { $0.status == .complete }.count
                )
                SidebarItem(
                    filter: .errors,
                    icon: "exclamationmark.triangle.fill",
                    color: .red,
                    count: aria2.downloads.filter { $0.status == .error }.count
                )
            }

            if rclone.isConnected {
                Section("Cloud") {
                    SidebarItem(
                        filter: .cloud,
                        icon: "cloud.fill",
                        color: .cyan,
                        count: rclone.remotes.count
                    )
                    SidebarItem(
                        filter: .cloudTransfers,
                        icon: "arrow.left.arrow.right.circle.fill",
                        color: .purple,
                        count: rclone.transfers.count
                    )
                }

                if !rclone.remotes.filter({ $0.isMounted }).isEmpty {
                    Section("Mounts") {
                        ForEach(rclone.remotes.filter { $0.isMounted }) { remote in
                            Label {
                                Text(remote.name)
                            } icon: {
                                Image(systemName: "externaldrive.fill.badge.checkmark")
                                    .foregroundStyle(.green)
                            }
                            .tag(SidebarFilter.mount(remote.name))
                        }
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .safeAreaInset(edge: .bottom) {
            statusFooter
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ZStack {
            switch selectedFilter {
            case .cloud, .cloudTransfers:
                CloudView()
            case .mount:
                CloudView()
            default:
                if !aria2.isConnected {
                    connectingView
                } else if filteredDownloads.isEmpty {
                    emptyState
                } else {
                    downloadsList
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    private var connectingView: some View {
        VStack(spacing: 16) {
            Image(systemName: "antenna.radiowaves.left.and.right")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)
                .symbolEffect(.pulse)
            Text("Connecting to aria2c...")
                .font(.title3)
                .foregroundStyle(.secondary)
            if let error = aria2.error {
                VStack(spacing: 6) {
                    Text(error)
                        .font(.callout)
                        .foregroundStyle(.red)
                    Text("Install with:  brew install aria2")
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.and.arrow.down.on.square")
                .font(.system(size: 48, weight: .light))
                .foregroundStyle(.tertiary)
            Text("No Downloads")
                .font(.title2.weight(.medium))
                .foregroundStyle(.secondary)
            Text("Drop a URL or file here, or press \u{2318}N")
                .font(.callout)
                .foregroundStyle(.tertiary)

            Button {
                showAddSheet = true
            } label: {
                Label("Add Download", systemImage: "plus")
                    .padding(.horizontal, 8)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)
            .padding(.top, 4)
        }
    }

    private var downloadsList: some View {
        List(selection: $selection) {
            ForEach(filteredDownloads) { download in
                DownloadRow(download: download)
                    .tag(download.id)
                    .contextMenu { downloadContextMenu(for: download) }
                    .listRowSeparator(.visible)
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
        .searchable(text: $searchText, prompt: "Filter downloads")
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { showAddSheet = true } label: {
                Label("Add", systemImage: "plus")
            }
            .help("Add download (\u{2318}N)")
        }

        ToolbarItemGroup(placement: .primaryAction) {
            Button {
                guard let dl = selectedDownloadObject else { return }
                Task {
                    if dl.status == .paused {
                        try? await aria2.resumeDownload(dl)
                    } else {
                        try? await aria2.pauseDownload(dl)
                    }
                }
            } label: {
                Label(
                    selectedDownloadObject?.status == .paused ? "Resume" : "Pause",
                    systemImage: selectedDownloadObject?.status == .paused ? "play.fill" : "pause.fill"
                )
            }
            .help(selectedDownloadObject?.status == .paused ? "Resume" : "Pause")
            .disabled(selectedDownloadObject == nil || selectedDownloadObject?.status == .complete)

            Button {
                for id in selection {
                    if let dl = aria2.downloads.first(where: { $0.id == id }) {
                        Task { try? await aria2.removeDownload(dl) }
                    }
                }
                selection.removeAll()
            } label: {
                Label("Remove", systemImage: "trash")
            }
            .help("Remove selected")
            .disabled(selection.isEmpty)
        }

        ToolbarItem(placement: .status) {
            speedIndicator
        }
    }

    private var speedIndicator: some View {
        HStack(spacing: 16) {
            if aria2.isConnected {
                HStack(spacing: 5) {
                    Image(systemName: "arrow.down")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(.blue)
                    Text(formatSpeed(aria2.globalDownloadSpeed))
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 5) {
                    Image(systemName: "arrow.up")
                        .font(.callout.weight(.bold))
                        .foregroundStyle(.orange)
                    Text(formatSpeed(aria2.globalUploadSpeed))
                        .font(.system(.callout, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Sidebar Footer (Status)

    private var statusFooter: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(aria2.isConnected ? Color.green : Color.red)
                .frame(width: 9, height: 9)
            Text(aria2.isConnected ? "Connected" : "Offline")
                .font(.callout)
                .foregroundStyle(.secondary)
            if let version = aria2.daemon.version {
                Spacer()
                Text("v\(version)")
                    .font(.callout)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Drop Overlay

    @ViewBuilder
    private var dropOverlay: some View {
        if isDragOver {
            ZStack {
                Color.black.opacity(0.15)
                VStack(spacing: 12) {
                    Image(systemName: "arrow.down.doc.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(.white)
                    Text("Drop to download")
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                }
                .padding(40)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
            }
            .ignoresSafeArea()
        }
    }

    // MARK: - Context Menu

    @ViewBuilder
    private func downloadContextMenu(for download: Download) -> some View {
        if download.status == .paused {
            Button("Resume") {
                Task { try? await aria2.resumeDownload(download) }
            }
        } else if download.isActive {
            Button("Pause") {
                Task { try? await aria2.pauseDownload(download) }
            }
        }

        Button("Copy URL") {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(download.url, forType: .string)
        }
        .disabled(download.url.isEmpty)

        if download.status == .complete, !download.dir.isEmpty {
            Divider()
            Button("Show in Finder") {
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: download.dir)
            }
        }

        Divider()

        Button("Remove", role: .destructive) {
            Task { try? await aria2.removeDownload(download) }
        }
    }

    // MARK: - Filtering

    private var filteredDownloads: [Download] {
        var list: [Download]
        switch selectedFilter {
        case .all: list = aria2.downloads
        case .active: list = aria2.downloads.filter { $0.status == .active }
        case .waiting: list = aria2.downloads.filter { $0.status == .waiting || $0.status == .paused }
        case .completed: list = aria2.downloads.filter { $0.status == .complete }
        case .errors: list = aria2.downloads.filter { $0.status == .error }
        case .cloud, .cloudTransfers, .mount: list = []
        }
        if !searchText.isEmpty {
            list = list.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }
        return list
    }

    private var selectedDownloadObject: Download? {
        guard let first = selection.first else { return nil }
        return aria2.downloads.first { $0.id == first }
    }

    // MARK: - Drop Handling

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.url") {
                provider.loadItem(forTypeIdentifier: "public.url", options: nil) { item, _ in
                    if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                        Task { @MainActor in
                            try? await aria2.addDownload(url: url.absoluteString)
                        }
                    }
                }
                return true
            }
            if provider.hasItemConformingToTypeIdentifier("public.text") {
                provider.loadItem(forTypeIdentifier: "public.text", options: nil) { item, _ in
                    if let text = item as? String,
                       text.hasPrefix("http") || text.hasPrefix("magnet:") || text.hasPrefix("ftp") {
                        Task { @MainActor in
                            try? await aria2.addDownload(url: text)
                        }
                    }
                }
                return true
            }
        }
        return false
    }
}

// MARK: - Sidebar Filter

enum SidebarFilter: Hashable {
    case all, active, waiting, completed, errors
    case cloud, cloudTransfers
    case mount(String)
}

struct SidebarItem: View {
    let filter: SidebarFilter
    let icon: String
    let color: Color
    let count: Int

    var body: some View {
        Label {
            HStack {
                Text(label)
                Spacer()
                if count > 0 {
                    Text("\(count)")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 1)
                        .background(.quaternary, in: Capsule())
                }
            }
        } icon: {
            Image(systemName: icon)
                .foregroundStyle(color)
        }
        .tag(filter)
    }

    private var label: String {
        switch filter {
        case .all: return "All Downloads"
        case .active: return "Active"
        case .waiting: return "Waiting"
        case .completed: return "Completed"
        case .errors: return "Errors"
        case .cloud: return "Cloud Accounts"
        case .cloudTransfers: return "Transfers"
        case .mount(let name): return name
        }
    }
}


#Preview {
    ContentView()
        .environmentObject(Aria2Manager())
        .frame(width: 900, height: 560)
}
