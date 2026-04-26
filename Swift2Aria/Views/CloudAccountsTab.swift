import SwiftUI

/// Preferences tab: manage rclone remotes
struct CloudAccountsTab: View {
    @EnvironmentObject var rclone: RcloneManager
    @EnvironmentObject var settings: AppSettings
    @State private var showAddRemote = false
    @State private var selectedRemote: CloudRemote?

    var body: some View {
        VStack(spacing: 0) {
            if !rclone.isConnected {
                notConnected
            } else {
                HSplitView {
                    remoteList
                        .frame(minWidth: 180, maxWidth: 200)
                    remoteDetail
                }
            }

            Divider()
            rcloneSettings
        }
        .sheet(isPresented: $showAddRemote) {
            AddRemoteSheet(rclone: rclone)
        }
    }

    // MARK: - Not Connected

    private var notConnected: some View {
        VStack(spacing: 12) {
            Image(systemName: "icloud.slash")
                .font(.system(size: 32, weight: .light))
                .foregroundStyle(.tertiary)
            Text("rclone not running")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Install with: brew install rclone")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Button("Retry") {
                rclone.start()
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Remote List

    private var remoteList: some View {
        VStack(spacing: 0) {
            List(selection: $selectedRemote) {
                ForEach(rclone.remotes) { remote in
                    Label {
                        VStack(alignment: .leading) {
                            Text(remote.name)
                            Text(remote.typeLabel)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: remote.icon)
                            .foregroundStyle(.blue)
                    }
                    .tag(remote)
                }
            }
            .listStyle(.sidebar)

            Divider()

            HStack {
                Button { showAddRemote = true } label: {
                    Image(systemName: "plus")
                }
                .buttonStyle(.borderless)

                Button {
                    guard let remote = selectedRemote else { return }
                    Task { try? await rclone.removeRemote(remote) }
                    selectedRemote = nil
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.borderless)
                .disabled(selectedRemote == nil)

                Spacer()
            }
            .padding(6)
        }
    }

    // MARK: - Remote Detail

    private var remoteDetail: some View {
        Group {
            if let remote = selectedRemote {
                Form {
                    Section {
                        LabeledContent("Name", value: remote.name)
                        LabeledContent("Type", value: remote.typeLabel)
                        if remote.isMounted {
                            LabeledContent("Mount Point", value: remote.mountPoint)
                        }
                    }

                    if remote.spaceTotal > 0 {
                        Section("Storage") {
                            LabeledContent("Total", value: formatBytes(remote.spaceTotal))
                            LabeledContent("Used", value: formatBytes(remote.spaceUsed))
                            LabeledContent("Free", value: formatBytes(remote.spaceFree))
                        }
                    }

                    Section {
                        HStack {
                            if remote.isMounted {
                                Button("Unmount") {
                                    Task { try? await rclone.unmountRemote(remote) }
                                }
                            } else {
                                Button("Mount in Finder") {
                                    Task { try? await rclone.mountRemote(remote) }
                                }
                            }

                            Button("Remove", role: .destructive) {
                                Task { try? await rclone.removeRemote(remote) }
                                selectedRemote = nil
                            }
                        }
                    }
                }
                .formStyle(.grouped)
            } else {
                Text("Select a remote")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }

    // MARK: - rclone Settings

    private var rcloneSettings: some View {
        HStack {
            HStack(spacing: 4) {
                Circle()
                    .fill(rclone.isConnected ? Color.green : Color.red)
                    .frame(width: 7, height: 7)
                Text(rclone.isConnected ? "rclone running" : "rclone stopped")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if let v = rclone.daemon.version {
                    Text("v\(v)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            HStack(spacing: 4) {
                Text("Binary:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Auto-detect", text: $settings.rclonePath)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
                    .frame(width: 200)
            }
        }
        .padding(10)
    }
}

// MARK: - Add Remote Sheet

struct AddRemoteSheet: View {
    let rclone: RcloneManager
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedType = "drive"
    @State private var params: [String: String] = [:]
    @State private var errorMessage: String?
    @State private var isAdding = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Cloud Account")
                    .font(.headline)
                Spacer()
            }
            .padding()

            Divider()

            Form {
                Section {
                    TextField("Remote name", text: $name)
                        .textFieldStyle(.roundedBorder)

                    Picker("Type", selection: $selectedType) {
                        ForEach(CloudRemote.supportedTypes, id: \.type) { item in
                            Text(item.label).tag(item.type)
                        }
                    }
                }

                Section("Configuration") {
                    Text("After adding, rclone will open a browser window for OAuth authentication (for cloud services like Google Drive, Dropbox, etc.).")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    switch selectedType {
                    case "s3":
                        TextField("Access Key ID", text: binding(for: "access_key_id"))
                            .textFieldStyle(.roundedBorder)
                        SecureField("Secret Access Key", text: binding(for: "secret_access_key"))
                            .textFieldStyle(.roundedBorder)
                        TextField("Region (e.g. us-east-1)", text: binding(for: "region"))
                            .textFieldStyle(.roundedBorder)
                    case "sftp":
                        TextField("Host", text: binding(for: "host"))
                            .textFieldStyle(.roundedBorder)
                        TextField("User", text: binding(for: "user"))
                            .textFieldStyle(.roundedBorder)
                        TextField("Port (22)", text: binding(for: "port"))
                            .textFieldStyle(.roundedBorder)
                    case "ftp":
                        TextField("Host", text: binding(for: "host"))
                            .textFieldStyle(.roundedBorder)
                        TextField("User", text: binding(for: "user"))
                            .textFieldStyle(.roundedBorder)
                        SecureField("Password", text: binding(for: "pass"))
                            .textFieldStyle(.roundedBorder)
                    case "webdav":
                        TextField("URL", text: binding(for: "url"))
                            .textFieldStyle(.roundedBorder)
                        TextField("User", text: binding(for: "user"))
                            .textFieldStyle(.roundedBorder)
                        SecureField("Password", text: binding(for: "pass"))
                            .textFieldStyle(.roundedBorder)
                    default:
                        Text("OAuth — will authenticate in browser")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }

                if let errorMessage {
                    Text(errorMessage)
                        .foregroundStyle(.red)
                        .font(.caption)
                }
            }
            .formStyle(.grouped)

            Divider()

            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Button("Add") { addRemote() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(name.isEmpty || isAdding)
                    .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 460, height: 420)
    }

    private func binding(for key: String) -> Binding<String> {
        Binding(
            get: { params[key] ?? "" },
            set: { params[key] = $0 }
        )
    }

    private func addRemote() {
        isAdding = true
        errorMessage = nil
        let cleanParams = params.filter { !$0.value.isEmpty }
        Task {
            do {
                try await rclone.addRemote(name: name, type: selectedType, parameters: cleanParams)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
                isAdding = false
            }
        }
    }
}

#Preview {
    CloudAccountsTab()
        .environmentObject(RcloneManager())
        .environmentObject(AppSettings.shared)
        .frame(width: 560, height: 400)
}
