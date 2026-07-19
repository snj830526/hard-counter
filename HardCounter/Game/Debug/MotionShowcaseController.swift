#if DEBUG
import CoreGraphics
import Foundation

struct MotionShowcaseController {
    enum Command {
        case start(label: String, intent: SwayIntent)
        case punch
    }

    private enum Demo: CaseIterable {
        case straight
        case smash
        case uppercut

        var label: String {
            switch self {
            case .straight: return "CPU STRAIGHT"
            case .smash: return "CPU SMASH"
            case .uppercut: return "CPU UPPERCUT"
            }
        }
    }

    private var demoIndex = 0
    private var nextDemoAt: TimeInterval?
    private var punchAt: TimeInterval?
    private let demos: [Demo]

    init(uppercutOnly: Bool = false) {
        demos = uppercutOnly ? [.uppercut] : Demo.allCases
    }

    mutating func reset(at time: TimeInterval) {
        demoIndex = 0
        nextDemoAt = time + 0.8
        punchAt = nil
    }

    mutating func command(
        at time: TimeInterval,
        state: FighterCombatState,
        towardOpponent: CGVector
    ) -> Command? {
        if let punchAt {
            guard time >= punchAt else { return nil }
            self.punchAt = nil
            nextDemoAt = time + 2.6
            return state.phase == .swaying ? .punch : nil
        }

        if nextDemoAt == nil { reset(at: time) }
        guard let nextDemoAt, time >= nextDemoAt, state.phase == .idle else { return nil }

        let demo = demos[demoIndex % demos.count]
        demoIndex += 1
        self.nextDemoAt = nil
        punchAt = time + CombatTuning.swayPunchCancelDelay + 0.03
        return .start(label: demo.label, intent: swayIntent(for: demo, toward: towardOpponent))
    }

    private func swayIntent(for demo: Demo, toward vector: CGVector) -> SwayIntent {
        let toward = normalized(vector)
        switch demo {
        case .straight:
            return SwayIntent(
                direction: .back,
                isTowardOpponent: false,
                screenDirection: CGVector(dx: -toward.dx, dy: -toward.dy)
            )
        case .smash:
            return SwayIntent(
                direction: .left,
                isTowardOpponent: false,
                screenDirection: CGVector(dx: -toward.dy, dy: toward.dx)
            )
        case .uppercut:
            return SwayIntent(
                direction: .forward,
                isTowardOpponent: true,
                screenDirection: toward
            )
        }
    }

    private func normalized(_ vector: CGVector) -> CGVector {
        let length = hypot(vector.dx, vector.dy)
        guard length > 0.001 else { return CGVector(dx: -1, dy: 0) }
        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
    }
}
#endif
