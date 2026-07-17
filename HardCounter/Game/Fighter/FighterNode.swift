import SpriteKit

final class FighterNode: SKNode {
    private var facing: CGFloat
    private let rig: FighterRig
    private var activePunchHand: PunchHand = .lead
    private var activePunchProfile = PunchProfile()
    private var activePunchAimDirection = CGVector(dx: 1, dy: 0)
    private var activeSwayDirection: SwayDirection = .back
    private var activeSwayScreenDirection = CGVector(dx: -1, dy: 0)
    private var locomotion = FighterLocomotionController()
    private var opponentDirection = CGVector(dx: 1, dy: 0)
    private var opponentIsTowardCamera = false
    private var isInNeutralPose = true

    private var animationRoot: SKNode { rig.animationRoot }
    private var locomotionRoot: SKNode { rig.locomotionRoot }
    private var body: SKNode { rig.body }
    private var pelvisMotionRoot: SKNode { rig.pelvisMotionRoot }
    private var pelvisPoseRoot: SKNode { rig.pelvisPoseRoot }
    private var upperBodyMotionRoot: SKNode { rig.upperBodyMotionRoot }
    private var upperBodyPoseRoot: SKNode { rig.upperBodyPoseRoot }
    private var torso: SKShapeNode { rig.torso }
    private var chestFacet: SKShapeNode { rig.chestFacet }
    private var faceFacet: SKShapeNode { rig.faceFacet }
    private var frontUpperArm: SKNode { rig.frontUpperArm }
    private var frontLowerArm: SKNode { rig.frontLowerArm }
    private var backUpperArm: SKNode { rig.backUpperArm }
    private var backLowerArm: SKNode { rig.backLowerArm }
    private var frontLeg: SKNode { rig.frontLeg }
    private var backLeg: SKNode { rig.backLeg }
    private var frontLowerLeg: SKNode { rig.frontLowerLeg }
    private var backLowerLeg: SKNode { rig.backLowerLeg }
    private var frontLegAnchor: SKNode { rig.frontLegAnchor }
    private var backLegAnchor: SKNode { rig.backLegAnchor }
    private var frontKneeMotionRoot: SKNode { rig.frontKneeMotionRoot }
    private var backKneeMotionRoot: SKNode { rig.backKneeMotionRoot }
    private var frontAnkleMotionRoot: SKNode { rig.frontAnkleMotionRoot }
    private var backAnkleMotionRoot: SKNode { rig.backAnkleMotionRoot }
    private var headAnchor: SKNode { rig.headAnchor }

