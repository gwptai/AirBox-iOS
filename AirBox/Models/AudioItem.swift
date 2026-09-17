import Foundation

struct AudioItem: Identifiable, Codable {
    let id: UUID
    var title: String
    var fileName: String
    var artist: String?
    var duration: Double?
    var dateAdded: Date
    var fileSize: Int64?

    init(
        id: UUID = UUID(),
        title: String,
        fileName: String,
        artist: String? = nil,
        duration: Double? = nil,
        dateAdded: Date = Date(),
        fileSize: Int64? = nil
    ) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.artist = artist
        self.duration = duration
        self.dateAdded = dateAdded
        self.fileSize = fileSize
    }

    var localURL: URL? {
        MediaStorage.audioDirectory?.appendingPathComponent(fileName)
    }

    var formattedDuration: String? {
        guard let duration = duration, duration > 0 else { return nil }
        let total = Int(duration)
        let m = total / 60
        let s = total % 60
        return String(format: "%d:%02d", m, s)
    }
}