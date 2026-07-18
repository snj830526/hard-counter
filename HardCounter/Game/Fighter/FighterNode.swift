import SpriteKit

final class FighterNode: SKNode {
    private var facing: CGFloat
    private let rig: FighterRig
    private let threeDRenderer: Fighter3DRenderer
    private let usesThreeDRenderer: Bool
    private var activePunchHand: PunchHand = .lead
    private var activePunchProfile = PunchProfile()
    private var activePunchAimDirection = CGVector(dx: 1, dy: 0)
    private var activeSwayDirection: SwayDirection = .back
    private var activeSwayScreenDirection = CGVector(dx: -1, dy: 0)
    private var activeSwayPerformance: CGFloat = 1
    private var locomotion = FighterLocomotionController()
    private var motionClipPlayer = FighterMotionClipPlayer()
    private var appliedPose = FighterPose.guardPose
    private var orientation: FighterOrientationController
    private var opponentDirection = CGVector(dx: 1, dy: 0)
    private var opponentIsTowardCamera = false
    private var isInNeutralPose = true
    private var currentPhase: FighterPhase = .idle

    private var animationRoot: SKNode { rig.animationRoot }
    private var locomotionRoot: SKNode { rig.locomotionRoot }
    private var actionRoot: SKNode { rig.actionRoot }
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

