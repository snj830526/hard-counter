import SceneKit
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
    private var locomotion: FighterLocomotionController
    private var motionClipPlayer = FighterMotionClipPlayer()
    private var appliedPose = FighterPose.guardPose
    private var orientation: FighterOrientationController
    private var opponentDirection = CGVector(dx: 1, dy: 0)
    private var opponentIsTowardCamera = false
    private var isInNeutralPose = true
    private var currentPhase: FighterPhase = .idle
    private let damageEffectRoot = SKNode()
    private var damageVisualTier = 0
    private var usesScreenSpaceDamageEffects = false

    var committedPunchAimDirection: CGVector { activePunchAimDirection }

    func attachThreeDPresentation(to parent: SCNNode) {
        threeDRenderer.attachPresentation(to: parent)
        threeDRenderer.spriteNode.isHidden = true
    }

    func setThreeDStageTransform(position: SCNVector3, scale: Float = 1) {
        threeDRenderer.setSharedStageTransform(position: position, scale: scale)
    }

    func threeDBodyWorldPosition(for technique: PunchTechnique = .straight) -> SCNVector3 {
        threeDRenderer.sharedBodyWorldPosition(for: technique)
    }

    func threeDDamageWorldPosition() -> SCNVector3 {
        threeDRenderer.sharedDamageWorldPosition()
    }

    func threeDHitBodySize(
        for technique: PunchTechnique
    ) -> (halfWidth: CGFloat, forwardRadius: CGFloat) {
        threeDRenderer.sharedHitBodySize(for: technique)
    }

    func threeDPunchReach(for technique: PunchTechnique) -> CGFloat {
        threeDRenderer.sharedPunchReach(for: technique)
    }

    func attachDamageEffects(to screenSpaceParent: SKNode) {
        damageEffectRoot.removeFromParent()
        screenSpaceParent.addChild(damageEffectRoot)
        damageEffectRoot.zPosition = 70
        usesScreenSpaceDamageEffects = true
    }

    func updateDamageEffectScreenPosition(_ position: CGPoint, fighterScale: CGFloat) {
        guard usesScreenSpaceDamageEffects else { return }
        damageEffectRoot.position = CGPoint(
            x: position.x,
            y: position.y + 62 * fighterScale
        )
        damageEffectRoot.setScale(fighterScale)
    }

    func updateDamageEffectAnchor(_ position: CGPoint, scale: CGFloat = 1) {
        guard usesScreenSpaceDamageEffects else { return }
        damageEffectRoot.position = position
        damageEffectRoot.setScale(scale)
    }

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
        locomotion = FighterLocomotionController(style: motionStyle)
        rig = FighterRig(facing: facing, appearance: appearance)
        threeDRenderer = Fighter3DRenderer(
            appearance: appearance,
            motionStyle: motionStyle
        )
        usesThreeDRenderer = !ProcessInfo.processInfo.arguments.contains("--legacy-2d-fighters")
        super.init()
        addChild(rig.animationRoot)
        addChild(threeDRenderer.spriteNode)
        damageEffectRoot.position = CGPoint(x: 0, y: 62)
        damageEffectRoot.zPosition = 56
        addChild(damageEffectRoot)
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
        if phase != .swaying { removeAction(forKey: "swayReturn") }
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
            let entryDuration = CombatTuning.swayDuration
                * Double(CombatTuning.swayEntryFraction)
            let holdDuration = CombatTuning.swayDuration
                * Double(CombatTuning.swayHoldFraction)
            let returnDuration = max(
                CombatTuning.swayDuration - entryDuration - holdDuration,
                0.01
            )
            transition(
                to: FighterPoseResolver.sway(
                    activeSwayDirection,
                    screenDirection: activeSwayScreenDirection,
                    facing: facing,
                    performance: activeSwayPerformance
                ),
                duration: entryDuration,
                style: .evasive
            )
            run(.sequence([
                .wait(forDuration: entryDuration + holdDuration),
                .run { [weak self] in
                    self?.transition(
                        to: .guardPose,
                        duration: returnDuration,
                        style: .settle
                    )
                }
            ]), withKey: "swayReturn")
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
            ? CombatTuning.counterHitReactionAnimationDuration
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

    func updateDamage(fraction: CGFloat) {
        let tier = fraction <= 0.18 ? 2 : (fraction <= 0.38 ? 1 : 0)
        guard tier != damageVisualTier else { return }
        damageVisualTier = tier
        damageEffectRoot.removeAllActions()
        damageEffectRoot.removeAllChildren()
        guard tier > 0 else { return }

        let sparkInterval = tier == 2 ? 0.42 : 0.92
        damageEffectRoot.run(.repeatForever(.sequence([
            .wait(forDuration: sparkInterval),
            .run { [weak self] in self?.spawnFaultSparks(severity: tier) }
        ])), withKey: "faultSparks")

        let smokeInterval = tier == 2 ? 0.68 : 1.35
        damageEffectRoot.run(.repeatForever(.sequence([
            .wait(forDuration: smokeInterval),
            .run { [weak self] in self?.spawnFaultSmoke(severity: tier) }
        ])), withKey: "faultSmoke")
        spawnFaultSparks(severity: tier)
        spawnFaultSmoke(severity: tier)
    }

    private func spawnFaultSparks(severity: Int) {
        let origin = CGPoint(
            x: severity == 2 ? CGFloat.random(in: -13...14) : 10,
            y: CGFloat.random(in: 7...23)
        )
        for index in 0..<(severity == 2 ? 6 : 3) {
            let angle = CGFloat.random(in: 0.18...2.96)
            let distance = CGFloat.random(in: 11...27)
            let sparkPath = CGMutablePath()
            sparkPath.move(to: CGPoint(x: -CGFloat.random(in: 1.5...3.5), y: 0))
            sparkPath.addLine(to: CGPoint(x: CGFloat.random(in: 2.5...6.5), y: 0))
            let spark = SKShapeNode(path: sparkPath)
            spark.position = origin
            spark.zRotation = angle
            spark.strokeColor = index.isMultiple(of: 3)
                ? ArenaVisualPalette.whiteMark
                : ArenaVisualPalette.amberSignal
            spark.lineWidth = index.isMultiple(of: 2) ? 1.25 : 0.8
            spark.lineCap = .round
            spark.glowWidth = 1.4
            damageEffectRoot.addChild(spark)
            spark.run(.sequence([
                .group([
                    .moveBy(
                        x: cos(angle) * distance,
                        y: sin(angle) * distance,
                        duration: 0.13
                    ),
                    .fadeAlpha(to: 0.55, duration: 0.13)
                ]),
                .group([
                    .moveBy(x: cos(angle) * distance * 0.35, y: -9, duration: 0.16),
                    .fadeOut(withDuration: 0.16)
                ]),
                .removeFromParent()
            ]))
        }
    }

    private func spawnFaultSmoke(severity: Int) {
        let cloud = SKNode()
        cloud.position = CGPoint(x: CGFloat.random(in: -8...9), y: 12)
        damageEffectRoot.addChild(cloud)
        for index in 0..<3 {
            let radius = CGFloat(severity == 2 ? 5.5 : 4.2) + CGFloat(index) * 0.8
            let puff = SKShapeNode(path: smokePuffPath(radius: radius, phase: index))
            puff.position = CGPoint(x: CGFloat(index - 1) * 3.5, y: CGFloat(index) * 2)
            puff.fillColor = SKColor(
                white: 0.20 + CGFloat(index) * 0.035,
                alpha: severity == 2 ? 0.30 : 0.20
            )
            puff.strokeColor = SKColor(white: 0.38, alpha: 0.08)
            puff.lineWidth = 0.6
            puff.alpha = 0
            puff.setScale(0.65)
            cloud.addChild(puff)
            puff.run(.sequence([
                .wait(forDuration: Double(index) * 0.065),
                .group([
                    .fadeAlpha(to: severity == 2 ? 0.46 : 0.32, duration: 0.16),
                    .scale(to: 1.12, duration: 0.16)
                ]),
                .group([
                    .moveBy(
                        x: CGFloat.random(in: -6...7),
                        y: 28 + CGFloat(index) * 5,
                        duration: 0.78
                    ),
                    .scale(to: 2.05 + CGFloat(index) * 0.14, duration: 0.78),
                    .fadeOut(withDuration: 0.78)
                ])
            ]))
        }
        cloud.run(.sequence([.wait(forDuration: 1.18), .removeFromParent()]))
    }

    private func smokePuffPath(radius: CGFloat, phase: Int) -> CGPath {
        let path = CGMutablePath()
        let points = 12
        for index in 0..<points {
            let angle = CGFloat(index) / CGFloat(points) * .pi * 2
            let modulation = 0.82 + CGFloat((index * 7 + phase * 5) % 5) * 0.075
            let point = CGPoint(
                x: cos(angle) * radius * modulation,
                y: sin(angle) * radius * modulation
            )
            index == 0 ? path.move(to: point) : path.addLine(to: point)
        }
        path.closeSubpath()
        return path
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
        updateDamage(fraction: 1)
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
        // The 3D renderer collapses its articulated rig around the fighter's
        // ring anchor. Moving and rotating the entire FighterNode as well was
        // a legacy 2D fall and made the enlarged character launch across the
        // screen while the camera continued tracking the unchanged anchor.
        guard !usesThreeDRenderer else { return }
        let fall = SKAction.group([
            .rotate(toAngle: -facing * 1.35, duration: CombatTuning.knockoutDuration, shortestUnitArc: true),
            .moveBy(x: -facing * 34, y: -28, duration: CombatTuning.knockoutDuration)
        ])
        fall.timingMode = .easeIn
        run(fall)
    }

}
