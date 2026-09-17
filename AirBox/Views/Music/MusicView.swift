import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct MusicView: View {
    @State private var tracks: [AudioItem] = MediaStorage.loadAudio()
    @State private var showImporter = false
    @State private var searchText = ""
    @State private var player: AVAudioPlayer?
    @State private var currentTrack: AudioItem?
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var timer: Timer?

    private let audioTypes: [UTType] = [
        .audio,
        UTType(filenameExtension: "mp3") ?? .audio,
        UTType(filenameExtension: "m4a") ?? .audio,
        UTType(filenameExtension: "wav") ?? .audio,
        UTType(filenameExtension: "flac") ?? .audio
    ]

    private var filteredTracks: [AudioItem] {
        guard !searchText.isEmpty else { return tracks }
        return tracks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if tracks.isEmpty {
                emptyView
            } else {
                List {
                    ForEach(filteredTracks) { track in
                        Button { play(track) } label: {
                            HStack(spacing: 14) {
                                Image(systemName: currentTrack?.id == track.id && isPlaying ? "waveform" : "music.note")
                                    .font(.title3)
                                    .frame(width: 42, height: 42)
                                    .background(Color.white.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .foregroundColor(.white)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(track.title)
                                        .foregroundColor(.white)
                                        .fontWeight(.medium)
                                        .lineLimit(1)
                                    HStack(spacing: 8) {
                                        if let duration = track.formattedDuration { Text(duration) }
                                        if let size = track.fileSize {
                                            Text(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))
                                        }
                                    }
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                }
                                Spacer()
                                Image(systemName: currentTrack?.id == track.id && isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.white)
                            }
                        }
                        .listRowBackground(Color.clear)
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }

            if let track = currentTrack, let duration = player?.duration, duration > 0 {
                VStack {
                    Spacer()
                    playerBar(track: track, duration: duration)
                }
                .ignoresSafeArea(.keyboard)
            }
        }
        .navigationTitle("Музыка")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Поиск музыки")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showImporter = true } label: {
                    Image(systemName: "plus")
                        .foregroundColor(.white)
                }
            }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: audioTypes, allowsMultipleSelection: true) { result in
            importTracks(result)
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.list")
                .font(.system(size: 64))
                .foregroundColor(.gray)
            Text("Нет музыки")
                .font(.title2.weight(.semibold))
                .foregroundColor(.white)
            Text("Нажми + чтобы импортировать треки")
                .foregroundColor(.gray)
        }
    }

    private func playerBar(track: AudioItem, duration: Double) -> some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading) {
                    Text(track.title).foregroundColor(.white).fontWeight(.semibold).lineLimit(1)
                    Text(isPlaying ? "Воспроизводится" : "Пауза").font(.caption).foregroundColor(.gray)
                }
                Spacer()
                Button {
                    if isPlaying { player?.pause() } else { player?.play() }
                    isPlaying.toggle()
                } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(.white)
                        .frame(width: 40, height: 40)
                        .background(Color.white.opacity(0.12))
                        .clipShape(Circle())
                }
            }

            Slider(value: $progress, in: 0...duration) { editing in
                if !editing { player?.currentTime = progress }
            }
            .tint(.white)

            HStack {
                Text(formatTime(progress))
                Spacer()
                Text(formatTime(duration))
            }
            .font(.caption2)
            .foregroundColor(.gray)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func play(_ track: AudioItem) {
        guard let url = track.localURL else { return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.allowAirPlay])
            try AVAudioSession.sharedInstance().setActive(true)
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.play()
            currentTrack = track
            isPlaying = true
            progress = 0
            timer?.invalidate()
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
                progress = player?.currentTime ?? 0
                if player?.isPlaying == false && progress >= (player?.duration ?? 0) {
                    isPlaying = false
                }
            }
        } catch {
            currentTrack = nil
            isPlaying = false
        }
    }

    private func importTracks(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        for sourceURL in urls {
            let accessing = sourceURL.startAccessingSecurityScopedResource()
            defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }
            guard let dir = MediaStorage.audioDirectory,
                  let copied = try? MediaStorage.copyFile(from: sourceURL, to: dir) else { continue }
            let localURL = dir.appendingPathComponent(copied.fileName)
            let duration = AVURLAsset(url: localURL).duration.seconds
            let item = AudioItem(
                title: sourceURL.deletingPathExtension().lastPathComponent,
                fileName: copied.fileName,
                duration: duration.isFinite && duration > 0 ? duration : nil,
                fileSize: copied.fileSize
            )
            tracks.insert(item, at: 0)
        }
        MediaStorage.saveAudio(tracks)
    }

    private func delete(at offsets: IndexSet) {
        let items = offsets.map { filteredTracks[$0] }
        for item in items {
            if currentTrack?.id == item.id {
                player?.stop()
                currentTrack = nil
                isPlaying = false
            }
            MediaStorage.deleteFile(named: item.fileName, in: MediaStorage.audioDirectory)
            tracks.removeAll { $0.id == item.id }
        }
        MediaStorage.saveAudio(tracks)
    }

    private func formatTime(_ value: Double) -> String {
        let total = max(0, Int(value))
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
