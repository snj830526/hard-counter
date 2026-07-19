import CoreGraphics

enum SwayInputResolver {
    static func resolve(movement: CGVector, towardOpponent: CGVector) -> SwayIntent {
        let opponentDistance = hypot(towardOpponent.dx, towardOpponent.dy)
        guard opponentDistance > 0.001 else {
            return .neutral
        }
        let opponentDirection = CGVector(
            dx: towardOpponent.dx / opponentDistance,
            dy: towardOpponent.dy / opponentDistance
        )
        let movementLength = hypot(movement.dx, movement.dy)
        guard movementLength > 0.18 else {
            return SwayIntent(
                direction: .back,
                isTowardOpponent: false,
                screenDirection: CGVector(
                    dx: -opponentDirection.dx,
                    dy: -opponentDirection.dy
                )
            )
        }
        let movementDirection = CGVector(
            dx: movement.dx / movementLength,
            dy: movement.dy / movementLength
        )

        let forwardDot = (
            movementDirection.dx * opponentDirection.dx
            + movementDirection.dy * opponentDirection.dy
        )
        let leftX = -opponentDirection.dy
        let leftY = opponentDirection.dx
        let lateralDot = movementDirection.dx * leftX + movementDirection.dy * leftY
        let continuousDirection = SwayDirection(
            forward: forwardDot,
            lateral: lateralDot
        )
        if forwardDot > 0.24 {
            return SwayIntent(
                direction: continuousDirection,
                isTowardOpponent: true,
                screenDirection: movementDirection
            )
        }
        if forwardDot < -0.18 {
            return SwayIntent(
                direction: continuousDirection,
                isTowardOpponent: false,
                screenDirection: movementDirection
            )
        }

        return SwayIntent(
            direction: continuousDirection,
            isTowardOpponent: false,
            screenDirection: movementDirection
        )
    }
}
