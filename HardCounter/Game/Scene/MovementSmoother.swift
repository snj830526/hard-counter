import CoreGraphics
import Foundation

struct MovementSmoother {
    private(set) var value = CGVector.zero

    let acceleration: CGFloat
    let turnAcceleration: CGFloat
    let deceleration: CGFloat
    let turnDotThreshold: CGFloat
    let idleThreshold: CGFloat

    mutating func update(toward target: CGVector, deltaTime: TimeInterval) -> CGVector {
        let targetIsIdle = hypot(target.dx, target.dy) < 0.001
        let dot = value.dx * target.dx + value.dy * target.dy
        let response: CGFloat
        if targetIsIdle {
            response = deceleration
        } else if dot < turnDotThreshold {
            response = turnAcceleration
        } else {
            response = acceleration
        }

        let blend = 1 - CGFloat(exp(-Double(response) * deltaTime))
        value = CGVector(
            dx: value.dx + (target.dx - value.dx) * blend,
            dy: value.dy + (target.dy - value.dy) * blend
        )
        if targetIsIdle, hypot(value.dx, value.dy) < idleThreshold {
            value = .zero
        }
        return value
    }

    mutating func reset() {
        value = .zero
    }
}
