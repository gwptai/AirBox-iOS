import SwiftUI
import UniformTypeIdentifiers

struct VideoListView: View {

    @StateObject private var viewModel = VideoViewModel()
    @State private var showFilePicker = false
    @State private var selectedVideo: VideoItem? = nil

    // Типы файлов, которые разрешено выбирать
    private let videoTypes: [UTType] = [
        .movie,
        .video,
        .mpeg4Movie,
        .quickTimeMovie,
        UTType(filenameExtension: "mkv") ?? .movie,
        UTType(filenameExtension: "avi") ?? .movie,
        UTType(filenameExtension: "webm") ?? .movie
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if viewModel.videos.isEmpty {
                emptyStateView
            } else {
                videoListView
            }

            if viewModel.isImporting {
                importingOverlayView
            }
        }
        .navigationTitle("Видео")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showFilePicker = true
                } label: {
                    Image(systemName: "plus")
                        .font(.title3)
                        .foregroundColor(.white)
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: videoTypes,
            allowsMultipleSelection: false
        ) { result in
            handlePickerResult(result)
        }
        .sheet(item: $selectedVideo) { video in
            videoPlayerSheet(for: video)
        }
        .alert(
            "Ошибка",
            isPresented: .constant(viewModel.errorMessage != nil)
        ) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Subviews

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .foregroundColor(.gray)

            Text("Нет видео")
                .font(.title2)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Text("Нажми + чтобы импортировать видео")
                .font(.subheadline)
                .foregroundColor(.gray)
        }
    }

    private var videoListView: some View {
        List {
            ForEach(viewModel.videos) { video in
                VideoRowView(video: video)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        selectedVideo = video
                    }
                    .listRowBackground(Color.clear)
                    .listRowSeparatorTint(Color.white.opacity(0.08))
                    .listRowInsets(
                        EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16)
                    )
            }
            .onDelete { indexSet in
                indexSet.forEach { i in
                    viewModel.deleteVideo(viewModel.videos[i])
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    @ViewBuilder
    private func videoPlayerSheet(for video: VideoItem) -> some View {
        if let url = video.localURL {
            VideoPlayerView(url: url)
                .ignoresSafeArea()
        } else {
            ZStack {
                Color.black.ignoresSafeArea()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text("Файл не найден")
                        .foregroundColor(.white)
                }
            }
        }
    }

    private var importingOverlayView: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 14) {
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.3)
                Text("Импорт...")
                    .foregroundColor(.white)
                    .font(.subheadline)
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(.systemGray5).opacity(0.95))
            )
        }
    }

    // MARK: - Actions

    private func handlePickerResult(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                await viewModel.importVideo(from: url)
            }
        case .failure(let error):
            viewModel.errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Row view

struct VideoRowView: View {

    let video: VideoItem

    var body: some View {
        HStack(spacing: 14) {
            // Превью-иконка
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 56, height: 56)

                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.white.opacity(0.5))
            }

            // Информация
            VStack(alignment: .leading, spacing: 5) {
                Text(video.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .lineLimit(2)

                HStack(spacing: 10) {
                    if let dur = video.formattedDuration {
                        Label(dur, systemImage: "clock")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }

                    if let size = video.fileSize {
                        Text(
                            ByteCountFormatter.string(
                                fromByteCount: size,
                                countStyle: .file
                            )
                        )
                        .font(.caption)
                        .foregroundColor(.gray)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.6))
        }
        .padding(.vertical, 6)
    }
}