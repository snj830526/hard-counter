import SceneKit
import SpriteKit

/// Experimental presentation-only renderer. Combat, input, hit detection and
/// networking continue to use FighterNode; this object only replaces its art.
final class Fighter3DRenderer {
    let spriteNode: SK3DNode
    private let motionStyle: Fighter3DMotionStyle
    private let motionProfile: Fighter3DMotionProfile

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
    private var targetStaminaFraction: CGFloat = 1
    private var displayedStaminaFraction: CGFloat = 1

    init(appearance: FighterAppearance, motionStyle: Fighter3DMotionStyle) {
        self.motionStyle = motionStyle
        motionProfile = motionStyle.profile
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
    }

    func show(phase newPhase: FighterPhase) {
        phase = newPhase
        phaseElapsed = 0
        if newPhase == .idle {
            followThrough = 0
            whiffOverreach = 0
            hitElapsed = nil
        }
    }

    func preparePunch(_ hand: PunchHand, profile: PunchProfile) {
        activeHand = hand
        punchProfile = profile
    }

    func prepareSway(
        _: SwayDirection,
        screenDirection: CGVector,
        performance: CGFloat
    ) {
        swayScreenDirection = screenDirection
        swayPerformance = performance
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
        targetStaminaFraction = 1
        displayedStaminaFraction = 1
        skeletonRoot.opacity = 1
        apply(guardPose)
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
        if let hitElapsed {
            let duration = hitKind == .counter
                ? CombatTuning.counterHitReaction
                : CombatTuning.hitReaction
            let t = CGFloat(min(hitElapsed / max(duration, 0.001), 1))
            let hitPose = Fighter3DPose.hit(
                technique: hitProfile.technique,
                strength: hitKind == .counter ? 1.25 : 1
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
        apply(pose)
    }

    private func applyHitConfirm(to pose: inout Fighter3DPose, amount: CGFloat) {
        let drive = amount * CGFloat(min(max(punchProfile.powerScale, 0.65), 1.30))
        let handSign: CGFloat = activeHand == .lead ? -1 : 1
        switch punchProfile.technique {
        case .straight:
            pose.rootZ += 0.10 * drive
            pose.spinePitch -= 0.055 * drive
            pose.pelvis.y += Float(0.08 * handSign * drive)
        case .smash:
            pose.rootZ += 0.07 * drive
            pose.rootRoll += 0.07 * handSign * drive
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
        let overreach = amount * CGFloat(min(max(punchProfile.powerScale, 0.65), 1.30))
        let handSign: CGFloat = activeHand == .lead ? -1 : 1
        switch punchProfile.technique {
        case .straight:
            pose.rootZ += 0.15 * overreach
            pose.rootY -= 0.025 * overreach
            pose.spinePitch -= 0.11 * overreach
        case .smash:
            pose.rootZ += 0.09 * overreach
            pose.rootRoll += 0.12 * handSign * overreach
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
            return guardPose.blended(
                to: punchLoadPose,
                amount: smooth(progress(duration))
            ).applyingLocomotion(movingGuard, relativeTo: guardPose, upperBodyAmount: 0.18)

        case .punchActive:
            let duration = CombatTuning.punchActive * punchProfile.activeScale
            let power = CGFloat(min(max(punchProfile.powerScale, 0.7), 1.3))
            return punchLoadPose.blended(
                to: punchStrikePose(power: power),
                amount: snap(progress(duration))
            ).applyingLocomotion(movingGuard, relativeTo: guardPose, upperBodyAmount: 0.10)

        case .punchRecovery:
            let duration = CombatTuning.punchRecovery * punchProfile.recoveryScale
            let recovery = pow(
                smooth(progress(duration)),
                max(motionProfile.recoveryWeight, 0.2)
            )
            return punchStrikePose(power: CGFloat(punchProfile.powerScale))
                .blended(to: guardPose, amount: recovery)
                .applyingLocomotion(movingGuard, relativeTo: guardPose, upperBodyAmount: 0.14)

        case .swaying:
            let amount = swayEnvelope(progress(CombatTuning.swayDuration))
            var swayPose = Fighter3DPose.continuousSway(
                screenDirection: swayScreenDirection,
                facingDirection: opponentScreenDirection,
                performance: swayPerformance
            )
                .aligned(
                    toScreenDirection: swayScreenDirection,
                    facingDirection: opponentScreenDirection,
                    facingSign: facingSign
                )
                .styledSway(with: motionProfile)
            applyGuardIdentity(to: &swayPose)
            return guardPose.blended(
                to: swayPose,
                amount: smooth(amount)
            ).applyingLocomotion(movingGuard, relativeTo: guardPose, upperBodyAmount: 0.08)

        case .hit:
            return movingGuard

        case .knockedOut:
            let t = smooth(progress(0.52))
            return guardPose.blended(
                to: Fighter3DPose.knockedOut.styled(with: motionProfile),
                amount: t
            )
        }
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

        let bounce = motionProfile.footworkBounce
        let stride = motionProfile.strideLength
        pose.rootY += locomotionFrame.pelvisCompression * 0.009
        pose.rootY += activeLift * 0.012 * bounce
        pose.pelvisRoll += locomotionFrame.pelvisRotation * 0.82
        pose.spineRoll += locomotionFrame.upperBodyRotation * 0.68
        pose.leadHip.x += Float(leadLift * 0.23 * stride)
        pose.rearHip.x += Float(rearLift * 0.23 * stride)
        pose.leadKnee.x += Float(leadLift * 0.28)
        pose.rearKnee.x += Float(rearLift * 0.28)
        pose.leadAnklePitch = leadLift * 0.11
        pose.rearAnklePitch = rearLift * 0.11

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
            pose.pelvisRoll += stepDifference * 0.030
            pose.spineRoll -= stepDifference * 0.040
            pose.head.z += Float(stepDifference * 0.026)
            pose.rootY -= movementAmount * 0.012
        case .pressure:
            // MASON advances from a loaded crouch. Both knees remain bent and
            // the torso follows the hips as one heavy unit.
            let load = max(movementAmount, max(leadLift, rearLift) * 0.72)
            pose.rootY -= load * 0.055
            pose.rootZ += load * 0.045
            pose.leadKnee.x += Float(load * 0.095)
            pose.rearKnee.x += Float(load * 0.095)
            pose.spinePitch -= load * 0.035
            pose.pelvisRoll += stepDifference * 0.018
        case .outBoxer:
            // LEO bounces on alternating feet and lets the upper body lag
            // behind the quick in-out step before snapping back over center.
            let bounce = max(leadLift, rearLift)
            pose.rootY += bounce * 0.050 + rhythm * movementAmount * 0.018
            pose.rootZ -= movementAmount * 0.025
            pose.pelvisRoll += stepDifference * 0.052
            pose.spineRoll -= stepDifference * 0.075
            pose.head.z += Float(stepDifference * 0.045)
            pose.leadAnklePitch += leadLift * 0.075
            pose.rearAnklePitch += rearLift * 0.075
        case .rival:
            pose.rootY -= movementAmount * 0.028
            pose.spineRoll -= locomotionFrame.upperBodyRotation * 0.12
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
            pose.leadHip.x -= 0.16
            pose.rearHip.x -= 0.14
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
                    pose.spinePitch -= 0.15 * power
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

    private func apply(_ pose: Fighter3DPose) {
        let pose = pose.sanitized()
        skeletonRoot.position = SCNVector3(pose.rootX, pose.rootY, pose.rootZ)
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
        key.light?.intensity = 680
        key.light?.color = ArenaVisualPalette.overheadLight
        key.light?.castsShadow = true
        key.light?.shadowRadius = 5
        key.light?.shadowColor = UIColor.black.withAlphaComponent(0.42)
        key.position = SCNVector3(-3, 5, 5)
        scene.rootNode.addChildNode(key)

        let warmRim = SCNNode()
        warmRim.light = SCNLight()
        warmRim.light?.type = .omni
        warmRim.light?.intensity = 190
        warmRim.light?.color = ArenaVisualPalette.warmCanvasLight
        warmRim.position = SCNVector3(3.2, 2.7, 4.2)
        scene.rootNode.addChildNode(warmRim)

        let coolRim = SCNNode()
        coolRim.light = SCNLight()
        coolRim.light?.type = .omni
        coolRim.light?.intensity = 140
        coolRim.light?.color = ArenaVisualPalette.coolCanvasLight
        coolRim.position = SCNVector3(-3.4, 2.2, -2.8)
        scene.rootNode.addChildNode(coolRim)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .ambient
        fill.light?.intensity = 225
        fill.light?.color = UIColor(red: 0.50, green: 0.61, blue: 0.78, alpha: 1)
        scene.rootNode.addChildNode(fill)
    }

    private func buildFighter(in scene: SCNScene, appearance: FighterAppearance) {
        let proportions = Fighter3DAppearanceProfile(appearance: appearance)
        let skin = material(appearance.skinColor, roughness: 0.66, specular: 0.20)
        let shadowSkin = material(appearance.skinShadowColor, roughness: 0.72, specular: 0.14)
        let kit = material(appearance.kitColor, roughness: 0.80, specular: 0.10)
        let accent = material(
            appearance.accentColor,
            roughness: 0.48,
            specular: 0.32,
            emission: 0.025
        )
        let hair = material(appearance.hairColor, roughness: 0.94, specular: 0.04)
        let eyeWhite = material(UIColor(white: 0.92, alpha: 1), roughness: 0.74, specular: 0.08)

        scene.rootNode.addChildNode(skeletonRoot)
        skeletonRoot.addChildNode(pelvis)
        pelvis.position = SCNVector3(0, 1.34, 0)

        let shorts = Fighter3DMeshFactory.shorts(
            proportions: proportions,
            material: kit
        )
        pelvis.addChildNode(shorts)
        attachKitDetails(appearance.kitStyle, proportions: proportions, kit: kit, accent: accent, to: pelvis)

        pelvis.addChildNode(spine)
        spine.position.y = 0.13
        let torso = Fighter3DMeshFactory.torso(
            proportions: proportions,
            material: skin
        )
        spine.addChildNode(torso)

        spine.addChildNode(head)
        head.position = SCNVector3(0, 1.17, 0)
        let neck = cylinder(radius: proportions.neckRadius, height: 0.23, material: shadowSkin)
        neck.position.y = -0.20
        head.addChildNode(neck)
        let skull = Fighter3DMeshFactory.head(
            proportions: proportions,
            material: skin
        )
        head.addChildNode(skull)
        attachHair(
            appearance.hairStyle,
            proportions: proportions,
            material: hair,
            to: head
        )
        attachFaceDetails(
            appearance.faceStyle,
            proportions: proportions,
            skin: skin,
            skinShadow: shadowSkin,
            eyeWhite: eyeWhite,
            hair: hair,
            accent: accent,
            to: head
        )

        attachArm(
            shoulder: leadShoulder,
            elbow: leadElbow,
            x: proportions.shoulderOffset,
            z: 0.13,
            material: skin,
            gloveMaterial: kit,
            accentMaterial: accent,
            proportions: proportions,
            to: spine
        )
        attachArm(
            shoulder: rearShoulder,
            elbow: rearElbow,
            x: -proportions.shoulderOffset,
            z: -0.13,
            material: shadowSkin,
            gloveMaterial: kit,
            accentMaterial: accent,
            proportions: proportions,
            to: spine
        )
        attachLeg(
            hip: leadHip,
            knee: leadKnee,
            ankle: leadAnkle,
            x: proportions.hipOffset,
            z: 0.17 * motionProfile.stanceDepth,
            material: skin,
            shoeMaterial: accent,
            proportions: proportions,
            to: pelvis
        )
        attachLeg(
            hip: rearHip,
            knee: rearKnee,
            ankle: rearAnkle,
            x: -proportions.hipOffset,
            z: -0.17 * motionProfile.stanceDepth,
            material: shadowSkin,
            shoeMaterial: accent,
            proportions: proportions,
            to: pelvis
        )
    }

    private func attachKitDetails(
        _ style: FighterKitStyle,
        proportions: Fighter3DAppearanceProfile,
        kit: SCNMaterial,
        accent: SCNMaterial,
        to pelvis: SCNNode
    ) {
        let waistbandHeight: CGFloat = style == .pressure ? 0.12 : 0.085
        let waistband = box(
            width: proportions.shortsWidth + 0.035,
            height: waistbandHeight,
            length: proportions.shortsDepth + 0.025,
            chamfer: 0.025,
            material: accent
        )
        waistband.position.y = 0.16
        pelvis.addChildNode(waistband)

        switch style {
        case .classic:
            let frontPatch = box(width: 0.13, height: 0.16, length: 0.025, chamfer: 0.01, material: accent)
            frontPatch.position = SCNVector3(0, -0.06, proportions.shortsDepth / 2 + 0.015)
            pelvis.addChildNode(frontPatch)
        case .pressure:
            for side: CGFloat in [-1, 1] {
                let panel = box(width: 0.105, height: 0.31, length: 0.025, chamfer: 0.015, material: accent)
                panel.position = SCNVector3(
                    side * (proportions.shortsWidth / 2 - 0.07),
                    -0.06,
                    proportions.shortsDepth / 2 + 0.015
                )
                pelvis.addChildNode(panel)
            }
        case .speed:
            for side: CGFloat in [-1, 1] {
                let stripe = box(width: 0.045, height: 0.30, length: proportions.shortsDepth + 0.02, chamfer: 0.01, material: accent)
                stripe.position = SCNVector3(side * (proportions.shortsWidth / 2 + 0.006), -0.04, 0)
                pelvis.addChildNode(stripe)
            }
        }
    }

    private func attachHair(
        _ style: FighterHairStyle,
        proportions: Fighter3DAppearanceProfile,
        material: SCNMaterial,
        to head: SCNNode
    ) {
        let hairRoot = SCNNode()
        hairRoot.scale = SCNVector3(
            proportions.headWidthScale,
            proportions.headHeightScale,
            proportions.headDepthScale
        )
        head.addChildNode(hairRoot)
        switch style {
        case .cropped:
            let cap = sphere(radius: 0.255, material: material)
            cap.scale = SCNVector3(0.90, 0.40, 0.94)
            cap.position.y = 0.17
            hairRoot.addChildNode(cap)

            let hairline = box(width: 0.34, height: 0.08, length: 0.07, chamfer: 0.025, material: material)
            hairline.position = SCNVector3(0, 0.15, 0.215)
            hairRoot.addChildNode(hairline)
        case .shaved:
            let scalp = sphere(radius: 0.252, material: material)
            scalp.scale = SCNVector3(0.89, 0.16, 0.92)
            scalp.position.y = 0.22
            hairRoot.addChildNode(scalp)
        case .swept:
            let cap = sphere(radius: 0.258, material: material)
            cap.scale = SCNVector3(0.92, 0.46, 0.96)
            cap.position.y = 0.17
            cap.eulerAngles.z = -0.10
            hairRoot.addChildNode(cap)

            let sweep = box(width: 0.29, height: 0.11, length: 0.10, chamfer: 0.035, material: material)
            sweep.position = SCNVector3(0.075, 0.20, 0.225)
            sweep.eulerAngles.z = -0.30
            hairRoot.addChildNode(sweep)
        }
    }

    private func attachFaceDetails(
        _ style: FighterFaceStyle,
        proportions: Fighter3DAppearanceProfile,
        skin: SCNMaterial,
        skinShadow: SCNMaterial,
        eyeWhite: SCNMaterial,
        hair: SCNMaterial,
        accent: SCNMaterial,
        to head: SCNNode
    ) {
        for side: CGFloat in [-1, 1] {
            let eye = sphere(radius: 0.034, material: eyeWhite)
            eye.scale = SCNVector3(1, 0.60, 0.42)
            eye.position = SCNVector3(
                side * 0.075 * proportions.headWidthScale,
                0.035 * proportions.headHeightScale,
                0.230 * proportions.headDepthScale
            )
            head.addChildNode(eye)

            let pupil = sphere(radius: 0.015, material: hair)
            pupil.scale = SCNVector3(0.72, 0.72, 0.36)
            pupil.position = SCNVector3(
                side * 0.075 * proportions.headWidthScale,
                0.035 * proportions.headHeightScale,
                0.248 * proportions.headDepthScale
            )
            head.addChildNode(pupil)

            let brow = box(
                width: style == .rugged ? 0.105 : 0.085,
                height: style == .rugged ? 0.030 : 0.022,
                length: 0.022,
                chamfer: 0.008,
                material: hair
            )
            brow.position = SCNVector3(
                side * 0.075 * proportions.headWidthScale,
                0.098 * proportions.headHeightScale,
                0.226 * proportions.headDepthScale
            )
            brow.eulerAngles.z = Float(side * (style == .sharp ? 0.18 : 0.08))
            head.addChildNode(brow)

            let ear = sphere(radius: 0.042, material: skinShadow)
            ear.scale = SCNVector3(0.52, 1, 0.62)
            ear.position = SCNVector3(
                side * 0.235 * proportions.headWidthScale,
                -0.015,
                0
            )
            head.addChildNode(ear)
        }

        let nose = sphere(radius: 0.042, material: skin)
        nose.scale = SCNVector3(0.62, 0.90, 0.72)
        nose.position = SCNVector3(
            0,
            -0.018 * proportions.headHeightScale,
            0.252 * proportions.headDepthScale
        )
        head.addChildNode(nose)

        let mouth = box(
            width: 0.105,
            height: 0.018,
            length: 0.022,
            chamfer: 0.006,
            material: skinShadow
        )
        mouth.position = SCNVector3(0, -0.112, 0.225)
        head.addChildNode(mouth)

        switch style {
        case .focused:
            let noseBridge = box(width: 0.030, height: 0.085, length: 0.025, chamfer: 0.008, material: skinShadow)
            noseBridge.position = SCNVector3(0, 0.035, 0.235)
            head.addChildNode(noseBridge)
        case .rugged, .veteran:
            let chinGuard = box(
                width: 0.17,
                height: 0.10,
                length: 0.035,
                chamfer: 0.025,
                material: hair
            )
            chinGuard.position = SCNVector3(0, -0.178, 0.188)
            head.addChildNode(chinGuard)
        case .sharp:
            let cheekMark = box(
                width: 0.075,
                height: 0.020,
                length: 0.025,
                chamfer: 0.006,
                material: accent
            )
            cheekMark.position = SCNVector3(0.105, -0.070, 0.222)
            cheekMark.eulerAngles.z = -0.32
            head.addChildNode(cheekMark)
        }
    }

    private func attachArm(
        shoulder: SCNNode,
        elbow: SCNNode,
        x: CGFloat,
        z: CGFloat,
        material: SCNMaterial,
        gloveMaterial: SCNMaterial,
        accentMaterial: SCNMaterial,
        proportions: Fighter3DAppearanceProfile,
        to parent: SCNNode
    ) {
        parent.addChildNode(shoulder)
        shoulder.position = SCNVector3(x, 0.84, z)
        shoulder.addChildNode(Fighter3DMeshFactory.joint(
            radius: 0.112 * proportions.limbRadiusScale,
            material: material
        ))
        shoulder.addChildNode(Fighter3DMeshFactory.upperArm(
            length: 0.58,
            radius: 0.108 * proportions.limbRadiusScale,
            material: material
        ))
        shoulder.addChildNode(elbow)
        elbow.position.y = -0.58
        elbow.addChildNode(Fighter3DMeshFactory.joint(
            radius: 0.086 * proportions.limbRadiusScale,
            material: material
        ))
        elbow.addChildNode(Fighter3DMeshFactory.forearm(
            length: 0.54,
            radius: 0.094 * proportions.limbRadiusScale,
            material: material
        ))
        let cuff = cylinder(radius: 0.105 * proportions.cuffScale, height: 0.16, material: accentMaterial)
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
        shoeMaterial: SCNMaterial,
        proportions: Fighter3DAppearanceProfile,
        to parent: SCNNode
    ) {
        parent.addChildNode(hip)
        hip.position = SCNVector3(x, -0.18, z)
        hip.addChildNode(Fighter3DMeshFactory.thigh(
            length: 0.66,
            radius: 0.145 * proportions.limbRadiusScale,
            material: material
        ))
        hip.addChildNode(knee)
        knee.position.y = -0.66
        knee.addChildNode(Fighter3DMeshFactory.joint(
            radius: 0.098 * proportions.limbRadiusScale,
            material: material
        ))
        knee.addChildNode(Fighter3DMeshFactory.calf(
            length: 0.64,
            radius: 0.112 * proportions.limbRadiusScale,
            material: material
        ))
        knee.addChildNode(ankle)
        ankle.position.y = -0.64
        let boot = cylinder(radius: 0.115 * proportions.cuffScale, height: 0.18, material: shoeMaterial)
        boot.position.y = -0.04
        ankle.addChildNode(boot)
        let shoe = box(
            width: proportions.shoeWidth,
            height: proportions.shoeHeight,
            length: proportions.shoeLength,
            chamfer: 0.055,
            material: shoeMaterial
        )
        shoe.position = SCNVector3(0, -0.06, 0.10)
        ankle.addChildNode(shoe)
    }

    private func segment(length: CGFloat, radius: CGFloat, material: SCNMaterial) -> SCNNode {
        let geometry = SCNCapsule(capRadius: radius, height: length)
        geometry.radialSegmentCount = 6
        geometry.capSegmentCount = 2
        geometry.materials = [material]
        let node = SCNNode(geometry: geometry)
        node.position.y = Float(-length / 2)
        return node
    }

    private func sphere(radius: CGFloat, material: SCNMaterial) -> SCNNode {
        let geometry = SCNSphere(radius: radius)
        geometry.segmentCount = 8
        geometry.materials = [material]
        return SCNNode(geometry: geometry)
    }

    private func cylinder(radius: CGFloat, height: CGFloat, material: SCNMaterial) -> SCNNode {
        let geometry = SCNCylinder(radius: radius, height: height)
        geometry.radialSegmentCount = 8
        geometry.materials = [material]
        return SCNNode(geometry: geometry)
    }

    private func box(
        width: CGFloat,
        height: CGFloat,
        length: CGFloat,
        chamfer: CGFloat,
        material: SCNMaterial
    ) -> SCNNode {
        let geometry = SCNBox(
            width: width,
            height: height,
            length: length,
            chamferRadius: chamfer
        )
        geometry.chamferSegmentCount = 1
        geometry.materials = [material]
        return SCNNode(geometry: geometry)
    }

    private func material(
        _ color: UIColor,
        roughness: CGFloat = 0.82,
        specular: CGFloat = 0.10,
        emission: CGFloat = 0
    ) -> SCNMaterial {
        let result = SCNMaterial()
        result.diffuse.contents = color
        result.roughness.contents = roughness
        result.metalness.contents = 0.02
        result.specular.contents = UIColor(white: specular, alpha: 1)
        if emission > 0 {
            result.emission.contents = color
            result.emission.intensity = emission
        }
        result.lightingModel = .physicallyBased
        return result
    }
}

private func smooth(_ value: CGFloat) -> CGFloat {
    let t = min(max(value, 0), 1)
    return t * t * (3 - 2 * t)
}

private func snap(_ value: CGFloat) -> CGFloat {
    let t = min(max(value, 0), 1)
    return 1 - pow(1 - t, 4)
}

private func swayEnvelope(_ value: CGFloat) -> CGFloat {
    let progress = min(max(value, 0), 1)
    let entryEnd = CombatTuning.swayEntryFraction
    let holdEnd = min(entryEnd + CombatTuning.swayHoldFraction, 0.72)
    if progress < entryEnd {
        return snap(progress / max(entryEnd, 0.001))
    }
    if progress < holdEnd { return 1 }
    return 1 - smooth((progress - holdEnd) / max(1 - holdEnd, 0.001))
}
