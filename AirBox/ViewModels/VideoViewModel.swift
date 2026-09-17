import Foundation
import AVFoundation

@MainActor
final class VideoViewModel: ObservableObject {
    @Published var videos: [VideoItem] = []
    @Published var isImporting = false
    @Published var errorMessage: String?

    init() {
        videos = MediaStorage.loadVideos()
    }

    func importVideo(from sourceURL: URL) async {
        isImporting = true
        errorMessage = nil

        let accessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if accessing { sourceURL.stopAccessingSecurityScopedResource() }
        }

        do {
            let result = try await Task.detached(priority: .userInitiated) {
                guard let videosDir = MediaStorage.videosDirectory else {
                    throw ImportError.directoryUnavailable
                }

                let copied = try MediaStorage.copyFile(from: sourceURL, to: videosDir)
                let localURL = videosDir.appendingPathComponent(copied.fileName)
                let duration = await Self.loadDuration(from: localURL)
                let title = sourceURL.deletingPathExtension().lastPathComponent

                return VideoItem(
                    title: title,
                    fileName: copied.fileName,
                    duration: duration,
                    fileSize: copied.fileSize
                )
            }.value

            videos.insert(result, at: 0)
            MediaStorage.saveVideos(videos)
        } catch {
            errorMessage = error.localizedDescription
        }

        isImporting = false
    }

    func deleteVideo(_ item: VideoItem) {
        MediaStorage.deleteFile(named: item.fileName, in: MediaStorage.videosDirectory)
        videos.removeAll { $0.id == item.id }
        MediaStorage.saveVideos(videos)
    }

    private static func loadDuration(from url: URL) async -> Double? {
        let asset = AVURLAsset(url: url)
        do {
            let cmDuration = try await asset.load(.duration)
            let seconds = CMTimeGetSeconds(cmDuration)
            return seconds.isFinite && seconds > 0 ? seconds : nil
        } catch {
            return nil
        }
    }

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
