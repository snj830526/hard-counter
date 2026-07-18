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
        let wallBottom = farY + 16
        let wall = SKShapeNode(rect: CGRect(
            x: 0,
            y: wallBottom,
            width: size.width,
            height: max(size.height - wallBottom, 0)
        ))
        wall.fillColor = SKColor(red: 0.018, green: 0.025, blue: 0.040, alpha: 1)
        wall.strokeColor = .clear
        wall.zPosition = -12
        backgroundLayer.addChild(wall)

        // Broad angular panels echo the fighters' low-poly surfaces without
        // competing with their kit colors.
        let leftPanel = polygon([
            CGPoint(x: 0, y: wallBottom),
            CGPoint(x: size.width * 0.48, y: wallBottom),
            CGPoint(x: size.width * 0.34, y: size.height),
            CGPoint(x: 0, y: size.height)
        ])
        leftPanel.fillColor = SKColor(red: 0.035, green: 0.055, blue: 0.078, alpha: 1)
        leftPanel.strokeColor = .clear
        leftPanel.zPosition = -11
        backgroundLayer.addChild(leftPanel)

        let rightPanel = polygon([
            CGPoint(x: size.width * 0.48, y: wallBottom),
            CGPoint(x: size.width, y: wallBottom),
            CGPoint(x: size.width, y: size.height),
            CGPoint(x: size.width * 0.66, y: size.height)
        ])
        rightPanel.fillColor = SKColor(red: 0.050, green: 0.038, blue: 0.055, alpha: 1)
        rightPanel.strokeColor = .clear
        rightPanel.zPosition = -11
        backgroundLayer.addChild(rightPanel)

        for row in 0..<3 {
            let rowY = wallBottom + 18 + CGFloat(row) * 18
            let tier = SKShapeNode(rect: CGRect(x: 0, y: rowY - 5, width: size.width, height: 10))
            tier.fillColor = SKColor(red: 0.055, green: 0.066, blue: 0.082, alpha: 0.96)
            tier.strokeColor = SKColor.white.withAlphaComponent(0.035)
            tier.lineWidth = 1
            tier.zPosition = -9
            backgroundLayer.addChild(tier)

            let count = 18 + row * 3
            for index in 0..<count {
                let x = (CGFloat(index) + 0.5) * size.width / CGFloat(count)
                let offset = CGFloat((index * 7 + row * 3) % 3) * 1.5
                let head = SKShapeNode(circleOfRadius: 2.4 + CGFloat((index + row) % 2) * 0.5)
                head.position = CGPoint(x: x, y: rowY + 5 + offset)
                head.fillColor = SKColor(
                    red: 0.16 + CGFloat(index % 3) * 0.018,
                    green: 0.17 + CGFloat(row) * 0.012,
                    blue: 0.19 + CGFloat((index + row) % 2) * 0.018,
                    alpha: 0.82
                )
                head.strokeColor = .clear
                head.zPosition = -8
                backgroundLayer.addChild(head)
            }
        }

        let trussY = size.height - 18
        addLine(
            from: CGPoint(x: 0, y: trussY),
            to: CGPoint(x: size.width, y: trussY),
            color: SKColor.white.withAlphaComponent(0.10),
            width: 3,
            to: backgroundLayer,
            z: -7
        )
        for index in 0..<5 {
            let lightX = size.width * (CGFloat(index) + 1) / 6
            let light = SKShapeNode(rectOf: CGSize(width: 54, height: 6), cornerRadius: 1.5)
            light.position = CGPoint(x: lightX, y: trussY - 1)
            light.fillColor = ArenaVisualPalette.overheadLight.withAlphaComponent(0.62)
            light.strokeColor = .clear
            light.glowWidth = 3
            light.zPosition = -6
            backgroundLayer.addChild(light)
        }
    }

    private func addMat(near: CGPoint, right: CGPoint, far: CGPoint, left: CGPoint) {
        let mat = polygon([near, right, far, left])
        mat.fillColor = SKColor(red: 0.145, green: 0.185, blue: 0.215, alpha: 1)
        mat.strokeColor = SKColor(red: 0.34, green: 0.43, blue: 0.47, alpha: 1)
        mat.lineWidth = 3
        mat.zPosition = -2
        backgroundLayer.addChild(mat)

        let center = CGPoint(
            x: (near.x + right.x + far.x + left.x) / 4,
            y: (near.y + right.y + far.y + left.y) / 4
        )
        let innerCanvas = polygon([near, right, far, left].map {
            CGPoint(x: center.x + ($0.x - center.x) * 0.88, y: center.y + ($0.y - center.y) * 0.88)
        })
        innerCanvas.fillColor = SKColor(red: 0.17, green: 0.215, blue: 0.245, alpha: 0.48)
        innerCanvas.strokeColor = SKColor.white.withAlphaComponent(0.055)
        innerCanvas.lineWidth = 1
        innerCanvas.zPosition = -1.8
        backgroundLayer.addChild(innerCanvas)

        // Canvas seams follow the same two axes as movement projection. This
        // makes depth readable while keeping the arena a lightweight 2D asset.
        for fraction in [CGFloat(0.25), 0.50, 0.75] {
            addLine(
                from: point(between: near, and: left, fraction: fraction),
                to: point(between: right, and: far, fraction: fraction),
                color: SKColor.white.withAlphaComponent(0.045),
                width: 0.8,
                to: backgroundLayer,
                z: -1.5
            )
            addLine(
                from: point(between: near, and: right, fraction: fraction),
                to: point(between: left, and: far, fraction: fraction),
                color: SKColor.black.withAlphaComponent(0.09),
                width: 0.8,
                to: backgroundLayer,
                z: -1.5
            )
        }

        let centerMark = polygon([near, right, far, left].map {
            CGPoint(x: center.x + ($0.x - center.x) * 0.28, y: center.y + ($0.y - center.y) * 0.28)
        })
        centerMark.fillColor = SKColor(red: 0.32, green: 0.40, blue: 0.44, alpha: 0.13)
        centerMark.strokeColor = SKColor.white.withAlphaComponent(0.035)
        centerMark.lineWidth = 1
        centerMark.zPosition = -1
        backgroundLayer.addChild(centerMark)

        let coolPool = SKShapeNode(ellipseOf: CGSize(width: 118, height: 38))
        coolPool.position = CGPoint(x: center.x - 76, y: center.y + 25)
        coolPool.fillColor = ArenaVisualPalette.coolCanvasLight.withAlphaComponent(0.035)
        coolPool.strokeColor = .clear
        coolPool.zPosition = -0.9
        backgroundLayer.addChild(coolPool)

        let warmPool = SKShapeNode(ellipseOf: CGSize(width: 112, height: 35))
        warmPool.position = CGPoint(x: center.x + 82, y: center.y - 20)
        warmPool.fillColor = ArenaVisualPalette.warmCanvasLight.withAlphaComponent(0.028)
        warmPool.strokeColor = .clear
        warmPool.zPosition = -0.9
        backgroundLayer.addChild(warmPool)

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

    private func point(
        between start: CGPoint,
        and end: CGPoint,
        fraction: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: start.x + (end.x - start.x) * fraction,
            y: start.y + (end.y - start.y) * fraction
        )
    }
}
