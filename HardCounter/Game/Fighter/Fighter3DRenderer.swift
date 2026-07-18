import SceneKit
import SpriteKit

/// Experimental presentation-only renderer. Combat, input, hit detection and
/// networking continue to use FighterNode; this object only replaces its art.
final class Fighter3DRenderer {
    let spriteNode: SK3DNode
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
    private var swayDirection: SwayDirection = .back
    private var swayScreenDirection = CGVector(dx: -1, dy: 0)
    private var swayPerformance: CGFloat = 1
    private var gaitClock: CGFloat = 0
    private var hitElapsed: TimeInterval?
    private var hitKind: HitKind = .normal
    private var hitProfile = PunchProfile()
    private var followThrough: CGFloat = 0
    private var whiffOverreach: CGFloat = 0

    init(appearance: FighterAppearance, motionStyle: Fighter3DMotionStyle) {
        motionProfile = motionStyle.profile
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        spriteNode = SK3DNode(viewportSize: CGSize(width: 176, height: 206))
        spriteNode.scnScene = scene
        spriteNode.position = CGPoint(x: 0, y: 76)
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
        _ direction: SwayDirection,
        screenDirection: CGVector,
        performance: CGFloat
    ) {
        swayDirection = direction
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

    func reset() {
        phase = .idle
        phaseElapsed = 0
        gaitClock = 0
        hitElapsed = nil
        followThrough = 0
        whiffOverreach = 0
        skeletonRoot.opacity = 1
        apply(guardPose)
    }

    func update(
        movement: FighterMovementState,
        orientation: FighterOrientationFrame,
        deltaTime: TimeInterval
    ) {
        guard deltaTime > 0 else { return }
        phaseElapsed += deltaTime
        if hitElapsed != nil { hitElapsed! += deltaTime }

        let direction = orientation.direction
        skeletonRoot.eulerAngles.y = Float(atan2(direction.dx, -direction.dy))

        let displacement = hypot(
            movement.screenDisplacement.dx,
            movement.screenDisplacement.dy
        )
        let movementAmount = min(hypot(
            movement.screenMovement.dx,
            movement.screenMovement.dy
        ), 1)
        if displacement > 0.001 {
            gaitClock += displacement * 0.19 * motionProfile.strideCadence
        } else if movementAmount > 0.04 {
            gaitClock += CGFloat(deltaTime)
                * (4.8 + movementAmount * 2.2)
                * motionProfile.strideCadence
        }

        var pose = poseForCurrentPhase(movementAmount: movementAmount)
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
            pose.rootZ += 0.09 * followThrough
            pose.spinePitch -= 0.05 * followThrough
            followThrough = max(followThrough - CGFloat(deltaTime) * 7.5, 0)
        }
        if whiffOverreach > 0 {
            pose.rootZ += 0.13 * whiffOverreach
            pose.spinePitch -= 0.09 * whiffOverreach
            whiffOverreach = max(whiffOverreach - CGFloat(deltaTime) * 4.5, 0)
        }
        apply(pose)
    }

