import CoreGraphics

struct FighterMovementState {
    let screenMovement: CGVector
    let screenDisplacement: CGVector
    let towardOpponent: CGVector

    static func stationary(towardOpponent: CGVector) -> FighterMovementState {
        FighterMovementState(
            screenMovement: .zero,
            screenDisplacement: .zero,
            towardOpponent: towardOpponent
        )
    }

    func locomotionInput(
        facing: CGFloat,
        horizontalScale: CGFloat,
        verticalScale: CGFloat,
        displayedOpponentDirection: CGVector
    ) -> FighterLocomotionInput {
        FighterLocomotionInput(
            screenMovement: screenMovement,
            localRootDisplacement: CGVector(
                dx: abs(horizontalScale) > 0.001
                    ? screenDisplacement.dx / horizontalScale : 0,
                dy: abs(verticalScale) > 0.001
                    ? screenDisplacement.dy / verticalScale : 0
            ),
            facing: facing,
            opponentDirection: normalized(
                displayedOpponentDirection,
                fallback: CGVector(dx: facing, dy: 0)
            )
        )
    }

    private func normalized(_ vector: CGVector, fallback: CGVector) -> CGVector {
        let length = hypot(vector.dx, vector.dy)
        guard length > 0.001 else { return fallback }
        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
    }
}

struct FighterLocomotionInput {
    let screenMovement: CGVector
    let localRootDisplacement: CGVector
    let facing: CGFloat
    let opponentDirection: CGVector
}
