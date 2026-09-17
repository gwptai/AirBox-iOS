import SwiftUI
import AVKit
import AVFoundation

struct VideoPlayerView: UIViewControllerRepresentable {

    let url: URL

    func makeUIViewController(context: Context) -> AVPlayerViewController {
        configureAudioSession()

        let player = AVPlayer(url: url)
        let controller = AVPlayerViewController()
        controller.player = player
        controller.allowsPictureInPicturePlayback = true
        controller.showsPlaybackControls = true
        controller.player?.play()

        return controller
    }

    func updateUIViewController(
        _ uiViewController: AVPlayerViewController,
        context: Context
    ) {}

    private func configureAudioSession() {
        let session = AVAudioSession.sharedInstance()

        do {
            try session.setCategory(.playback, mode: .moviePlayback, options: [.allowAirPlay])
            try session.setActive(true)
        } catch {
            print("AirBox audio session error: \(error.localizedDescription)")
        }
    }
}
