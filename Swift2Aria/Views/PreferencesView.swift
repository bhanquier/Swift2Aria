import SwiftUI

struct PreferencesView: View {
    var body: some View {
        TabView {
            GeneralTab()
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            DownloadRulesTab()
                .tabItem {
                    Label("Rules", systemImage: "list.bullet.rectangle")
                }

            CloudAccountsTab()
                .tabItem {
                    Label("Cloud", systemImage: "cloud.fill")
                }

            NetworkTab()
                .tabItem {
                    Label("Network", systemImage: "network")
                }

            AdvancedTab()
                .tabItem {
                    Label("Advanced", systemImage: "wrench.and.screwdriver")
                }

            BrowserExtensionTab()
                .tabItem {
                    Label("Extension", systemImage: "puzzlepiece")
                }
        }
        .frame(width: 560, height: 420)
    }
}

// MARK: - General

struct GeneralTab: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Launch at login", isOn: $settings.launchAtLogin)
                Toggle("Show in Dock", isOn: $settings.showInDock)
                Toggle("Notify when download completes", isOn: $settings.notifyOnComplete)
            }

            Section("Default Download Directory") {
                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.blue)
                    TextField("Path", text: $settings.downloadDirectory)
                        .textFieldStyle(.roundedBorder)
                    Button("Choose...") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        if panel.runModal() == .OK, let path = panel.url?.path {
                            settings.downloadDirectory = path
                        }
                    }
                    .controlSize(.small)
                }
            }

            Section("Concurrent Downloads") {
                HStack {
                    Slider(
                        value: Binding(
                            get: { Double(settings.maxConcurrentDownloads) },
                            set: { settings.maxConcurrentDownloads = Int($0) }
                        ),
                        in: 1...20,
                        step: 1
                    )
                    Text("\(settings.maxConcurrentDownloads)")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 28, alignment: .trailing)
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Download Rules

struct DownloadRulesTab: View {
    @EnvironmentObject var settings: AppSettings
    @State private var selectedRule: DownloadRule.Category? = .video

    var body: some View {
        HSplitView {
            // Category list
            List(selection: $selectedRule) {
                ForEach(DownloadRule.Category.allCases) { cat in
                    Label {
                        HStack {
                            Text(cat.label)
                            Spacer()
                            if let rule = settings.downloadRules.first(where: { $0.category == cat }),
                               !rule.directory.isEmpty || rule.speedLimit > 0 || rule.maxConnections != 16 {
                                Image(systemName: "slider.horizontal.3")
                                    .font(.caption2)
                                    .foregroundStyle(.blue)
                            }
                        }
                    } icon: {
                        Image(systemName: cat.icon)
                            .foregroundStyle(.secondary)
                    }
                    .tag(cat)
                }
            }
            .listStyle(.sidebar)
            .frame(minWidth: 160, maxWidth: 180)

            // Rule editor
            if let selected = selectedRule,
               let ruleIndex = settings.downloadRules.firstIndex(where: { $0.category == selected }) {
                RuleEditor(rule: $settings.downloadRules[ruleIndex])
            } else {
                Text("Select a category")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

struct RuleEditor: View {
    @Binding var rule: DownloadRule
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section {
                Toggle("Enabled", isOn: $rule.enabled)
                Toggle("Auto-start downloads", isOn: $rule.autoStart)
            }

            Section("Directory Override") {
                HStack {
                    TextField("Use default (\(settings.downloadDirectory))", text: $rule.directory)
                        .textFieldStyle(.roundedBorder)
                    Button("Choose...") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        if panel.runModal() == .OK, let path = panel.url?.path {
                            rule.directory = path
                        }
                    }
                    .controlSize(.small)

                    if !rule.directory.isEmpty {
                        Button {
                            rule.directory = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            Section("Connections per Server") {
                HStack {
                    Slider(
                        value: Binding(
                            get: { Double(rule.maxConnections) },
                            set: { rule.maxConnections = Int($0) }
                        ),
                        in: 1...32,
                        step: 1
                    )
                    Text("\(rule.maxConnections)")
                        .font(.system(.body, design: .monospaced))
                        .frame(width: 28, alignment: .trailing)
                }
            }

            Section("Speed Limit") {
                HStack {
                    Slider(
                        value: Binding(
                            get: { Double(rule.speedLimit) },
                            set: { rule.speedLimit = Int($0) }
                        ),
                        in: 0...102400,
                        step: 512
                    )
                    if rule.speedLimit == 0 {
                        Text("Unlimited")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                            .frame(width: 80, alignment: .trailing)
                    } else {
                        Text(formatKBSpeed(rule.speedLimit))
                            .font(.system(.callout, design: .monospaced))
                            .frame(width: 80, alignment: .trailing)
                    }
                }
            }

            if rule.category != .other {
                Section("File Extensions") {
                    Text(rule.category.extensions.joined(separator: ", "))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
    }

    private func formatKBSpeed(_ kb: Int) -> String {
        if kb >= 1024 {
            return String(format: "%.1f MB/s", Double(kb) / 1024.0)
        }
        return "\(kb) KB/s"
    }
}

// MARK: - Network

struct NetworkTab: View {
    @EnvironmentObject var settings: AppSettings

    var body: some View {
        Form {
            Section("Speed Limits") {
                HStack {
                    Text("Global download limit")
                    Spacer()
                    TextField("0", value: $settings.globalDownloadLimit, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("KB/s")
                        .foregroundStyle(.secondary)
                }
                Text("0 = unlimited")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                HStack {
                    Text("Global upload limit")
                    Spacer()
                    TextField("0", value: $settings.globalUploadLimit, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                    Text("KB/s")
                        .foregroundStyle(.secondary)
                }
            }

            Section("Connections") {
                HStack {
                    Text("Max connections per server")
                    Spacer()
                    TextField("16", value: $settings.maxConnectionsPerServer, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 60)
                }
            }

            Section("Proxy") {
                TextField("http://proxy:port (leave empty for none)", text: $settings.proxyURL)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Advanced

struct AdvancedTab: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var aria2: Aria2Manager
    @EnvironmentObject var rclone: RcloneManager
    @State private var aria2cResolvedPath: String?
    @State private var rcloneResolvedPath: String?

    var body: some View {
        Form {
            Section("Binaries") {
                binaryRow(
                    name: "aria2c",
                    version: aria2.daemon.version,
                    resolvedPath: aria2cResolvedPath,
                    customPath: $settings.aria2cPath
                )

                binaryRow(
                    name: "rclone",
                    version: rclone.daemon.version,
                    resolvedPath: rcloneResolvedPath,
                    customPath: $settings.rclonePath
                )

                Text("By default, Swift2Aria uses the binaries bundled with the app. Use a custom path to override with your own build.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Section("RPC") {
                HStack {
                    Text("Port")
                    Spacer()
                    TextField("6800", value: $settings.rpcPort, format: .number)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 80)
                }

                HStack {
                    Text("Secret token")
                    Spacer()
                    SecureField("Secret", text: $settings.rpcSecret)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 200)
                }

                Text("This token secures the local communication between Swift2Aria and the aria2c / rclone daemons. It is generated automatically and stored locally in your Application Support folder.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Section("File Allocation") {
                Picker("Method", selection: $settings.fileAllocation) {
                    ForEach(AppSettings.FileAllocation.allCases) { method in
                        Text(method.label).tag(method)
                    }
                }
            }

            Section("Extra Arguments") {
                TextField("e.g. --bt-tracker=udp://...", text: $settings.extraArguments)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.body, design: .monospaced))
                Text("Additional command-line arguments passed to aria2c")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Section {
                HStack {
                    Button("Restart Services") {
                        aria2.stop()
                        rclone.stop()
                        aria2.start()
                        rclone.start()
                    }

                    Button("Reset All Settings", role: .destructive) {
                        settings.downloadRules = DownloadRule.defaults
                        settings.aria2cPath = ""
                        settings.rclonePath = ""
                    }
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            aria2cResolvedPath = aria2.daemon.findAria2cBinary()
            rcloneResolvedPath = rclone.daemon.findRcloneBinary()
        }
    }

    @ViewBuilder
    private func binaryRow(name: String, version: String?, resolvedPath: String?, customPath: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "terminal.fill")
                    .foregroundStyle(.secondary)
                Text(name)
                    .font(.headline)

                Spacer()

                if let version {
                    Text("v\(version)")
                        .font(.system(.caption, design: .monospaced))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.blue.opacity(0.1), in: Capsule())
                        .foregroundStyle(.blue)
                }
            }

            // Source indicator
            if let resolved = resolvedPath {
                let isBundled = resolved.contains(".app/Contents/Resources")
                let isCustom = !customPath.wrappedValue.isEmpty
                HStack(spacing: 4) {
                    Image(systemName: isCustom ? "person.fill" : (isBundled ? "shippingbox.fill" : "arrow.down.circle"))
                        .font(.caption2)
                    Text(isCustom ? "Custom" : (isBundled ? "Bundled" : "System"))
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(isCustom ? .orange : (isBundled ? .green : .secondary))

                Text(resolved)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            } else {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text("Not found")
                        .font(.caption2.weight(.medium))
                }
                .foregroundStyle(.red)
            }

            // Custom path override
            HStack(spacing: 6) {
                TextField("Use bundled (default)", text: customPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(.caption, design: .monospaced))

                Button("Browse...") {
                    let panel = NSOpenPanel()
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    panel.message = "Select \(name) binary"
                    if panel.runModal() == .OK, let path = panel.url?.path {
                        customPath.wrappedValue = path
                    }
                }
                .controlSize(.small)

                if !customPath.wrappedValue.isEmpty {
                    Button {
                        customPath.wrappedValue = ""
                    } label: {
                        Image(systemName: "arrow.uturn.backward")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                    .help("Reset to bundled")
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Browser Extension

struct BrowserExtensionTab: View {
    var body: some View {
        Form {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Chrome Extension", systemImage: "puzzlepiece.fill")
                        .font(.headline)
                    Text("Install the companion extension to send downloads directly from your browser.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Installation") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 8) {
                        Text("1")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(.blue, in: Circle())
                        Text("Open Chrome and go to the Extensions page")
                            .font(.callout)
                    }

                    HStack(spacing: 8) {
                        Text("2")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(.blue, in: Circle())
                        Text("Enable Developer mode (top right)")
                            .font(.callout)
                    }

                    HStack(spacing: 8) {
                        Text("3")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 18, height: 18)
                            .background(.blue, in: Circle())
                        Text("Click Load unpacked and select the ChromeExtension folder")
                            .font(.callout)
                    }
                }
            }

            Section {
                HStack(spacing: 12) {
                    Button("Show in Finder") {
                        if let url = Bundle.main.resourceURL?.appendingPathComponent("ChromeExtension"),
                           FileManager.default.fileExists(atPath: url.path) {
                            NSWorkspace.shared.selectFile(url.path, inFileViewerRootedAtPath: url.deletingLastPathComponent().path)
                        }
                    }

                    Button("Open Chrome Extensions") {
                        if let url = URL(string: "chrome://extensions/") {
                            NSWorkspace.shared.open(url)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

#Preview {
    PreferencesView()
        .environmentObject(Aria2Manager())
        .environmentObject(RcloneManager())
        .environmentObject(AppSettings.shared)
}
