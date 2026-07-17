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

    func rebuild(in size: CGSize, safeInsets: EdgeInsetsSnapshot) {
        backgroundLayer.removeAllChildren()
        foregroundLayer.removeAllChildren()

        let left = safeInsets.leading + 24
        let right = size.width - safeInsets.trailing - 24
        let nearY = max(safeInsets.bottom + 66, size.height * 0.22)
        let farY = size.height * 0.65
        let nearLeft = CGPoint(x: left, y: nearY)
        let nearRight = CGPoint(x: right, y: nearY)
        let farLeft = CGPoint(x: left + size.width * 0.12, y: farY)
        let farRight = CGPoint(x: right - size.width * 0.12, y: farY)

        addArenaBackdrop(size: size, farY: farY)
        addMat(nearLeft: nearLeft, nearRight: nearRight, farLeft: farLeft, farRight: farRight)
        addPostsAndRopes(nearLeft: nearLeft, nearRight: nearRight, farLeft: farLeft, farRight: farRight)
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

    private func addMat(nearLeft: CGPoint, nearRight: CGPoint, farLeft: CGPoint, farRight: CGPoint) {
        let mat = polygon([nearLeft, nearRight, farRight, farLeft])
        mat.fillColor = SKColor(red: 0.20, green: 0.25, blue: 0.29, alpha: 1)
        mat.strokeColor = SKColor(red: 0.48, green: 0.54, blue: 0.56, alpha: 1)
        mat.lineWidth = 3
        mat.zPosition = -2
        backgroundLayer.addChild(mat)

        let centerMark = polygon([
            CGPoint(x: (nearLeft.x + nearRight.x) / 2 - 45, y: nearLeft.y + 35),
            CGPoint(x: (nearLeft.x + nearRight.x) / 2 + 45, y: nearLeft.y + 35),
            CGPoint(x: (farLeft.x + farRight.x) / 2 + 27, y: farLeft.y - 35),
            CGPoint(x: (farLeft.x + farRight.x) / 2 - 27, y: farLeft.y - 35)
        ])
        centerMark.fillColor = SKColor.white.withAlphaComponent(0.045)
        centerMark.strokeColor = .clear
        centerMark.zPosition = -1
        backgroundLayer.addChild(centerMark)

        let apronDepth: CGFloat = 20
        let apron = polygon([
            CGPoint(x: nearLeft.x, y: nearLeft.y),
            CGPoint(x: nearRight.x, y: nearRight.y),
            CGPoint(x: nearRight.x - 8, y: nearRight.y - apronDepth),
            CGPoint(x: nearLeft.x + 8, y: nearLeft.y - apronDepth)
        ])
        apron.fillColor = SKColor(red: 0.08, green: 0.11, blue: 0.14, alpha: 1)
        apron.strokeColor = .black.withAlphaComponent(0.6)
        apron.lineWidth = 2
        apron.zPosition = 25
        foregroundLayer.addChild(apron)
    }

    private func addPostsAndRopes(nearLeft: CGPoint, nearRight: CGPoint, farLeft: CGPoint, farRight: CGPoint) {
        let ropeColors: [SKColor] = [
            SKColor(red: 0.82, green: 0.12, blue: 0.10, alpha: 1),
            SKColor.white.withAlphaComponent(0.92),
            SKColor(red: 0.15, green: 0.31, blue: 0.72, alpha: 1)
        ]

        for level in 0..<3 {
            let rise = CGFloat(38 + level * 28)
            let backLeft = CGPoint(x: farLeft.x, y: farLeft.y + rise)
            let backRight = CGPoint(x: farRight.x, y: farRight.y + rise)
            addLine(from: backLeft, to: backRight, color: ropeColors[level], width: 4, to: backgroundLayer, z: 2)

            let frontLeft = CGPoint(x: nearLeft.x, y: nearLeft.y + rise)
            let frontRight = CGPoint(x: nearRight.x, y: nearRight.y + rise)
            addLine(from: frontLeft, to: frontRight, color: ropeColors[level], width: 5, to: foregroundLayer, z: 32)
            addLine(from: frontLeft, to: backLeft, color: ropeColors[level].withAlphaComponent(0.80), width: 4, to: foregroundLayer, z: 31)
            addLine(from: frontRight, to: backRight, color: ropeColors[level].withAlphaComponent(0.80), width: 4, to: foregroundLayer, z: 31)
        }

        addPost(at: farLeft, color: .systemRed, to: backgroundLayer, z: 3)
        addPost(at: farRight, color: .systemBlue, to: backgroundLayer, z: 3)
        addPost(at: nearLeft, color: .systemBlue, to: foregroundLayer, z: 34)
        addPost(at: nearRight, color: .systemRed, to: foregroundLayer, z: 34)
    }

    private func addPost(at point: CGPoint, color: SKColor, to layer: SKNode, z: CGFloat) {
        let post = SKShapeNode(rectOf: CGSize(width: 12, height: 112), cornerRadius: 2)
        post.position = CGPoint(x: point.x, y: point.y + 55)
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
