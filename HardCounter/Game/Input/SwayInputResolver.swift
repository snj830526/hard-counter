import CoreGraphics

enum SwayInputResolver {
    static func resolve(movement: CGVector, towardOpponent: CGVector) -> SwayIntent {
        let movementLength = hypot(movement.dx, movement.dy)
        guard movementLength > 0.18 else { return .neutral }

        let direction: SwayDirection
        if abs(movement.dx) > abs(movement.dy) {
            direction = movement.dx < 0 ? .left : .right
        } else {
            direction = movement.dy > 0 ? .up : .down
        }

        let opponentDistance = hypot(towardOpponent.dx, towardOpponent.dy)
        guard opponentDistance > 0.001 else {
            return SwayIntent(direction: direction, isTowardOpponent: false)
        }

        let forwardDot = (
            movement.dx / movementLength * towardOpponent.dx / opponentDistance
            + movement.dy / movementLength * towardOpponent.dy / opponentDistance
        )
        return SwayIntent(direction: direction, isTowardOpponent: forwardDot > 0.24)
    }
}
