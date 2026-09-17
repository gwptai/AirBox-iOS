import SwiftUI
import UniformTypeIdentifiers

struct VideoListView: View {
    @StateObject private var viewModel = VideoViewModel()
    @State private var showFilePicker = false
    @State private var selectedVideo: VideoItem? = nil
    @State private var searchText = ""

    private let videoTypes: [UTType] = [.movie, .video, .mpeg4Movie, .quickTimeMovie,
        UTType(filenameExtension: "mkv") ?? .movie, UTType(filenameExtension: "avi") ?? .movie,
        UTType(filenameExtension: "webm") ?? .movie]

    private var filteredVideos: [VideoItem] {
        searchText.isEmpty ? viewModel.videos : viewModel.videos.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            AppBackground()
            if viewModel.videos.isEmpty {
                EmptyStateView(icon: "film.stack", title: "Нет видео", subtitle: "Импортируй видео,\nчтобы посмотреть его здесь", actionTitle: "Импортировать видео") { showFilePicker = true }
            } else { videoListView }
            if viewModel.isImporting { LoadingOverlay(text: "Импортируем видео…") }
        }
        .navigationTitle("Видео")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Поиск видео")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                CircleIconButton(systemImage: "plus") { showFilePicker = true }
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: videoTypes, allowsMultipleSelection: true) { result in handlePickerResult(result) }
        .sheet(item: $selectedVideo) { video in videoPlayerSheet(for: video) }
        .alert("Ошибка", isPresented: Binding(get: { viewModel.errorMessage != nil }, set: { if !$0 { viewModel.errorMessage = nil } })) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
    }

    private var videoListView: some View {
        List {
            ForEach(filteredVideos) { video in
                VideoRowView(video: video).contentShape(Rectangle()).onTapGesture { selectedVideo = video }
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
            }
            .onDelete { offsets in offsets.map { filteredVideos[$0] }.forEach { viewModel.deleteVideo($0) } }
        }
        .listStyle(.plain).scrollContentBackground(.hidden)
    }

    @ViewBuilder private func videoPlayerSheet(for video: VideoItem) -> some View {
        if let url = video.localURL { VideoPlayerContainerView(title: video.title, url: url) { selectedVideo = nil } }
        else { ZStack { AppBackground(); EmptyStateView(icon: "exclamationmark.triangle", title: "Файл не найден", subtitle: "Возможно, видео было удалено") } }
    }

    private func handlePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls): Task { for url in urls { await viewModel.importVideo(from: url) } }
        case .failure(let error): viewModel.errorMessage = error.localizedDescription
        }
    }
}

struct VideoRowView: View {
    let video: VideoItem
    var body: some View {
        HStack(spacing: AppTheme.spacingM) {
            MediaThumbnail(systemImage: "play.rectangle.fill")
            VStack(alignment: .leading, spacing: 6) {
                Text(video.title).font(.system(size: 16, weight: .semibold)).foregroundColor(.white).lineLimit(2)
                HStack(spacing: 8) {
                    if let dur = video.formattedDuration { InfoChip(icon: "clock", text: dur) }
                    if let size = video.fileSize { InfoChip(icon: "internaldrive", text: ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) }
                }
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundColor(AppTheme.textTertiary)
        }
        .cardStyle()
    }
}
