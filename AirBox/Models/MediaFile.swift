import Foundation

struct MediaFile: Identifiable, Codable {
    let id: UUID
    var name: String
    var fileName: String
    var fileExtension: String
    var dateAdded: Date
    var fileSize: Int64?

    init(
        id: UUID = UUID(),
        name: String,
        fileName: String,
        fileExtension: String,
        dateAdded: Date = Date(),
        fileSize: Int64? = nil
    ) {
        self.id = id
        self.name = name
        self.fileName = fileName
        self.fileExtension = fileExtension
        self.dateAdded = dateAdded
        self.fileSize = fileSize
    }

    var localURL: URL? {
        MediaStorage.filesDirectory?.appendingPathComponent(fileName)
    }

    var formattedSize: String? {
        guard let size = fileSize else { return nil }
        let f = ByteCountFormatter()
        f.allowedUnits = [.useKB, .useMB, .useGB]
        f.countStyle = .file
        return f.string(fromByteCount: size)
    }

    var sfSymbol: String {
        switch fileExtension.lowercased() {
        case "pdf":                     return "doc.fill"
        case "txt", "md":              return "doc.text.fill"
        case "jpg", "jpeg",
             "png", "heic":            return "photo.fill"
        case "zip", "rar":             return "archivebox.fill"
        default:                       return "doc.fill"
        }
    }
}