    private func poseForCurrentPhase(movementAmount: CGFloat) -> Fighter3DPose {
        switch phase {
        case .idle:
            var pose = guardPose
            let breath = sin(CGFloat(phaseElapsed) * motionProfile.breathFrequency)
            pose.spineY += breath * 0.015 * motionProfile.breathAmplitude
            pose.spinePitch += breath * 0.018 * motionProfile.breathAmplitude
            guard movementAmount > 0.035 else { return pose }

            let step = sin(gaitClock)
            let settle = cos(gaitClock * 2)
            let bounce = motionProfile.footworkBounce
            pose.rootY += abs(step) * 0.028 * bounce
            pose.rootZ += settle * 0.025 * movementAmount
            pose.pelvisRoll += step * 0.055 * movementAmount * bounce
            pose.spineRoll -= step * 0.035 * movementAmount * bounce
            let stride = motionProfile.strideLength
            pose.leadHip.x += Float(step * 0.36 * movementAmount * stride)
            pose.rearHip.x -= Float(step * 0.36 * movementAmount * stride)
            pose.leadKnee.x += Float(max(-step, 0) * 0.34 * movementAmount)
            pose.rearKnee.x += Float(max(step, 0) * 0.34 * movementAmount)
            return pose

        case .punchStartup:
            let duration = CombatTuning.punchStartup * punchProfile.startupScale
            return guardPose.blended(
                to: punchLoadPose,
                amount: smooth(progress(duration))
            )

        case .punchActive:
            let duration = CombatTuning.punchActive * punchProfile.activeScale
            let power = CGFloat(min(max(punchProfile.powerScale, 0.7), 1.3))
            return punchLoadPose.blended(
                to: punchStrikePose(power: power),
                amount: snap(progress(duration))
            )

        case .punchRecovery:
            let duration = CombatTuning.punchRecovery * punchProfile.recoveryScale
            let recovery = pow(
                smooth(progress(duration)),
                max(motionProfile.recoveryWeight, 0.2)
            )
            return punchStrikePose(power: CGFloat(punchProfile.powerScale))
                .blended(to: guardPose, amount: recovery)

        case .swaying:
            let amount = sin(min(progress(CombatTuning.swayDuration), 1) * .pi)
            let swayPose = Fighter3DPose.sway(
                direction: swayDirection,
                performance: swayPerformance
            )
                .aligned(
                    toScreenDirection: swayScreenDirection,
                    swayDirection: swayDirection
                )
                .styledSway(with: motionProfile)
            return guardPose.blended(
                to: swayPose,
                amount: smooth(amount)
            )

        case .hit:
            return guardPose

        case .knockedOut:
            let t = smooth(progress(0.52))
            return guardPose.blended(
                to: Fighter3DPose.knockedOut.styled(with: motionProfile),
                amount: t
            )
        }
    }

    private var guardPose: Fighter3DPose {
        Fighter3DPose.guardPose.styled(with: motionProfile)
    }

    private var punchLoadPose: Fighter3DPose {
        Fighter3DPose.punchLoad(
            hand: activeHand,
            technique: punchProfile.technique
        ).styled(
            with: motionProfile,
            technique: punchProfile.technique,
            signatureIntensity: 0.32
        )
    }

