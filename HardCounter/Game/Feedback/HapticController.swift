import UIKit

final class HapticController {
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let counterImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let swayFeedback = UISelectionFeedbackGenerator()

    func prepare() {
        lightImpact.prepare()
        mediumImpact.prepare()
        counterImpact.prepare()
        swayFeedback.prepare()
    }

    func playHit(_ kind: HitKind, technique: PunchTechnique = .straight) {
        switch kind {
        case .normal:
            switch technique {
            case .straight:
                lightImpact.impactOccurred(intensity: 0.90)
            case .smash:
                mediumImpact.impactOccurred(intensity: 1)
            case .uppercut:
                mediumImpact.impactOccurred(intensity: 0.92)
            }
        case .counter:
            counterImpact.impactOccurred(intensity: 1)
        }
    }

    func playSway() {
        swayFeedback.selectionChanged()
    }
}
