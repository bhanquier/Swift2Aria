import Foundation

func formatBytes(_ bytes: Int64) -> String {
    let units = ["B", "KB", "MB", "GB", "TB"]
    var value = Double(bytes)
    var unitIndex = 0
    while value >= 1024 && unitIndex < units.count - 1 {
        value /= 1024
        unitIndex += 1
    }
    return unitIndex == 0
        ? "\(Int(value)) \(units[unitIndex])"
        : String(format: "%.1f %@", value, units[unitIndex])
}

func formatSpeed(_ bytesPerSecond: Int64) -> String {
    formatBytes(bytesPerSecond) + "/s"
}

func formatDuration(_ seconds: Double) -> String {
    let s = Int(seconds)
    if s < 60 { return "\(s)s" }
    if s < 3600 { return "\(s / 60)m \(s % 60)s" }
    let h = s / 3600
    let m = (s % 3600) / 60
    return "\(h)h \(m)m"
}
