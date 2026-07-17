import UIKit

final class HapticController {
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let counterImpact = UIImpactFeedbackGenerator(style: .heavy)
    private let swayFeedback = UISelectionFeedbackGenerator()

    func prepare() {
        lightImpact.prepare()
        counterImpact.prepare()
        swayFeedback.prepare()
    }

    func playHit(_ kind: HitKind) {
        switch kind {
        case .normal:
            lightImpact.impactOccurred(intensity: 0.75)
        case .counter:
            counterImpact.impactOccurred(intensity: 1)
        }
    }

    func playSway() {
        swayFeedback.selectionChanged()
    }
}
