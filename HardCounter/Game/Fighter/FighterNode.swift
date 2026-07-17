import SpriteKit

final class FighterNode: SKNode {
    private static let skinColor = SKColor(red: 0.73, green: 0.47, blue: 0.30, alpha: 1)
    private static let upperArmLength: CGFloat = 37
    private static let lowerArmLength: CGFloat = 35
    private static let upperLegLength: CGFloat = 35
    private static let lowerLegLength: CGFloat = 35
    private enum TransitionStyle {
        case settle
        case anticipation
        case strike
        case evasive
    }

    private struct Pose {
        var bodyX: CGFloat = 0
        var bodyY: CGFloat = 0
        var bodyRotation: CGFloat = 0
        var pelvisRotation: CGFloat = 0
        var frontUpper: CGFloat
        var frontLower: CGFloat
        var backUpper: CGFloat
        var backLower: CGFloat
        var frontLeg: CGFloat
        var backLeg: CGFloat
        var frontKnee: CGFloat = 0.10
        var backKnee: CGFloat = 0.14

        static let guardPose = Pose(
            frontUpper: 0.90, frontLower: 2.45,
            backUpper: 0.45, backLower: 2.60,
            frontLeg: -0.18, backLeg: 0.30,
            frontKnee: 0.12, backKnee: 0.16
        )

        static let leadWindUp = Pose(
            bodyX: -5, bodyRotation: -0.08, pelvisRotation: -0.025,
            frontUpper: 0.42, frontLower: 2.58,
            backUpper: 0.45, backLower: 2.60,
            frontLeg: -0.24, backLeg: 0.38,
            frontKnee: 0.16, backKnee: 0.20
        )

        static let leadPunch = Pose(
            bodyX: 12, bodyRotation: 0.09, pelvisRotation: 0.035,
            frontUpper: 1.48, frontLower: 0.02,
            backUpper: 0.45, backLower: 2.60,
            frontLeg: -0.10, backLeg: 0.42,
            frontKnee: 0.06, backKnee: 0.20
        )

        static let rearWindUp = Pose(
            bodyX: -8, bodyRotation: -0.18, pelvisRotation: -0.11,
            frontUpper: 0.90, frontLower: 2.45,
            backUpper: -0.18, backLower: 2.82,
            frontLeg: -0.26, backLeg: 0.42,
            frontKnee: 0.17, backKnee: 0.23
        )

        static let rearPunch = Pose(
            bodyX: 16, bodyRotation: 0.16, pelvisRotation: 0.14,
            frontUpper: 0.72, frontLower: 2.58,
            backUpper: 1.52, backLower: 0.04,
            frontLeg: -0.08, backLeg: 0.48,
            frontKnee: 0.08, backKnee: 0.24
        )

        static let swayBack = Pose(
            bodyX: -20, bodyRotation: -0.20, pelvisRotation: 0.055,
            frontUpper: 0.82, frontLower: 2.50,
            backUpper: 0.39, backLower: 2.66,
            frontLeg: -0.26, backLeg: 0.39,
            frontKnee: 0.18, backKnee: 0.21
        )

        static let swayLeft = Pose(
            bodyX: -12, bodyRotation: 0.24, pelvisRotation: -0.075,
            frontUpper: 0.84, frontLower: 2.50,
            backUpper: 0.40, backLower: 2.64,
            frontLeg: -0.23, backLeg: 0.37,
            frontKnee: 0.20, backKnee: 0.18
        )

        static let swayRight = Pose(
            bodyX: 12, bodyRotation: -0.26, pelvisRotation: 0.08,
            frontUpper: 0.82, frontLower: 2.56,
            backUpper: 0.43, backLower: 2.57,
            frontLeg: -0.12, backLeg: 0.32,
            frontKnee: 0.12, backKnee: 0.22
        )

        static let swayForward = Pose(
            bodyX: 8, bodyRotation: 0.08, pelvisRotation: 0.045,
            frontUpper: 0.80, frontLower: 2.52,
            backUpper: 0.38, backLower: 2.66,
            frontLeg: -0.12, backLeg: 0.38,
            frontKnee: 0.15, backKnee: 0.20
        )
    }

