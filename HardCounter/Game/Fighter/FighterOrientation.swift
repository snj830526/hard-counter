import CoreGraphics
import Foundation

struct FighterOrientationFrame {
    let direction: CGVector
    let facing: CGFloat

    var depthAmount: CGFloat {
        abs(direction.dy)
    }

    var towardCameraAmount: CGFloat {
        max(-direction.dy, 0)
    }

    var awayFromCameraAmount: CGFloat {
        max(direction.dy, 0)
    }
}

struct FighterOrientationController {
    private var displayedAngle: CGFloat
    private var facing: CGFloat

    init(facingRight: Bool) {
        facing = facingRight ? 1 : -1
        displayedAngle = facingRight ? 0 : .pi
    }

    mutating func update(
        toward targetDirection: CGVector,
        deltaTime: TimeInterval
    ) -> FighterOrientationFrame {
        let fallback = CGVector(dx: cos(displayedAngle), dy: sin(displayedAngle))
        let target = normalized(targetDirection, fallback: fallback)
        let targetAngle = atan2(target.dy, target.dx)

        if deltaTime <= 0 {
            displayedAngle = targetAngle
        } else {
            let angleDelta = atan2(
                sin(targetAngle - displayedAngle),
                cos(targetAngle - displayedAngle)
            )
            let response: CGFloat = abs(angleDelta) > 1.1 ? 13.5 : 10.5
            let blend = 1 - CGFloat(exp(-Double(response) * deltaTime))
            displayedAngle += angleDelta * blend
        }

        let direction = CGVector(dx: cos(displayedAngle), dy: sin(displayedAngle))
        // Change mirrored sides only after the body has left its nearly
        // head-on silhouette. Near depth, both sides converge on a symmetric
        // pose so crossing the centre line no longer causes a visible pop.
        if direction.dx > 0.34 {
            facing = 1
        } else if direction.dx < -0.34 {
            facing = -1
        }

        return FighterOrientationFrame(direction: direction, facing: facing)
    }

    private func normalized(_ vector: CGVector, fallback: CGVector) -> CGVector {
        let length = hypot(vector.dx, vector.dy)
        guard length > 0.001 else { return fallback }
        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
    }
}
