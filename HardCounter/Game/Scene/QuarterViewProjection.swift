import CoreGraphics

struct QuarterViewProjection {
    static let halfWidth: CGFloat = 320
    static let halfDepth: CGFloat = 180

    let center: CGPoint
    let widthAxis: CGVector
    let depthAxis: CGVector

    init(size: CGSize, safeInsets: EdgeInsetsSnapshot) {
        let usableWidth = size.width - safeInsets.leading - safeInsets.trailing
        let originX = safeInsets.leading + usableWidth * 0.50
        center = CGPoint(x: originX, y: size.height * 0.42)
        widthAxis = CGVector(dx: usableWidth * 0.24, dy: size.height * 0.10)
        depthAxis = CGVector(dx: -usableWidth * 0.18, dy: size.height * 0.15)
    }

    func project(_ world: CGPoint) -> CGPoint {
        let u = world.x / Self.halfWidth
        let v = world.y / Self.halfDepth
        return CGPoint(
            x: center.x + widthAxis.dx * u + depthAxis.dx * v,
            y: center.y + widthAxis.dy * u + depthAxis.dy * v
        )
    }

    func screenVector(forWorldVector vector: CGVector) -> CGVector {
        CGVector(
            dx: widthAxis.dx * vector.dx / Self.halfWidth + depthAxis.dx * vector.dy / Self.halfDepth,
            dy: widthAxis.dy * vector.dx / Self.halfWidth + depthAxis.dy * vector.dy / Self.halfDepth
        )
    }

    func worldDirection(forScreenVector vector: CGVector) -> CGVector {
        let magnitude = min(hypot(vector.dx, vector.dy), 1)
        guard magnitude > 0.001 else { return .zero }

        let determinant = widthAxis.dx * depthAxis.dy - depthAxis.dx * widthAxis.dy
        guard abs(determinant) > 0.001 else { return .zero }
        let u = (vector.dx * depthAxis.dy - depthAxis.dx * vector.dy) / determinant
        let v = (widthAxis.dx * vector.dy - vector.dx * widthAxis.dy) / determinant
        let world = CGVector(dx: u * Self.halfWidth, dy: v * Self.halfDepth)
        let worldLength = hypot(world.dx, world.dy)
        guard worldLength > 0.001 else { return .zero }
        return CGVector(dx: world.dx / worldLength * magnitude, dy: world.dy / worldLength * magnitude)
    }

    func depthProgress(at world: CGPoint) -> CGFloat {
        let u = min(max(world.x / Self.halfWidth, -1), 1)
        let v = min(max(world.y / Self.halfDepth, -1), 1)
        return (u + v + 2) / 4
    }

    func clamped(_ world: CGPoint, margin: CGFloat = 34) -> CGPoint {
        CGPoint(
            x: min(max(world.x, -Self.halfWidth + margin), Self.halfWidth - margin),
            y: min(max(world.y, -Self.halfDepth + margin), Self.halfDepth - margin)
        )
    }
}
