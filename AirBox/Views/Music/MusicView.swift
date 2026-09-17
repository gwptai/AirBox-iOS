import SwiftUI
import UniformTypeIdentifiers
import AVFoundation

struct MusicView: View {
    @State private var tracks: [AudioItem] = MediaStorage.loadAudio()
    @State private var showImporter = false
    @State private var searchText = ""
    @State private var player: AVPlayer?
    @State private var currentTrack: AudioItem?
    @State private var isPlaying = false
    @State private var progress: Double = 0
    @State private var errorMessage: String?

    private let audioTypes: [UTType] = [.audio, .mp3, .mpeg4Audio, .wav, .aiff]
    private var filteredTracks: [AudioItem] {
        searchText.isEmpty ? tracks : tracks.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            AppBackground()
            if tracks.isEmpty {
                EmptyStateView(icon: "music.note.list", title: "Нет музыки", subtitle: "Импортируй музыку,\nчтобы слушать её здесь", actionTitle: "Импортировать музыку") { showImporter = true }
            } else {
                List {
                    ForEach(filteredTracks) { track in
                        Button { play(track) } label: { musicRow(track) }
                            .buttonStyle(.plain)
                            .listRowBackground(Color.clear)
                            .listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .onDelete(perform: delete)
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            if let track = currentTrack {
                VStack { Spacer(); playerBar(track: track) }
                    .ignoresSafeArea(.keyboard)
            }
        }
        .navigationTitle("Музыка")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Поиск музыки")
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { CircleIconButton(systemImage: "plus") { showImporter = true } } }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: audioTypes, allowsMultipleSelection: true) { importTracks($0) }
        .alert("Не удалось воспроизвести", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK") { errorMessage = nil }
        } message: { Text(errorMessage ?? "Неизвестная ошибка") }
        .onReceive(Timer.publish(every: 0.2, on: .main, in: .common).autoconnect()) { _ in
            updatePlaybackState()
        }
        .onDisappear { stopPlayback() }
    }

    private func musicRow(_ track: AudioItem) -> some View {
        HStack(spacing: AppTheme.spacingM) {
            MediaThumbnail(systemImage: currentTrack?.id == track.id && isPlaying ? "waveform" : "music.note")
            VStack(alignment: .leading, spacing: 6) {
                Text(track.title).font(.system(size: 16, weight: .semibold)).foregroundColor(.white).lineLimit(1)
                HStack(spacing: 8) {
                    if let duration = track.formattedDuration { InfoChip(icon: "clock", text: duration) }
                    if let size = track.fileSize { InfoChip(icon: "internaldrive", text: ByteCountFormatter.string(fromByteCount: size, countStyle: .file)) }
                }
            }
            Spacer()
            Image(systemName: currentTrack?.id == track.id && isPlaying ? "pause.circle.fill" : "play.circle.fill")
                .font(.title2)
                .foregroundStyle(AppTheme.accentGradient)
        }
        .cardStyle()
    }

    private func playerBar(track: AudioItem) -> some View {
        let duration = max(track.duration ?? 0, 0.01)
        return VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title).foregroundColor(.white).font(.system(size: 15, weight: .semibold)).lineLimit(1)
                    Text(isPlaying ? "Воспроизводится" : "Пауза").font(.caption).foregroundColor(AppTheme.textSecondary)
                }
                Spacer()
                Button { togglePlayback() } label: {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(.black)
                        .frame(width: 40, height: 40)
                        .background(AppTheme.accentGradient)
                        .clipShape(Circle())
                }
            }
            Slider(value: $progress, in: 0...duration) { editing in
                if !editing { seek(to: progress) }
            }
            .tint(AppTheme.accent)
            HStack { Text(formatTime(progress)); Spacer(); Text(formatTime(duration)) }
                .font(.caption2).foregroundColor(AppTheme.textSecondary)
        }
        .padding(16)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous).stroke(AppTheme.stroke, lineWidth: 1))
        .padding(.horizontal, 12)
        .padding(.bottom, 8)
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .default, options: [.allowAirPlay])
        try session.setActive(true)
    }

    private func play(_ track: AudioItem) {
        guard let url = track.localURL, FileManager.default.fileExists(atPath: url.path) else {
            errorMessage = "Файл музыки не найден. Импортируй его заново."
            return
        }

        if currentTrack?.id == track.id, let player {
            if player.timeControlStatus == .playing {
                player.pause()
                isPlaying = false
            } else {
                player.play()
                isPlaying = true
            }
            return
        }

        do {
            try configureAudioSession()
            player?.pause()
            let newPlayer = AVPlayer(url: url)
            newPlayer.volume = 1.0
            player = newPlayer
            currentTrack = track
            progress = 0
            newPlayer.play()
            isPlaying = true
        } catch {
            player = nil
            currentTrack = nil
            isPlaying = false
            errorMessage = error.localizedDescription
        }
    }

    private func togglePlayback() {
        guard let player else { return }
        if player.timeControlStatus == .playing {
            player.pause()
            isPlaying = false
        } else {
            player.play()
            isPlaying = true
        }
    }

    private func seek(to value: Double) {
        guard let player else { return }
        player.seek(to: CMTime(seconds: max(0, value), preferredTimescale: 600))
    }

    private func updatePlaybackState() {
        guard let player, let item = player.currentItem else { return }
        let current = item.currentTime().seconds
        if current.isFinite {
            progress = max(0, current)
        }

        if item.status == .failed {
            isPlaying = false
            errorMessage = item.error?.localizedDescription ?? "Не удалось воспроизвести аудиофайл."
            return
        }

        if item.status == .readyToPlay, player.timeControlStatus == .playing {
            isPlaying = true
        }

        if item.duration.isNumeric && current >= max(item.duration.seconds - 0.15, 0) {
            isPlaying = false
        }
    }

    private func stopPlayback() {
        player?.pause()
        player = nil
        isPlaying = false
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func importTracks(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let dir = MediaStorage.audioDirectory else { return }
            var imported = false
            for sourceURL in urls {
                let accessing = sourceURL.startAccessingSecurityScopedResource()
                defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }
                do {
                    let copied = try MediaStorage.copyFile(from: sourceURL, to: dir)
                    let localURL = dir.appendingPathComponent(copied.fileName)
                    tracks.insert(AudioItem(title: sourceURL.deletingPathExtension().lastPathComponent, fileName: copied.fileName, duration: nil, fileSize: copied.fileSize), at: 0)
                    imported = true

                    // Read duration asynchronously with the modern AVAsset API.
                    let asset = AVURLAsset(url: localURL)
                    let insertedID = tracks[0].id
                    Task { @MainActor in
                        do {
                            let duration = try await asset.load(.duration)
                            guard duration.isNumeric else { return }
                            let seconds = duration.seconds
                            guard seconds.isFinite, seconds > 0,
                                  let index = tracks.firstIndex(where: { $0.id == insertedID }) else { return }
                            tracks[index].duration = seconds
                            MediaStorage.saveAudio(tracks)
                        } catch {
                            // Duration is optional metadata; playback itself still works.
                        }
                    }
                } catch {
                    errorMessage = "Не удалось импортировать \(sourceURL.lastPathComponent): \(error.localizedDescription)"
                }
            }
            if imported { MediaStorage.saveAudio(tracks) }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    private func delete(at offsets: IndexSet) {
        for item in offsets.map({ filteredTracks[$0] }) {
            if currentTrack?.id == item.id {
                stopPlayback()
                currentTrack = nil
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
