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
        wall.fillColor = ArenaVisualPalette.void
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
        leftPanel.fillColor = ArenaVisualPalette.carbon
        leftPanel.strokeColor = .clear
        leftPanel.zPosition = -11
        backgroundLayer.addChild(leftPanel)

        let rightPanel = polygon([
            CGPoint(x: size.width * 0.48, y: wallBottom),
            CGPoint(x: size.width, y: wallBottom),
            CGPoint(x: size.width, y: size.height),
            CGPoint(x: size.width * 0.66, y: size.height)
        ])
        rightPanel.fillColor = SKColor(red: 0.065, green: 0.050, blue: 0.055, alpha: 1)
        rightPanel.strokeColor = .clear
        rightPanel.zPosition = -11
        backgroundLayer.addChild(rightPanel)

        for row in 0..<3 {
            let rowY = wallBottom + 17 + CGFloat(row) * 18
            let tier = SKShapeNode(rect: CGRect(x: 0, y: rowY - 6, width: size.width, height: 12))
            tier.fillColor = ArenaVisualPalette.gunmetal.withAlphaComponent(0.96)
            tier.strokeColor = SKColor.white.withAlphaComponent(0.06)
            tier.lineWidth = 1
            tier.zPosition = -9
            backgroundLayer.addChild(tier)

            let count = 12 + row * 2
            for index in 0..<count {
                let x = (CGFloat(index) + 0.5) * size.width / CGFloat(count)
                let bay = SKShapeNode(rectOf: CGSize(width: 18, height: 7), cornerRadius: 1.5)
                bay.position = CGPoint(x: x, y: rowY + 3)
                bay.fillColor = SKColor.black.withAlphaComponent(0.55)
                bay.strokeColor = (index + row).isMultiple(of: 3)
                    ? ArenaVisualPalette.cyanSignal.withAlphaComponent(0.34)
                    : SKColor.white.withAlphaComponent(0.08)
                bay.lineWidth = 0.7
                bay.zPosition = -8
                backgroundLayer.addChild(bay)

                let indicator = SKShapeNode(rectOf: CGSize(width: 7, height: 1.5), cornerRadius: 0.5)
                indicator.position = CGPoint(x: x, y: rowY + 3)
                indicator.fillColor = (index + row).isMultiple(of: 4)
                    ? ArenaVisualPalette.amberSignal.withAlphaComponent(0.72)
                    : ArenaVisualPalette.cyanSignal.withAlphaComponent(0.48)
                indicator.strokeColor = .clear
                indicator.glowWidth = 1
                indicator.zPosition = -7.8
                backgroundLayer.addChild(indicator)
            }
        }

        let leagueBanner = SKLabelNode(fontNamed: "Menlo-Bold")
        leagueBanner.text = "HC // MECHA COMBAT LEAGUE"
        leagueBanner.fontSize = 9
        leagueBanner.fontColor = ArenaVisualPalette.whiteMark.withAlphaComponent(0.62)
        leagueBanner.position = CGPoint(x: size.width / 2, y: wallBottom + 69)
        leagueBanner.zPosition = -6.5
        backgroundLayer.addChild(leagueBanner)

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
        mat.fillColor = SKColor(red: 0.075, green: 0.098, blue: 0.115, alpha: 1)
        mat.strokeColor = ArenaVisualPalette.raisedMetal
        mat.lineWidth = 3
        mat.zPosition = -2
        backgroundLayer.addChild(mat)

        // A soft inner edge keeps the canvas from reading as one flat panel.
        for edge in [(near, right), (right, far), (far, left), (left, near)] {
            addLine(
                from: edge.0,
                to: edge.1,
                color: SKColor.black.withAlphaComponent(0.16),
                width: 11,
                to: backgroundLayer,
                z: -1.75
            )
        }

        let center = CGPoint(
            x: (near.x + right.x + far.x + left.x) / 4,
            y: (near.y + right.y + far.y + left.y) / 4
        )
        let innerCanvas = polygon([near, right, far, left].map {
            CGPoint(x: center.x + ($0.x - center.x) * 0.88, y: center.y + ($0.y - center.y) * 0.88)
        })
        innerCanvas.fillColor = SKColor(red: 0.12, green: 0.145, blue: 0.16, alpha: 0.52)
        innerCanvas.strokeColor = ArenaVisualPalette.cyanSignal.withAlphaComponent(0.10)
        innerCanvas.lineWidth = 1
        innerCanvas.zPosition = -1.8
        backgroundLayer.addChild(innerCanvas)

        addDeckMaterial(near: near, right: right, far: far, left: left)

        // Canvas seams follow the same two axes as movement projection. This
        // makes depth readable while keeping the arena a lightweight 2D asset.
        for fraction in [CGFloat(0.25), 0.50, 0.75] {
            addLine(
                from: point(between: near, and: left, fraction: fraction),
                to: point(between: right, and: far, fraction: fraction),
                color: ArenaVisualPalette.cyanSignal.withAlphaComponent(0.055),
                width: 0.8,
                to: backgroundLayer,
                z: -1.5
            )
            addLine(
                from: point(between: near, and: right, fraction: fraction),
                to: point(between: left, and: far, fraction: fraction),
                color: ArenaVisualPalette.amberSignal.withAlphaComponent(0.045),
                width: 0.8,
                to: backgroundLayer,
                z: -1.5
            )
        }

        let centerMark = polygon([near, right, far, left].map {
            CGPoint(x: center.x + ($0.x - center.x) * 0.28, y: center.y + ($0.y - center.y) * 0.28)
        })
        centerMark.fillColor = ArenaVisualPalette.gunmetal.withAlphaComponent(0.22)
        centerMark.strokeColor = ArenaVisualPalette.whiteMark.withAlphaComponent(0.08)
        centerMark.lineWidth = 1
        centerMark.zPosition = -1
        backgroundLayer.addChild(centerMark)

        for scale in [CGFloat(0.18), 0.10] {
            let diamond = polygon([near, right, far, left].map {
                CGPoint(
                    x: center.x + ($0.x - center.x) * scale,
                    y: center.y + ($0.y - center.y) * scale
                )
            })
            diamond.fillColor = .clear
            diamond.strokeColor = (scale == 0.18
                ? ArenaVisualPalette.cyanSignal : ArenaVisualPalette.amberSignal)
                .withAlphaComponent(scale == 0.18 ? 0.12 : 0.15)
            diamond.lineWidth = scale == 0.18 ? 1.2 : 1.8
            diamond.zPosition = -0.8
            backgroundLayer.addChild(diamond)
        }

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
            ArenaVisualPalette.cyanSignal,
            ArenaVisualPalette.magentaSignal,
            ArenaVisualPalette.neonLime
        ]

        for level in 0..<3 {
            let rise = CGFloat(20 + level * 19)
            let nearRope = CGPoint(x: near.x, y: near.y + rise)
            let rightRope = CGPoint(x: right.x, y: right.y + rise)
            let farRope = CGPoint(x: far.x, y: far.y + rise)
            let leftRope = CGPoint(x: left.x, y: left.y + rise)
            let shadowOffset = CGVector(dx: 1.5, dy: -4)
            addLine(
                from: CGPoint(x: leftRope.x + shadowOffset.dx, y: leftRope.y + shadowOffset.dy),
                to: CGPoint(x: farRope.x + shadowOffset.dx, y: farRope.y + shadowOffset.dy),
                color: SKColor.black.withAlphaComponent(0.32),
                width: 6,
                to: backgroundLayer,
                z: 1.5
            )
            addLine(
                from: CGPoint(x: farRope.x + shadowOffset.dx, y: farRope.y + shadowOffset.dy),
                to: CGPoint(x: rightRope.x + shadowOffset.dx, y: rightRope.y + shadowOffset.dy),
                color: SKColor.black.withAlphaComponent(0.32),
                width: 6,
                to: backgroundLayer,
                z: 1.5
            )
            addLine(
                from: CGPoint(x: leftRope.x + shadowOffset.dx, y: leftRope.y + shadowOffset.dy),
                to: CGPoint(x: nearRope.x + shadowOffset.dx, y: nearRope.y + shadowOffset.dy),
                color: SKColor.black.withAlphaComponent(0.38),
                width: 5.5,
                to: foregroundLayer,
                z: 30.5
            )
            addLine(
                from: CGPoint(x: nearRope.x + shadowOffset.dx, y: nearRope.y + shadowOffset.dy),
                to: CGPoint(x: rightRope.x + shadowOffset.dx, y: rightRope.y + shadowOffset.dy),
                color: SKColor.black.withAlphaComponent(0.38),
                width: 5.5,
                to: foregroundLayer,
                z: 31.5
            )
            addLayeredRope(from: leftRope, to: farRope, color: ropeColors[level], width: 4, to: backgroundLayer, z: 2)
            addLayeredRope(from: farRope, to: rightRope, color: ropeColors[level], width: 4, to: backgroundLayer, z: 2)
            addLayeredRope(from: leftRope, to: nearRope, color: ropeColors[level], width: 3.5, to: foregroundLayer, z: 31)
            addLayeredRope(from: nearRope, to: rightRope, color: ropeColors[level], width: 3.5, to: foregroundLayer, z: 32)
        }

        addPost(at: far, color: ArenaVisualPalette.amberSignal, to: backgroundLayer, z: 3)
        addPost(at: left, color: ArenaVisualPalette.cyanSignal, to: foregroundLayer, z: 33)
        addPost(at: right, color: ArenaVisualPalette.cyanSignal, to: foregroundLayer, z: 33)
        addPost(at: near, color: ArenaVisualPalette.amberSignal, to: foregroundLayer, z: 34)
    }

    private func addLayeredRope(
        from start: CGPoint,
        to end: CGPoint,
        color: SKColor,
        width: CGFloat,
        to layer: SKNode,
        z: CGFloat
    ) {
        addLine(
            from: start,
            to: end,
            color: SKColor.black.withAlphaComponent(0.72),
            width: width + 2.8,
            to: layer,
            z: z
        )
        let glow = addLineNode(
            from: start,
            to: end,
            color: color.withAlphaComponent(0.70),
            width: width + 0.15,
            z: z + 0.08
        )
        glow.glowWidth = width * 0.48
        layer.addChild(glow)

        let dx = end.x - start.x
        let dy = end.y - start.y
        let length = max(hypot(dx, dy), 0.001)
        let normal = CGVector(dx: -dy / length, dy: dx / length)
        let highlightOffset = width * 0.14
        addLine(
            from: CGPoint(
                x: start.x + normal.dx * highlightOffset,
                y: start.y + normal.dy * highlightOffset
            ),
            to: CGPoint(
                x: end.x + normal.dx * highlightOffset,
                y: end.y + normal.dy * highlightOffset
            ),
            color: ArenaVisualPalette.whiteMark.withAlphaComponent(0.48),
            width: 0.64,
            to: layer,
            z: z + 0.14
        )
    }

    private func addApron(from start: CGPoint, to end: CGPoint, outward: CGVector) {
        let apron = polygon([
            start, end,
            CGPoint(x: end.x + outward.dx, y: end.y + outward.dy),
            CGPoint(x: start.x + outward.dx, y: start.y + outward.dy)
        ])
        apron.fillColor = ArenaVisualPalette.carbon
        apron.strokeColor = .black.withAlphaComponent(0.6)
        apron.lineWidth = 2
        apron.zPosition = 25
        foregroundLayer.addChild(apron)

        let signal = addLineNode(
            from: CGPoint(x: start.x + outward.dx * 0.45, y: start.y + outward.dy * 0.45),
            to: CGPoint(x: end.x + outward.dx * 0.45, y: end.y + outward.dy * 0.45),
            color: outward.dx < 0
                ? ArenaVisualPalette.amberSignal.withAlphaComponent(0.65)
                : ArenaVisualPalette.cyanSignal.withAlphaComponent(0.65),
            width: 1.5,
            z: 25.2
        )
        signal.glowWidth = 1.5
        foregroundLayer.addChild(signal)

        for fraction in [CGFloat(0.16), 0.34, 0.52, 0.70, 0.88] {
            let top = point(between: start, and: end, fraction: fraction)
            let bottom = CGPoint(x: top.x + outward.dx, y: top.y + outward.dy)
            addLine(
                from: top,
                to: bottom,
                color: ArenaVisualPalette.raisedMetal.withAlphaComponent(0.48),
                width: 0.8,
                to: foregroundLayer,
                z: 25.15
            )
            let bolt = SKShapeNode(circleOfRadius: 1.15)
            bolt.position = CGPoint(
                x: top.x + outward.dx * 0.78,
                y: top.y + outward.dy * 0.78
            )
            bolt.fillColor = ArenaVisualPalette.whiteMark.withAlphaComponent(0.44)
            bolt.strokeColor = SKColor.black.withAlphaComponent(0.65)
            bolt.lineWidth = 0.6
            bolt.zPosition = 25.3
            foregroundLayer.addChild(bolt)
        }
    }

    private func addDeckMaterial(
        near: CGPoint,
        right: CGPoint,
        far: CGPoint,
        left: CGPoint
    ) {
        let columns = 5
        let rows = 4
        let gap: CGFloat = 0.006
        for row in 0..<rows {
            for column in 0..<columns {
                let u0 = CGFloat(column) / CGFloat(columns) + gap
                let u1 = CGFloat(column + 1) / CGFloat(columns) - gap
                let v0 = CGFloat(row) / CGFloat(rows) + gap
                let v1 = CGFloat(row + 1) / CGFloat(rows) - gap
                let points = [
                    deckPoint(near: near, right: right, far: far, left: left, u: u0, v: v0),
                    deckPoint(near: near, right: right, far: far, left: left, u: u1, v: v0),
                    deckPoint(near: near, right: right, far: far, left: left, u: u1, v: v1),
                    deckPoint(near: near, right: right, far: far, left: left, u: u0, v: v1)
                ]
                let plate = polygon(points)
                plate.fillColor = (column + row).isMultiple(of: 2)
                    ? ArenaVisualPalette.raisedMetal.withAlphaComponent(0.12)
                    : ArenaVisualPalette.carbon.withAlphaComponent(0.16)
                plate.strokeColor = SKColor.black.withAlphaComponent(0.22)
                plate.lineWidth = 0.65
                plate.zPosition = -1.72
                backgroundLayer.addChild(plate)

                addLine(
                    from: points[3],
                    to: points[2],
                    color: ArenaVisualPalette.whiteMark.withAlphaComponent(0.055),
                    width: 0.7,
                    to: backgroundLayer,
                    z: -1.68
                )
            }
        }

        for row in 1..<rows {
            for column in 1..<columns {
                let point = deckPoint(
                    near: near,
                    right: right,
                    far: far,
                    left: left,
                    u: CGFloat(column) / CGFloat(columns),
                    v: CGFloat(row) / CGFloat(rows)
                )
                let housing = SKShapeNode(circleOfRadius: 1.8)
                housing.position = point
                housing.fillColor = SKColor.black.withAlphaComponent(0.58)
                housing.strokeColor = ArenaVisualPalette.raisedMetal.withAlphaComponent(0.54)
                housing.lineWidth = 0.7
                housing.zPosition = -1.25
                backgroundLayer.addChild(housing)

                let specular = SKShapeNode(circleOfRadius: 0.48)
                specular.position = CGPoint(x: point.x - 0.45, y: point.y + 0.45)
                specular.fillColor = ArenaVisualPalette.whiteMark.withAlphaComponent(0.55)
                specular.strokeColor = .clear
                specular.zPosition = -1.2
                backgroundLayer.addChild(specular)
            }
        }

        let scratches: [(CGFloat, CGFloat, CGFloat, CGFloat)] = [
            (0.13, 0.23, 13, 2), (0.29, 0.67, -11, 3),
            (0.44, 0.31, 17, -2), (0.58, 0.78, 9, 3),
            (0.72, 0.18, -14, 2), (0.84, 0.56, 12, -3),
            (0.37, 0.88, -8, 2), (0.66, 0.43, 15, 1)
        ]
        for scratch in scratches {
            let start = deckPoint(
                near: near,
                right: right,
                far: far,
                left: left,
                u: scratch.0,
                v: scratch.1
            )
            addLine(
                from: start,
                to: CGPoint(x: start.x + scratch.2, y: start.y + scratch.3),
                color: ArenaVisualPalette.whiteMark.withAlphaComponent(0.10),
                width: 0.65,
                to: backgroundLayer,
                z: -1.1
            )
        }
    }

    private func deckPoint(
        near: CGPoint,
        right: CGPoint,
        far: CGPoint,
        left: CGPoint,
        u: CGFloat,
        v: CGFloat
    ) -> CGPoint {
        let nearEdge = point(between: near, and: right, fraction: u)
        let farEdge = point(between: left, and: far, fraction: u)
        return point(between: nearEdge, and: farEdge, fraction: v)
    }

    private func addPost(at point: CGPoint, color: SKColor, to layer: SKNode, z: CGFloat) {
        let postShadow = SKShapeNode(rectOf: CGSize(width: 15, height: 82), cornerRadius: 3)
        postShadow.position = CGPoint(x: point.x + 2, y: point.y + 36)
        postShadow.fillColor = SKColor.black.withAlphaComponent(0.72)
        postShadow.strokeColor = .clear
        postShadow.zPosition = z - 0.2
        layer.addChild(postShadow)

        let post = SKShapeNode(rectOf: CGSize(width: 12, height: 78), cornerRadius: 2)
        post.position = CGPoint(x: point.x, y: point.y + 38)
        post.fillColor = ArenaVisualPalette.carbon
        post.strokeColor = ArenaVisualPalette.raisedMetal.withAlphaComponent(0.82)
        post.lineWidth = 1.5
        post.zPosition = z
        layer.addChild(post)

        for yOffset in stride(from: CGFloat(9), through: 67, by: 14.5) {
            let panel = SKShapeNode(rectOf: CGSize(width: 8, height: 10), cornerRadius: 1)
            panel.position = CGPoint(x: point.x, y: point.y + yOffset)
            panel.fillColor = ArenaVisualPalette.gunmetal.withAlphaComponent(0.96)
            panel.strokeColor = SKColor.white.withAlphaComponent(0.08)
            panel.lineWidth = 0.6
            panel.zPosition = z + 0.05
            layer.addChild(panel)
        }

        let edgeHighlight = SKShapeNode(rectOf: CGSize(width: 1.1, height: 70), cornerRadius: 0.5)
        edgeHighlight.position = CGPoint(x: point.x - 4.2, y: point.y + 39)
        edgeHighlight.fillColor = ArenaVisualPalette.whiteMark.withAlphaComponent(0.20)
        edgeHighlight.strokeColor = .clear
        edgeHighlight.zPosition = z + 0.1
        layer.addChild(edgeHighlight)

        let postSignal = SKShapeNode(rectOf: CGSize(width: 1.7, height: 58), cornerRadius: 0.8)
        postSignal.position = CGPoint(x: point.x + 3.7, y: point.y + 37)
        postSignal.fillColor = color.withAlphaComponent(0.66)
        postSignal.strokeColor = .clear
        postSignal.glowWidth = 0.45
        postSignal.zPosition = z + 0.12
        layer.addChild(postSignal)

        for yOffset in [CGFloat(4), 76] {
            let collar = SKShapeNode(rectOf: CGSize(width: 17, height: 7), cornerRadius: 1.5)
            collar.position = CGPoint(x: point.x, y: point.y + yOffset)
            collar.fillColor = ArenaVisualPalette.raisedMetal
            collar.strokeColor = SKColor.black.withAlphaComponent(0.72)
            collar.lineWidth = 1
            collar.zPosition = z + 0.16
            layer.addChild(collar)
        }

        let pad = SKShapeNode(rectOf: CGSize(width: 18, height: 30), cornerRadius: 4)
        pad.position = CGPoint(x: point.x, y: point.y + 55)
        pad.fillColor = ArenaVisualPalette.carbon
        pad.strokeColor = color.withAlphaComponent(0.72)
        pad.lineWidth = 1.5
        pad.zPosition = z + 0.2
        layer.addChild(pad)

        let padHighlight = SKShapeNode(rectOf: CGSize(width: 10, height: 18), cornerRadius: 2)
        padHighlight.position = CGPoint(x: point.x, y: point.y + 55)
        padHighlight.fillColor = ArenaVisualPalette.gunmetal
        padHighlight.strokeColor = ArenaVisualPalette.whiteMark.withAlphaComponent(0.14)
        padHighlight.lineWidth = 0.7
        padHighlight.zPosition = z + 0.3
        layer.addChild(padHighlight)

        let padSignal = SKShapeNode(rectOf: CGSize(width: 6.5, height: 1.6), cornerRadius: 0.7)
        padSignal.position = CGPoint(x: point.x, y: point.y + 55)
        padSignal.fillColor = color.withAlphaComponent(0.82)
        padSignal.strokeColor = .clear
        padSignal.glowWidth = 0.5
        padSignal.zPosition = z + 0.4
        layer.addChild(padSignal)
    }

    private func addLine(from start: CGPoint, to end: CGPoint, color: SKColor, width: CGFloat, to layer: SKNode, z: CGFloat) {
        let line = addLineNode(from: start, to: end, color: color, width: width, z: z)
        layer.addChild(line)
    }

    private func addLineNode(
        from start: CGPoint,
        to end: CGPoint,
        color: SKColor,
        width: CGFloat,
        z: CGFloat
    ) -> SKShapeNode {
        let line = SKShapeNode()
        let path = CGMutablePath()
        path.move(to: start)
        path.addLine(to: end)
        line.path = path
        line.strokeColor = color
        line.lineWidth = width
        line.zPosition = z
        return line
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
