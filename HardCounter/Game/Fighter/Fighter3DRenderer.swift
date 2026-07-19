import SceneKit
import SpriteKit

/// Experimental presentation-only renderer. Combat, input, hit detection and
/// networking continue to use FighterNode; this object only replaces its art.
final class Fighter3DRenderer {
    let spriteNode: SK3DNode
    private let motionStyle: Fighter3DMotionStyle
    private let motionProfile: Fighter3DMotionProfile
    private let soleClearance: CGFloat

    private let presentationRoot = SCNNode()
    private let skeletonRoot = SCNNode()
    private let pelvis = SCNNode()
    private let spine = SCNNode()
    private let head = SCNNode()
    private let leadShoulder = SCNNode()
    private let leadElbow = SCNNode()
    private let rearShoulder = SCNNode()
    private let rearElbow = SCNNode()
    private let leadHip = SCNNode()
    private let leadKnee = SCNNode()
    private let leadAnkle = SCNNode()
    private let rearHip = SCNNode()
    private let rearKnee = SCNNode()
    private let rearAnkle = SCNNode()
    private var leadFootIK: SCNIKConstraint?
    private var rearFootIK: SCNIKConstraint?
    private var leadFootPlantTarget: SCNVector3?
    private var rearFootPlantTarget: SCNVector3?
    private var neutralLeadFootPosition: SCNVector3?
    private var neutralRearFootPosition: SCNVector3?
    private var leadFootStepStart: SCNVector3?
    private var rearFootStepStart: SCNVector3?
    private var previousStepProgress: CGFloat = 1
    private var previousInitiatingFoot: FighterSupportFoot = .both
    private var rigGroundingOffset: CGFloat = 0
    private var armActuators: [SCNNode] = []
    private var legActuators: [SCNNode] = []
    private var powerCore: SCNNode?

    private var phase: FighterPhase = .idle
    private var phaseElapsed: TimeInterval = 0
    private var activeHand: PunchHand = .lead
    private var punchProfile = PunchProfile()
    private var swayScreenDirection = CGVector(dx: -1, dy: 0)
    private var swayPerformance: CGFloat = 1
    private var opponentScreenDirection = CGVector(dx: 1, dy: 0)
    private var facingSign: CGFloat = 1
    private var hitElapsed: TimeInterval?
    private var hitKind: HitKind = .normal
    private var hitProfile = PunchProfile()
    private var followThrough: CGFloat = 0
    private var whiffOverreach: CGFloat = 0
    private var punchMotionClip: Fighter3DMotionClip?
    private var swayMotionClip: Fighter3DMotionClip?
    private var targetStaminaFraction: CGFloat = 1
    private var displayedStaminaFraction: CGFloat = 1
    private var lastAppliedPose = Fighter3DPose.guardPose
    private var knockoutStartPose = Fighter3DPose.guardPose

    init(appearance: FighterAppearance, motionStyle: Fighter3DMotionStyle) {
        self.motionStyle = motionStyle
        motionProfile = motionStyle.profile
        let proportions = Fighter3DAppearanceProfile(appearance: appearance)
        // The ankle target represents the center of the joint, while contact
        // happens at the lowest of the boot cuff and shoe box.
        // Leave a tiny presentation gap above raised seams/markings on the
        // canvas; otherwise correct contact still reads as mesh intersection.
        soleClearance = max(0.13, 0.06 + proportions.shoeHeight * 0.5) + 0.025
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        spriteNode = SK3DNode(viewportSize: CGSize(width: 192, height: 232))
        spriteNode.scnScene = scene
        spriteNode.position = CGPoint(x: 0, y: 60)
        spriteNode.zPosition = 20
        spriteNode.isPlaying = true
        spriteNode.loops = true
        spriteNode.isUserInteractionEnabled = false

        buildCamera(in: scene)
        buildLights(in: scene)
        buildFighter(in: scene, appearance: appearance)
        apply(guardPose)
        calibrateRigGrounding()
        apply(guardPose)
        captureNeutralFootPositions()
    }

    func show(phase newPhase: FighterPhase) {
        phase = newPhase
        phaseElapsed = 0
        if newPhase == .knockedOut {
            knockoutStartPose = lastAppliedPose
            hitElapsed = nil
            followThrough = 0
            whiffOverreach = 0
        }
        if newPhase == .idle {
            followThrough = 0
            whiffOverreach = 0
            hitElapsed = nil
        }
    }

    func preparePunch(_ hand: PunchHand, profile: PunchProfile) {
        activeHand = hand
        punchProfile = profile
        punchMotionClip = makePunchMotionClip()
    }

    func prepareSway(
        _: SwayDirection,
        screenDirection: CGVector,
        performance: CGFloat
    ) {
        swayScreenDirection = screenDirection
        swayPerformance = performance
        swayMotionClip = makeSwayMotionClip()
    }

    func playHit(_ kind: HitKind, profile: PunchProfile) {
        hitKind = kind
        hitProfile = profile
        hitElapsed = 0
    }

    func playHitConfirm(_ profile: PunchProfile) {
        followThrough = CGFloat(0.55 + profile.powerScale * 0.35)
    }

    func playWhiff(_ profile: PunchProfile) {
        whiffOverreach = CGFloat(0.65 + profile.powerScale * 0.25)
    }

    func updateStamina(fraction: CGFloat) {
        targetStaminaFraction = min(max(fraction, 0), 1)
    }

    func reset() {
        phase = .idle
        phaseElapsed = 0
        hitElapsed = nil
        followThrough = 0
        whiffOverreach = 0
        punchMotionClip = nil
        swayMotionClip = nil
        targetStaminaFraction = 1
        displayedStaminaFraction = 1
        lastAppliedPose = guardPose
        leadFootPlantTarget = nil
        rearFootPlantTarget = nil
        leadFootStepStart = nil
        rearFootStepStart = nil
        previousStepProgress = 1
        previousInitiatingFoot = .both
        skeletonRoot.opacity = 1
        apply(guardPose)
    }

    /// Moves this fighter's live rig into a shared SceneKit stage. Pose updates
    /// continue to target the same skeleton; only the presentation parent and
    /// camera change.
    func attachPresentation(to parent: SCNNode) {
        presentationRoot.removeFromParentNode()
        parent.addChildNode(presentationRoot)
    }

    func setSharedStageTransform(position: SCNVector3, scale: Float) {
        presentationRoot.position = position
        presentationRoot.scale = SCNVector3(scale, scale, scale)
    }

    /// Live presentation-space anchors used by the shared arena. These come
    /// from the animated rig rather than an estimated offset above the feet.
    func sharedBodyWorldPosition(for technique: PunchTechnique = .straight) -> SCNVector3 {
        let localPoint: SCNVector3
        switch technique {
        case .straight:
            localPoint = SCNVector3(0, 0.62, 0)
        case .smash:
            localPoint = SCNVector3(0, 0.82, 0)
        case .uppercut:
            localPoint = SCNVector3(0, 1.08, 0)
        }
        return spine.presentation.convertPosition(localPoint, to: nil)
    }

    func sharedDamageWorldPosition() -> SCNVector3 {
        spine.presentation.convertPosition(SCNVector3(0, 0.56, 0), to: nil)
    }

