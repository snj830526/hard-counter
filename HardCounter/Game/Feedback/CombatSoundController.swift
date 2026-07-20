import AVFoundation

/// Keeps short mechanical impact sounds decoded and ready so the audio transient lands on
/// the same frame as hit stop instead of paying file-loading cost on contact.
final class CombatSoundController {
    private let mediumNames = [
        "punch_medium_1",
        "punch_medium_2",
        "punch_medium_3"
    ]
    private let heavyNames = [
        "punch_heavy_1",
        "punch_heavy_2",
        "punch_heavy_3"
    ]
    private var players: [String: AVAudioPlayer] = [:]
    private var lastMediumIndex = -1
    private var lastHeavyIndex = -1

    func prepare() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true)

        for name in mediumNames + heavyNames {
            guard let url = Bundle.main.url(
                forResource: name,
                withExtension: "wav"
            ), let player = try? AVAudioPlayer(contentsOf: url) else { continue }
            player.enableRate = true
            player.prepareToPlay()
            players[name] = player
        }
    }

    func playHit(_ kind: HitKind, technique: PunchTechnique) {
        let usesHeavySound = kind == .counter || technique != .straight
        let name = nextName(heavy: usesHeavySound)
        guard let player = players[name] else { return }

        player.currentTime = 0
        switch (kind, technique) {
        case (.counter, _):
            player.volume = 1
            player.rate = 0.88
        case (_, .smash):
            player.volume = 0.94
            player.rate = 0.94
        case (_, .uppercut):
            player.volume = 0.90
            player.rate = 1.02
        case (_, .straight):
            player.volume = 0.82
            player.rate = 1
        }
        player.play()
    }

    private func nextName(heavy: Bool) -> String {
        let names = heavy ? heavyNames : mediumNames
        let previous = heavy ? lastHeavyIndex : lastMediumIndex
        let candidates = names.indices.filter { $0 != previous }
        let index = candidates.randomElement() ?? 0
        if heavy {
            lastHeavyIndex = index
        } else {
            lastMediumIndex = index
        }
        return names[index]
    }
}
