import Foundation

/// Reads `.ips` crash reports persisted in Application Support/CrashReports by `CrashHandler`.
final class FileCrashRepository: CrashRepository {
    static var directory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CrashReports", isDirectory: true)
    }

    func fetchReports() -> [CrashReport] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: Self.directory, includingPropertiesForKeys: nil)) ?? []
        return files.filter { $0.pathExtension == "ips" }.compactMap(parse)
    }

    func delete(_ report: CrashReport) {
        try? FileManager.default.removeItem(
            at: Self.directory.appendingPathComponent("\(report.id).ips"))
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: Self.directory)
    }

    private func parse(_ url: URL) -> CrashReport? {
        guard let text = try? String(contentsOf: url, encoding: .utf8),
              let newline = text.firstIndex(of: "\n"),
              let header = json(String(text[..<newline])),
              let body = json(String(text[text.index(after: newline)...]))
        else { return nil }

        let exception = body["exception"] as? [String: Any] ?? [:]
        let images = body["usedImages"] as? [[String: Any]] ?? []
        let threads = body["threads"] as? [[String: Any]] ?? []
        let frames = threads.first?["frames"] as? [[String: Any]] ?? []

        let stack = frames.enumerated().map { index, frame -> String in
            let imageIdx = frame["imageIndex"] as? Int ?? 0
            let image = imageIdx < images.count ? images[imageIdx]["name"] as? String ?? "?" : "?"
            let symbol = frame["symbol"] as? String ?? "+0x\(String(frame["imageOffset"] as? Int ?? 0, radix: 16))"
            return "\(index)  \(image)  \(symbol)"
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SS Z"
        let date = formatter.date(from: header["timestamp"] as? String ?? "") ?? Date()

        // Uncaught exceptions carry their message in `asi`; signals in exception/termination.
        let termination = body["termination"] as? [String: Any] ?? [:]
        let asi = (body["asi"] as? [String: Any])?.values.compactMap { ($0 as? [String])?.first }.first
        let reason = asi ?? exception["subtype"] as? String ?? termination["indicator"] as? String ?? "Unknown"

        return CrashReport(
            id: header["incident_id"] as? String ?? url.deletingPathExtension().lastPathComponent,
            date: date,
            type: "\(exception["type"] as? String ?? "Crash") (\(exception["signal"] as? String ?? "?"))",
            reason: reason,
            appVersion: header["app_version"] as? String ?? "?",
            osVersion: header["os_version"] as? String ?? "?",
            stackTrace: stack)
    }

    private func json(_ s: String) -> [String: Any]? {
        guard let data = s.data(using: .utf8) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}