    func update(
        movement: FighterMovementState,
        orientation: FighterOrientationFrame,
        locomotionFrame: FighterLocomotionFrame,
        deltaTime: TimeInterval
    ) {
        guard deltaTime > 0 else { return }
        phaseElapsed += deltaTime
        if hitElapsed != nil { hitElapsed! += deltaTime }
        let staminaBlend = 1 - exp(-CGFloat(deltaTime) * 7.5)
        displayedStaminaFraction += (
            targetStaminaFraction - displayedStaminaFraction
        ) * staminaBlend

        let direction = orientation.direction
        opponentScreenDirection = direction
        facingSign = orientation.facing
        skeletonRoot.eulerAngles.y = Float(atan2(direction.dx, -direction.dy))

        let movementAmount = min(hypot(
            movement.screenMovement.dx,
            movement.screenMovement.dy
        ), 1)

        var pose = poseForCurrentPhase(
            movementAmount: movementAmount,
            locomotionFrame: locomotionFrame
        )
        pose = FighterFullBodyPoseSolver.apply(
            body: movement.bodyMotion,
            to: pose
        )
        if let hitElapsed {
            let duration = hitKind == .counter
                ? CombatTuning.counterHitReaction
                : CombatTuning.hitReaction
            let t = CGFloat(min(hitElapsed / max(duration, 0.001), 1))
            let hitPose = Fighter3DPose.hit(
                technique: hitProfile.technique,
                strength: (hitKind == .counter ? 1.25 : 1)
                    * CombatTuning.hitReactionAmplitude
            ).styled(with: motionProfile)
            let envelope = t < 0.22
                ? smooth(t / 0.22)
                : 1 - smooth((t - 0.22) / 0.78)
            pose = pose.blended(to: hitPose, amount: envelope)
            if t >= 1 { self.hitElapsed = nil }
        }

        if followThrough > 0 {
            applyHitConfirm(to: &pose, amount: followThrough)
            followThrough = max(followThrough - CGFloat(deltaTime) * 7.5, 0)
        }
        if whiffOverreach > 0 {
            applyWhiff(to: &pose, amount: whiffOverreach)
            whiffOverreach = max(whiffOverreach - CGFloat(deltaTime) * 4.5, 0)
        }
        let fatigue = 1 - min(displayedStaminaFraction / 0.28, 1)
        let fatigueBreath = sin(CGFloat(phaseElapsed) * 5.2)
        pose = pose.fatigued(amount: fatigue, breath: fatigueBreath)
        pose = inertializedPose(
            toward: pose,
            movementAmount: movementAmount,
            deltaTime: deltaTime
        )
        apply(
            pose,
            locomotionFrame: locomotionFrame,
            bodyMotion: movement.bodyMotion
        )
    }

    private func applyHitConfirm(to pose: inout Fighter3DPose, amount: CGFloat) {
        let drive = amount
            * CGFloat(min(max(punchProfile.powerScale, 0.65), 1.30))
            * CombatTuning.punchMotionAmplitude
        let handSign: CGFloat = activeHand == .lead ? -1 : 1
        switch punchProfile.technique {
        case .straight:
            pose.rootZ += 0.10 * drive
            pose.spinePitch += 0.055 * drive
            pose.pelvis.y += Float(0.08 * handSign * drive)
        case .smash:
            pose.rootZ += 0.07 * drive
            pose.rootRoll += 0.04 * handSign * drive
            pose.pelvis.y += Float(0.16 * handSign * drive)
            pose.spine.y += Float(0.20 * handSign * drive)
        case .uppercut:
            pose.rootY += 0.07 * drive
            pose.rootZ += 0.05 * drive
            pose.spinePitch -= 0.09 * drive
            pose.leadKnee.x -= activeHand == .lead ? Float(0.05 * drive) : 0
            pose.rearKnee.x -= activeHand == .rear ? Float(0.05 * drive) : 0
        }
    }

    private func applyWhiff(to pose: inout Fighter3DPose, amount: CGFloat) {
        let overreach = amount
            * CGFloat(min(max(punchProfile.powerScale, 0.65), 1.30))
            * CombatTuning.punchMotionAmplitude
        let handSign: CGFloat = activeHand == .lead ? -1 : 1
        switch punchProfile.technique {
        case .straight:
            pose.rootZ += 0.15 * overreach
            pose.rootY -= 0.025 * overreach
            pose.spinePitch += 0.11 * overreach
        case .smash:
            pose.rootZ += 0.09 * overreach
            pose.rootRoll += 0.07 * handSign * overreach
            pose.spine.y += Float(0.24 * handSign * overreach)
        case .uppercut:
            pose.rootZ += 0.10 * overreach
            pose.rootY += 0.045 * overreach
            pose.spinePitch -= 0.15 * overreach
        }
    }

    private func poseForCurrentPhase(
        movementAmount: CGFloat,
        locomotionFrame: FighterLocomotionFrame
    ) -> Fighter3DPose {
        let movingGuard = locomotionGuardPose(
            movementAmount: movementAmount,
            locomotionFrame: locomotionFrame
        )
        switch phase {
        case .idle:
            return movingGuard

        case .punchStartup:
            let duration = CombatTuning.punchStartup * punchProfile.startupScale
            let clip = punchMotionClip ?? makePunchMotionClip()
            return clip.sample(at: progress(duration) * 0.36)
                .applyingLocomotion(movingGuard, relativeTo: guardPose, upperBodyAmount: 0.18)

        case .punchActive:
            let duration = CombatTuning.punchActive * punchProfile.activeScale
            let clip = punchMotionClip ?? makePunchMotionClip()
            return clip.sample(at: 0.36 + progress(duration) * 0.24)
                .applyingLocomotion(movingGuard, relativeTo: guardPose, upperBodyAmount: 0.10)

        case .punchRecovery:
            let duration = CombatTuning.punchRecovery * punchProfile.recoveryScale
            let clip = punchMotionClip ?? makePunchMotionClip()
            let weightedRecovery = pow(
                progress(duration),
                max(motionProfile.recoveryWeight, 0.2)
            )
            return clip.sample(at: 0.60 + weightedRecovery * 0.40)
                .applyingLocomotion(movingGuard, relativeTo: guardPose, upperBodyAmount: 0.14)

        case .swaying:
            let clip = swayMotionClip ?? makeSwayMotionClip()
            return clip.sample(at: progress(CombatTuning.swayDuration))
                .applyingLocomotion(movingGuard, relativeTo: guardPose, upperBodyAmount: 0.08)

        case .hit:
            return movingGuard

        case .knockedOut:
            let progress = progress(CombatTuning.knockoutDuration)
            var bucklePose = knockoutStartPose
            bucklePose.rootY -= 0.20
            bucklePose.rootZ -= 0.04
            bucklePose.rootPitch += 0.10
            bucklePose.rootRoll -= 0.06
            bucklePose.spinePitch += 0.12
            bucklePose.leadKnee.x += 0.30
            bucklePose.rearKnee.x += 0.34
            if progress < 0.34 {
                return knockoutStartPose.blended(
                    to: bucklePose,
                    amount: smooth(progress / 0.34)
                )
            }
            let fallProgress = min(max((progress - 0.34) / 0.66, 0), 1)
            return bucklePose.blended(
                to: Fighter3DPose.knockedOut.styled(with: motionProfile),
                amount: fallProgress * fallProgress
            )
        }
    }

