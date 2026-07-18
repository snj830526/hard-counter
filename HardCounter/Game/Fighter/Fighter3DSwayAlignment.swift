import CoreGraphics

struct Fighter3DSwayOffset {
    let localX: CGFloat
    let localY: CGFloat
    let localZ: CGFloat
}

enum Fighter3DSwayAlignment {
    static func torsoOffset(
        screenDirection: CGVector,
        facingDirection: CGVector,
        pelvisYaw: CGFloat,
        travel: CGFloat
    ) -> Fighter3DSwayOffset {
        let inputLength = hypot(screenDirection.dx, screenDirection.dy)
        guard inputLength > 0.001 else {
            return Fighter3DSwayOffset(localX: 0, localY: 0, localZ: 0)
        }
        let input = CGVector(
            dx: screenDirection.dx / inputLength,
            dy: screenDirection.dy / inputLength
        )

        let facingLength = hypot(facingDirection.dx, facingDirection.dy)
        let facing = facingLength > 0.001
            ? CGVector(
                dx: facingDirection.dx / facingLength,
                dy: facingDirection.dy / facingLength
            )
            : CGVector(dx: 1, dy: 0)
        let worldYaw = atan2(facing.dx, -facing.dy) + pelvisYaw
        let screenHorizontal = input.dx * travel * 0.82

        return Fighter3DSwayOffset(
            localX: screenHorizontal * cos(worldYaw),
            localY: input.dy * travel * 0.52,
            localZ: screenHorizontal * sin(worldYaw)
        )
    }
}
