#if DEBUG
import CoreGraphics
import Foundation

struct SwayShowcaseController {
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

    mutating func reset(at time: TimeInterval) {
        index = 0
        nextDemoAt = time + 0.8
    }

    mutating func command(
        at time: TimeInterval,
        state: FighterCombatState,
        towardOpponent: CGVector
    ) -> (Demo, SwayIntent)? {
        if nextDemoAt == nil { reset(at: time) }
        guard let nextDemoAt, time >= nextDemoAt, state.phase == .idle else { return nil }

        let demo = demos[index % demos.count]
        index += 1
        self.nextDemoAt = time + 1.35
        return (
            demo,
            SwayInputResolver.resolve(
                movement: demo.screenDirection,
                towardOpponent: towardOpponent
            )
        )
    }
}
#endif
