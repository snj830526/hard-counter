#if DEBUG
import CoreGraphics
import Foundation

struct SwayShowcaseController {
    struct Demo {
        let label: String
        let direction: SwayDirection
    }

    private let demos = [
        Demo(label: "CPU SLIP LEFT", direction: .left),
        Demo(label: "CPU SLIP RIGHT", direction: .right),
        Demo(label: "CPU PULL BACK", direction: .back),
        Demo(label: "CPU FORWARD FAIL", direction: .forward)
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
        let toward = normalized(towardOpponent)
        let screenDirection: CGVector
        switch demo.direction {
        case .left:
            screenDirection = CGVector(dx: -toward.dy, dy: toward.dx)
        case .right:
            screenDirection = CGVector(dx: toward.dy, dy: -toward.dx)
        case .back:
            screenDirection = CGVector(dx: -toward.dx, dy: -toward.dy)
        case .forward:
            screenDirection = toward
        }
        return (demo, SwayIntent(
            direction: demo.direction,
            isTowardOpponent: demo.direction == .forward,
            screenDirection: screenDirection
        ))
    }

    private func normalized(_ vector: CGVector) -> CGVector {
        let length = hypot(vector.dx, vector.dy)
        guard length > 0.001 else { return CGVector(dx: -1, dy: 0) }
        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
    }
}
#endif
