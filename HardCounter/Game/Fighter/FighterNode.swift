import SpriteKit

final class FighterNode: SKNode {
    private static let skinColor = SKColor(red: 0.73, green: 0.47, blue: 0.30, alpha: 1)
    private struct Pose {
        var bodyX: CGFloat = 0
        var bodyY: CGFloat = 0
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
            bodyX: -20, bodyRotation: -0.20,
            frontUpper: 0.82, frontLower: 2.50,
            backUpper: 0.39, backLower: 2.66,
            frontLeg: -0.26, backLeg: 0.39
        )

        static let swayLeft = Pose(
            bodyX: -12, bodyRotation: 0.24,
            frontUpper: 0.84, frontLower: 2.50,
            backUpper: 0.40, backLower: 2.64,
            frontLeg: -0.23, backLeg: 0.37
        )

        static let swayRight = Pose(
            bodyX: 12, bodyRotation: -0.26,
            frontUpper: 0.82, frontLower: 2.56,
            backUpper: 0.43, backLower: 2.57,
            frontLeg: -0.12, backLeg: 0.32
        )

        static let swayForward = Pose(
            bodyX: 8, bodyRotation: 0.08,
            frontUpper: 0.80, frontLower: 2.52,
            backUpper: 0.38, backLower: 2.66,
            frontLeg: -0.12, backLeg: 0.38
        )
    }

    private var facing: CGFloat
    private let lineColor: SKColor
    private let animationRoot = SKNode()
    private let locomotionRoot = SKNode()
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
    private let frontLegAnchor = SKNode()
    private let backLegAnchor = SKNode()
    private let headAnchor = SKNode()
    private let head: SKShapeNode
    private var activePunchHand: PunchHand = .lead
    private var activePunchProfile = PunchProfile()
    private var activeSwayDirection: SwayDirection = .back
    private var locomotionClock: TimeInterval = 0
    private var gaitPhase: CGFloat = 0
    private var displayedMoveIntensity: CGFloat = 0
    private var lastMoveDirection = CGVector(dx: 1, dy: 0)

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
            transition(
                to: punchPose(isActive: false),
                duration: CombatTuning.punchStartup * activePunchProfile.startupScale * 0.82
            )
        case .punchActive:
            let snapScale: Double = activePunchProfile.motion == .counter ? 0.38 : 0.52
            transition(to: punchPose(isActive: true), duration: CombatTuning.punchActive * snapScale)
        case .punchRecovery:
            transition(
                to: .guardPose,
                duration: CombatTuning.punchRecovery * activePunchProfile.recoveryScale * 0.72
            )
        case .swaying:
            let pose: Pose
            switch activeSwayDirection {
            case .left: pose = .swayLeft
            case .right: pose = .swayRight
            case .back: pose = .swayBack
            case .forward: pose = .swayForward
            }
            transition(to: pose, duration: CombatTuning.swayDuration * 0.46)
        case .hit:
            break
        case .knockedOut:
            playKnockout()
        }
    }

    func preparePunch(_ hand: PunchHand, profile: PunchProfile) {
        activePunchHand = hand
        activePunchProfile = profile
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
        case .forward: activeSwayDirection = .forward
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
        frontLegAnchor.position.x = 5 + depthAmount * 5
        backLegAnchor.position.x = -5 - depthAmount * 5

        if normalizedY < 0 {
            frontUpperArm.zPosition = 4
            backUpperArm.zPosition = 1
            frontLegAnchor.zPosition = 2
            backLegAnchor.zPosition = -1
        } else {
            frontUpperArm.zPosition = 1
            backUpperArm.zPosition = -3
            frontLegAnchor.zPosition = 0
            backLegAnchor.zPosition = -2
        }

        torso.fillColor = lineColor.withAlphaComponent(
            0.70 + facingCameraAmount * 0.18 - facingAwayAmount * 0.08
        )
        chestFacet.alpha = 0.18 + facingCameraAmount * 0.82
        faceFacet.alpha = 0.22 + facingCameraAmount * 0.78
    }

    func updateLocomotion(movement: CGVector, deltaTime: TimeInterval) {
        guard deltaTime > 0 else { return }

        locomotionClock += deltaTime
        let targetIntensity = min(hypot(movement.dx, movement.dy), 1)
        let visualResponse: CGFloat = targetIntensity > displayedMoveIntensity ? 7.5 : 9.5
        let blend = 1 - CGFloat(exp(-Double(visualResponse) * deltaTime))
        displayedMoveIntensity += (targetIntensity - displayedMoveIntensity) * blend

        if targetIntensity > 0.025 {
            lastMoveDirection = CGVector(
                dx: movement.dx / targetIntensity,
                dy: movement.dy / targetIntensity
            )
        }

        if displayedMoveIntensity > 0.015 {
            gaitPhase += CGFloat(deltaTime) * (4.4 + displayedMoveIntensity * 2.6)
        }

        let localDirectionX = lastMoveDirection.dx * facing
        let step = sin(gaitPhase)
        let stepLift = abs(sin(gaitPhase * 2))
        let stride = displayedMoveIntensity * (0.11 + abs(lastMoveDirection.dy) * 0.04)

        frontLegAnchor.zRotation = step * stride
        backLegAnchor.zRotation = -step * stride
        let plantedLegY = 24 - body.position.y
        frontLegAnchor.position.y = plantedLegY + max(-step, 0) * displayedMoveIntensity * 2.5
        backLegAnchor.position.y = plantedLegY + max(step, 0) * displayedMoveIntensity * 2.5

        let idleAmount = 1 - displayedMoveIntensity
        let idleBob = sin(CGFloat(locomotionClock) * 5.1) * 1.4 * idleAmount
        let movingBob = stepLift * 1.20 * displayedMoveIntensity
        locomotionRoot.position = CGPoint(
            x: localDirectionX * displayedMoveIntensity * 1.8,
            y: idleBob + movingBob
        )
        locomotionRoot.zRotation = -localDirectionX * displayedMoveIntensity * 0.028
        // The chin stays more stable than the rotating shoulders, which keeps
        // the guard readable during punches and changes of direction.
        headAnchor.zRotation = -body.zRotation * 0.38
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
            .move(to: .zero, duration: duration * 0.70),
            .rotate(toAngle: 0, duration: duration * 0.70, shortestUnitArc: true)
        ])
        recover.timingMode = .easeInEaseOut
        body.run(.sequence([recoil, recover]), withKey: "pose")
    }

    func resetPose() {
        removeAllActions()
        locomotionRoot.removeAllActions()
        body.removeAllActions()
        animationRoot.position = .zero
        locomotionRoot.position = .zero
        locomotionRoot.zRotation = 0
        headAnchor.zRotation = 0
        body.position = .zero
        body.zRotation = 0
        body.alpha = 1
        body.setScale(1)
        frontLegAnchor.zRotation = 0
        backLegAnchor.zRotation = 0
        frontLegAnchor.position.y = 24
        backLegAnchor.position.y = 24
        displayedMoveIntensity = 0
        gaitPhase = 0
        zRotation = 0
        transition(to: .guardPose, duration: CombatTuning.poseResetDuration)
    }

    private func buildRig() {
        addChild(animationRoot)
        animationRoot.xScale = facing
        animationRoot.addChild(locomotionRoot)
        locomotionRoot.addChild(body)

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

        let neck = Self.makePolygon([
            CGPoint(x: -6, y: 77), CGPoint(x: 6, y: 77),
            CGPoint(x: 7, y: 96), CGPoint(x: -6, y: 95)
        ])
        neck.fillColor = Self.skinColor.withAlphaComponent(0.88)
        neck.strokeColor = .black.withAlphaComponent(0.62)
        neck.lineWidth = 1.5
        neck.zPosition = -0.5
        body.addChild(neck)

        let shoulderFacet = Self.makePolygon([
            CGPoint(x: -16, y: 72), CGPoint(x: 17, y: 71),
            CGPoint(x: 15, y: 82), CGPoint(x: -14, y: 84)
        ])
        shoulderFacet.fillColor = lineColor.withAlphaComponent(0.74)
        shoulderFacet.strokeColor = .clear
        shoulderFacet.zPosition = 0.7
        body.addChild(shoulderFacet)

        let shorts = Self.makePolygon([
            CGPoint(x: -18, y: 14), CGPoint(x: 18, y: 14),
            CGPoint(x: 14, y: 37), CGPoint(x: -14, y: 37)
        ])
        shorts.fillColor = lineColor
        shorts.strokeColor = .black.withAlphaComponent(0.75)
        shorts.lineWidth = 2
        shorts.zPosition = 3
        body.addChild(shorts)

        headAnchor.position = CGPoint(x: 0, y: 108)
        headAnchor.zPosition = 1
        head.position = .zero
        head.fillColor = Self.skinColor
        head.strokeColor = .black.withAlphaComponent(0.75)
        head.lineWidth = 2
        headAnchor.addChild(head)
        body.addChild(headAnchor)

        faceFacet = Self.makePolygon([
            CGPoint(x: 0, y: -17), CGPoint(x: 17, y: -3), CGPoint(x: 2, y: 15)
        ])
        faceFacet.fillColor = Self.skinColor.withAlphaComponent(0.48)
        faceFacet.strokeColor = .clear
        faceFacet.zPosition = 1
        headAnchor.addChild(faceFacet)

        attachArm(backUpperArm, lower: backLowerArm, z: -2)
        attachArm(frontUpperArm, lower: frontLowerArm, z: 2)
        addGlove(to: backLowerArm, alpha: 0.78)
        addGlove(to: frontLowerArm, alpha: 1)
        attachLeg(backLeg, to: backLegAnchor, x: -5, z: -2)
        attachLeg(frontLeg, to: frontLegAnchor, x: 5, z: 1)
        addShoe(to: backLeg, alpha: 0.78)
        addShoe(to: frontLeg, alpha: 1)
        apply(.guardPose)
    }

    private func attachArm(_ upper: SKNode, lower: SKNode, z: CGFloat) {
        upper.position = CGPoint(x: 0, y: 78)
        upper.zPosition = z
        lower.position = CGPoint(x: 0, y: -39)
        upper.addChild(lower)
        body.addChild(upper)
    }

    private func attachLeg(_ leg: SKNode, to anchor: SKNode, x: CGFloat, z: CGFloat) {
        anchor.position = CGPoint(x: x, y: 24)
        anchor.zPosition = z
        leg.position = .zero
        anchor.addChild(leg)
        body.addChild(anchor)
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

    private func transition(to pose: Pose, duration: TimeInterval) {
        let actions: [(SKNode, CGFloat)] = [
            (frontUpperArm, pose.frontUpper), (frontLowerArm, pose.frontLower),
            (backUpperArm, pose.backUpper), (backLowerArm, pose.backLower),
            (frontLeg, pose.frontLeg), (backLeg, pose.backLeg)
        ]
        for (node, angle) in actions {
            let rotation = SKAction.rotate(toAngle: angle, duration: duration, shortestUnitArc: true)
            rotation.timingMode = .easeInEaseOut
            node.run(rotation, withKey: "poseRotation")
        }
        let bodyMove = SKAction.group([
            .move(to: CGPoint(x: pose.bodyX, y: pose.bodyY), duration: duration),
            .rotate(toAngle: pose.bodyRotation, duration: duration, shortestUnitArc: true)
        ])
        bodyMove.timingMode = .easeInEaseOut
        body.run(bodyMove, withKey: "pose")
    }

    private func punchPose(isActive: Bool) -> Pose {
        var pose: Pose
        if activePunchHand == .lead {
            pose = isActive ? .leadPunch : .leadWindUp
        } else {
            pose = isActive ? .rearPunch : .rearWindUp
        }

        let power = CGFloat(activePunchProfile.powerScale)
        let powerMotion = 0.78 + power * 0.24
        pose.bodyX *= powerMotion
        pose.bodyRotation *= 0.80 + power * 0.25
        pose.bodyRotation += CGFloat(activePunchProfile.lateralDrive) * (isActive ? 0.055 : 0.025)

        switch activePunchProfile.motion {
        case .quick:
            if activePunchHand == .lead {
                pose.bodyRotation *= 0.72
                if isActive {
                    pose.bodyX -= 2
                    pose.frontLeg = -0.14
                    pose.backLeg = 0.34
                }
            }
        case .retreating:
            pose.bodyRotation *= 0.68
            pose.bodyX -= isActive ? 7 : 3
            pose.frontLeg = -0.25
            pose.backLeg = 0.27
            if isActive {
                if activePunchHand == .lead {
                    pose.frontLower = 0.11
                } else {
                    pose.backLower = 0.13
                }
            }
        case .driving:
            if isActive {
                pose.bodyX += activePunchHand == .lead ? 6 : 10
                pose.bodyRotation *= activePunchHand == .lead ? 1.08 : 1.20
                pose.frontLeg = -0.03
                pose.backLeg = 0.54
            } else {
                pose.bodyX -= 4
                pose.bodyRotation *= 1.14
                pose.backLeg += 0.06
            }
        case .counter:
            if isActive {
                pose.bodyX += 13
                pose.bodyRotation *= 1.30
                pose.frontLeg = 0.02
                pose.backLeg = 0.58
            } else {
                pose.bodyX -= 7
                pose.bodyRotation *= 1.24
                pose.frontLeg = -0.30
                pose.backLeg = 0.48
            }
        }
        return pose
    }

    private func apply(_ pose: Pose) {
        body.position.x = pose.bodyX
        body.position.y = pose.bodyY
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