    private func makePunchMotionClip() -> Fighter3DMotionClip {
        let guardPose = guardPose
        let loadPose = punchLoadPose
        let power = CGFloat(min(max(punchProfile.powerScale, 0.7), 1.3))
        let strikePose = punchStrikePose(power: power)
        let handSign: CGFloat = activeHand == .lead ? -1 : 1

        var coilPose = guardPose.stagedBlend(
            to: loadPose,
            lowerBody: 0.88,
            torso: 0.70,
            arms: 0.46
        )
        coilPose.rootY -= 0.065
        coilPose.rootZ -= 0.050
        coilPose.pelvis.y -= Float(handSign * 0.105)
        coilPose.spine.y -= Float(handSign * 0.065)
        coilPose.leadKnee.x += activeHand == .rear ? 0.07 : 0.11
        coilPose.rearKnee.x += activeHand == .rear ? 0.12 : 0.07
        coilPose = FighterFullBodyActionPoseSolver.strike(
            frame: FighterFullBodyActionFrame(
                forward: -0.18,
                lateral: handSign * 0.18,
                screenHorizontal: 0,
                screenVertical: 0,
                intensity: power,
                compression: 0.72,
                weightShift: activeHand == .rear ? -0.82 : 0.68,
                reach: -0.12
            ),
            hand: activeHand,
            technique: punchProfile.technique,
            to: coilPose
        )

        var drivePose = loadPose.stagedBlend(
            to: strikePose,
            lowerBody: 0.86,
            torso: 0.58,
            arms: 0.18
        )
        drivePose.rootY += punchProfile.technique == .uppercut ? 0.085 : 0.020
        drivePose.rootZ += 0.105 * power
        drivePose.pelvis.y += Float(handSign * 0.16 * power)
        drivePose.spine.y += Float(handSign * 0.105 * power)
        if activeHand == .rear {
            drivePose.rearKnee.x -= Float(0.10 * power)
            drivePose.rearAnklePitch += 0.10 * power
        } else {
            drivePose.leadKnee.x -= Float(0.08 * power)
            drivePose.leadAnklePitch += 0.08 * power
        }
        drivePose = FighterFullBodyActionPoseSolver.strike(
            frame: FighterFullBodyActionFrame(
                forward: 0.72,
                lateral: handSign * 0.20,
                screenHorizontal: 0,
                screenVertical: 0,
                intensity: power,
                compression: 0.48,
                weightShift: activeHand == .rear ? -0.25 : 0.28,
                reach: 0.48
            ),
            hand: activeHand,
            technique: punchProfile.technique,
            to: drivePose
        )

        let connectedStrikePose = FighterFullBodyActionPoseSolver.strike(
            frame: FighterFullBodyActionFrame(
                forward: 1,
                lateral: handSign * 0.30,
                screenHorizontal: 0,
                screenVertical: 0,
                intensity: power,
                compression: punchProfile.technique == .uppercut ? 0.12 : 0.20,
                weightShift: activeHand == .rear ? 0.72 : -0.42,
                reach: 1
            ),
            hand: activeHand,
            technique: punchProfile.technique,
            to: strikePose
        )

        var followPose = connectedStrikePose
        switch punchProfile.technique {
        case .straight:
            followPose.rootZ += 0.15 * power
            followPose.rootRoll += handSign * 0.050 * power
            followPose.pelvis.y += Float(handSign * 0.15 * power)
            followPose.spine.y += Float(handSign * 0.21 * power)
            followPose.spinePitch += 0.095 * power
        case .smash:
            followPose.rootZ += 0.12 * power
            followPose.rootRoll += handSign * 0.070 * power
            followPose.pelvis.y += Float(handSign * 0.22 * power)
            followPose.spine.y += Float(handSign * 0.28 * power)
        case .uppercut:
            followPose.rootY += 0.15 * power
            followPose.rootZ += 0.09 * power
            followPose.spinePitch += 0.15 * power
        }

        var recoilPose = followPose.stagedBlend(
            to: guardPose,
            lowerBody: 0.34,
            torso: 0.48,
            arms: 0.82
        )
        recoilPose.rootY -= 0.035
        recoilPose.rootZ += 0.025
        recoilPose.leadKnee.x += 0.055
        recoilPose.rearKnee.x += 0.055

        return Fighter3DMotionClip(keyframes: [
            Fighter3DMotionKeyframe(position: 0.00, pose: guardPose, arrivalCurve: .linear),
            Fighter3DMotionKeyframe(position: 0.18, pose: coilPose, arrivalCurve: .smooth),
            Fighter3DMotionKeyframe(position: 0.36, pose: loadPose, arrivalCurve: .smooth),
            Fighter3DMotionKeyframe(position: 0.48, pose: drivePose, arrivalCurve: .explosive),
            Fighter3DMotionKeyframe(position: 0.60, pose: connectedStrikePose, arrivalCurve: .explosive),
            Fighter3DMotionKeyframe(position: 0.72, pose: followPose, arrivalCurve: .smooth),
            Fighter3DMotionKeyframe(position: 0.86, pose: recoilPose, arrivalCurve: .settle),
            Fighter3DMotionKeyframe(position: 1.00, pose: guardPose, arrivalCurve: .settle)
        ])
    }

    private func makeSwayMotionClip() -> Fighter3DMotionClip {
        let guardPose = guardPose
        let components = swayMotionComponents()
        let performance = min(max(swayPerformance, 0.72), 1.20)
        let swayLength = max(hypot(swayScreenDirection.dx, swayScreenDirection.dy), 0.001)
        let screenHorizontal = swayScreenDirection.dx / swayLength
        let screenVertical = swayScreenDirection.dy / swayLength
        let loadFrame = FighterFullBodyActionFrame(
            forward: components.forward * 0.22,
            lateral: -components.lateral * 0.18,
            screenHorizontal: -screenHorizontal * 0.18,
            screenVertical: -screenVertical * 0.18,
            intensity: performance,
            compression: 0.58,
            weightShift: -components.lateral * 0.35,
            reach: 0
        )
        let loadPose = FighterFullBodyActionPoseSolver.sway(
            frame: loadFrame,
            from: guardPose
        )

        let evadeFrame = FighterFullBodyActionFrame(
            forward: components.forward,
            lateral: components.lateral,
            screenHorizontal: screenHorizontal,
            screenVertical: screenVertical,
            intensity: performance * motionProfile.swayRange,
            compression: 0.88 + abs(components.forward) * 0.18,
            weightShift: components.lateral,
            reach: 0
        )
        var evadePose = FighterFullBodyActionPoseSolver.sway(
            frame: evadeFrame,
            from: guardPose
        )
        applyGuardIdentity(to: &evadePose)

        let apexFrame = FighterFullBodyActionFrame(
            forward: components.forward * 1.12,
            lateral: components.lateral * 1.14,
            screenHorizontal: screenHorizontal * 1.14,
            screenVertical: screenVertical * 1.14,
            intensity: performance * motionProfile.swayRange,
            compression: 1.0,
            weightShift: components.lateral,
            reach: 0
        )
        var apexPose = FighterFullBodyActionPoseSolver.sway(
            frame: apexFrame,
            from: guardPose
        )
        applyGuardIdentity(to: &apexPose)

        var recoveryPose = apexPose.stagedBlend(
            to: guardPose,
            lowerBody: 0.52,
            torso: 0.40,
            arms: 0.58
        )
        recoveryPose.rootY -= 0.025
        recoveryPose.leadKnee.x += 0.035
        recoveryPose.rearKnee.x += 0.035

        return Fighter3DMotionClip(keyframes: [
            Fighter3DMotionKeyframe(position: 0.00, pose: guardPose, arrivalCurve: .linear),
            Fighter3DMotionKeyframe(position: 0.08, pose: loadPose, arrivalCurve: .explosive),
            Fighter3DMotionKeyframe(position: 0.20, pose: evadePose, arrivalCurve: .explosive),
            Fighter3DMotionKeyframe(position: 0.34, pose: apexPose, arrivalCurve: .smooth),
            Fighter3DMotionKeyframe(position: 0.48, pose: apexPose, arrivalCurve: .hold),
            Fighter3DMotionKeyframe(position: 0.87, pose: recoveryPose, arrivalCurve: .smooth),
            Fighter3DMotionKeyframe(position: 1.00, pose: guardPose, arrivalCurve: .settle)
        ])
    }

    private func swayMotionComponents() -> (forward: CGFloat, lateral: CGFloat) {
        let swayLength = max(hypot(swayScreenDirection.dx, swayScreenDirection.dy), 0.001)
        let facingLength = max(hypot(opponentScreenDirection.dx, opponentScreenDirection.dy), 0.001)
        let sway = CGVector(dx: swayScreenDirection.dx / swayLength, dy: swayScreenDirection.dy / swayLength)
        let facing = CGVector(dx: opponentScreenDirection.dx / facingLength, dy: opponentScreenDirection.dy / facingLength)
        return (
            sway.dx * facing.dx + sway.dy * facing.dy,
            sway.dx * -facing.dy + sway.dy * facing.dx
        )
    }

    private func locomotionGuardPose(
        movementAmount: CGFloat,
        locomotionFrame: FighterLocomotionFrame
    ) -> Fighter3DPose {
        var pose = guardPose
        let breath = sin(CGFloat(phaseElapsed) * motionProfile.breathFrequency)
        let idleAmount = max(1 - movementAmount * 2.2, 0)
        let weightShift = sin(
            CGFloat(phaseElapsed) * motionProfile.breathFrequency * 0.54 + 0.65
        ) * idleAmount * motionProfile.idleWeightShift
        pose.spineY += breath * 0.015 * motionProfile.breathAmplitude
        pose.spinePitch += breath * 0.018 * motionProfile.breathAmplitude
        pose.spineX += weightShift * 0.018
        pose.pelvisRoll += weightShift * 0.022
        pose.spineRoll -= weightShift * 0.016
        pose.head.z += Float(weightShift * 0.012)

        let leadLift = min(
            max(locomotionFrame.frontAnkleLift / 0.105, 0) * motionProfile.footLift,
            1.35
        )
        let rearLift = min(
            max(locomotionFrame.backAnkleLift / 0.105, 0) * motionProfile.footLift,
            1.35
        )
        let activeLift = max(leadLift, rearLift)
        let settlingActivity = max(
            activeLift,
            min(abs(locomotionFrame.pelvisCompression) * 0.22, 1),
            min(hypot(
                locomotionFrame.upperBodyPosition.x,
                locomotionFrame.upperBodyPosition.y
            ) * 0.12, 1)
        )
        guard movementAmount > 0.025 || settlingActivity > 0.025 else { return pose }

        pose = makeLocomotionMotionClip(
            frame: locomotionFrame,
            movementAmount: movementAmount
        ).sample(at: locomotionFrame.stepProgress)
        pose.spineY += breath * idleAmount * 0.015 * motionProfile.breathAmplitude
        pose.pelvisRoll += locomotionFrame.pelvisRotation * 0.82
        pose.spineRoll += locomotionFrame.upperBodyRotation * 0.68

        let guardRhythm = (leadLift - rearLift) * 0.065
            * motionProfile.strideCadence * motionProfile.guardRhythm
        pose.leadShoulder.z += Float(guardRhythm)
        pose.leadElbow.z -= Float(guardRhythm * 0.72)
        pose.rearShoulder.z -= Float(guardRhythm * 0.82)
        pose.rearElbow.z += Float(guardRhythm * 0.58)

        let screenUpperX = locomotionFrame.upperBodyPosition.x * facingSign * 0.012
        let bodyYaw = atan2(
            opponentScreenDirection.dx,
            -opponentScreenDirection.dy
        ) + CGFloat(pose.pelvis.y)
        pose.spineX += screenUpperX * cos(bodyYaw)
        pose.spineZ += screenUpperX * sin(bodyYaw)
        pose.spineY += locomotionFrame.upperBodyPosition.y * 0.007
        applyFootworkIdentity(
            to: &pose,
            movementAmount: movementAmount,
            leadLift: leadLift,
            rearLift: rearLift,
            locomotionFrame: locomotionFrame
        )
        return pose
    }

