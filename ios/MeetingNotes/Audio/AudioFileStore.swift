import Foundation

/// Resolves `Recording.audioFileName` against the app's current container — never store or
/// pass around the absolute URL, since the container path changes between launches and on restore.
enum AudioFileStore {
    static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("Recordings", isDirectory: true)
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    static func url(for fileName: String) -> URL {
        directory.appendingPathComponent(fileName)
    }

    static func newRecordingURL() -> (fileName: String, url: URL) {
        let fileName = "\(UUID().uuidString).m4a"
        return (fileName, url(for: fileName))
    }

    static func delete(fileName: String) {
        try? FileManager.default.removeItem(at: url(for: fileName))
    }
}