    init(
        facingRight: Bool,
        appearance: FighterAppearance,
        motionStyle: Fighter3DMotionStyle
    ) {
        facing = facingRight ? 1 : -1
        orientation = FighterOrientationController(facingRight: facingRight)
        rig = FighterRig(facing: facing, appearance: appearance)
        threeDRenderer = Fighter3DRenderer(
            appearance: appearance,
            motionStyle: motionStyle
        )
        usesThreeDRenderer = !ProcessInfo.processInfo.arguments.contains("--legacy-2d-fighters")
        super.init()
        addChild(rig.animationRoot)
        addChild(threeDRenderer.spriteNode)
        rig.animationRoot.isHidden = usesThreeDRenderer
        threeDRenderer.spriteNode.isHidden = !usesThreeDRenderer
        threeDRenderer.spriteNode.isPlaying = usesThreeDRenderer
        apply(.guardPose)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { nil }

    func show(phase: FighterPhase) {
        currentPhase = phase
        isInNeutralPose = phase == .idle
        threeDRenderer.show(phase: phase)
        switch phase {
        case .idle:
            motionClipPlayer.finishAction()
            removePoseActions()
            actionRoot.position = .zero
            actionRoot.zRotation = 0
        case .punchStartup:
            if usesRearStraightMotionClip {
                removePoseActions()
                motionClipPlayer.play(FighterMotionLibrary.rearStraight(
                    guardPose: appliedPose,
                    loadPose: projectedPunchPose(isActive: false),
                    strikePose: projectedPunchPose(isActive: true),
                    startup: CombatTuning.punchStartup * activePunchProfile.startupScale,
                    active: CombatTuning.punchActive * activePunchProfile.activeScale,
                    recovery: CombatTuning.punchRecovery * activePunchProfile.recoveryScale
                ))
            } else {
                motionClipPlayer.finishAction()
                actionRoot.position = .zero
                actionRoot.zRotation = 0
                transition(
                    to: projectedPunchPose(isActive: false),
                    duration: CombatTuning.punchStartup * activePunchProfile.startupScale * 0.72,
                    style: .anticipation
                )
            }
        case .punchActive:
            if motionClipPlayer.isPlayingAction { break }
            let snapScale: Double
            switch activePunchProfile.technique {
            case .straight:
                snapScale = activePunchProfile.motion == .counter ? 0.50 : 0.64
            case .smash:
                snapScale = activePunchProfile.motion == .counter ? 0.46 : 0.52
            case .uppercut:
                snapScale = activePunchProfile.motion == .counter ? 0.48 : 0.56
            }
            transition(
                to: projectedPunchPose(isActive: true),
                duration: CombatTuning.punchActive * activePunchProfile.activeScale * snapScale,
                style: .strike
            )
        case .punchRecovery:
            if motionClipPlayer.isPlayingAction { break }
            transition(
                to: .guardPose,
                duration: CombatTuning.punchRecovery * activePunchProfile.recoveryScale * 0.76,
                style: .settle
            )
        case .swaying:
            motionClipPlayer.finishAction()
            actionRoot.position = .zero
            actionRoot.zRotation = 0
            transition(
                to: FighterPoseResolver.sway(
                    activeSwayDirection,
                    screenDirection: activeSwayScreenDirection,
                    facing: facing,
                    performance: activeSwayPerformance
                ),
                duration: CombatTuning.swayDuration * 0.30,
                style: .evasive
            )
        case .hit:
            break
        case .knockedOut:
            motionClipPlayer.finishAction()
            actionRoot.position = .zero
            actionRoot.zRotation = 0
            playKnockout()
        }
    }

    func preparePunch(_ hand: PunchHand, profile: PunchProfile) {
        activePunchHand = hand
        activePunchProfile = profile
        threeDRenderer.preparePunch(hand, profile: profile)
        // Lock the exact continuous aim vector at commitment. The opponent may
        // keep moving during startup, but the fist should finish along one
        // readable line instead of snapping between projected pose updates.
        activePunchAimDirection = opponentDirection
    }

    func prepareSway(
        _ direction: SwayDirection,
        screenDirection: CGVector,
        performance: Double
    ) {
        activeSwayDirection = direction
        activeSwayScreenDirection = screenDirection
        activeSwayPerformance = CGFloat(performance)
        threeDRenderer.prepareSway(
            direction,
            screenDirection: screenDirection,
            performance: CGFloat(performance)
        )
    }

    private func applyOrientation(_ frame: FighterOrientationFrame) {
        opponentDirection = frame.direction
        facing = frame.facing
        let depthAmount = frame.depthAmount
        let facingCameraAmount = frame.towardCameraAmount
        let facingAwayAmount = frame.awayFromCameraAmount
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

        if frame.direction.dy < -0.18 { opponentIsTowardCamera = true }
        if frame.direction.dy > 0.18 { opponentIsTowardCamera = false }

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

        // Rear-hand attacks can otherwise remain behind the torso in several
        // quarter-view orientations. Keep the committed striking arm in front
        // until recovery finishes so the punch silhouette never disappears.
        switch currentPhase {
        case .punchStartup, .punchActive, .punchRecovery:
            if activePunchHand == .lead {
                frontUpperArm.zPosition = 6
            } else {
                backUpperArm.zPosition = 6
            }
        case .idle, .swaying, .hit, .knockedOut:
            break
        }

        torso.fillColor = rig.skinColor.withAlphaComponent(
            0.70 + facingCameraAmount * 0.18 - facingAwayAmount * 0.08
        )
        chestFacet.alpha = 0.18 + facingCameraAmount * 0.82
        faceFacet.alpha = 0.22 + facingCameraAmount * 0.78
    }

    func updateMotion(
        _ movementState: FighterMovementState,
        deltaTime: TimeInterval
    ) {
        let orientationFrame = orientation.update(
            toward: movementState.towardOpponent,
            deltaTime: deltaTime
        )
        applyOrientation(orientationFrame)
        guard deltaTime > 0 else { return }

        let actionFrame = motionClipPlayer.update(
            phase: currentPhase,
            deltaTime: deltaTime
        )
        if let actionFrame {
            apply(actionFrame.pose)
            actionRoot.position = actionFrame.rootPosition
            actionRoot.zRotation = actionFrame.rootRotation
        }
        let horizontalScale = xScale * animationRoot.xScale
        let verticalScale = yScale * animationRoot.yScale
        let input = movementState.locomotionInput(
            facing: facing,
            horizontalScale: horizontalScale,
            verticalScale: verticalScale,
            displayedOpponentDirection: opponentDirection
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
            footOffset: CGPoint(
                x: frame.frontFootOffset.x + (actionFrame?.frontFootOffset.x ?? 0),
                y: frame.frontFootOffset.y + (actionFrame?.frontFootOffset.y ?? 0)
            ),
            upperLength: FighterGeometry.upperLegLength,
            lowerLength: FighterGeometry.lowerLegLength
        )
        let backLegSolution = FighterLegIK.solve(
            upperAngle: backLeg.zRotation,
            kneeAngle: backLowerLeg.zRotation,
            bendDirection: -1,
            footOffset: CGPoint(
                x: frame.backFootOffset.x + (actionFrame?.backFootOffset.x ?? 0),
                y: frame.backFootOffset.y + (actionFrame?.backFootOffset.y ?? 0)
            ),
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
        threeDRenderer.update(
            movement: movementState,
            orientation: orientationFrame,
            locomotionFrame: frame,
            deltaTime: deltaTime
        )
    }

    func playHit(_ kind: HitKind, profile: PunchProfile = PunchProfile()) {
        threeDRenderer.playHit(kind, profile: profile)
        let baseDistance = kind == .counter
            ? CombatTuning.counterKnockback
            : CombatTuning.normalKnockback
        let duration = kind == .counter
            ? CombatTuning.counterHitReaction
            : CombatTuning.hitReaction
        let techniqueTravel: CGFloat
        let lift: CGFloat
        let recoilRotation: CGFloat
        switch profile.technique {
        case .straight:
            techniqueTravel = 1
            lift = 1
            recoilRotation = -0.18
        case .smash:
            techniqueTravel = 0.82
            lift = 4
            recoilRotation = -0.30
        case .uppercut:
            techniqueTravel = 0.52
            lift = 13
            recoilRotation = -0.12
        }
        let power = CGFloat(min(max(profile.powerScale, 0.65), 1.30))
        let distance = baseDistance * techniqueTravel * (0.78 + power * 0.22)
        body.removeAction(forKey: "impact")
        headAnchor.removeAction(forKey: "impact")
        if profile.technique == .straight {
            removePoseActions()
            body.position = .zero
            body.zRotation = 0
            motionClipPlayer.play(FighterMotionLibrary.straightHit(
                from: appliedPose,
                kind: kind,
                profile: profile
            ))
        } else {
            let recoil = SKAction.group([
                .move(to: CGPoint(x: -distance, y: lift), duration: duration * 0.20),
                .rotate(
                    toAngle: recoilRotation,
                    duration: duration * 0.20,
                    shortestUnitArc: true
                )
            ])
            recoil.timingMode = .easeOut
            let rebound = SKAction.group([
                .move(
                    to: CGPoint(x: distance * 0.08, y: -lift * 0.12),
                    duration: duration * 0.26
                ),
                .rotate(
                    toAngle: -recoilRotation * 0.12,
                    duration: duration * 0.26,
                    shortestUnitArc: true
                )
            ])
            rebound.timingMode = .easeInEaseOut
            let recover = SKAction.group([
                .move(to: .zero, duration: duration * 0.54),
                .rotate(toAngle: 0, duration: duration * 0.54, shortestUnitArc: true)
            ])
            recover.timingMode = .easeInEaseOut
            body.run(.sequence([recoil, rebound, recover]), withKey: "impact")
        }

        let headRecoil = SKAction.move(
            to: CGPoint(x: -distance * 0.18, y: 108 + lift * 0.58),
            duration: duration * 0.16
        )
        headRecoil.timingMode = .easeOut
        let headRecover = SKAction.move(
            to: CGPoint(x: 0, y: 108),
            duration: duration * 0.60
        )
        headRecover.timingMode = .easeInEaseOut
        headAnchor.run(.sequence([
            .wait(forDuration: duration * 0.04),
            headRecoil,
            headRecover
        ]), withKey: "impact")
    }

    func playHitConfirm(_ profile: PunchProfile) {
        threeDRenderer.playHitConfirm(profile)
        if profile.technique == .straight, motionClipPlayer.isPlayingAction { return }
        body.removeAction(forKey: "impact")
        let travel: CGFloat
        switch profile.technique {
        case .straight: travel = 2.5
        case .smash: travel = 4.5
        case .uppercut: travel = 3.5
        }
        let drive = travel * CGFloat(min(max(profile.powerScale, 0.65), 1.30))
        let followThrough = SKAction.moveTo(x: drive, duration: 0.045)
        followThrough.timingMode = .easeOut
        let settle = SKAction.move(to: .zero, duration: 0.11)
        settle.timingMode = .easeInEaseOut
        body.run(.sequence([followThrough, settle]), withKey: "impact")
    }

    func playWhiff(_ profile: PunchProfile) {
        threeDRenderer.playWhiff(profile)
        if profile.technique == .straight, motionClipPlayer.isPlayingAction { return }
        body.removeAction(forKey: "impact")
        let travel: CGFloat
        let drop: CGFloat
        switch profile.technique {
        case .straight:
            travel = 4.5
            drop = -1
        case .smash:
            travel = 7
            drop = -3
        case .uppercut:
            travel = 5.5
            drop = 3
        }
        let overreach = SKAction.group([
            .move(to: CGPoint(x: travel, y: drop), duration: 0.075),
            .rotate(toAngle: 0.045, duration: 0.075, shortestUnitArc: true)
        ])
        overreach.timingMode = .easeOut
        let recover = SKAction.group([
            .move(to: .zero, duration: 0.18),
            .rotate(toAngle: 0, duration: 0.18, shortestUnitArc: true)
        ])
        recover.timingMode = .easeInEaseOut
        body.run(.sequence([overreach, recover]), withKey: "impact")
    }

    func updateStamina(fraction: CGFloat) {
        threeDRenderer.updateStamina(fraction: fraction)
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
        actionRoot.position = .zero
        actionRoot.zRotation = 0
        pelvisMotionRoot.position = .zero
        pelvisMotionRoot.zRotation = 0
        pelvisPoseRoot.position = .zero
        pelvisPoseRoot.zRotation = 0
        upperBodyMotionRoot.position = .zero
        upperBodyMotionRoot.zRotation = 0
        upperBodyPoseRoot.position = .zero
        upperBodyPoseRoot.zRotation = 0
        headAnchor.zRotation = 0
        headAnchor.position = CGPoint(x: 0, y: 108)
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
        motionClipPlayer.reset()
        threeDRenderer.reset()
        appliedPose = .guardPose
        isInNeutralPose = true
        currentPhase = .idle
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
        let upperTranslationX: CGFloat = style == .evasive ? 0.90 : 0.68
        let upperTranslationY: CGFloat = style == .evasive ? 0.92 : 0.78
        let upperBodyMove = SKAction.group([
            .move(
                to: CGPoint(x: pose.bodyX * upperTranslationX, y: pose.bodyY * upperTranslationY),
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
        case .evasive: upperBodyDelay = 0
        case .settle: upperBodyDelay = 0
        }
        upperBodyPoseRoot.run(delayed(upperBodyMove, by: upperBodyDelay), withKey: "pose")

        let pelvisDurationScale: Double
        switch style {
        case .strike: pelvisDurationScale = 0.56
        case .anticipation: pelvisDurationScale = 0.76
        case .evasive: pelvisDurationScale = 1
        case .settle: pelvisDurationScale = 0.72
        }
        // During a sway the pelvis must travel with the rib cage. Letting the
        // shoulders cover almost the full distance while the hips moved only a
        // third of it opened a visible gap at the waist. Punches still keep the
        // smaller hip translation so their torso twist remains distinct.
        let pelvisTranslationX: CGFloat = style == .evasive ? 0.72 : 0.34
        let pelvisTranslationY: CGFloat = style == .evasive ? 0.76 : 0.36
        let pelvisMove = SKAction.group([
            .move(
                to: CGPoint(
                    x: pose.bodyX * pelvisTranslationX,
                    y: pose.bodyY * pelvisTranslationY
                ),
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

    private var usesRearStraightMotionClip: Bool {
        activePunchHand == .rear && activePunchProfile.technique == .straight
    }

    private func removePoseActions() {
        let nodes = [
            frontUpperArm, frontLowerArm, backUpperArm, backLowerArm,
            frontLeg, frontLowerLeg, backLeg, backLowerLeg,
            pelvisPoseRoot, upperBodyPoseRoot
        ]
        for node in nodes {
            node.removeAction(forKey: "pose")
            node.removeAction(forKey: "poseRotation")
        }
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
        if activePunchProfile.technique == .straight {
            let baseArmAngle: CGFloat = activePunchHand == .lead ? 1.48 : 1.52
            let armProjectionBlend: CGFloat = isActive ? 1.0 : 0.34
            let aimDelta = shortestAngleDelta(from: baseArmAngle, to: projectedArmAngle)
            let projectedAngle = baseArmAngle + aimDelta * armProjectionBlend
            if activePunchHand == .lead {
                pose.frontUpper += projectedAngle - baseArmAngle
            } else {
                pose.backUpper += projectedAngle - baseArmAngle
            }
        } else if activePunchProfile.technique == .smash, isActive {
            // Keep the elbow below the target line, then drive the forearm up
            // through it. This gives the smash a long, rising silhouette while
            // still following opponents around the quarter-view ring.
            let upperArmAngle = projectedArmAngle - 0.30
            if activePunchHand == .lead {
                pose.frontUpper = upperArmAngle
                pose.frontLower = 0.52
            } else {
                pose.backUpper = upperArmAngle - 0.04
                pose.backLower = 0.58
            }
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
        appliedPose = pose
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