    private func makeLocomotionMotionClip(
        frame: FighterLocomotionFrame,
        movementAmount: CGFloat
    ) -> Fighter3DMotionClip {
        let guardPose = guardPose
        let intensity = max(frame.movementIntensity, movementAmount * 0.35)
        let stride = motionProfile.strideLength
        let forward = frame.forwardDrive
        let lateral = frame.lateralDrive
        let movingLead = frame.frontFootInitiates
        let supportSign: CGFloat = movingLead ? 1 : -1

        var loadPose = guardPose
        loadPose.rootY -= 0.075 * intensity
        loadPose.rootZ -= forward * 0.035 * intensity
        loadPose.pelvis.y -= Float(lateral * 0.095 * intensity)
        loadPose.spine.y += Float(lateral * 0.045 * intensity)
        loadPose.leadKnee.x += Float((movingLead ? 0.055 : 0.115) * intensity)
        loadPose.rearKnee.x += Float((movingLead ? 0.115 : 0.055) * intensity)
        loadPose.pelvisRoll += supportSign * 0.035 * intensity
        loadPose.spineRoll -= supportSign * 0.026 * intensity

        var pushPose = loadPose
        pushPose.rootZ += forward * 0.090 * intensity
        pushPose.rootX += lateral * 0.065 * intensity
        pushPose.pelvis.y += Float(lateral * 0.145 * intensity)
        pushPose.spine.y -= Float(lateral * 0.075 * intensity)
        if movingLead {
            pushPose.rearKnee.x -= Float(0.075 * intensity)
            pushPose.rearAnklePitch += 0.09 * intensity
            pushPose.leadHip.x += Float((0.13 + forward * 0.15) * stride * intensity)
            pushPose.leadHip.z += Float(lateral * 0.13 * intensity)
            pushPose.leadKnee.x += Float(0.27 * intensity)
        } else {
            pushPose.leadKnee.x -= Float(0.075 * intensity)
            pushPose.leadAnklePitch += 0.09 * intensity
            pushPose.rearHip.x += Float((0.13 + forward * 0.15) * stride * intensity)
            pushPose.rearHip.z += Float(lateral * 0.13 * intensity)
            pushPose.rearKnee.x += Float(0.27 * intensity)
        }

        var travelPose = pushPose
        travelPose.rootY += 0.050 * motionProfile.footworkBounce * intensity
        travelPose.rootZ += forward * 0.055 * intensity
        travelPose.rootX += lateral * 0.045 * intensity
        travelPose.pelvisRoll -= supportSign * 0.055 * intensity
        travelPose.spineRoll += supportSign * 0.043 * intensity
        if movingLead {
            travelPose.leadHip.x += Float(0.08 * stride * intensity)
            travelPose.leadKnee.x += Float(0.12 * intensity)
            travelPose.leadAnklePitch += 0.12 * intensity
        } else {
            travelPose.rearHip.x += Float(0.08 * stride * intensity)
            travelPose.rearKnee.x += Float(0.12 * intensity)
            travelPose.rearAnklePitch += 0.12 * intensity
        }

        var catchPose = guardPose
        catchPose.rootY -= 0.075 * intensity
        catchPose.rootZ += forward * 0.045 * intensity
        catchPose.rootX += lateral * 0.035 * intensity
        catchPose.pelvis.y += Float(lateral * 0.090 * intensity)
        catchPose.pelvisRoll -= supportSign * 0.032 * intensity
        catchPose.spineRoll += supportSign * 0.025 * intensity
        if movingLead {
            catchPose.rearHip.x += Float((0.08 + forward * 0.08) * stride * intensity)
            catchPose.rearKnee.x += Float(0.23 * intensity)
            catchPose.rearAnklePitch += 0.09 * intensity
        } else {
            catchPose.leadHip.x += Float((0.08 + forward * 0.08) * stride * intensity)
            catchPose.leadKnee.x += Float(0.23 * intensity)
            catchPose.leadAnklePitch += 0.09 * intensity
        }

        var settlePose = guardPose
        settlePose.rootY -= frame.landingAmount * 0.018
        settlePose.rootZ += forward * 0.018 * intensity
        settlePose.rootX += lateral * 0.012 * intensity
        settlePose.leadKnee.x += Float(0.035 * intensity)
        settlePose.rearKnee.x += Float(0.035 * intensity)

        let timing: (
            load: CGFloat,
            push: CGFloat,
            travel: CGFloat,
            catch: CGFloat,
            settle: CGFloat
        )
        switch motionStyle {
        case .allRounder:
            timing = (0.13, 0.28, 0.43, 0.65, 0.83)
        case .pressure:
            timing = (0.15, 0.31, 0.46, 0.68, 0.86)
        case .outBoxer:
            timing = (0.09, 0.23, 0.38, 0.58, 0.76)
        case .rival:
            timing = (0.13, 0.29, 0.44, 0.66, 0.84)
        }

        return Fighter3DMotionClip(keyframes: [
            Fighter3DMotionKeyframe(position: 0.00, pose: guardPose, arrivalCurve: .linear),
            Fighter3DMotionKeyframe(position: timing.load, pose: loadPose, arrivalCurve: .smooth),
            Fighter3DMotionKeyframe(position: timing.push, pose: pushPose, arrivalCurve: .explosive),
            Fighter3DMotionKeyframe(position: timing.travel, pose: travelPose, arrivalCurve: .smooth),
            Fighter3DMotionKeyframe(position: timing.catch, pose: catchPose, arrivalCurve: .explosive),
            Fighter3DMotionKeyframe(position: timing.settle, pose: settlePose, arrivalCurve: .settle),
            Fighter3DMotionKeyframe(position: 1.00, pose: guardPose, arrivalCurve: .settle)
        ])
    }