    private var facing: CGFloat
    private let lineColor: SKColor
    private let animationRoot = SKNode()
    private let locomotionRoot = SKNode()
    private let body = SKNode()
    private let pelvisMotionRoot = SKNode()
    private let pelvisPoseRoot = SKNode()
    private let upperBodyMotionRoot = SKNode()
    private let upperBodyPoseRoot = SKNode()
    private var torso = SKShapeNode()
    private var chestFacet = SKShapeNode()
    private var faceFacet = SKShapeNode()
    private let frontUpperArm: SKNode
    private let frontLowerArm: SKNode
    private let backUpperArm: SKNode
    private let backLowerArm: SKNode
    private let frontLeg: SKNode
    private let backLeg: SKNode
    private let frontLowerLeg: SKNode
    private let backLowerLeg: SKNode
    private let frontLegAnchor = SKNode()
    private let backLegAnchor = SKNode()
    private let frontKneeMotionRoot = SKNode()
    private let backKneeMotionRoot = SKNode()
    private let frontAnkleMotionRoot = SKNode()
    private let backAnkleMotionRoot = SKNode()
    private let headAnchor = SKNode()
    private let head: SKShapeNode
    private var activePunchHand: PunchHand = .lead
    private var activePunchProfile = PunchProfile()
    private var activeSwayDirection: SwayDirection = .back
    private var locomotionClock: TimeInterval = 0
    private var gaitPhase: CGFloat = 0
    private var displayedMoveIntensity: CGFloat = 0
    private var lastMoveDirection = CGVector(dx: 1, dy: 0)
    private var opponentDirection = CGVector(dx: 1, dy: 0)
    private var opponentIsTowardCamera = false
    private var isInNeutralPose = true

