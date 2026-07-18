#if DEBUG
import CoreGraphics
import Foundation

struct FootworkShowcaseController {
    struct Frame {
        let label: String
        let screenMovement: CGVector
    }

    struct Transition {
        let label: String
        let action: CombatAction
    }

    private enum TransitionKind {
        case punch
        case sway
    }

    private struct Demo {
        let label: String
        let direction: CGVector
        let transition: TransitionKind?
    }

    private let demos = [
        Demo(label: "MOVE RIGHT", direction: CGVector(dx: 1, dy: 0), transition: .punch),
        Demo(label: "REVERSE LEFT", direction: CGVector(dx: -1, dy: 0), transition: nil),
        Demo(label: "MOVE UP", direction: CGVector(dx: 0, dy: 1), transition: nil),
        Demo(label: "REVERSE DOWN", direction: CGVector(dx: 0, dy: -1), transition: nil),
        Demo(label: "DIAGONAL UP RIGHT", direction: CGVector(dx: 0.707, dy: 0.707), transition: .sway),
        Demo(label: "DIAGONAL DOWN LEFT", direction: CGVector(dx: -0.707, dy: -0.707), transition: nil),
        Demo(label: "DIAGONAL UP LEFT", direction: CGVector(dx: -0.707, dy: 0.707), transition: nil),
        Demo(label: "DIAGONAL DOWN RIGHT", direction: CGVector(dx: 0.707, dy: -0.707), transition: nil)
    ]
    private let moveDuration: TimeInterval = 0.78
    private let settleDuration: TimeInterval = 0.30
    private var startedAt: TimeInterval?
    private var lastTransitionCycle: Int?

    mutating func reset(at time: TimeInterval) {
        startedAt = time + 0.65
        lastTransitionCycle = nil
    }

    mutating func frame(at time: TimeInterval) -> Frame {
        if startedAt == nil { reset(at: time) }
        let elapsed = max(time - (startedAt ?? time), 0)
        let stageDuration = moveDuration + settleDuration
        let stage = Int(elapsed / stageDuration) % demos.count
        let stageElapsed = elapsed.truncatingRemainder(dividingBy: stageDuration)
        let demo = demos[stage]
        let isMoving = stageElapsed < moveDuration
        let label = isMoving ? demo.label : "PLANT AND SETTLE"
        let frame = Frame(
            label: label,
            screenMovement: isMoving ? demo.direction : .zero
        )
        return frame
    }

    mutating func transition(
        at time: TimeInterval,
        state: FighterCombatState,
        towardOpponent: CGVector
    ) -> Transition? {
        guard let startedAt else { return nil }
        let elapsed = max(time - startedAt, 0)
        let stageDuration = moveDuration + settleDuration
        let cycle = Int(elapsed / stageDuration)
        let stage = cycle % demos.count
        let stageElapsed = elapsed.truncatingRemainder(dividingBy: stageDuration)
        let demo = demos[stage]
        guard let transition = demo.transition,
              stageElapsed >= 0.50,
              stageElapsed < moveDuration,
              lastTransitionCycle != cycle,
              state.phase == .idle else { return nil }

        lastTransitionCycle = cycle
        switch transition {
        case .punch:
            return Transition(label: "STEP INTO PUNCH", action: .punch(.neutral))
        case .sway:
            return Transition(
                label: "MOVE INTO SWAY",
                action: .sway(SwayInputResolver.resolve(
                    movement: demo.direction,
                    towardOpponent: towardOpponent
                ))
            )
        }
    }
}
#endif