    private func applyFootworkIdentity(
        to pose: inout Fighter3DPose,
        movementAmount: CGFloat,
        leadLift: CGFloat,
        rearLift: CGFloat,
        locomotionFrame: FighterLocomotionFrame
    ) {
        let stepDifference = leadLift - rearLift
        let rhythm = sin(CGFloat(phaseElapsed) * motionProfile.breathFrequency)
        switch motionStyle {
        case .allRounder:
            // JIN keeps the head over the hips and lets the shoulders roll
            // against each planted step: compact, readable counter footwork.
            pose.pelvisRoll += stepDifference * 0.018
            pose.spineRoll -= stepDifference * 0.025
            pose.head.z += Float(stepDifference * 0.016)
            pose.rootY -= movementAmount * 0.012
            pose.pelvis.y += Float(stepDifference * 0.045)
            pose.spine.y -= Float(stepDifference * 0.032)
        case .pressure:
            // MASON advances from a loaded crouch. Both knees remain bent and
            // the torso follows the hips as one heavy unit.
            let load = max(movementAmount, max(leadLift, rearLift) * 0.72)
            pose.rootY -= load * 0.055
            pose.rootZ += max(locomotionFrame.forwardDrive, 0) * load * 0.075
                - max(-locomotionFrame.forwardDrive, 0) * load * 0.025
            pose.leadKnee.x += Float(load * 0.095)
            pose.rearKnee.x += Float(load * 0.095)
            pose.spinePitch -= load * 0.035
            pose.pelvisRoll += stepDifference * 0.018
            pose.pelvis.y += Float(stepDifference * 0.065)
            pose.spine.y -= Float(stepDifference * 0.040)
        case .outBoxer:
            // LEO bounces on alternating feet and lets the upper body lag
            // behind the quick in-out step before snapping back over center.
            let bounce = max(leadLift, rearLift)
            pose.rootY += bounce * 0.050 + rhythm * movementAmount * 0.018
            pose.rootZ -= movementAmount * 0.025
            pose.pelvisRoll += stepDifference * 0.030
            pose.spineRoll -= stepDifference * 0.045
            pose.head.z += Float(stepDifference * 0.028)
            pose.pelvis.y += Float(stepDifference * 0.075)
            pose.spine.y -= Float(stepDifference * 0.060)
            pose.leadAnklePitch += leadLift * 0.075
            pose.rearAnklePitch += rearLift * 0.075
        case .rival:
            pose.rootY -= movementAmount * 0.028
            pose.spineRoll -= locomotionFrame.upperBodyRotation * 0.12
            pose.pelvis.y += Float(stepDifference * 0.052)
            pose.spine.y -= Float(stepDifference * 0.038)
        }
    }

    private var guardPose: Fighter3DPose {
        var pose = Fighter3DPose.guardPose.styled(with: motionProfile)
        applyGuardIdentity(to: &pose)
        return pose
    }

    private func applyGuardIdentity(to pose: inout Fighter3DPose) {
        switch motionStyle {
        case .allRounder:
            // Upright orthodox stance: centered head, even knees and a compact
            // guard. This remains the visual reference for the other styles.
            pose.pelvis.y += 0.08
            pose.spine.y -= 0.06
            pose.leadHip.x -= 0.02
            pose.rearHip.x += 0.02
        case .pressure:
            // Peek-a-boo crouch: compressed legs, head behind both gloves and
            // the chest leaning into close-range pressure.
            pose.rootY -= 0.08
            // Positive pitch is forward in the model's local stance. Keep the
            // head stacked over the lead knee instead of arching backward.
            // Hinge at the pelvis, then cancel that rotation at both hip
            // joints. The legs keep supporting the body while the complete
            // trunk folds forward instead of sliding toward the opponent.
            pose.pelvis.x += 0.18
            pose.spine.x += 0.18
            pose.head.x -= 0.12
            pose.leadKnee.x += 0.08
            pose.rearKnee.x += 0.05
            // Fold the thighs farther in front of the hips. The feet stay
            // under the stance while the pelvis reads behind the chest.
            pose.leadHip.x -= 0.27
            pose.rearHip.x -= 0.25
            pose.leadKnee.x += 0.04
            pose.rearKnee.x += 0.04
            pose.leadShoulder.x -= 0.13
            pose.rearShoulder.x -= 0.13
        case .outBoxer:
            // Bladed freestyle stance: tall rear shoulder, offset hips and a
            // wide base. The gloves remain near the face but are staggered.
            pose.rootY += 0.035
            pose.rootZ -= 0.075
            pose.pelvis.y += 0.34
            pose.spine.y -= 0.27
            pose.pelvis.z += 0.055
            pose.spine.z -= 0.045
            pose.leadHip.x -= 0.10
            pose.rearHip.x += 0.08
            pose.leadKnee.x -= 0.07
            pose.rearKnee.x += 0.08
            // A deliberately asymmetric freestyle guard: the lead hand
            // floats around chest height while the rear glove protects the
            // cheek. Combined with the bladed hips this must read differently
            // even when rendered as a solid silhouette.
            pose.leadShoulder.x += 0.30
            pose.leadElbow.x += 0.38
            pose.rearShoulder.x -= 0.10
            pose.rearElbow.x -= 0.12
            pose.head.y += 0.08
        case .rival:
            pose.rootY -= 0.055
            pose.rootZ += 0.035
            pose.spine.x -= 0.08
            pose.leadKnee.x += 0.09
            pose.rearKnee.x += 0.09
        }
    }

    private var punchLoadPose: Fighter3DPose {
        var pose = Fighter3DPose.punchLoad(
            hand: activeHand,
            technique: punchProfile.technique
        ).styled(
            with: motionProfile,
            technique: punchProfile.technique,
            signatureIntensity: 0.32
        )
        applyPunchIdentity(to: &pose, isStrike: false, power: 1)
        return pose
    }

    private func punchStrikePose(power: CGFloat) -> Fighter3DPose {
        var pose = Fighter3DPose.punchStrike(
            hand: activeHand,
            technique: punchProfile.technique,
            power: power
        ).styled(
            with: motionProfile,
            technique: punchProfile.technique,
            signatureIntensity: 1
        )
        applyPunchIdentity(to: &pose, isStrike: true, power: power)
        return pose
    }

    private func applyPunchIdentity(
        to pose: inout Fighter3DPose,
        isStrike: Bool,
        power: CGFloat
    ) {
        let handSign: CGFloat = activeHand == .lead ? -1 : 1
        switch motionStyle {
        case .allRounder:
            if punchProfile.technique == .uppercut {
                if isStrike {
                    pose.rootY += 0.16 * power
                    pose.rootZ += 0.08 * power
                    pose.spinePitch += 0.12 * power
                    pose.leadKnee.x -= Float(0.10 * power)
                    pose.rearKnee.x -= Float(0.10 * power)
                } else {
                    pose.rootY -= 0.11
                    pose.rootZ -= 0.06
                    pose.spinePitch += 0.11
                    pose.leadKnee.x += 0.15
                    pose.rearKnee.x += 0.15
                }
            } else {
                pose.pelvis.y += Float(handSign * (isStrike ? 0.08 : -0.05))
                pose.spine.y += Float(handSign * (isStrike ? 0.06 : -0.04))
            }
        case .pressure:
            if punchProfile.technique == .smash {
                if isStrike {
                    pose.rootZ += 0.17 * power
                    pose.rootRoll += handSign * 0.20 * power
                    pose.pelvis.y += Float(handSign * 0.26 * power)
                    pose.spine.y += Float(handSign * 0.32 * power)
                    pose.leadKnee.x -= Float(0.06 * power)
                    pose.rearKnee.x -= Float(0.04 * power)
                } else {
                    pose.rootY -= 0.13
                    pose.rootZ -= 0.08
                    pose.rootRoll -= handSign * 0.13
                    pose.pelvis.y -= Float(handSign * 0.22)
                    pose.spine.y -= Float(handSign * 0.27)
                    pose.leadKnee.x += 0.16
                    pose.rearKnee.x += 0.13
                }
            } else {
                pose.rootY -= isStrike ? 0.035 : 0.075
                pose.rootZ += isStrike ? 0.07 * power : -0.04
            }
        case .outBoxer:
            if punchProfile.technique == .straight {
                if isStrike {
                    pose.rootZ += 0.24 * power
                    pose.rootY += 0.045 * power
                    pose.spinePitch += 0.15 * power
                    pose.pelvis.y += Float(handSign * 0.22 * power)
                    pose.spine.y += Float(handSign * 0.18 * power)
                    if activeHand == .rear {
                        pose.rearAnklePitch += 0.18 * power
                    } else {
                        pose.leadAnklePitch += 0.14 * power
                    }
                } else {
                    pose.rootZ -= 0.12
                    pose.rootY += 0.025
                    pose.pelvis.y -= Float(handSign * 0.18)
                    pose.spine.y -= Float(handSign * 0.15)
                }
            } else {
                pose.rootY += isStrike ? 0.035 : 0.015
                pose.rootZ += isStrike ? 0.10 * power : -0.055
            }
        case .rival:
            pose.rootY -= isStrike ? 0.015 : 0.055
            pose.rootZ += isStrike ? 0.08 * power : -0.035
        }
    }

    private func progress(_ duration: TimeInterval) -> CGFloat {
        CGFloat(min(max(phaseElapsed / max(duration, 0.001), 0), 1))
    }

