import SpriteKit

final class FighterNode: SKNode {
    private static let skinColor = SKColor(red: 0.73, green: 0.47, blue: 0.30, alpha: 1)
    private struct Pose {
        var bodyX: CGFloat = 0
        var bodyRotation: CGFloat = 0
        var frontUpper: CGFloat
        var frontLower: CGFloat
        var backUpper: CGFloat
        var backLower: CGFloat
        var frontLeg: CGFloat
        var backLeg: CGFloat

        static let guardPose = Pose(
            frontUpper: 0.90, frontLower: 2.45,
            backUpper: 0.45, backLower: 2.60,
            frontLeg: -0.18, backLeg: 0.30
        )

        static let leadWindUp = Pose(
            bodyX: -5, bodyRotation: -0.08,
            frontUpper: 0.42, frontLower: 2.58,
            backUpper: 0.45, backLower: 2.60,
            frontLeg: -0.24, backLeg: 0.38
        )

        static let leadPunch = Pose(
            bodyX: 12, bodyRotation: 0.09,
            frontUpper: 1.48, frontLower: 0.02,
            backUpper: 0.45, backLower: 2.60,
            frontLeg: -0.10, backLeg: 0.42
        )

        static let rearWindUp = Pose(
            bodyX: -8, bodyRotation: -0.18,
            frontUpper: 0.90, frontLower: 2.45,
            backUpper: -0.18, backLower: 2.82,
            frontLeg: -0.26, backLeg: 0.42
        )

        static let rearPunch = Pose(
            bodyX: 16, bodyRotation: 0.16,
            frontUpper: 0.72, frontLower: 2.58,
            backUpper: 1.52, backLower: 0.04,
            frontLeg: -0.08, backLeg: 0.48
        )

        static let swayBack = Pose(
            bodyX: -28, bodyRotation: -0.28,
            frontUpper: 0.78, frontLower: 2.52,
            backUpper: 0.35, backLower: 2.72,
            frontLeg: -0.34, backLeg: 0.48
        )

        static let swayLeft = Pose(
            bodyX: -18, bodyRotation: 0.34,
            frontUpper: 0.82, frontLower: 2.52,
            backUpper: 0.38, backLower: 2.68,
            frontLeg: -0.30, backLeg: 0.42
        )

        static let swayRight = Pose(
            bodyX: 18, bodyRotation: -0.38,
            frontUpper: 0.78, frontLower: 2.62,
            backUpper: 0.42, backLower: 2.55,
            frontLeg: -0.08, backLeg: 0.30
        )
    }

    private var facing: CGFloat
    private let lineColor: SKColor
    private let animationRoot = SKNode()
    private let body = SKNode()
    private var torso = SKShapeNode()
    private var chestFacet = SKShapeNode()
    private var faceFacet = SKShapeNode()
    private let frontUpperArm: SKNode
    private let frontLowerArm: SKNode
    private let backUpperArm: SKNode
    private let backLowerArm: SKNode
    private let frontLeg: SKNode
    private let backLeg: SKNode
    private let head: SKShapeNode
    private var activePunchHand: PunchHand = .lead
    private var activeSwayDirection: SwayDirection = .back

