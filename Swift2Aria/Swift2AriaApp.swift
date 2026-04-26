import SwiftUI

@main
struct Swift2AriaApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var aria2: Aria2Manager { appDelegate.aria2 }
    var rclone: RcloneManager { appDelegate.rclone }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appDelegate.aria2)
                .environmentObject(appDelegate.rclone)
                .environmentObject(AppSettings.shared)
        } label: {
            menuBarLabel
        }
        .menuBarExtraStyle(.window)

        Window("Swift2Aria", id: "main") {
            ContentView()
                .environmentObject(appDelegate.aria2)
                .environmentObject(appDelegate.rclone)
                .environmentObject(AppSettings.shared)
                .frame(minWidth: 860, minHeight: 520)
                .onOpenURL { url in appDelegate.aria2.handleURL(url) }
        }
        .defaultSize(width: 1000, height: 640)
        .commands {
            CommandGroup(after: .newItem) {
                Button("Add Download...") {
                    NotificationCenter.default.post(name: .showAddDownload, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button("Pause All Downloads") {
                    Task { try? await appDelegate.aria2.rpcClient?.pauseAll() }
                }
                .keyboardShortcut("p", modifiers: [.command, .shift])

                Button("Resume All Downloads") {
                    Task { try? await appDelegate.aria2.rpcClient?.unpauseAll() }
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])
            }
        }

        Settings {
            PreferencesView()
                .environmentObject(appDelegate.aria2)
                .environmentObject(appDelegate.rclone)
                .environmentObject(AppSettings.shared)
        }
    }

    private var menuBarLabel: some View {
        HStack(spacing: 3) {
            Image(systemName: "arrow.down.circle.fill")
            if appDelegate.aria2.globalDownloadSpeed > 0 || appDelegate.rclone.globalSpeed > 0 {
                Text(formatSpeed(appDelegate.aria2.globalDownloadSpeed + appDelegate.rclone.globalSpeed))
                    .font(.caption2.monospacedDigit())
            }
        }
    }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    let aria2 = Aria2Manager()
    let rclone = RcloneManager()

    func applicationDidFinishLaunching(_ notification: Notification) {
        aria2.start()
        rclone.start()
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        aria2.stop()
        rclone.stop()
    }
}

extension Notification.Name {
    static let showAddDownload = Notification.Name("showAddDownload")
}
