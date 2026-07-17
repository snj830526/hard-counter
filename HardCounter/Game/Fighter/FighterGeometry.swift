import SpriteKit

enum FighterGeometry {
    static let skinColor = SKColor(red: 0.73, green: 0.47, blue: 0.30, alpha: 1)
    static let upperArmLength: CGFloat = 37
    static let lowerArmLength: CGFloat = 35
    static let upperLegLength: CGFloat = 35
    static let lowerLegLength: CGFloat = 35

    static func makeLimb(
        length: CGFloat,
        topWidth: CGFloat,
        bottomWidth: CGFloat,
        color: SKColor
    ) -> SKNode {
        let node = makePolygon([
            CGPoint(x: -topWidth * 0.50, y: 1),
            CGPoint(x: topWidth * 0.50, y: -1),
            CGPoint(x: bottomWidth * 0.48, y: -length),
            CGPoint(x: -bottomWidth * 0.48, y: -length + 1)
        ])
        node.fillColor = color
        node.strokeColor = .black.withAlphaComponent(0.68)
        node.lineWidth = 1.5
        return node
    }

    static func regularPolygon(radius: CGFloat, sides: Int, startAngle: CGFloat) -> [CGPoint] {
        (0..<sides).map { index in
            let angle = startAngle + CGFloat(index) * 2 * .pi / CGFloat(sides)
            return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        }
    }

    static func makePolygon(_ points: [CGPoint]) -> SKShapeNode {
        let node = SKShapeNode()
        guard let first = points.first else { return node }
        let path = CGMutablePath()
        path.move(to: first)
        points.dropFirst().forEach { path.addLine(to: $0) }
        path.closeSubpath()
        node.path = path
        return node
    }
}