    /// Pose-space inertialization keeps state changes continuous while allowing
    /// each body group to retain a distinct boxing rhythm. It is deliberately
    /// phase-aware: the fist snaps, the evasive torso reacts quickly, and the
    /// body settles back into stance with visibly more weight.
    private func inertializedPose(
        toward target: Fighter3DPose,
        movementAmount: CGFloat,
        deltaTime: TimeInterval
    ) -> Fighter3DPose {
        let responses: (lower: CGFloat, torso: CGFloat, arms: CGFloat)
        switch phase {
        case .idle:
            responses = movementAmount > 0.03
                ? (28, 17, 15)
                : (12, 8.5, 9.5)
        case .punchStartup:
            responses = (24, 21, 24)
        case .punchActive:
            responses = (34, 42, 58)
        case .punchRecovery:
            responses = (14, 15, 22)
        case .swaying:
            responses = (25, 36, 27)
        case .hit:
            responses = (42, 52, 48)
        case .knockedOut:
            responses = (9, 10, 9)
        }

        func amount(for response: CGFloat) -> CGFloat {
            1 - CGFloat(exp(-Double(response) * deltaTime))
        }
        return lastAppliedPose.stagedBlend(
            to: target,
            lowerBody: amount(for: responses.lower),
            torso: amount(for: responses.torso),
            arms: amount(for: responses.arms)
        )
    }

    private func apply(
        _ pose: Fighter3DPose,
        locomotionFrame: FighterLocomotionFrame? = nil,
        bodyMotion: FighterBodyMotionFrame = .neutral
    ) {
        lastAppliedPose = pose
        let pose = pose.sanitized()
        skeletonRoot.position = SCNVector3(
            pose.rootX,
            pose.rootY + rigGroundingOffset,
            pose.rootZ
        )
        skeletonRoot.eulerAngles.x = Float(pose.rootPitch)
        skeletonRoot.eulerAngles.z = Float(pose.rootRoll)
        pelvis.eulerAngles = pose.pelvis
        spine.position = SCNVector3(pose.spineX, 0.13 + pose.spineY, pose.spineZ)
        spine.eulerAngles = pose.spine
        head.eulerAngles = pose.head
        leadShoulder.eulerAngles = pose.leadShoulder
        leadElbow.eulerAngles = pose.leadElbow
        rearShoulder.eulerAngles = pose.rearShoulder
        rearElbow.eulerAngles = pose.rearElbow
        leadHip.eulerAngles = pose.leadHip
        leadKnee.eulerAngles = pose.leadKnee
        rearHip.eulerAngles = pose.rearHip
        rearKnee.eulerAngles = pose.rearKnee
        leadAnkle.eulerAngles.x = clamp(
            -(pose.leadHip.x + pose.leadKnee.x) + Float(pose.leadAnklePitch),
            minimum: -0.72,
            maximum: 0.72
        )
        rearAnkle.eulerAngles.x = clamp(
            -(pose.rearHip.x + pose.rearKnee.x) + Float(pose.rearAnklePitch),
            minimum: -0.72,
            maximum: 0.72
        )
        applyMechanicalSecondaryMotion(pose: pose)
        applyKnockoutGrounding()
        applyFootPlanting(
            locomotionFrame: locomotionFrame,
            bodyMotion: bodyMotion
        )
    }

    /// Once the articulated rig falls sideways, feet are no longer the lowest
    /// contact points. Clamp the actual animated mesh bounds to the canvas so
    /// shoulders, gloves or the head cannot pass through the ring while the
    /// authored knockout pose rotates around its root.
    private func applyKnockoutGrounding() {
        guard phase == .knockedOut else { return }
        var lowestPoint = Float.greatestFiniteMagnitude
        let groundingSpace = presentationRoot
        skeletonRoot.enumerateChildNodes { node, _ in
            guard node.geometry != nil else { return }
            let bounds = node.boundingBox
            for x in [bounds.min.x, bounds.max.x] {
                for y in [bounds.min.y, bounds.max.y] {
                    for z in [bounds.min.z, bounds.max.z] {
                        let point = node.convertPosition(
                            SCNVector3(x, y, z),
                            to: groundingSpace
                        )
                        lowestPoint = min(lowestPoint, point.y)
                    }
                }
            }
        }
        guard lowestPoint.isFinite else { return }
        let canvasClearance: Float = 0.025
        if lowestPoint < canvasClearance {
            skeletonRoot.position.y += canvasClearance - lowestPoint
        }
    }

