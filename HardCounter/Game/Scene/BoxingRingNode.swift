import SpriteKit

final class BoxingRingNode: SKNode {
    private let backgroundLayer = SKNode()
    private let foregroundLayer = SKNode()

    override init() {
        super.init()
        addChild(backgroundLayer)
        addChild(foregroundLayer)
        backgroundLayer.zPosition = 0
        foregroundLayer.zPosition = 30
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { nil }

    func rebuild(in size: CGSize, projection: QuarterViewProjection) {
        backgroundLayer.removeAllChildren()
        foregroundLayer.removeAllChildren()

        let near = projection.project(CGPoint(x: -QuarterViewProjection.halfWidth, y: -QuarterViewProjection.halfDepth))
        let right = projection.project(CGPoint(x: QuarterViewProjection.halfWidth, y: -QuarterViewProjection.halfDepth))
        let far = projection.project(CGPoint(x: QuarterViewProjection.halfWidth, y: QuarterViewProjection.halfDepth))
        let left = projection.project(CGPoint(x: -QuarterViewProjection.halfWidth, y: QuarterViewProjection.halfDepth))

        addArenaBackdrop(size: size, farY: max(far.y, left.y))
        addMat(near: near, right: right, far: far, left: left)
        addPostsAndRopes(near: near, right: right, far: far, left: left)
    }

    private func addArenaBackdrop(size: CGSize, farY: CGFloat) {
        let crowdBand = SKShapeNode(rect: CGRect(x: 0, y: farY + 24, width: size.width, height: size.height - farY - 24))
        crowdBand.fillColor = SKColor(red: 0.025, green: 0.03, blue: 0.045, alpha: 1)
        crowdBand.strokeColor = .clear
        crowdBand.zPosition = -10
        backgroundLayer.addChild(crowdBand)

        let colors: [SKColor] = [.systemRed, .systemBlue, .systemYellow, .systemTeal, .systemPurple]
        for index in 0..<28 {
            let column = CGFloat(index) / 27
            let x = 18 + column * (size.width - 36)
            let rowOffset = CGFloat((index * 17) % 4) * 7
            let spectator = SKShapeNode(circleOfRadius: 4 + CGFloat(index % 2))
            spectator.position = CGPoint(x: x, y: farY + 47 + rowOffset)
            spectator.fillColor = colors[index % colors.count].withAlphaComponent(0.28)
            spectator.strokeColor = .clear
            spectator.zPosition = -8
            backgroundLayer.addChild(spectator)
        }

        for index in 0..<5 {
            let light = SKShapeNode(rectOf: CGSize(width: 74, height: 7), cornerRadius: 2)
            light.position = CGPoint(x: size.width * (CGFloat(index) + 1) / 6, y: size.height - 17)
            light.fillColor = SKColor.white.withAlphaComponent(0.50)
            light.strokeColor = .clear
            light.glowWidth = 4
            light.zPosition = -7
            backgroundLayer.addChild(light)
        }
    }

    private func addMat(near: CGPoint, right: CGPoint, far: CGPoint, left: CGPoint) {
        let mat = polygon([near, right, far, left])
        mat.fillColor = SKColor(red: 0.20, green: 0.25, blue: 0.29, alpha: 1)
        mat.strokeColor = SKColor(red: 0.48, green: 0.54, blue: 0.56, alpha: 1)
        mat.lineWidth = 3
        mat.zPosition = -2
        backgroundLayer.addChild(mat)

        let center = CGPoint(
            x: (near.x + right.x + far.x + left.x) / 4,
            y: (near.y + right.y + far.y + left.y) / 4
        )
        let centerMark = polygon([near, right, far, left].map {
            CGPoint(x: center.x + ($0.x - center.x) * 0.28, y: center.y + ($0.y - center.y) * 0.28)
        })
        centerMark.fillColor = SKColor.white.withAlphaComponent(0.045)
        centerMark.strokeColor = .clear
        centerMark.zPosition = -1
        backgroundLayer.addChild(centerMark)

        addApron(from: left, to: near, outward: CGVector(dx: -5, dy: -15))
        addApron(from: near, to: right, outward: CGVector(dx: 8, dy: -14))
    }

    private func addPostsAndRopes(near: CGPoint, right: CGPoint, far: CGPoint, left: CGPoint) {
        let ropeColors: [SKColor] = [
            SKColor(red: 0.82, green: 0.12, blue: 0.10, alpha: 1),
            SKColor.white.withAlphaComponent(0.92),
            SKColor(red: 0.15, green: 0.31, blue: 0.72, alpha: 1)
        ]

        for level in 0..<3 {
            let rise = CGFloat(20 + level * 19)
            let nearRope = CGPoint(x: near.x, y: near.y + rise)
            let rightRope = CGPoint(x: right.x, y: right.y + rise)
            let farRope = CGPoint(x: far.x, y: far.y + rise)
            let leftRope = CGPoint(x: left.x, y: left.y + rise)
            addLine(from: leftRope, to: farRope, color: ropeColors[level].withAlphaComponent(0.78), width: 4, to: backgroundLayer, z: 2)
            addLine(from: farRope, to: rightRope, color: ropeColors[level].withAlphaComponent(0.78), width: 4, to: backgroundLayer, z: 2)
            addLine(from: leftRope, to: nearRope, color: ropeColors[level].withAlphaComponent(0.88), width: 3.5, to: foregroundLayer, z: 31)
            addLine(from: nearRope, to: rightRope, color: ropeColors[level].withAlphaComponent(0.88), width: 3.5, to: foregroundLayer, z: 32)
        }

        addPost(at: far, color: .systemRed, to: backgroundLayer, z: 3)
        addPost(at: left, color: .systemBlue, to: foregroundLayer, z: 33)
        addPost(at: right, color: .systemBlue, to: foregroundLayer, z: 33)
        addPost(at: near, color: .systemRed, to: foregroundLayer, z: 34)
    }

    private func addApron(from start: CGPoint, to end: CGPoint, outward: CGVector) {
        let apron = polygon([
            start, end,
            CGPoint(x: end.x + outward.dx, y: end.y + outward.dy),
            CGPoint(x: start.x + outward.dx, y: start.y + outward.dy)
        ])
        apron.fillColor = SKColor(red: 0.08, green: 0.11, blue: 0.14, alpha: 1)
        apron.strokeColor = .black.withAlphaComponent(0.6)
        apron.lineWidth = 2
        apron.zPosition = 25
        foregroundLayer.addChild(apron)
    }

    private func addPost(at point: CGPoint, color: SKColor, to layer: SKNode, z: CGFloat) {
        let post = SKShapeNode(rectOf: CGSize(width: 10, height: 78), cornerRadius: 2)
        post.position = CGPoint(x: point.x, y: point.y + 38)
        post.fillColor = color
        post.strokeColor = .black.withAlphaComponent(0.65)
        post.lineWidth = 2
        post.zPosition = z
        layer.addChild(post)
    }

    private func addLine(from start: CGPoint, to end: CGPoint, color: SKColor, width: CGFloat, to layer: SKNode, z: CGFloat) {
        let line = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        line.path = path
        line.strokeColor = color
        line.lineWidth = width
        line.zPosition = z
        layer.addChild(line)
    }

    private func polygon(_ points: [CGPoint]) -> SKShapeNode {
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
