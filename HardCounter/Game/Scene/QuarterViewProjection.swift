import CoreGraphics

struct QuarterViewProjection {
    static let halfWidth = ArenaViewTuning.ringHalfWidth
    static let halfDepth = ArenaViewTuning.ringHalfDepth

    let center: CGPoint
    let widthAxis: CGVector
    let depthAxis: CGVector
    let viewAngle: CGFloat

    init(
        size: CGSize,
        safeInsets: EdgeInsetsSnapshot,
        viewAngle: CGFloat = 0
    ) {
        let usableWidth = size.width - safeInsets.leading - safeInsets.trailing
        let originX = safeInsets.leading + usableWidth * 0.50
        center = CGPoint(x: originX, y: size.height * 0.42)
        widthAxis = CGVector(dx: usableWidth * 0.24, dy: size.height * 0.10)
        depthAxis = CGVector(dx: -usableWidth * 0.18, dy: size.height * 0.15)
        self.viewAngle = viewAngle
    }

    func project(_ world: CGPoint) -> CGPoint {
        let normalizedWorld = CGPoint(
            x: world.x / Self.halfWidth,
            y: world.y / Self.halfDepth
        )
        let cameraSpace = rotate(normalizedWorld, by: -viewAngle)
        return CGPoint(
            x: center.x + widthAxis.dx * cameraSpace.x
                + depthAxis.dx * cameraSpace.y,
            y: center.y + widthAxis.dy * cameraSpace.x
                + depthAxis.dy * cameraSpace.y
        )
    }

    func screenVector(forWorldVector vector: CGVector) -> CGVector {
        let normalizedWorld = CGVector(
            dx: vector.dx / Self.halfWidth,
            dy: vector.dy / Self.halfDepth
        )
        let cameraSpace = rotate(normalizedWorld, by: -viewAngle)
        return CGVector(
            dx: widthAxis.dx * cameraSpace.dx + depthAxis.dx * cameraSpace.dy,
            dy: widthAxis.dy * cameraSpace.dx + depthAxis.dy * cameraSpace.dy
        )
    }

    /// Converts a world-space input direction back into a screen-space input
    /// while preserving analog stick magnitude. `screenVector` intentionally
    /// includes projection scale and is therefore suited to geometry, not
    /// networked controls.
    func screenDirection(forWorldDirection vector: CGVector) -> CGVector {
        let magnitude = min(hypot(vector.dx, vector.dy), 1)
        guard magnitude > 0.001 else { return .zero }
        let projected = screenVector(forWorldVector: vector)
        let projectedLength = hypot(projected.dx, projected.dy)
        guard projectedLength > 0.001 else { return .zero }
        return CGVector(
            dx: projected.dx / projectedLength * magnitude,
            dy: projected.dy / projectedLength * magnitude
        )
    }

    func worldDirection(forScreenVector vector: CGVector) -> CGVector {
        let magnitude = min(hypot(vector.dx, vector.dy), 1)
        guard magnitude > 0.001 else { return .zero }

        let determinant = widthAxis.dx * depthAxis.dy - depthAxis.dx * widthAxis.dy
        guard abs(determinant) > 0.001 else { return .zero }
        let u = (vector.dx * depthAxis.dy - depthAxis.dx * vector.dy) / determinant
        let v = (widthAxis.dx * vector.dy - vector.dx * widthAxis.dy) / determinant
        let normalizedWorld = rotate(CGVector(dx: u, dy: v), by: viewAngle)
        let world = CGVector(
            dx: normalizedWorld.dx * Self.halfWidth,
            dy: normalizedWorld.dy * Self.halfDepth
        )
        let worldLength = hypot(world.dx, world.dy)
        guard worldLength > 0.001 else { return .zero }
        return CGVector(
            dx: world.dx / worldLength * magnitude,
            dy: world.dy / worldLength * magnitude
        )
    }

    func depthProgress(at world: CGPoint) -> CGFloat {
        let normalizedWorld = CGPoint(
            x: world.x / Self.halfWidth,
            y: world.y / Self.halfDepth
        )
        let cameraSpace = rotate(normalizedWorld, by: -viewAngle)
        let u = min(max(cameraSpace.x, -1), 1)
        let v = min(max(cameraSpace.y, -1), 1)
        return (u + v + 2) / 4
    }

    /// Returns the ideal camera angle that maps a world-space fighter vector
    /// onto screen-right. CombatScene snaps it to the nearest fixed camera.
    func viewAnglePlacingOnScreenRight(_ worldVector: CGVector) -> CGFloat? {
        let normalizedWorld = CGVector(
            dx: worldVector.dx / Self.halfWidth,
            dy: worldVector.dy / Self.halfDepth
        )
        guard hypot(normalizedWorld.dx, normalizedWorld.dy) > 0.001 else {
            return nil
        }

        let determinant = widthAxis.dx * depthAxis.dy
            - depthAxis.dx * widthAxis.dy
        guard abs(determinant) > 0.001 else { return nil }
        let cameraX = depthAxis.dy / determinant
        let cameraY = -widthAxis.dy / determinant
        let worldAngle = atan2(normalizedWorld.dy, normalizedWorld.dx)
        let screenRightCameraAngle = atan2(cameraY, cameraX)
        return worldAngle - screenRightCameraAngle
    }

    func clamped(_ world: CGPoint, margin: CGFloat = 34) -> CGPoint {
        CGPoint(
            x: min(max(world.x, -Self.halfWidth + margin), Self.halfWidth - margin),
            y: min(max(world.y, -Self.halfDepth + margin), Self.halfDepth - margin)
        )
    }

    private func rotate(_ point: CGPoint, by angle: CGFloat) -> CGPoint {
        let cosine = cos(angle)
        let sine = sin(angle)
        return CGPoint(
            x: point.x * cosine - point.y * sine,
            y: point.x * sine + point.y * cosine
        )
    }

    private func rotate(_ vector: CGVector, by angle: CGFloat) -> CGVector {
        let cosine = cos(angle)
        let sine = sin(angle)
        return CGVector(
            dx: vector.dx * cosine - vector.dy * sine,
            dy: vector.dx * sine + vector.dy * cosine
        )
    }
}
