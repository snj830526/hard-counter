import CoreGraphics

enum SwayInputResolver {
    static func resolve(movement: CGVector, towardOpponent: CGVector) -> SwayIntent {
        let movementLength = hypot(movement.dx, movement.dy)
        guard movementLength > 0.18 else { return .neutral }

        let opponentDistance = hypot(towardOpponent.dx, towardOpponent.dy)
        guard opponentDistance > 0.001 else {
            return .neutral
        }

        let forwardDot = (
            movement.dx / movementLength * towardOpponent.dx / opponentDistance
            + movement.dy / movementLength * towardOpponent.dy / opponentDistance
        )
        if forwardDot > 0.24 {
            return SwayIntent(direction: .forward, isTowardOpponent: true)
        }
        if forwardDot < -0.18 {
            return SwayIntent(direction: .back, isTowardOpponent: false)
        }

        let leftX = -towardOpponent.dy / opponentDistance
        let leftY = towardOpponent.dx / opponentDistance
        let lateralDot = movement.dx / movementLength * leftX + movement.dy / movementLength * leftY
        return SwayIntent(direction: lateralDot >= 0 ? .left : .right, isTowardOpponent: false)
    }
}