    init(facingRight: Bool, color: SKColor) {
        facing = facingRight ? 1 : -1
        rig = FighterRig(facing: facing, color: color)
        super.init()
        addChild(rig.animationRoot)
        apply(.guardPose)
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
                to: projectedPunchPose(isActive: false),
                duration: CombatTuning.punchStartup * activePunchProfile.startupScale * 0.72,
                style: .anticipation
            )
        case .punchActive:
            let snapScale: Double = activePunchProfile.motion == .counter ? 0.50 : 0.64
            transition(
                to: projectedPunchPose(isActive: true),
                duration: CombatTuning.punchActive * snapScale,
                style: .strike
            )
        case .punchRecovery:
            transition(
                to: .guardPose,
                duration: CombatTuning.punchRecovery * activePunchProfile.recoveryScale * 0.76,
                style: .settle
            )
        case .swaying:
            transition(
                to: FighterPoseResolver.sway(
                    activeSwayDirection,
                    screenDirection: activeSwayScreenDirection,
                    facing: facing
                ),
                duration: CombatTuning.swayDuration * 0.34,
                style: .evasive
            )
        case .hit:
            break
        case .knockedOut:
            playKnockout()
        }
    }

    func preparePunch(_ hand: PunchHand, profile: PunchProfile) {
        activePunchHand = hand
        activePunchProfile = profile
        // Lock the exact continuous aim vector at commitment. The opponent may
        // keep moving during startup, but the fist should finish along one
        // readable line instead of snapping between projected pose updates.
        activePunchAimDirection = opponentDirection
    }

    func prepareSway(_ direction: SwayDirection, screenDirection: CGVector) {
        activeSwayDirection = direction
        activeSwayScreenDirection = screenDirection
    }

    private func orient(toward direction: CGVector) {
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

        torso.fillColor = rig.lineColor.withAlphaComponent(
            0.70 + facingCameraAmount * 0.18 - facingAwayAmount * 0.08
        )
        chestFacet.alpha = 0.18 + facingCameraAmount * 0.82
        faceFacet.alpha = 0.22 + facingCameraAmount * 0.78
    }

    func updateMotion(
        _ movementState: FighterMovementState,
        deltaTime: TimeInterval
    ) {
        orient(toward: movementState.towardOpponent)
        guard deltaTime > 0 else { return }
        let horizontalScale = xScale * animationRoot.xScale
        let verticalScale = yScale * animationRoot.yScale
        let input = movementState.locomotionInput(
            facing: facing,
            horizontalScale: horizontalScale,
            verticalScale: verticalScale
        )
        let frame = locomotion.update(
            input: input,
            isNeutralPose: isInNeutralPose,
            deltaTime: deltaTime
        )

        let frontLegSolution = FighterLegIK.solve(
            upperAngle: frontLeg.zRotation,
            kneeAngle: frontLowerLeg.zRotation,
            bendDirection: -1,
            footOffset: frame.frontFootOffset,
            upperLength: FighterGeometry.upperLegLength,
            lowerLength: FighterGeometry.lowerLegLength
        )
        let backLegSolution = FighterLegIK.solve(
            upperAngle: backLeg.zRotation,
            kneeAngle: backLowerLeg.zRotation,
            bendDirection: -1,
            footOffset: frame.backFootOffset,
            upperLength: FighterGeometry.upperLegLength,
            lowerLength: FighterGeometry.lowerLegLength
        )
        frontLegAnchor.zRotation = frontLegSolution.hipCorrection
        backLegAnchor.zRotation = backLegSolution.hipCorrection
        frontKneeMotionRoot.zRotation = frontLegSolution.kneeCorrection
        backKneeMotionRoot.zRotation = backLegSolution.kneeCorrection
        // Negative compression lowers the hips and flexes both knees. The old
        // subtraction raised the hip on each load/landing beat, producing the
        // rigid straight-leg pop visible during movement.
        let plantedLegY = 36 - pelvisPoseRoot.position.y + frame.pelvisCompression
        frontLegAnchor.position.y = plantedLegY
        backLegAnchor.position.y = plantedLegY
        pelvisMotionRoot.position = frame.pelvisPosition
        pelvisMotionRoot.zRotation = frame.pelvisRotation
        upperBodyMotionRoot.position = frame.upperBodyPosition
        upperBodyMotionRoot.zRotation = frame.upperBodyRotation

        frontAnkleMotionRoot.zRotation = -(
            frontLegAnchor.zRotation + frontLeg.zRotation
                + frontKneeMotionRoot.zRotation + frontLowerLeg.zRotation
        ) * 0.92 + frame.frontAnkleLift
        backAnkleMotionRoot.zRotation = -(
            backLegAnchor.zRotation + backLeg.zRotation
                + backKneeMotionRoot.zRotation + backLowerLeg.zRotation
        ) * 0.92 + frame.backAnkleLift

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
        locomotion.reset()
        isInNeutralPose = true
        zRotation = 0
        transition(to: .guardPose, duration: CombatTuning.poseResetDuration, style: .settle)
    }

    private func transition(
        to pose: FighterPose,
        duration: TimeInterval,
        style: FighterTransitionStyle
    ) {
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
            let delay = transitionDelay(
                for: node,
                style: style,
                duration: duration,
                isActiveArm: isActiveArm,
                isLeg: isLeg
            )
            node.run(delayed(rotation, by: delay), withKey: "poseRotation")
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
        let upperBodyDelay: TimeInterval
        switch style {
        case .anticipation: upperBodyDelay = duration * 0.09
        case .strike: upperBodyDelay = duration * 0.08
        case .evasive: upperBodyDelay = duration * 0.14
        case .settle: upperBodyDelay = 0
        }
        upperBodyPoseRoot.run(delayed(upperBodyMove, by: upperBodyDelay), withKey: "pose")

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

    private func transitionDelay(
        for node: SKNode,
        style: FighterTransitionStyle,
        duration: TimeInterval,
        isActiveArm: Bool,
        isLeg: Bool
    ) -> TimeInterval {
        switch style {
        case .anticipation:
            if isLeg { return 0 }
            if isActiveArm {
                return node === frontLowerArm || node === backLowerArm
                    ? duration * 0.20 : duration * 0.13
            }
            return duration * 0.08
        case .strike:
            if isLeg { return 0 }
            if isActiveArm {
                return node === frontLowerArm || node === backLowerArm
                    ? duration * 0.14 : duration * 0.09
            }
            return duration * 0.06
        case .evasive:
            if isLeg { return 0 }
            return duration * 0.20
        case .settle:
            return 0
        }
    }

    private func delayed(_ action: SKAction, by delay: TimeInterval) -> SKAction {
        guard delay > 0 else { return action }
        return .sequence([.wait(forDuration: delay), action])
    }

    private func projectedPunchPose(isActive: Bool) -> FighterPose {
        var pose = FighterPoseResolver.punch(
            hand: activePunchHand,
            profile: activePunchProfile,
            isActive: isActive
        )
        let localDirection = CGVector(
            dx: activePunchAimDirection.dx * facing,
            dy: activePunchAimDirection.dy
        )
        let directionLength = max(hypot(localDirection.dx, localDirection.dy), 0.001)
        let normalized = CGVector(
            dx: localDirection.dx / directionLength,
            dy: localDirection.dy / directionLength
        )

        // Limb geometry points down at angle zero. Convert the opponent's
        // projected screen direction into that local angular convention.
        let projectedArmAngle = atan2(normalized.dx, -normalized.dy)
        let baseArmAngle: CGFloat = activePunchHand == .lead ? 1.48 : 1.52
        let armProjectionBlend: CGFloat = isActive ? 1.0 : 0.34
        let aimDelta = shortestAngleDelta(from: baseArmAngle, to: projectedArmAngle)
        let projectedAngle = baseArmAngle + aimDelta * armProjectionBlend
        if activePunchHand == .lead {
            pose.frontUpper += projectedAngle - baseArmAngle
        } else {
            pose.backUpper += projectedAngle - baseArmAngle
        }

        let bodyTravel = pose.bodyX
        pose.bodyX = bodyTravel * normalized.dx
        pose.bodyY += bodyTravel * normalized.dy * 0.72
        return pose
    }

    private func shortestAngleDelta(from source: CGFloat, to target: CGFloat) -> CGFloat {
        atan2(sin(target - source), cos(target - source))
    }

    private func apply(_ pose: FighterPose) {
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

}
