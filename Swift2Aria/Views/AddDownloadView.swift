import SwiftUI
import UniformTypeIdentifiers

struct AddDownloadView: View {
    @EnvironmentObject var aria2: Aria2Manager
    @Environment(\.dismiss) private var dismiss

    @State private var url = ""
    @State private var downloadDir = ""
    @State private var connections = 16.0
    @State private var errorMessage: String?
    @State private var isAdding = false
    @State private var isDragOver = false

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()
            formContent
            Divider()
            footer
        }
        .frame(width: 520, height: 380)
        .onAppear {
            downloadDir = AppSettings.shared.downloadDirectory
            pasteFromClipboardIfURL()
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 1) {
                Text("New Download")
                    .font(.headline)
                Text("Enter a URL, magnet link, or drop a torrent file")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(16)
    }

    // MARK: - Form

    private var formContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // URL input
                VStack(alignment: .leading, spacing: 6) {
                    Text("URL")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(isDragOver ? Color.blue.opacity(0.1) : Color(nsColor: .controlBackgroundColor))
                            .strokeBorder(isDragOver ? Color.blue : Color(nsColor: .separatorColor), lineWidth: 1)
                            .frame(height: 72)

                        if url.isEmpty {
                            VStack(spacing: 4) {
                                Image(systemName: "link")
                                    .foregroundStyle(.tertiary)
                                Text("Paste URL or drop file here")
                                    .font(.callout)
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        TextEditor(text: $url)
                            .font(.system(.body, design: .monospaced))
                            .scrollContentBackground(.hidden)
                            .padding(6)
                    }
                    .frame(height: 72)
                    .onDrop(of: [.url, .fileURL, .text], isTargeted: $isDragOver) { providers in
                        handleDrop(providers)
                    }

                    HStack(spacing: 8) {
                        Button {
                            pasteFromClipboardIfURL()
                        } label: {
                            Label("Paste", systemImage: "doc.on.clipboard")
                        }
                        .controlSize(.small)

                        Button {
                            openTorrentFile()
                        } label: {
                            Label("Open Torrent...", systemImage: "doc.badge.plus")
                        }
                        .controlSize(.small)
                    }
                }

                // Save to
                VStack(alignment: .leading, spacing: 6) {
                    Text("Save to")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Image(systemName: "folder.fill")
                            .foregroundStyle(.secondary)
                        TextField("Directory", text: $downloadDir)
                            .textFieldStyle(.roundedBorder)
                        Button("Choose...") {
                            let panel = NSOpenPanel()
                            panel.canChooseFiles = false
                            panel.canChooseDirectories = true
                            if panel.runModal() == .OK, let path = panel.url?.path {
                                downloadDir = path
                            }
                        }
                        .controlSize(.small)
                    }
                }

                // Connections
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text("Connections")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("\(Int(connections))")
                            .font(.system(.subheadline, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .trailing)
                    }

                    Slider(value: $connections, in: 1...32, step: 1) {
                        Text("Connections")
                    }
                }

                // Error
                if let errorMessage {
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.red)
                        Text(errorMessage)
                            .foregroundStyle(.red)
                    }
                    .font(.callout)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            Spacer()

            Button("Cancel") { dismiss() }
                .keyboardShortcut(.cancelAction)

            Button {
                addDownload()
            } label: {
                if isAdding {
                    ProgressView()
                        .controlSize(.small)
                        .padding(.horizontal, 8)
                } else {
                    Text("Download")
                }
            }
            .keyboardShortcut(.defaultAction)
            .disabled(url.trimmingCharacters(in: .whitespaces).isEmpty || isAdding)
            .buttonStyle(.borderedProminent)
        }
        .padding(16)
    }

    // MARK: - Actions

    private func addDownload() {
        let trimmed = url.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        isAdding = true
        errorMessage = nil

        var options: [String: String] = [:]
        if !downloadDir.isEmpty {
            options["dir"] = downloadDir
        }
        let conn = Int(connections)
        options["max-connection-per-server"] = "\(conn)"
        options["split"] = "\(conn)"

        Task {
            do {
                try await aria2.addDownload(url: trimmed, options: options)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isAdding = false
            }
        }
    }

    private func pasteFromClipboardIfURL() {
        guard url.isEmpty else { return }
        if let clipboard = NSPasteboard.general.string(forType: .string),
           clipboard.hasPrefix("http") || clipboard.hasPrefix("magnet:") || clipboard.hasPrefix("ftp") {
            url = clipboard
        }
    }

    private func openTorrentFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [
            UTType(filenameExtension: "torrent") ?? .data,
            UTType(filenameExtension: "metalink") ?? .data,
        ]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let fileURL = panel.url {
            Task {
                do {
                    try await aria2.addTorrent(fileURL: fileURL)
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                }
            }
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        for provider in providers {
            if provider.hasItemConformingToTypeIdentifier("public.url") {
                provider.loadItem(forTypeIdentifier: "public.url", options: nil) { item, _ in
                    if let data = item as? Data, let droppedURL = URL(dataRepresentation: data, relativeTo: nil) {
                        DispatchQueue.main.async { url = droppedURL.absoluteString }
                    }
                }
                return true
            }
            if provider.hasItemConformingToTypeIdentifier("public.text") {
                provider.loadItem(forTypeIdentifier: "public.text", options: nil) { item, _ in
                    if let text = item as? String {
                        DispatchQueue.main.async { url = text }
                    }
                }
                return true
            }
        }
        return false
    }
}

#Preview {
    AddDownloadView()
        .environmentObject(Aria2Manager())
}
