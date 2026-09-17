import Foundation

final class MediaStorage {

    // MARK: - Directories

    static var documentsDirectory: URL? {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
    }

    static var videosDirectory: URL? {
        guard let base = documentsDirectory else { return nil }
        let url = base.appendingPathComponent("Videos", isDirectory: true)
        createIfNeeded(url)
        return url
    }

    static var audioDirectory: URL? {
        guard let base = documentsDirectory else { return nil }
        let url = base.appendingPathComponent("Audio", isDirectory: true)
        createIfNeeded(url)
        return url
    }

    static var filesDirectory: URL? {
        guard let base = documentsDirectory else { return nil }
        let url = base.appendingPathComponent("Files", isDirectory: true)
        createIfNeeded(url)
        return url
    }

    private static func createIfNeeded(_ url: URL) {
        guard !FileManager.default.fileExists(atPath: url.path) else { return }
        try? FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
    }

    // MARK: - Keys

    private static let videoKey = "airbox.videos"
    private static let audioKey = "airbox.audio"
    private static let filesKey = "airbox.files"

    // MARK: - Video

    static func saveVideos(_ items: [VideoItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: videoKey)
    }

    static func loadVideos() -> [VideoItem] {
        guard
            let data = UserDefaults.standard.data(forKey: videoKey),
            let items = try? JSONDecoder().decode([VideoItem].self, from: data)
        else { return [] }
        return items
    }

    // MARK: - Audio

    static func saveAudio(_ items: [AudioItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: audioKey)
    }

    static func loadAudio() -> [AudioItem] {
        guard
            let data = UserDefaults.standard.data(forKey: audioKey),
            let items = try? JSONDecoder().decode([AudioItem].self, from: data)
        else { return [] }
        return items
    }

    // MARK: - Files

    static func saveFiles(_ items: [MediaFile]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: filesKey)
    }

    static func loadFiles() -> [MediaFile] {
        guard
            let data = UserDefaults.standard.data(forKey: filesKey),
            let items = try? JSONDecoder().decode([MediaFile].self, from: data)
        else { return [] }
        return items
    }

    // MARK: - File operations

    static func copyFile(
        from sourceURL: URL,
        to targetDirectory: URL
    ) throws -> (fileName: String, fileSize: Int64) {
        let ext = sourceURL.pathExtension
        let uniqueName = UUID().uuidString + (ext.isEmpty ? "" : ".\(ext)")
        let destination = targetDirectory.appendingPathComponent(uniqueName)
        try FileManager.default.copyItem(at: sourceURL, to: destination)
        let attrs = try FileManager.default.attributesOfItem(atPath: destination.path)
        let size = (attrs[.size] as? Int64) ?? 0
        return (fileName: uniqueName, fileSize: size)
    }

    static func deleteFile(named fileName: String, in directory: URL?) {
        guard let dir = directory else { return }
        try? FileManager.default.removeItem(
            at: dir.appendingPathComponent(fileName)
        )
    }
}