    init(facingRight: Bool, color: SKColor) {
        facing = facingRight ? 1 : -1
        lineColor = color
        frontUpperArm = Self.makeLimb(length: 39, width: 11, color: Self.skinColor)
        frontLowerArm = Self.makeLimb(length: 37, width: 10, color: Self.skinColor)
        backUpperArm = Self.makeLimb(length: 37, width: 10, color: Self.skinColor.withAlphaComponent(0.82))
        backLowerArm = Self.makeLimb(length: 35, width: 9, color: Self.skinColor.withAlphaComponent(0.82))
        frontLeg = Self.makeLimb(length: 58, width: 13, color: Self.skinColor)
        backLeg = Self.makeLimb(length: 58, width: 12, color: Self.skinColor.withAlphaComponent(0.82))
        head = Self.makePolygon(Self.regularPolygon(radius: 19, sides: 7, startAngle: .pi / 2))
        super.init()
        buildRig()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { nil }

    func show(phase: FighterPhase) {
        switch phase {
        case .idle:
            transition(to: .guardPose, duration: CombatTuning.idleReturnDuration)
        case .punchStartup:
            let pose: Pose = activePunchHand == .lead ? .leadWindUp : .rearWindUp
            transition(to: pose, duration: CombatTuning.punchStartup * 0.88)
        case .punchActive:
            let pose: Pose = activePunchHand == .lead ? .leadPunch : .rearPunch
            transition(to: pose, duration: CombatTuning.punchActive * 0.55)
        case .punchRecovery:
            transition(to: .guardPose, duration: CombatTuning.punchRecovery * 0.78)
        case .swaying:
            let pose: Pose
            switch activeSwayDirection {
            case .left: pose = .swayLeft
            case .right: pose = .swayRight
            case .back: pose = .swayBack
            }
            transition(to: pose, duration: CombatTuning.swayDuration * 0.32)
        case .hit:
            break
        case .knockedOut:
            playKnockout()
        }
    }

    func preparePunch(_ hand: PunchHand) {
        activePunchHand = hand
    }

    func prepareSway(_ direction: SwayDirection) {
        guard facing < 0 else {
            activeSwayDirection = direction
            return
        }
        switch direction {
        case .left: activeSwayDirection = .right
        case .right: activeSwayDirection = .left
        case .back: activeSwayDirection = .back
        }
    }

    func orient(toward direction: CGVector) {
        let length = hypot(direction.dx, direction.dy)
        guard length > 0.001 else { return }

        let normalizedX = direction.dx / length
        let normalizedY = direction.dy / length
        // Keep the last side while nearly head-on. This prevents rapid mirror
        // popping when the fighters cross the same horizontal line.
        if abs(normalizedX) > 0.18 {
            facing = normalizedX > 0 ? 1 : -1
        }
        let sideAmount = abs(normalizedX)
        let depthAmount = abs(normalizedY)
        let facingCameraAmount = max(-normalizedY, 0)
        let facingAwayAmount = max(normalizedY, 0)
        let widthScale = 0.72 + sideAmount * 0.28

        animationRoot.xScale = facing * widthScale
        animationRoot.yScale = 1 + depthAmount * 0.04

        // A side-on boxer has overlapping shoulders and feet. As the opponent
        // moves into depth, spread the stance and swap limb depth to sell yaw.
        let shoulderSpread = depthAmount * 10
        frontUpperArm.position.x = shoulderSpread
        backUpperArm.position.x = -shoulderSpread
        frontLeg.position.x = 5 + depthAmount * 5
        backLeg.position.x = -5 - depthAmount * 5

        if normalizedY < 0 {
            frontUpperArm.zPosition = 4
            backUpperArm.zPosition = 1
            frontLeg.zPosition = 2
            backLeg.zPosition = -1
        } else {
            frontUpperArm.zPosition = 1
            backUpperArm.zPosition = -3
            frontLeg.zPosition = 0
            backLeg.zPosition = -2
        }

        torso.fillColor = lineColor.withAlphaComponent(
            0.70 + facingCameraAmount * 0.18 - facingAwayAmount * 0.08
        )
        chestFacet.alpha = 0.18 + facingCameraAmount * 0.82
        faceFacet.alpha = 0.22 + facingCameraAmount * 0.78
    }

    func setMoving(_ isMoving: Bool) {
        animationRoot.speed = isMoving ? 1.7 : 1
    }

    func playHit(_ kind: HitKind) {
        let distance = kind == .counter ? CombatTuning.counterKnockback : CombatTuning.normalKnockback
        let duration = kind == .counter ? CombatTuning.counterHitReaction : CombatTuning.hitReaction
        body.removeAction(forKey: "pose")
        let recoil = SKAction.group([
            .moveTo(x: -distance, duration: duration * 0.22),
            .rotate(toAngle: -0.22, duration: duration * 0.22, shortestUnitArc: true)
        ])
        recoil.timingMode = .easeOut
        let recover = SKAction.group([
            .moveTo(x: 0, duration: duration * 0.70),
            .rotate(toAngle: 0, duration: duration * 0.70, shortestUnitArc: true)
        ])
        recover.timingMode = .easeInEaseOut
        body.run(.sequence([recoil, recover]), withKey: "pose")
    }

    func resetPose() {
        removeAllActions()
        body.removeAllActions()
        animationRoot.position = .zero
        body.position = .zero
        body.zRotation = 0
        body.alpha = 1
        body.setScale(1)
        zRotation = 0
        transition(to: .guardPose, duration: CombatTuning.poseResetDuration)
        startIdleMotion()
    }

    private func buildRig() {
        addChild(animationRoot)
        animationRoot.xScale = facing
        animationRoot.addChild(body)

        torso = Self.makePolygon([
            CGPoint(x: -13, y: 20), CGPoint(x: 13, y: 20),
            CGPoint(x: 18, y: 78), CGPoint(x: -15, y: 82)
        ])
        torso.fillColor = lineColor.withAlphaComponent(0.88)
        torso.strokeColor = .black.withAlphaComponent(0.72)
        torso.lineWidth = 2
        body.addChild(torso)

        chestFacet = Self.makePolygon([
            CGPoint(x: -13, y: 22), CGPoint(x: 13, y: 22), CGPoint(x: 17, y: 78), CGPoint(x: 1, y: 62)
        ])
        chestFacet.fillColor = lineColor.withAlphaComponent(0.45)
        chestFacet.strokeColor = .clear
        chestFacet.zPosition = 0.5
        body.addChild(chestFacet)

        let shorts = Self.makePolygon([
            CGPoint(x: -18, y: 14), CGPoint(x: 18, y: 14),
            CGPoint(x: 14, y: 37), CGPoint(x: -14, y: 37)
        ])
        shorts.fillColor = lineColor
        shorts.strokeColor = .black.withAlphaComponent(0.75)
        shorts.lineWidth = 2
        shorts.zPosition = 3
        body.addChild(shorts)

        head.position = CGPoint(x: 0, y: 108)
        head.fillColor = Self.skinColor
        head.strokeColor = .black.withAlphaComponent(0.75)
        head.lineWidth = 2
        body.addChild(head)

        faceFacet = Self.makePolygon([
            CGPoint(x: 0, y: 91), CGPoint(x: 17, y: 105), CGPoint(x: 2, y: 123)
        ])
        faceFacet.fillColor = Self.skinColor.withAlphaComponent(0.48)
        faceFacet.strokeColor = .clear
        faceFacet.zPosition = 1
        body.addChild(faceFacet)

        attachArm(backUpperArm, lower: backLowerArm, z: -2)
        attachArm(frontUpperArm, lower: frontLowerArm, z: 2)
        addGlove(to: backLowerArm, alpha: 0.78)
        addGlove(to: frontLowerArm, alpha: 1)
        attachLeg(backLeg, x: -5, z: -2)
        attachLeg(frontLeg, x: 5, z: 1)
        addShoe(to: backLeg, alpha: 0.78)
        addShoe(to: frontLeg, alpha: 1)
        apply(.guardPose)
        startIdleMotion()
    }

    private func attachArm(_ upper: SKNode, lower: SKNode, z: CGFloat) {
        upper.position = CGPoint(x: 0, y: 78)
        upper.zPosition = z
        lower.position = CGPoint(x: 0, y: -39)
        upper.addChild(lower)
        body.addChild(upper)
    }

    private func attachLeg(_ leg: SKNode, x: CGFloat, z: CGFloat) {
        leg.position = CGPoint(x: x, y: 24)
        leg.zPosition = z
        body.addChild(leg)
    }

    private func addGlove(to lowerArm: SKNode, alpha: CGFloat) {
        let glove = Self.makePolygon(Self.regularPolygon(radius: 10, sides: 6, startAngle: 0))
        glove.position = CGPoint(x: 0, y: -35)
        glove.fillColor = lineColor.withAlphaComponent(alpha)
        glove.strokeColor = .black.withAlphaComponent(0.75)
        glove.lineWidth = 2
        glove.zPosition = 4
        lowerArm.addChild(glove)
    }

    private func addShoe(to leg: SKNode, alpha: CGFloat) {
        let shoe = Self.makePolygon([
            CGPoint(x: -6, y: -54), CGPoint(x: 16, y: -58),
            CGPoint(x: 18, y: -50), CGPoint(x: -5, y: -46)
        ])
        shoe.fillColor = lineColor.withAlphaComponent(alpha)
        shoe.strokeColor = .black.withAlphaComponent(0.75)
        shoe.lineWidth = 2
        leg.addChild(shoe)
    }

    private func startIdleMotion() {
        let up = SKAction.moveTo(y: 3, duration: CombatTuning.idleMotionHalfCycle)
        up.timingMode = .easeInEaseOut
        let down = SKAction.moveTo(y: -2, duration: CombatTuning.idleMotionHalfCycle)
        down.timingMode = .easeInEaseOut
        animationRoot.run(.repeatForever(.sequence([up, down])), withKey: "idle")
    }

    private func transition(to pose: Pose, duration: TimeInterval) {
        let actions: [(SKNode, CGFloat)] = [
            (frontUpperArm, pose.frontUpper), (frontLowerArm, pose.frontLower),
            (backUpperArm, pose.backUpper), (backLowerArm, pose.backLower),
            (frontLeg, pose.frontLeg), (backLeg, pose.backLeg)
        ]
        let rotations = actions.map { node, angle in
            SKAction.run { node.run(.rotate(toAngle: angle, duration: duration, shortestUnitArc: true)) }
        }
        let bodyMove = SKAction.group([
            .moveTo(x: pose.bodyX, duration: duration),
            .rotate(toAngle: pose.bodyRotation, duration: duration, shortestUnitArc: true)
        ])
        bodyMove.timingMode = .easeInEaseOut
        body.run(bodyMove, withKey: "pose")
        run(.group(rotations))
    }

    private func apply(_ pose: Pose) {
        body.position.x = pose.bodyX
        body.zRotation = pose.bodyRotation
        frontUpperArm.zRotation = pose.frontUpper
        frontLowerArm.zRotation = pose.frontLower
        backUpperArm.zRotation = pose.backUpper
        backLowerArm.zRotation = pose.backLower
        frontLeg.zRotation = pose.frontLeg
        backLeg.zRotation = pose.backLeg
    }

    private func playKnockout() {
        removeAllActions()
        let fall = SKAction.group([
            .rotate(toAngle: -facing * 1.35, duration: CombatTuning.knockoutDuration, shortestUnitArc: true),
            .moveBy(x: -facing * 34, y: -28, duration: CombatTuning.knockoutDuration)
        ])
        fall.timingMode = .easeIn
        run(fall)
    }

    private static func makeLimb(length: CGFloat, width: CGFloat, color: SKColor) -> SKNode {
        let node = makePolygon([
            CGPoint(x: -width * 0.48, y: 1),
            CGPoint(x: width * 0.52, y: -2),
            CGPoint(x: width * 0.36, y: -length),
            CGPoint(x: -width * 0.34, y: -length + 2)
        ])
        node.fillColor = color
        node.strokeColor = .black.withAlphaComponent(0.68)
        node.lineWidth = 1.5
        return node
    }

    private static func regularPolygon(radius: CGFloat, sides: Int, startAngle: CGFloat) -> [CGPoint] {
        (0..<sides).map { index in
            let angle = startAngle + CGFloat(index) * 2 * .pi / CGFloat(sides)
            return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
        }
    }

    private static func makePolygon(_ points: [CGPoint]) -> SKShapeNode {
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
