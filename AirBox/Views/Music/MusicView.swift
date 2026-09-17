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

    private let audioTypes: [UTType] = [.audio, UTType(filenameExtension: "mp3") ?? .audio, UTType(filenameExtension: "m4a") ?? .audio, UTType(filenameExtension: "wav") ?? .audio, UTType(filenameExtension: "flac") ?? .audio]
    private var filteredTracks: [AudioItem] { searchText.isEmpty ? tracks : tracks.filter { $0.title.localizedCaseInsensitiveContains(searchText) } }

    var body: some View {
        ZStack {
            AppBackground()
            if tracks.isEmpty { EmptyStateView(icon: "music.note.list", title: "Нет музыки", subtitle: "Импортируй музыку,\nчтобы слушать её здесь", actionTitle: "Импортировать музыку") { showImporter = true } }
            else {
                List {
                    ForEach(filteredTracks) { track in
                        Button { play(track) } label: { musicRow(track) }
                            .listRowBackground(Color.clear).listRowSeparator(.hidden)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                    }
                    .onDelete(perform: delete)
                }.listStyle(.plain).scrollContentBackground(.hidden)
            }
            if let track = currentTrack, let duration = player?.duration, duration > 0 {
                VStack { Spacer(); playerBar(track: track, duration: duration) }.ignoresSafeArea(.keyboard)
            }
        }
        .navigationTitle("Музыка").navigationBarTitleDisplayMode(.large)
        .searchable(text: $searchText, prompt: "Поиск музыки")
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { CircleIconButton(systemImage: "plus") { showImporter = true } } }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: audioTypes, allowsMultipleSelection: true) { importTracks($0) }
        .onDisappear { timer?.invalidate(); timer = nil }
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
            Image(systemName: currentTrack?.id == track.id && isPlaying ? "pause.circle.fill" : "play.circle.fill").font(.title2).foregroundStyle(AppTheme.accentGradient)
        }.cardStyle()
    }

    private func playerBar(track: AudioItem, duration: Double) -> some View {
        VStack(spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 3) { Text(track.title).foregroundColor(.white).font(.system(size: 15, weight: .semibold)).lineLimit(1); Text(isPlaying ? "Воспроизводится" : "Пауза").font(.caption).foregroundColor(AppTheme.textSecondary) }
                Spacer()
                Button { if isPlaying { player?.pause() } else { player?.play() }; isPlaying.toggle() } label: { Image(systemName: isPlaying ? "pause.fill" : "play.fill").foregroundColor(.black).frame(width: 40, height: 40).background(AppTheme.accentGradient).clipShape(Circle()) }
            }
            Slider(value: $progress, in: 0...duration) { editing in if !editing { player?.currentTime = progress } }.tint(AppTheme.accent)
            HStack { Text(formatTime(progress)); Spacer(); Text(formatTime(duration)) }.font(.caption2).foregroundColor(AppTheme.textSecondary)
        }
        .padding(16).background(.ultraThinMaterial).clipShape(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous)).overlay(RoundedRectangle(cornerRadius: AppTheme.radiusL, style: .continuous).stroke(AppTheme.stroke, lineWidth: 1)).padding(.horizontal, 12).padding(.bottom, 8)
    }

    private func play(_ track: AudioItem) {
        guard let url = track.localURL else { return }
        do {
            let session = AVAudioSession.sharedInstance(); try session.setCategory(.playback, mode: .default, options: [.allowAirPlay]); try session.setActive(true)
            player = try AVAudioPlayer(contentsOf: url); player?.prepareToPlay(); player?.play(); currentTrack = track; isPlaying = true; progress = 0
            timer?.invalidate(); timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in progress = player?.currentTime ?? 0; if player?.isPlaying == false && progress >= (player?.duration ?? 0) { isPlaying = false } }
        } catch { currentTrack = nil; isPlaying = false }
    }

    private func importTracks(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        for sourceURL in urls {
            let accessing = sourceURL.startAccessingSecurityScopedResource(); defer { if accessing { sourceURL.stopAccessingSecurityScopedResource() } }
            guard let dir = MediaStorage.audioDirectory, let copied = try? MediaStorage.copyFile(from: sourceURL, to: dir) else { continue }
            let localURL = dir.appendingPathComponent(copied.fileName); let duration = AVURLAsset(url: localURL).duration.seconds
            tracks.insert(AudioItem(title: sourceURL.deletingPathExtension().lastPathComponent, fileName: copied.fileName, duration: duration.isFinite && duration > 0 ? duration : nil, fileSize: copied.fileSize), at: 0)
        }
        MediaStorage.saveAudio(tracks)
    }

    private func delete(at offsets: IndexSet) {
        for item in offsets.map({ filteredTracks[$0] }) { if currentTrack?.id == item.id { player?.stop(); currentTrack = nil; isPlaying = false }; MediaStorage.deleteFile(named: item.fileName, in: MediaStorage.audioDirectory); tracks.removeAll { $0.id == item.id } }
        MediaStorage.saveAudio(tracks)
    }
    private func formatTime(_ value: Double) -> String { let total = max(0, Int(value)); return String(format: "%d:%02d", total / 60, total % 60) }
}