    private func buildCamera(in scene: SCNScene) {
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 3.12
        camera.zNear = 0.1
        camera.zFar = 100
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 1.34, 6)
        scene.rootNode.addChildNode(cameraNode)
        spriteNode.pointOfView = cameraNode
    }

    private func buildLights(in scene: SCNScene) {
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .omni
        key.light?.intensity = 760
        key.light?.color = ArenaVisualPalette.overheadLight
        key.light?.castsShadow = true
        key.light?.shadowRadius = 5
        key.light?.shadowColor = UIColor.black.withAlphaComponent(0.42)
        key.position = SCNVector3(-3, 5, 5)
        scene.rootNode.addChildNode(key)

        let warmRim = SCNNode()
        warmRim.light = SCNLight()
        warmRim.light?.type = .omni
        warmRim.light?.intensity = 90
        warmRim.light?.color = ArenaVisualPalette.warmCanvasLight
        warmRim.position = SCNVector3(3.2, 2.7, 4.2)
        scene.rootNode.addChildNode(warmRim)

        let coolRim = SCNNode()
        coolRim.light = SCNLight()
        coolRim.light?.type = .omni
        coolRim.light?.intensity = 70
        coolRim.light?.color = ArenaVisualPalette.coolCanvasLight
        coolRim.position = SCNVector3(-3.4, 2.2, -2.8)
        scene.rootNode.addChildNode(coolRim)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .omni
        fill.light?.intensity = 420
        fill.light?.color = UIColor(white: 0.82, alpha: 1)
        fill.position = SCNVector3(0, 2.5, 5.5)
        scene.rootNode.addChildNode(fill)
    }

    private func buildFighter(in scene: SCNScene, appearance: FighterAppearance) {
        let proportions = Fighter3DAppearanceProfile(appearance: appearance)
        let palette = Fighter3DMaterialPalette(appearance: appearance)

        scene.rootNode.addChildNode(presentationRoot)
        presentationRoot.addChildNode(skeletonRoot)
        skeletonRoot.addChildNode(pelvis)
        pelvis.position = SCNVector3(0, 1.34, 0)

        let hipFrame = Fighter3DMeshFactory.hipFrame(
            proportions: proportions,
            material: palette.kit
        )
        pelvis.addChildNode(hipFrame)
        Fighter3DDetailFactory.attachHipArmor(
            appearance.kitStyle,
            proportions: proportions,
            palette: palette,
            to: pelvis
        )

        pelvis.addChildNode(spine)
        spine.position.y = 0.13
        let torso = Fighter3DMeshFactory.torso(
            proportions: proportions,
            material: palette.skin
        )
        spine.addChildNode(torso)
        powerCore = Fighter3DDetailFactory.attachTorsoArmor(
            appearance.kitStyle,
            proportions: proportions,
            palette: palette,
            to: spine
        )

        spine.addChildNode(head)
        head.position = SCNVector3(0, 1.17, 0)
        let neck = Fighter3DMeshFactory.cylinder(
            radius: proportions.neckRadius,
            height: 0.23,
            material: palette.jointSkin
        )
        neck.position.y = -0.20
        head.addChildNode(neck)
        let skull = Fighter3DMeshFactory.head(
            proportions: proportions,
            material: palette.skin
        )
        head.addChildNode(skull)
        Fighter3DDetailFactory.attachHelmet(
            appearance.hairStyle,
            proportions: proportions,
            palette: palette,
            to: head
        )
        Fighter3DDetailFactory.attachSensorFace(
            appearance.faceStyle,
            proportions: proportions,
            palette: palette,
            to: head
        )

        attachArm(
            shoulder: leadShoulder,
            elbow: leadElbow,
            x: proportions.shoulderOffset,
            z: 0.13,
            material: palette.skin,
            jointMaterial: palette.jointSkin,
            gloveMaterial: palette.kit,
            accentMaterial: palette.accent,
            markingMaterial: palette.marking,
            proportions: proportions,
            to: spine
        )
        attachArm(
            shoulder: rearShoulder,
            elbow: rearElbow,
            x: -proportions.shoulderOffset,
            z: -0.13,
            material: palette.skin,
            jointMaterial: palette.jointSkin,
            gloveMaterial: palette.kit,
            accentMaterial: palette.accent,
            markingMaterial: palette.marking,
            proportions: proportions,
            to: spine
        )
        attachLeg(
            hip: leadHip,
            knee: leadKnee,
            ankle: leadAnkle,
            x: proportions.hipOffset,
            z: 0.17 * motionProfile.stanceDepth,
            material: palette.skin,
            jointMaterial: palette.jointSkin,
            shoeMaterial: palette.kit,
            markingMaterial: palette.marking,
            proportions: proportions,
            to: pelvis
        )
        attachLeg(
            hip: rearHip,
            knee: rearKnee,
            ankle: rearAnkle,
            x: -proportions.hipOffset,
            z: -0.17 * motionProfile.stanceDepth,
            material: palette.skin,
            jointMaterial: palette.jointSkin,
            shoeMaterial: palette.kit,
            markingMaterial: palette.marking,
            proportions: proportions,
            to: pelvis
        )
        configureFootIK()
    }

    private func configureFootIK() {
        let lead = SCNIKConstraint.inverseKinematicsConstraint(
            chainRootNode: leadHip
        )
        let rear = SCNIKConstraint.inverseKinematicsConstraint(
            chainRootNode: rearHip
        )
        for (constraint, hip, knee, ankle) in [
            (lead, leadHip, leadKnee, leadAnkle),
            (rear, rearHip, rearKnee, rearAnkle)
        ] {
            constraint.influenceFactor = 0
            constraint.setMaxAllowedRotationAngle(42, forJoint: hip)
            constraint.setMaxAllowedRotationAngle(72, forJoint: knee)
            constraint.setMaxAllowedRotationAngle(18, forJoint: ankle)
            ankle.constraints = [constraint]
        }
        leadFootIK = lead
        rearFootIK = rear
    }

    private func applyFootPlanting(
        locomotionFrame: FighterLocomotionFrame?,
        bodyMotion: FighterBodyMotionFrame
    ) {
        guard phase != .knockedOut,
              let frame = locomotionFrame,
              let leadFootIK,
              let rearFootIK,
              let neutralLeadFootPosition,
              let neutralRearFootPosition else {
            leadFootIK?.influenceFactor = 0
            rearFootIK?.influenceFactor = 0
            return
        }

        // The feet own one deterministic step-and-slide path. The initiating
        // foot travels and lands first; only then may the trailing foot catch
        // up. Hip and torso clips can still express style, but they no longer
        // invent a second, conflicting location for either foot.
        leadFootIK.influenceFactor = 0
        rearFootIK.influenceFactor = 0
        let leadCurrent = leadAnkle.convertPosition(SCNVector3Zero, to: nil)
        let rearCurrent = rearAnkle.convertPosition(SCNVector3Zero, to: nil)
        let desiredLead = presentationRoot.convertPosition(
            neutralLeadFootPosition,
            to: nil
        )
        let desiredRear = presentationRoot.convertPosition(
            neutralRearFootPosition,
            to: nil
        )
        if leadFootPlantTarget == nil { leadFootPlantTarget = desiredLead }
        if rearFootPlantTarget == nil { rearFootPlantTarget = desiredRear }

        let beganNewStep = frame.stepProgress + 0.001 < previousStepProgress
            || bodyMotion.initiatingFoot != previousInitiatingFoot
        if beganNewStep, bodyMotion.initiatingFoot != .both {
            leadFootStepStart = leadFootPlantTarget ?? leadCurrent
            rearFootStepStart = rearFootPlantTarget ?? rearCurrent
        }

        if bodyMotion.initiatingFoot == .both {
            leadFootPlantTarget = desiredLead
            rearFootPlantTarget = desiredRear
            leadFootStepStart = desiredLead
            rearFootStepStart = desiredRear
        } else {
            let leadStart = leadFootStepStart ?? leadFootPlantTarget ?? leadCurrent
            let rearStart = rearFootStepStart ?? rearFootPlantTarget ?? rearCurrent
            let scale = CGFloat(max(abs(presentationRoot.presentation.scale.x), 0.01))
            switch bodyMotion.initiatingFoot {
            case .lead:
                if frame.stepProgress <= 0.40 {
                    leadFootPlantTarget = steppingTarget(
                        from: leadStart,
                        toward: desiredLead,
                        progress: frame.stepProgress / 0.40,
                        lift: frame.frontAnkleLift * scale
                    )
                }
                if frame.stepProgress >= 0.54, frame.stepProgress <= 0.86 {
                    rearFootPlantTarget = steppingTarget(
                        from: rearStart,
                        toward: desiredRear,
                        progress: (frame.stepProgress - 0.54) / 0.32,
                        lift: frame.backAnkleLift * scale
                    )
                }
            case .rear:
                if frame.stepProgress <= 0.40 {
                    rearFootPlantTarget = steppingTarget(
                        from: rearStart,
                        toward: desiredRear,
                        progress: frame.stepProgress / 0.40,
                        lift: frame.backAnkleLift * scale
                    )
                }
                if frame.stepProgress >= 0.54, frame.stepProgress <= 0.86 {
                    leadFootPlantTarget = steppingTarget(
                        from: leadStart,
                        toward: desiredLead,
                        progress: (frame.stepProgress - 0.54) / 0.32,
                        lift: frame.frontAnkleLift * scale
                    )
                }
            case .both:
                break
            }
        }

        leadFootPlantTarget = reachablePlantTarget(
            leadFootPlantTarget ?? leadCurrent,
            from: leadCurrent,
            groundHeight: desiredLead.y
        )
        rearFootPlantTarget = reachablePlantTarget(
            rearFootPlantTarget ?? rearCurrent,
            from: rearCurrent,
            groundHeight: desiredRear.y
        )
        leadFootIK.targetPosition = leadFootPlantTarget ?? leadCurrent
        rearFootIK.targetPosition = rearFootPlantTarget ?? rearCurrent
        let activeInfluence: CGFloat = bodyMotion.initiatingFoot == .both ? 0.90 : 0.96
        leadFootIK.influenceFactor = activeInfluence
        rearFootIK.influenceFactor = activeInfluence
        previousStepProgress = frame.stepProgress
        previousInitiatingFoot = bodyMotion.initiatingFoot
    }

    private func captureNeutralFootPositions() {
        var leadPosition = leadAnkle.convertPosition(
            SCNVector3Zero,
            to: presentationRoot
        )
        var rearPosition = rearAnkle.convertPosition(
            SCNVector3Zero,
            to: presentationRoot
        )
        // Both IK targets describe the ankle joint. Pinning their neutral Y to
        // the sole thickness keeps the actual shoe bottom on the mat at zero.
        leadPosition.y = Float(soleClearance)
        rearPosition.y = Float(soleClearance)
        neutralLeadFootPosition = leadPosition
        neutralRearFootPosition = rearPosition
    }

    private func calibrateRigGrounding() {
        let leadPosition = leadAnkle.convertPosition(
            SCNVector3Zero,
            to: presentationRoot
        )
        let rearPosition = rearAnkle.convertPosition(
            SCNVector3Zero,
            to: presentationRoot
        )
        let lowestAnkle = CGFloat(min(leadPosition.y, rearPosition.y))
        rigGroundingOffset = max(soleClearance - lowestAnkle, 0)
    }

    private func steppingTarget(
        from start: SCNVector3,
        toward destination: SCNVector3,
        progress: CGFloat,
        lift: CGFloat
    ) -> SCNVector3 {
        let amount = smooth(progress)
        return SCNVector3(
            start.x + (destination.x - start.x) * Float(amount),
            start.y + (destination.y - start.y) * Float(amount) + Float(max(lift, 0)),
            start.z + (destination.z - start.z) * Float(amount)
        )
    }

    /// Prevents a planted target from forcing an impossible leg extension if
    /// collision resolution or network correction moves the fighter root by a
    /// large amount in one frame. The target yields only as much as necessary,
    /// preserving contact without allowing the knee to fold unpredictably.
    private func reachablePlantTarget(
        _ target: SCNVector3,
        from current: SCNVector3,
        groundHeight: Float
    ) -> SCNVector3 {
        let scale = max(abs(presentationRoot.presentation.scale.x), 0.01)
        let maximumPlanarCorrection = 0.30 * scale
        let dx = target.x - current.x
        let dz = target.z - current.z
        let distance = hypot(dx, dz)
        var result = target
        if distance > maximumPlanarCorrection {
            let retained = maximumPlanarCorrection / distance
            result.x = current.x + dx * retained
            result.z = current.z + dz * retained
        }
        // Vertical placement is ground-relative, not current-foot-relative.
        // Root compression can exceed the old per-frame correction cap; that
        // cap allowed the whole shoe to follow the pelvis under the canvas.
        // The authored target already contains swing lift, so preserving it
        // while enforcing the neutral ground plane keeps both plants clean.
        result.y = max(result.y, groundHeight)
        return result
    }

    private func attachArm(
        shoulder: SCNNode,
        elbow: SCNNode,
        x: CGFloat,
        z: CGFloat,
        material: SCNMaterial,
        jointMaterial: SCNMaterial,
        gloveMaterial: SCNMaterial,
        accentMaterial: SCNMaterial,
        markingMaterial: SCNMaterial,
        proportions: Fighter3DAppearanceProfile,
        to parent: SCNNode
    ) {
        parent.addChildNode(shoulder)
        shoulder.position = SCNVector3(x, 0.84, z)
        shoulder.addChildNode(Fighter3DMeshFactory.joint(
            radius: 0.112 * proportions.limbRadiusScale,
            material: jointMaterial
        ))
        let shoulderArmor = Fighter3DMeshFactory.box(
            width: 0.27 * proportions.limbRadiusScale,
            height: 0.19,
            length: 0.25 * proportions.limbRadiusScale,
            chamfer: 0.045,
            material: gloveMaterial
        )
        shoulderArmor.position = SCNVector3(0, -0.045, 0)
        shoulder.addChildNode(shoulderArmor)
        shoulder.addChildNode(Fighter3DMeshFactory.upperArm(
            length: 0.58,
            radius: 0.108 * proportions.limbRadiusScale,
            material: material
        ))
        let upperActuator = Fighter3DMeshFactory.cylinder(
            radius: 0.035 * proportions.limbRadiusScale,
            height: 0.40,
            material: accentMaterial
        )
        upperActuator.position = SCNVector3(
            x >= 0 ? 0.075 : -0.075,
            -0.29,
            0.025
        )
        shoulder.addChildNode(upperActuator)
        armActuators.append(upperActuator)
        shoulder.addChildNode(elbow)
        elbow.position.y = -0.58
        elbow.addChildNode(Fighter3DMeshFactory.joint(
            radius: 0.086 * proportions.limbRadiusScale,
            material: jointMaterial
        ))
        elbow.addChildNode(Fighter3DMeshFactory.forearm(
            length: 0.54,
            radius: 0.094 * proportions.limbRadiusScale,
            material: material
        ))
        let forearmGuard = Fighter3DMeshFactory.box(
            width: 0.20 * proportions.limbRadiusScale,
            height: 0.30,
            length: 0.19 * proportions.limbRadiusScale,
            chamfer: 0.035,
            material: gloveMaterial
        )
        forearmGuard.position = SCNVector3(0, -0.25, 0.015)
        elbow.addChildNode(forearmGuard)
        let forearmMark = Fighter3DMeshFactory.box(
            width: 0.055 * proportions.limbRadiusScale,
            height: 0.20,
            length: 0.025,
            chamfer: 0.006,
            material: markingMaterial
        )
        forearmMark.position = SCNVector3(0, -0.25, 0.12)
        forearmMark.eulerAngles.z = x >= 0 ? -0.18 : 0.18
        elbow.addChildNode(forearmMark)
        let cuff = Fighter3DMeshFactory.cylinder(
            radius: 0.105 * proportions.cuffScale,
            height: 0.16,
            material: accentMaterial
        )
        cuff.position.y = -0.48
        elbow.addChildNode(cuff)
        let glove = Fighter3DMeshFactory.glove(
            radius: proportions.gloveRadius,
            widthScale: proportions.gloveWidthScale,
            heightScale: proportions.gloveHeightScale,
            depthScale: proportions.gloveDepthScale,
            side: x >= 0 ? 1 : -1,
            material: gloveMaterial
        )
        glove.position.y = -0.57
        elbow.addChildNode(glove)
    }

    private func attachLeg(
        hip: SCNNode,
        knee: SCNNode,
        ankle: SCNNode,
        x: CGFloat,
        z: CGFloat,
        material: SCNMaterial,
        jointMaterial: SCNMaterial,
        shoeMaterial: SCNMaterial,
        markingMaterial: SCNMaterial,
        proportions: Fighter3DAppearanceProfile,
        to parent: SCNNode
    ) {
        parent.addChildNode(hip)
        hip.position = SCNVector3(x, -0.18, z)
        let hipArmor = Fighter3DMeshFactory.box(
            width: 0.25 * proportions.limbRadiusScale,
            height: 0.20,
            length: 0.25 * proportions.limbRadiusScale,
            chamfer: 0.045,
            material: shoeMaterial
        )
        hipArmor.position.y = -0.04
        hip.addChildNode(hipArmor)
        hip.addChildNode(Fighter3DMeshFactory.thigh(
            length: 0.66,
            radius: 0.145 * proportions.limbRadiusScale,
            material: material
        ))
        hip.addChildNode(knee)
        knee.position.y = -0.66
        knee.addChildNode(Fighter3DMeshFactory.joint(
            radius: 0.098 * proportions.limbRadiusScale,
            material: jointMaterial
        ))
        let kneeGuard = Fighter3DMeshFactory.box(
            width: 0.19 * proportions.limbRadiusScale,
            height: 0.17,
            length: 0.12,
            chamfer: 0.035,
            material: shoeMaterial
        )
        kneeGuard.position = SCNVector3(0, -0.02, 0.085)
        knee.addChildNode(kneeGuard)
        knee.addChildNode(Fighter3DMeshFactory.calf(
            length: 0.64,
            radius: 0.112 * proportions.limbRadiusScale,
            material: material
        ))
        let calfActuator = Fighter3DMeshFactory.cylinder(
            radius: 0.032 * proportions.limbRadiusScale,
            height: 0.40,
            material: jointMaterial
        )
        calfActuator.position = SCNVector3(x >= 0 ? 0.075 : -0.075, -0.31, 0)
        knee.addChildNode(calfActuator)
        legActuators.append(calfActuator)
        let shinMark = Fighter3DMeshFactory.box(
            width: 0.050 * proportions.limbRadiusScale,
            height: 0.22,
            length: 0.025,
            chamfer: 0.006,
            material: markingMaterial
        )
        shinMark.position = SCNVector3(0, -0.31, 0.115)
        knee.addChildNode(shinMark)
        knee.addChildNode(ankle)
        ankle.position.y = -0.64
        let boot = Fighter3DMeshFactory.cylinder(
            radius: 0.115 * proportions.cuffScale,
            height: 0.18,
            material: shoeMaterial
        )
        boot.position.y = -0.04
        ankle.addChildNode(boot)
        let shoe = Fighter3DMeshFactory.box(
            width: proportions.shoeWidth,
            height: proportions.shoeHeight,
            length: proportions.shoeLength,
            chamfer: 0.055,
            material: shoeMaterial
        )
        shoe.position = SCNVector3(0, -0.06, 0.10)
        ankle.addChildNode(shoe)
    }

    private func applyMechanicalSecondaryMotion(pose: Fighter3DPose) {
        let armDrive: CGFloat
        switch phase {
        case .punchStartup:
            armDrive = 0.88
        case .punchActive:
            armDrive = 1.18
        case .punchRecovery:
            armDrive = 1.05
        case .swaying:
            armDrive = 0.94
        case .hit:
            armDrive = 0.90
        case .idle, .knockedOut:
            armDrive = 1
        }
        for actuator in armActuators {
            actuator.scale.y = Float(armDrive)
        }

        let kneeLoad = min(
            (abs(CGFloat(pose.leadKnee.x)) + abs(CGFloat(pose.rearKnee.x))) * 0.10,
            0.16
        )
        for actuator in legActuators {
            actuator.scale.y = Float(1 - kneeLoad)
        }

        let idlePulse = sin(CGFloat(phaseElapsed) * 3.8) * 0.025
        let actionPulse: CGFloat = phase == .punchActive ? 0.16 : (phase == .swaying ? 0.07 : 0)
        let coreScale = 1 + idlePulse + actionPulse
        powerCore?.scale = SCNVector3(coreScale, coreScale, coreScale)
    }

}

private func smooth(_ value: CGFloat) -> CGFloat {
    let t = min(max(value, 0), 1)
    return t * t * (3 - 2 * t)
}
