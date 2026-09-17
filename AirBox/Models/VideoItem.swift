import Foundation

struct VideoItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var fileName: String
    var duration: Double?
    var dateAdded: Date
    var fileSize: Int64?

    init(
        id: UUID = UUID(),
        title: String,
        fileName: String,
        duration: Double? = nil,
        dateAdded: Date = Date(),
        fileSize: Int64? = nil
    ) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.duration = duration
        self.dateAdded = dateAdded
        self.fileSize = fileSize
    }

    var localURL: URL? {
        MediaStorage.videosDirectory?.appendingPathComponent(fileName)
    }

    var formattedDuration: String? {
        guard let duration = duration, duration > 0 else { return nil }
        let total = Int(duration)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        } else {
            return String(format: "%d:%02d", m, s)
        }
    }
}