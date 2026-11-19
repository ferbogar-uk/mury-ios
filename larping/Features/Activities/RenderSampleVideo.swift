import AVFoundation
import SwiftUI

/// A muted, looping sample video shown full-screen while a flyover is rendered, instead of a black screen.
/// The file is `RenderSample.mp4` in the app bundle; without it `isAvailable` is false and the plain waiting
/// screen stays. It is a made-up sample (not a real run) and is labelled as such on screen.
struct RenderSampleVideo: UIViewRepresentable {
    static var url: URL? { Bundle.main.url(forResource: "RenderSample", withExtension: "mp4") }
    static var isAvailable: Bool { url != nil }

    func makeUIView(context: Context) -> LoopingPlayerView {
        let view = LoopingPlayerView()
        if let url = Self.url { view.play(url) }
        return view
    }

    func updateUIView(_ uiView: LoopingPlayerView, context: Context) {}

    static func dismantleUIView(_ uiView: LoopingPlayerView, coordinator: ()) { uiView.stop() }

    final class LoopingPlayerView: UIView {
        override class var layerClass: AnyClass { AVPlayerLayer.self }
        private var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
        private var player: AVQueuePlayer?
        private var looper: AVPlayerLooper?

        func play(_ url: URL) {
            let item = AVPlayerItem(url: url)
            let queue = AVQueuePlayer()
            queue.isMuted = true
            looper = AVPlayerLooper(player: queue, templateItem: item)
            playerLayer.player = queue
            playerLayer.videoGravity = .resizeAspectFill
            player = queue
            queue.play()
        }

        func stop() {
            player?.pause()
            looper?.disableLooping()
            playerLayer.player = nil
            player = nil
            looper = nil
        }
    }
}
