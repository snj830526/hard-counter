import CoreGraphics
import Foundation

struct CPUController {
    private var nextAttackTime: TimeInterval?
    private var nextMovementDecisionTime: TimeInterval = 0
    private var movementVector = CGVector.zero
    private var circlingDirection: CGFloat = 1

    mutating func reset(at time: TimeInterval) {
        nextAttackTime = time + CombatTuning.cpuInitialDelay
        nextMovementDecisionTime = time
        movementVector = .zero
        circlingDirection = Bool.random() ? 1 : -1
    }

    mutating func shouldPunch(at time: TimeInterval, state: FighterCombatState) -> Bool {
        if nextAttackTime == nil { reset(at: time) }
        guard let nextAttackTime, time >= nextAttackTime, state.phase == .idle else { return false }
        self.nextAttackTime = time + Double.random(in: CombatTuning.cpuAttackInterval)
        return true
    }

    mutating func movement(
        at time: TimeInterval,
        playerPosition: CGPoint,
        cpuPosition: CGPoint,
        visibleDistance: CGFloat,
        preferredPunchRange: CGFloat
    ) -> CGVector {
        guard time >= nextMovementDecisionTime else { return movementVector }
        nextMovementDecisionTime = time + Double.random(in: CombatTuning.cpuMovementDecisionInterval)

        let toward = normalized(CGVector(
            dx: playerPosition.x - cpuPosition.x,
            dy: playerPosition.y - cpuPosition.y
        ))
        // Hold a circling lane across several decisions. Re-rolling the side on
        // every update made the CPU zigzag even when its tactical state had not
        // changed.
        if Double.random(in: 0...1) < 0.14 {
            circlingDirection *= -1
        }
        let circle = CGVector(
            dx: -toward.dy * circlingDirection,
            dy: toward.dx * circlingDirection
        )
        let roll = Double.random(in: 0...1)

        if visibleDistance > preferredPunchRange * 1.55 {
            movementVector = roll < 0.58 ? toward : (roll < 0.84 ? circle : .zero)
        } else if visibleDistance < preferredPunchRange * 0.62 {
            movementVector = roll < 0.52
                ? CGVector(dx: -toward.dx, dy: -toward.dy)
                : (roll < 0.84 ? circle : .zero)
        } else {
            if roll < 0.25 {
                movementVector = toward
            } else if roll < 0.56 {
                movementVector = circle
            } else if roll < 0.76 {
                movementVector = CGVector(dx: -toward.dx, dy: -toward.dy)
            } else {
                movementVector = .zero
            }
        }
        return movementVector
    }

    private func normalized(_ vector: CGVector) -> CGVector {
        let length = hypot(vector.dx, vector.dy)
        guard length > 0.001 else { return CGVector(dx: -1, dy: 0) }
        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
    }
}
