import SwiftUI
import UniformTypeIdentifiers

struct VideoListView: View {
    @StateObject private var viewModel = VideoViewModel()
    @State private var showFilePicker = false
    @State private var selectedVideo: VideoItem? = nil
    @State private var searchText = ""

    private let videoTypes: [UTType] = [
        .movie, .video, .mpeg4Movie, .quickTimeMovie,
        UTType(filenameExtension: "mkv") ?? .movie,
        UTType(filenameExtension: "avi") ?? .movie,
        UTType(filenameExtension: "webm") ?? .movie
    ]

    private var filteredVideos: [VideoItem] {
        guard !searchText.isEmpty else { return viewModel.videos }
        return viewModel.videos.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if viewModel.videos.isEmpty { emptyStateView } else { videoListView }
            if viewModel.isImporting { importingOverlayView }
        }
        .navigationTitle("Видео")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Поиск видео")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showFilePicker = true } label: {
                    Image(systemName: "plus").font(.title3).foregroundColor(.white)
                }
            }
        }
        .fileImporter(isPresented: $showFilePicker, allowedContentTypes: videoTypes, allowsMultipleSelection: true) { result in
            handlePickerResult(result)
        }
        .sheet(item: $selectedVideo) { video in
            videoPlayerSheet(for: video)
        }
        .alert("Ошибка", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack").font(.system(size: 64)).foregroundColor(.gray)
            Text("Нет видео").font(.title2.weight(.semibold)).foregroundColor(.white)
            Text("Нажми + чтобы импортировать видео").font(.subheadline).foregroundColor(.gray)
        }
    }

    private var videoListView: some View {
        List {
            ForEach(filteredVideos) { video in
                VideoRowView(video: video)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedVideo = video }
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Color.white.opacity(0.08))
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
            .onDelete { offsets in
                offsets.map { filteredVideos[$0] }.forEach { viewModel.deleteVideo($0) }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func videoPlayerSheet(for video: VideoItem) -> some View {
        if let url = video.localURL {
            VideoPlayerView(url: url).ignoresSafeArea()
        } else {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle").font(.system(size: 40)).foregroundColor(.orange)
                    Text("Файл не найден").foregroundColor(.white)
                }
            }
        }
    }

    private var importingOverlayView: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                ProgressView().tint(.white).scaleEffect(1.3)
                Text("Импорт...").foregroundColor(.white).font(.subheadline)
            }
            .padding(32)
            .background(RoundedRectangle(cornerRadius: 20).fill(Color(.systemGray5).opacity(0.95)))
        }
    }

    private func handlePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                for url in urls { await viewModel.importVideo(from: url) }
            }
        case .failure(let error):
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

struct VideoRowView: View {
    let video: VideoItem

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.07)).frame(width: 56, height: 56)
                Image(systemName: "play.rectangle.fill").font(.system(size: 24)).foregroundColor(.white.opacity(0.5))
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(video.title).font(.body.weight(.medium)).foregroundColor(.white).lineLimit(2)
                HStack(spacing: 10) {
                    if let dur = video.formattedDuration { Label(dur, systemImage: "clock") }
                    if let size = video.fileSize {
                        Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                    }
                }
                .font(.caption).foregroundColor(.gray)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundColor(.gray.opacity(0.6))
        }
        .padding(.vertical, 6)
    }
}
