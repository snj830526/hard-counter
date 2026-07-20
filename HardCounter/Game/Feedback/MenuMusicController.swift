import AVFoundation
import Combine

/// Owns one player for the whole menu flow so navigation never restarts the song.
final class MenuMusicController: ObservableObject {
    private static let musicVolume: Float = 0.32

    private var player: AVAudioPlayer?
    private var pendingPause: DispatchWorkItem?
    private var menuIsVisible = false
    private var appIsActive = true

    func setMenuVisible(_ isVisible: Bool, animated: Bool = true) {
        menuIsVisible = isVisible
        updatePlayback(animated: animated)
    }

    func setAppActive(_ isActive: Bool) {
        appIsActive = isActive
        updatePlayback(animated: isActive)
    }

    private func updatePlayback(animated: Bool) {
        pendingPause?.cancel()
        pendingPause = nil

        guard menuIsVisible && appIsActive else {
            pause(animated: animated)
            return
        }

        let player = makePlayerIfNeeded()
        guard let player else { return }

        if !player.isPlaying {
            player.volume = animated ? 0 : Self.musicVolume
            player.play()
        }
        player.setVolume(Self.musicVolume, fadeDuration: animated ? 0.7 : 0)
    }

    private func makePlayerIfNeeded() -> AVAudioPlayer? {
        if let player { return player }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)

        guard let url = Bundle.main.url(
            forResource: "menu_future_power_loop",
            withExtension: "caf"
        ), let player = try? AVAudioPlayer(contentsOf: url) else { return nil }

        player.numberOfLoops = -1
        player.volume = 0
        player.prepareToPlay()
        self.player = player
        return player
    }

    private func pause(animated: Bool) {
        guard let player, player.isPlaying else { return }

        guard animated else {
            player.pause()
            player.volume = 0
            return
        }

        player.setVolume(0, fadeDuration: 0.35)
        let workItem = DispatchWorkItem { [weak self, weak player] in
            guard let self, !self.menuIsVisible || !self.appIsActive else { return }
            player?.pause()
        }
        pendingPause = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.36, execute: workItem)
    }
}