    private func punchStrikePose(power: CGFloat) -> Fighter3DPose {
        Fighter3DPose.punchStrike(
            hand: activeHand,
            technique: punchProfile.technique,
            power: power
        ).styled(
            with: motionProfile,
            technique: punchProfile.technique,
            signatureIntensity: 1
        )
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
        spine.position = SCNVector3(pose.spineX, 0.13 + pose.spineY, 0)
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
            -(pose.leadHip.x + pose.leadKnee.x),
            minimum: -0.72,
            maximum: 0.72
        )
        rearAnkle.eulerAngles.x = clamp(
            -(pose.rearHip.x + pose.rearKnee.x),
            minimum: -0.72,
            maximum: 0.72
        )
    }

    private func buildCamera(in scene: SCNScene) {
        let cameraNode = SCNNode()
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 2.68
        camera.zNear = 0.1
        camera.zFar = 100
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 1.45, 6)
        scene.rootNode.addChildNode(cameraNode)
        spriteNode.pointOfView = cameraNode
    }

    private func buildLights(in scene: SCNScene) {
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .omni
        key.light?.intensity = 920
        key.light?.color = UIColor(white: 1, alpha: 1)
        key.position = SCNVector3(-3, 5, 5)
        scene.rootNode.addChildNode(key)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .ambient
        fill.light?.intensity = 430
        fill.light?.color = UIColor(red: 0.56, green: 0.66, blue: 0.82, alpha: 1)
        scene.rootNode.addChildNode(fill)
    }

    private func buildFighter(in scene: SCNScene, appearance: FighterAppearance) {
        let buildScale: CGFloat
        switch appearance.bodyBuild {
        case .balanced: buildScale = 1
        case .heavyweight: buildScale = 1.13
        case .lean: buildScale = 0.90
        }
        let skin = material(appearance.skinColor)
        let shadowSkin = material(appearance.skinShadowColor)
        let kit = material(appearance.kitColor)
        let accent = material(appearance.accentColor)
        let hair = material(appearance.hairColor)

        scene.rootNode.addChildNode(skeletonRoot)
        skeletonRoot.addChildNode(pelvis)
        pelvis.position = SCNVector3(0, 1.34, 0)

        let shorts = box(
            width: 0.58 * buildScale,
            height: 0.40,
            length: 0.42 * buildScale,
            chamfer: 0.08,
            material: kit
        )
        shorts.position.y = -0.03
        pelvis.addChildNode(shorts)

        pelvis.addChildNode(spine)
        spine.position.y = 0.13
        let torso = box(
            width: 0.82 * buildScale,
            height: 0.88,
            length: 0.38 * buildScale,
            chamfer: 0.18,
            material: skin
        )
        torso.position.y = 0.48
        spine.addChildNode(torso)

        let chest = box(
            width: 0.70 * buildScale,
            height: 0.28,
            length: 0.405 * buildScale,
            chamfer: 0.10,
            material: shadowSkin
        )
        chest.position = SCNVector3(0, 0.66, 0.01)
        spine.addChildNode(chest)

        spine.addChildNode(head)
        head.position = SCNVector3(0, 1.17, 0)
        let neck = cylinder(radius: 0.11, height: 0.23, material: shadowSkin)
        neck.position.y = -0.20
        head.addChildNode(neck)
        let skull = sphere(radius: 0.25, material: skin)
        skull.scale = SCNVector3(0.88, 1.10, 0.92)
        head.addChildNode(skull)
        let hairCap = sphere(radius: 0.255, material: hair)
        hairCap.scale = SCNVector3(0.90, 0.42, 0.94)
        hairCap.position.y = 0.17
        head.addChildNode(hairCap)

        attachArm(
            shoulder: leadShoulder,
            elbow: leadElbow,
            x: 0.46 * buildScale,
            z: 0.13,
            material: skin,
            gloveMaterial: kit,
            to: spine
        )
        attachArm(
            shoulder: rearShoulder,
            elbow: rearElbow,
            x: -0.46 * buildScale,
            z: -0.13,
            material: shadowSkin,
            gloveMaterial: kit,
            to: spine
        )
        attachLeg(
            hip: leadHip,
            knee: leadKnee,
            ankle: leadAnkle,
            x: 0.20 * buildScale,
            z: 0.17 * motionProfile.stanceDepth,
            material: skin,
            shoeMaterial: accent,
            to: pelvis
        )
        attachLeg(
            hip: rearHip,
            knee: rearKnee,
            ankle: rearAnkle,
            x: -0.20 * buildScale,
            z: -0.17 * motionProfile.stanceDepth,
            material: shadowSkin,
            shoeMaterial: accent,
            to: pelvis
        )
    }

    private func attachArm(
        shoulder: SCNNode,
        elbow: SCNNode,
        x: CGFloat,
        z: CGFloat,
        material: SCNMaterial,
        gloveMaterial: SCNMaterial,
        to parent: SCNNode
    ) {
        parent.addChildNode(shoulder)
        shoulder.position = SCNVector3(x, 0.84, z)
        shoulder.addChildNode(sphere(radius: 0.12, material: material))
        shoulder.addChildNode(segment(length: 0.58, radius: 0.105, material: material))
        shoulder.addChildNode(elbow)
        elbow.position.y = -0.58
        elbow.addChildNode(sphere(radius: 0.10, material: material))
        elbow.addChildNode(segment(length: 0.54, radius: 0.09, material: material))
        let glove = sphere(radius: 0.17, material: gloveMaterial)
        glove.scale = SCNVector3(1.0, 0.90, 1.18)
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
        to parent: SCNNode
    ) {
        parent.addChildNode(hip)
        hip.position = SCNVector3(x, -0.18, z)
        hip.addChildNode(sphere(radius: 0.15, material: material))
        hip.addChildNode(segment(length: 0.66, radius: 0.14, material: material))
        hip.addChildNode(knee)
        knee.position.y = -0.66
        knee.addChildNode(sphere(radius: 0.115, material: material))
        knee.addChildNode(segment(length: 0.64, radius: 0.105, material: material))
        knee.addChildNode(ankle)
        ankle.position.y = -0.64
        let shoe = box(width: 0.22, height: 0.13, length: 0.39, chamfer: 0.055, material: shoeMaterial)
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

    private func material(_ color: UIColor) -> SCNMaterial {
        let result = SCNMaterial()
        result.diffuse.contents = color
        result.roughness.contents = 0.82
        result.metalness.contents = 0.02
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
