import Cocoa
import UniformTypeIdentifiers

class ShareViewController: NSViewController {

    override var nibName: NSNib.Name? { nil }

    override func loadView() {
        view = NSView(frame: .zero)
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        handleSharedItems()
    }

    private func handleSharedItems() {
        guard let items = extensionContext?.inputItems as? [NSExtensionItem] else {
            done()
            return
        }

        for item in items {
            guard let attachments = item.attachments else { continue }

            for provider in attachments {
                // Handle URLs
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.url.identifier, options: nil) { [weak self] item, _ in
                        if let url = item as? URL {
                            self?.sendToApp(url: url.absoluteString)
                        } else if let data = item as? Data, let url = URL(dataRepresentation: data, relativeTo: nil) {
                            self?.sendToApp(url: url.absoluteString)
                        }
                    }
                    return
                }

                // Handle plain text (magnet links, pasted URLs)
                if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.plainText.identifier, options: nil) { [weak self] item, _ in
                        if let text = item as? String,
                           text.hasPrefix("http") || text.hasPrefix("magnet:") || text.hasPrefix("ftp") {
                            self?.sendToApp(url: text)
                        } else {
                            self?.done()
                        }
                    }
                    return
                }

                // Handle .torrent / .metalink files
                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
                    provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { [weak self] item, _ in
                        if let url = item as? URL {
                            let ext = url.pathExtension.lowercased()
                            if ext == "torrent" || ext == "metalink" {
                                self?.sendToApp(url: url.absoluteString)
                                return
                            }
                        }
                        self?.done()
                    }
                    return
                }
            }
        }

        done()
    }

    /// Send URL to main app via URL scheme
    private func sendToApp(url: String) {
        guard let encoded = url.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let appURL = URL(string: "aria2mac://add?url=\(encoded)") else {
            done()
            return
        }

        // Open the main app with the URL scheme
        NSWorkspace.shared.open(appURL)

        // Small delay then close extension
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            self?.done()
        }
    }

    private func done() {
        extensionContext?.completeRequest(returningItems: nil)
    }
}
