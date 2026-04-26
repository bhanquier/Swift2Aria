import Foundation

enum SecretsStore {
    private static let directory = FileManager.default
        .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        .appendingPathComponent("Swift2Aria")
    private static let file = directory.appendingPathComponent("rpc-secret")

    static func saveSecret(_ value: String) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? value.write(to: file, atomically: true, encoding: .utf8)
    }

    static func loadSecret() -> String? {
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        return try? String(contentsOf: file, encoding: .utf8)
    }
}
