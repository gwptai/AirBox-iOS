import Foundation
import AVFoundation

@MainActor
final class VideoViewModel: ObservableObject {

    @Published var videos: [VideoItem] = []
    @Published var isImporting: Bool = false
    @Published var errorMessage: String? = nil

    init() {
        videos = MediaStorage.loadVideos()
    }

    // MARK: - Import

    func importVideo(from sourceURL: URL) async {
        isImporting = true
        errorMessage = nil

        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing { sourceURL.stopAccessingSecurityScopedResource() }
        }

        do {
            guard let videosDir = MediaStorage.videosDirectory else {
                throw ImportError.directoryUnavailable
            }

            let (fileName, fileSize) = try MediaStorage.copyFile(
                from: sourceURL,
                to: videosDir
            )

            let localURL = videosDir.appendingPathComponent(fileName)
            let duration = await loadDuration(from: localURL)

            let title = sourceURL
                .deletingPathExtension()
                .lastPathComponent

            let item = VideoItem(
                title: title,
                fileName: fileName,
                duration: duration,
                fileSize: fileSize
            )

            videos.insert(item, at: 0)
            MediaStorage.saveVideos(videos)

        } catch {
            errorMessage = error.localizedDescription
        }

        isImporting = false
    }

    // MARK: - Delete

    func deleteVideo(_ item: VideoItem) {
        MediaStorage.deleteFile(
            named: item.fileName,
            in: MediaStorage.videosDirectory
        )
        videos.removeAll { $0.id == item.id }
        MediaStorage.saveVideos(videos)
    }

    // MARK: - Private

    private func loadDuration(from url: URL) async -> Double? {
        let asset = AVURLAsset(url: url)
        do {
            let cmDuration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(cmDuration)
            return (seconds.isFinite && seconds > 0) ? seconds : nil
        } catch {
            return nil
        }
    }

    // MARK: - Errors

    enum ImportError: LocalizedError {
        case directoryUnavailable

        var errorDescription: String? {
            switch self {
            case .directoryUnavailable:
                return "Не удалось получить доступ к папке Videos."
            }
        }
    }
}