    init(facingRight: Bool, color: SKColor) {
        facing = facingRight ? 1 : -1
        lineColor = color
        frontUpperArm = Self.makeLimb(length: Self.upperArmLength, topWidth: 12, bottomWidth: 9, color: Self.skinColor)
        frontLowerArm = Self.makeLimb(length: Self.lowerArmLength, topWidth: 10, bottomWidth: 8, color: Self.skinColor)
        backUpperArm = Self.makeLimb(length: Self.upperArmLength, topWidth: 11, bottomWidth: 8, color: Self.skinColor.withAlphaComponent(0.82))
        backLowerArm = Self.makeLimb(length: Self.lowerArmLength, topWidth: 9, bottomWidth: 7, color: Self.skinColor.withAlphaComponent(0.82))
        frontLeg = Self.makeLimb(length: Self.upperLegLength, topWidth: 16, bottomWidth: 12, color: Self.skinColor)
        backLeg = Self.makeLimb(length: Self.upperLegLength, topWidth: 15, bottomWidth: 11, color: Self.skinColor.withAlphaComponent(0.82))
        frontLowerLeg = Self.makeLimb(length: Self.lowerLegLength, topWidth: 12, bottomWidth: 9, color: Self.skinColor)
        backLowerLeg = Self.makeLimb(length: Self.lowerLegLength, topWidth: 11, bottomWidth: 8, color: Self.skinColor.withAlphaComponent(0.82))
        head = Self.makePolygon(Self.regularPolygon(radius: 15.5, sides: 8, startAngle: .pi / 2))
        super.init()
        buildRig()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { nil }

    func show(phase: FighterPhase) {
        isInNeutralPose = phase == .idle
        switch phase {
        case .idle:
            transition(to: .guardPose, duration: CombatTuning.idleReturnDuration, style: .settle)
        case .punchStartup:
            transition(
                to: punchPose(isActive: false),
                duration: CombatTuning.punchStartup * activePunchProfile.startupScale * 0.82,
                style: .anticipation
            )
        case .punchActive:
            let snapScale: Double = activePunchProfile.motion == .counter ? 0.38 : 0.52
            transition(
                to: punchPose(isActive: true),
                duration: CombatTuning.punchActive * snapScale,
                style: .strike
            )
        case .punchRecovery:
            transition(
                to: .guardPose,
                duration: CombatTuning.punchRecovery * activePunchProfile.recoveryScale * 0.72,
                style: .settle
            )
        case .swaying:
            let pose: Pose
            switch activeSwayDirection {
            case .left: pose = .swayLeft
            case .right: pose = .swayRight
            case .back: pose = .swayBack
            case .forward: pose = .swayForward
            }
            transition(to: pose, duration: CombatTuning.swayDuration * 0.46, style: .evasive)
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
        opponentDirection = CGVector(dx: normalizedX, dy: normalizedY)
        // Keep the last side while nearly head-on. This prevents rapid mirror
        // popping when the fighters cross the same horizontal line.
        if normalizedX > 0.30 { facing = 1 }
        if normalizedX < -0.30 { facing = -1 }
        let depthAmount = abs(normalizedY)
        let facingCameraAmount = max(-normalizedY, 0)
        let facingAwayAmount = max(normalizedY, 0)
        // The torso should open up as the opponent moves into depth. Compressing
        // the whole rig in this pose made diagonal and head-on boxers look thin.
        let widthScale = 0.90 + depthAmount * 0.10

        animationRoot.xScale = facing * widthScale
        animationRoot.yScale = 1 + depthAmount * 0.04

        // A side-on boxer has overlapping shoulders and feet. As the opponent
        // moves into depth, spread the stance and swap limb depth to sell yaw.
        let shoulderSpread = depthAmount * 10
        frontUpperArm.position.x = shoulderSpread
        backUpperArm.position.x = -shoulderSpread
        frontLegAnchor.position.x = 6 + depthAmount * 6
        backLegAnchor.position.x = -6 - depthAmount * 6

        if normalizedY < -0.18 { opponentIsTowardCamera = true }
        if normalizedY > 0.18 { opponentIsTowardCamera = false }

        if opponentIsTowardCamera {
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
        let visualResponse: CGFloat = targetIntensity > displayedMoveIntensity ? 10.5 : 12.5
        let blend = 1 - CGFloat(exp(-Double(visualResponse) * deltaTime))
        displayedMoveIntensity += (targetIntensity - displayedMoveIntensity) * blend

        if targetIntensity > 0.025 {
            lastMoveDirection = CGVector(
                dx: movement.dx / targetIntensity,
                dy: movement.dy / targetIntensity
            )
        }

        if displayedMoveIntensity > 0.015 {
            gaitPhase += CGFloat(deltaTime) * (4.6 + displayedMoveIntensity * 2.8)
        }

        let localDirectionX = lastMoveDirection.dx * facing
        let step = sin(gaitPhase)
        let firstSlide = CGFloat(pow(Double(max(step, 0)), 1.55))
        let followSlide = CGFloat(pow(Double(max(-step, 0)), 1.55))
        let forwardDrive = lastMoveDirection.dx * opponentDirection.dx
            + lastMoveDirection.dy * opponentDirection.dy
        let lateralDrive = lastMoveDirection.dx * -opponentDirection.dy
            + lastMoveDirection.dy * opponentDirection.dx
        let frontFootInitiates = abs(forwardDrive) >= abs(lateralDrive)
            ? forwardDrive >= 0
            : lateralDrive * facing >= 0
        let frontSlide = frontFootInitiates ? firstSlide : followSlide
        let backSlide = frontFootInitiates ? followSlide : firstSlide
        let stride = displayedMoveIntensity * 0.065

        // Boxing footwork is a shuffle: the foot nearest the travel direction
        // slides first and the other foot restores the stance. Neither leg
        // swings through like a walking gait.
        frontLegAnchor.zRotation = (frontSlide - backSlide * 0.28) * stride
        backLegAnchor.zRotation = -(backSlide - frontSlide * 0.28) * stride
        let stanceFlex = 0.025 + displayedMoveIntensity * 0.025
        frontKneeMotionRoot.zRotation = stanceFlex
            + frontSlide * displayedMoveIntensity * 0.17
            + backSlide * displayedMoveIntensity * 0.025
        backKneeMotionRoot.zRotation = stanceFlex
            + backSlide * displayedMoveIntensity * 0.17
            + frontSlide * displayedMoveIntensity * 0.025
        let shufflePulse = min(firstSlide + followSlide, 1)
        let pelvisCompression = -shufflePulse * displayedMoveIntensity * 0.85
        let plantedLegY = 36 - pelvisPoseRoot.position.y - pelvisCompression
        frontLegAnchor.position.y = plantedLegY + frontSlide * displayedMoveIntensity * 1.45
        backLegAnchor.position.y = plantedLegY + backSlide * displayedMoveIntensity * 1.45

        let idleAmount = isInNeutralPose ? 1 - displayedMoveIntensity : 0
        let breath = sin(CGFloat(locomotionClock) * 2.7)
        let guardPulse = sin(CGFloat(locomotionClock) * 5.4)
        let supportBias = frontSlide - backSlide
        let weightTransfer = -supportBias * displayedMoveIntensity * 1.55
        let directionalLean = localDirectionX * displayedMoveIntensity

        pelvisMotionRoot.position = CGPoint(x: weightTransfer, y: pelvisCompression)
        pelvisMotionRoot.zRotation = supportBias * displayedMoveIntensity * 0.016
            - directionalLean * 0.022

        upperBodyMotionRoot.position = CGPoint(
            x: weightTransfer * 0.58 + directionalLean * 1.5,
            y: pelvisCompression * 0.62
                + breath * idleAmount * 0.85 + guardPulse * idleAmount * 0.25
        )
        upperBodyMotionRoot.zRotation = -supportBias * displayedMoveIntensity * 0.014
            - directionalLean * 0.034
            + breath * idleAmount * 0.008

        frontAnkleMotionRoot.zRotation = -(
            frontLegAnchor.zRotation + frontLeg.zRotation
                + frontKneeMotionRoot.zRotation + frontLowerLeg.zRotation
        ) * 0.92 + frontSlide * displayedMoveIntensity * 0.025
        backAnkleMotionRoot.zRotation = -(
            backLegAnchor.zRotation + backLeg.zRotation
                + backKneeMotionRoot.zRotation + backLowerLeg.zRotation
        ) * 0.92 + backSlide * displayedMoveIntensity * 0.025

        locomotionRoot.position = .zero
        locomotionRoot.zRotation = 0
        // Pelvis drives the action, shoulders follow and the chin resists both.
        // This keeps the guard readable without making the head feel welded on.
        headAnchor.zRotation = -(
            upperBodyPoseRoot.zRotation + upperBodyMotionRoot.zRotation
        ) * 0.46
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
        pelvisMotionRoot.removeAllActions()
        pelvisPoseRoot.removeAllActions()
        upperBodyMotionRoot.removeAllActions()
        upperBodyPoseRoot.removeAllActions()
        animationRoot.position = .zero
        locomotionRoot.position = .zero
        locomotionRoot.zRotation = 0
        pelvisMotionRoot.position = .zero
        pelvisMotionRoot.zRotation = 0
        pelvisPoseRoot.position = .zero
        pelvisPoseRoot.zRotation = 0
        upperBodyMotionRoot.position = .zero
        upperBodyMotionRoot.zRotation = 0
        upperBodyPoseRoot.position = .zero
        upperBodyPoseRoot.zRotation = 0
        headAnchor.zRotation = 0
        body.position = .zero
        body.zRotation = 0
        body.alpha = 1
        body.setScale(1)
        frontLegAnchor.zRotation = 0
        backLegAnchor.zRotation = 0
        frontKneeMotionRoot.zRotation = 0
        backKneeMotionRoot.zRotation = 0
        frontAnkleMotionRoot.zRotation = 0
        backAnkleMotionRoot.zRotation = 0
        frontLegAnchor.position.y = 36
        backLegAnchor.position.y = 36
        displayedMoveIntensity = 0
        isInNeutralPose = true
        gaitPhase = 0
        zRotation = 0
        transition(to: .guardPose, duration: CombatTuning.poseResetDuration, style: .settle)
    }

    private func buildRig() {
        addChild(animationRoot)
        animationRoot.xScale = facing
        animationRoot.addChild(locomotionRoot)
        locomotionRoot.addChild(body)
        body.addChild(pelvisMotionRoot)
        pelvisMotionRoot.addChild(pelvisPoseRoot)
        body.addChild(upperBodyMotionRoot)
        upperBodyMotionRoot.addChild(upperBodyPoseRoot)

        torso = Self.makePolygon([
            CGPoint(x: -12, y: 31), CGPoint(x: 12, y: 31),
            CGPoint(x: 18, y: 67), CGPoint(x: 22, y: 78),
            CGPoint(x: 14, y: 85), CGPoint(x: -17, y: 84),
            CGPoint(x: -22, y: 76), CGPoint(x: -17, y: 65)
        ])
        torso.fillColor = lineColor.withAlphaComponent(0.88)
        torso.strokeColor = .black.withAlphaComponent(0.72)
        torso.lineWidth = 2
        upperBodyPoseRoot.addChild(torso)

        let abdomen = Self.makePolygon([
            CGPoint(x: -12, y: 18), CGPoint(x: 12, y: 18),
            CGPoint(x: 11, y: 36), CGPoint(x: -11, y: 36)
        ])
        abdomen.fillColor = lineColor.withAlphaComponent(0.84)
        abdomen.strokeColor = .black.withAlphaComponent(0.58)
        abdomen.lineWidth = 1.5
        abdomen.zPosition = -0.2
        upperBodyPoseRoot.addChild(abdomen)

        chestFacet = Self.makePolygon([
            CGPoint(x: -10, y: 36), CGPoint(x: 11, y: 35),
            CGPoint(x: 19, y: 76), CGPoint(x: 4, y: 68), CGPoint(x: 0, y: 51)
        ])
        chestFacet.fillColor = lineColor.withAlphaComponent(0.45)
        chestFacet.strokeColor = .clear
        chestFacet.zPosition = 0.5
        upperBodyPoseRoot.addChild(chestFacet)

        let neck = Self.makePolygon([
            CGPoint(x: -6, y: 80), CGPoint(x: 6, y: 80),
            CGPoint(x: 7, y: 98), CGPoint(x: -6, y: 97)
        ])
        neck.fillColor = Self.skinColor.withAlphaComponent(0.88)
        neck.strokeColor = .black.withAlphaComponent(0.62)
        neck.lineWidth = 1.5
        neck.zPosition = -0.5
        upperBodyPoseRoot.addChild(neck)

        let shoulderFacet = Self.makePolygon([
            CGPoint(x: -20, y: 73), CGPoint(x: 21, y: 72),
            CGPoint(x: 14, y: 85), CGPoint(x: -17, y: 84)
        ])
        shoulderFacet.fillColor = lineColor.withAlphaComponent(0.74)
        shoulderFacet.strokeColor = .clear
        shoulderFacet.zPosition = 0.7
        upperBodyPoseRoot.addChild(shoulderFacet)

        let shorts = Self.makePolygon([
            CGPoint(x: -17, y: 20), CGPoint(x: 17, y: 20),
            CGPoint(x: 15, y: 41), CGPoint(x: -15, y: 41)
        ])
        shorts.fillColor = lineColor
        shorts.strokeColor = .black.withAlphaComponent(0.75)
        shorts.lineWidth = 2
        shorts.zPosition = 3
        pelvisPoseRoot.addChild(shorts)

        headAnchor.position = CGPoint(x: 0, y: 108)
        headAnchor.zPosition = 1
        head.position = .zero
        head.fillColor = Self.skinColor
        head.strokeColor = .black.withAlphaComponent(0.75)
        head.lineWidth = 2
        headAnchor.addChild(head)
        upperBodyPoseRoot.addChild(headAnchor)

        faceFacet = Self.makePolygon([
            CGPoint(x: 1, y: -14), CGPoint(x: 14, y: -3),
            CGPoint(x: 5, y: 13), CGPoint(x: -1, y: 8)
        ])
        faceFacet.fillColor = Self.skinColor.withAlphaComponent(0.48)
        faceFacet.strokeColor = .clear
        faceFacet.zPosition = 1
        headAnchor.addChild(faceFacet)

        attachArm(backUpperArm, lower: backLowerArm, z: -2)
        attachArm(frontUpperArm, lower: frontLowerArm, z: 2)
        addGlove(to: backLowerArm, alpha: 0.78)
        addGlove(to: frontLowerArm, alpha: 1)
        attachLeg(
            backLeg,
            lower: backLowerLeg,
            kneeRoot: backKneeMotionRoot,
            ankleRoot: backAnkleMotionRoot,
            to: backLegAnchor,
            x: -6,
            z: -2
        )
        attachLeg(
            frontLeg,
            lower: frontLowerLeg,
            kneeRoot: frontKneeMotionRoot,
            ankleRoot: frontAnkleMotionRoot,
            to: frontLegAnchor,
            x: 6,
            z: 1
        )
        addShoe(to: backAnkleMotionRoot, alpha: 0.78)
        addShoe(to: frontAnkleMotionRoot, alpha: 1)
        apply(.guardPose)
    }

    private func attachArm(_ upper: SKNode, lower: SKNode, z: CGFloat) {
        upper.position = CGPoint(x: 0, y: 79)
        upper.zPosition = z
        lower.position = CGPoint(x: 0, y: -Self.upperArmLength)
        upper.addChild(lower)
        addJoint(to: upper, at: CGPoint(x: 0, y: -Self.upperArmLength), radius: 5, alpha: z < 0 ? 0.82 : 1)
        upperBodyPoseRoot.addChild(upper)
    }

    private func attachLeg(
        _ leg: SKNode,
        lower: SKNode,
        kneeRoot: SKNode,
        ankleRoot: SKNode,
        to anchor: SKNode,
        x: CGFloat,
        z: CGFloat
    ) {
        anchor.position = CGPoint(x: x, y: 36)
        anchor.zPosition = z
        leg.position = .zero
        kneeRoot.position = CGPoint(x: 0, y: -Self.upperLegLength)
        lower.position = .zero
        ankleRoot.position = CGPoint(x: 0, y: -Self.lowerLegLength)
        lower.addChild(ankleRoot)
        kneeRoot.addChild(lower)
        leg.addChild(kneeRoot)
        addJoint(to: kneeRoot, at: .zero, radius: 6, alpha: z < 0 ? 0.82 : 1)
        anchor.addChild(leg)
        pelvisPoseRoot.addChild(anchor)
    }

    private func addGlove(to lowerArm: SKNode, alpha: CGFloat) {
        let glove = Self.makePolygon(Self.regularPolygon(radius: 10, sides: 6, startAngle: 0))
        glove.position = CGPoint(x: 0, y: -Self.lowerArmLength + 1)
        glove.fillColor = lineColor.withAlphaComponent(alpha)
        glove.strokeColor = .black.withAlphaComponent(0.75)
        glove.lineWidth = 2
        glove.zPosition = 4
        lowerArm.addChild(glove)
    }

    private func addShoe(to ankle: SKNode, alpha: CGFloat) {
        let shoe = Self.makePolygon([
            CGPoint(x: -5, y: 2), CGPoint(x: 17, y: -2),
            CGPoint(x: 20, y: 7), CGPoint(x: -5, y: 10)
        ])
        shoe.fillColor = lineColor.withAlphaComponent(alpha)
        shoe.strokeColor = .black.withAlphaComponent(0.75)
        shoe.lineWidth = 2
        ankle.addChild(shoe)
    }

    private func addJoint(
        to parent: SKNode,
        at position: CGPoint,
        radius: CGFloat,
        alpha: CGFloat
    ) {
        let joint = SKShapeNode(circleOfRadius: radius)
        joint.position = position
        joint.fillColor = Self.skinColor.withAlphaComponent(alpha)
        joint.strokeColor = .black.withAlphaComponent(0.58)
        joint.lineWidth = 1.2
        joint.zPosition = 2
        parent.addChild(joint)
    }

    private func transition(to pose: Pose, duration: TimeInterval, style: TransitionStyle) {
        let actions: [(SKNode, CGFloat)] = [
            (frontUpperArm, pose.frontUpper), (frontLowerArm, pose.frontLower),
            (backUpperArm, pose.backUpper), (backLowerArm, pose.backLower),
            (frontLeg, pose.frontLeg), (frontLowerLeg, pose.frontKnee),
            (backLeg, pose.backLeg), (backLowerLeg, pose.backKnee)
        ]
        for (node, angle) in actions {
            let isActiveArm = activePunchHand == .lead
                ? (node === frontUpperArm || node === frontLowerArm)
                : (node === backUpperArm || node === backLowerArm)
            let isLeg = node === frontLeg || node === backLeg
                || node === frontLowerLeg || node === backLowerLeg
            let durationScale: Double
            switch style {
            case .strike:
                durationScale = isActiveArm ? 0.52 : (isLeg ? 1.05 : 0.82)
            case .anticipation:
                durationScale = isActiveArm ? 0.84 : (isLeg ? 0.94 : 1)
            case .evasive:
                durationScale = isLeg ? 0.82 : 1
            case .settle:
                durationScale = isLeg ? 0.78 : 1
            }
            let rotation = SKAction.rotate(
                toAngle: angle,
                duration: duration * durationScale,
                shortestUnitArc: true
            )
            rotation.timingMode = style == .strike ? .easeOut : .easeInEaseOut
            node.run(rotation, withKey: "poseRotation")
        }
        let upperDurationScale: Double = style == .strike ? 0.72 : 1
        let upperBodyMove = SKAction.group([
            .move(
                to: CGPoint(x: pose.bodyX * 0.68, y: pose.bodyY * 0.78),
                duration: duration * upperDurationScale
            ),
            .rotate(
                toAngle: pose.bodyRotation,
                duration: duration * upperDurationScale,
                shortestUnitArc: true
            )
        ])
        upperBodyMove.timingMode = style == .strike || style == .evasive ? .easeOut : .easeInEaseOut
        upperBodyPoseRoot.run(upperBodyMove, withKey: "pose")

        let pelvisDurationScale: Double
        switch style {
        case .strike: pelvisDurationScale = 0.56
        case .anticipation: pelvisDurationScale = 0.76
        case .evasive: pelvisDurationScale = 0.82
        case .settle: pelvisDurationScale = 0.72
        }
        let pelvisMove = SKAction.group([
            .move(
                to: CGPoint(x: pose.bodyX * 0.34, y: pose.bodyY * 0.36),
                duration: duration * pelvisDurationScale
            ),
            .rotate(
                toAngle: pose.pelvisRotation,
                duration: duration * pelvisDurationScale,
                shortestUnitArc: true
            )
        ])
        pelvisMove.timingMode = style == .strike || style == .evasive ? .easeOut : .easeInEaseOut
        pelvisPoseRoot.run(pelvisMove, withKey: "pose")
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
                    pose.frontKnee = 0.08
                    pose.backKnee = 0.18
                }
            }
        case .retreating:
            pose.bodyRotation *= 0.68
            pose.bodyX -= isActive ? 7 : 3
            pose.frontLeg = -0.25
            pose.backLeg = 0.27
            pose.frontKnee = 0.18
            pose.backKnee = 0.14
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
                pose.frontKnee = 0.06
                pose.backKnee = 0.27
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
                pose.frontKnee = 0.04
                pose.backKnee = 0.30
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
        upperBodyPoseRoot.position.x = pose.bodyX * 0.68
        upperBodyPoseRoot.position.y = pose.bodyY * 0.78
        upperBodyPoseRoot.zRotation = pose.bodyRotation
        pelvisPoseRoot.position.x = pose.bodyX * 0.34
        pelvisPoseRoot.position.y = pose.bodyY * 0.36
        pelvisPoseRoot.zRotation = pose.pelvisRotation
        frontUpperArm.zRotation = pose.frontUpper
        frontLowerArm.zRotation = pose.frontLower
        backUpperArm.zRotation = pose.backUpper
        backLowerArm.zRotation = pose.backLower
        frontLeg.zRotation = pose.frontLeg
        backLeg.zRotation = pose.backLeg
        frontLowerLeg.zRotation = pose.frontKnee
        backLowerLeg.zRotation = pose.backKnee
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

    private static func makeLimb(
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
