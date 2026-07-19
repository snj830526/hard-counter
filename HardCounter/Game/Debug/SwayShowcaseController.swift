#if DEBUG
import CoreGraphics
import Foundation

struct SwayShowcaseController {
    enum Command {
        case sway(Demo, SwayIntent)
        case punch(PunchTechnique)
    }

    struct Demo {
        let label: String
        let screenDirection: CGVector
    }

    private let demos = [
        Demo(label: "SWAY 0°", screenDirection: CGVector(dx: 1, dy: 0)),
        Demo(label: "SWAY 45°", screenDirection: CGVector(dx: 0.707, dy: 0.707)),
        Demo(label: "SWAY 90°", screenDirection: CGVector(dx: 0, dy: 1)),
        Demo(label: "SWAY 135°", screenDirection: CGVector(dx: -0.707, dy: 0.707)),
        Demo(label: "SWAY 180°", screenDirection: CGVector(dx: -1, dy: 0)),
        Demo(label: "SWAY 225°", screenDirection: CGVector(dx: -0.707, dy: -0.707)),
        Demo(label: "SWAY 270°", screenDirection: CGVector(dx: 0, dy: -1)),
        Demo(label: "SWAY 315°", screenDirection: CGVector(dx: 0.707, dy: -0.707))
    ]
    private var index = 0
    private var nextDemoAt: TimeInterval?
    private var followUpAt: TimeInterval?
    private var pendingTechnique: PunchTechnique?

    mutating func reset(at time: TimeInterval) {
        index = 0
        nextDemoAt = time + 0.8
        followUpAt = nil
        pendingTechnique = nil
    }

    mutating func command(
        at time: TimeInterval,
        state: FighterCombatState,
        towardOpponent: CGVector
    ) -> Command? {
        if let followUpAt, time >= followUpAt,
           let pendingTechnique, state.phase == .swaying {
            self.followUpAt = nil
            self.pendingTechnique = nil
            nextDemoAt = time + 2.0
            return .punch(pendingTechnique)
        }
        if nextDemoAt == nil, followUpAt == nil { reset(at: time) }
        guard let nextDemoAt, time >= nextDemoAt, state.phase == .idle else { return nil }

        let demo = demos[index % demos.count]
        index += 1
        self.nextDemoAt = nil
        let intent = SwayInputResolver.resolve(
            movement: demo.screenDirection,
            towardOpponent: towardOpponent
        )
        pendingTechnique = intent.direction.followUpTechnique
        followUpAt = time + CombatTuning.swayPunchCancelDelay + 0.03
        return .sway(demo, intent)
    }
}
#endif
