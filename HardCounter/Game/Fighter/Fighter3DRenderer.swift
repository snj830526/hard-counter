import SceneKit
import SpriteKit

/// Experimental presentation-only renderer. Combat, input, hit detection and
/// networking continue to use FighterNode; this object only replaces its art.
final class Fighter3DRenderer {
    let spriteNode: SK3DNode

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
    private var swayPerformance: CGFloat = 1
    private var gaitClock: CGFloat = 0
    private var hitElapsed: TimeInterval?
    private var hitKind: HitKind = .normal
    private var hitProfile = PunchProfile()
    private var followThrough: CGFloat = 0
    private var whiffOverreach: CGFloat = 0

    init(appearance: FighterAppearance) {
        let scene = SCNScene()
        scene.background.contents = UIColor.clear

        spriteNode = SK3DNode(viewportSize: CGSize(width: 176, height: 206))
        spriteNode.scnScene = scene
        spriteNode.position = CGPoint(x: 0, y: 82)
        spriteNode.zPosition = 20
        spriteNode.isPlaying = true
        spriteNode.loops = true
        spriteNode.isUserInteractionEnabled = false

        buildCamera(in: scene)
        buildLights(in: scene)
        buildFighter(in: scene, appearance: appearance)
        apply(.guardPose)
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

    func prepareSway(_ direction: SwayDirection, performance: CGFloat) {
        swayDirection = direction
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
        apply(.guardPose)
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
            gaitClock += displacement * 0.19
        } else if movementAmount > 0.04 {
            gaitClock += CGFloat(deltaTime) * (4.8 + movementAmount * 2.2)
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
            )
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
            var pose = Fighter3DPose.guardPose
            let breath = sin(CGFloat(phaseElapsed) * 4.4)
            pose.rootY += breath * 0.015
            pose.spinePitch += breath * 0.018
            guard movementAmount > 0.035 else { return pose }

            let step = sin(gaitClock)
            let settle = cos(gaitClock * 2)
            pose.rootY += abs(step) * 0.028
            pose.rootZ += settle * 0.025 * movementAmount
            pose.pelvisRoll += step * 0.055 * movementAmount
            pose.spineRoll -= step * 0.035 * movementAmount
            pose.leadHip.x += Float(step * 0.36 * movementAmount)
            pose.rearHip.x -= Float(step * 0.36 * movementAmount)
            pose.leadKnee.x += Float(max(-step, 0) * 0.34 * movementAmount)
            pose.rearKnee.x += Float(max(step, 0) * 0.34 * movementAmount)
            return pose

        case .punchStartup:
            let duration = CombatTuning.punchStartup * punchProfile.startupScale
            return Fighter3DPose.guardPose.blended(
                to: .punchLoad(hand: activeHand, technique: punchProfile.technique),
                amount: smooth(progress(duration))
            )

        case .punchActive:
            let duration = CombatTuning.punchActive * punchProfile.activeScale
            let power = CGFloat(min(max(punchProfile.powerScale, 0.7), 1.3))
            return Fighter3DPose.punchLoad(
                hand: activeHand,
                technique: punchProfile.technique
            ).blended(
                to: .punchStrike(
                    hand: activeHand,
                    technique: punchProfile.technique,
                    power: power
                ),
                amount: snap(progress(duration))
            )

        case .punchRecovery:
            let duration = CombatTuning.punchRecovery * punchProfile.recoveryScale
            return Fighter3DPose.punchStrike(
                hand: activeHand,
                technique: punchProfile.technique,
                power: CGFloat(punchProfile.powerScale)
            ).blended(to: .guardPose, amount: smooth(progress(duration)))

        case .swaying:
            let amount = sin(min(progress(CombatTuning.swayDuration), 1) * .pi)
            return Fighter3DPose.guardPose.blended(
                to: .sway(direction: swayDirection, performance: swayPerformance),
                amount: smooth(amount)
            )

        case .hit:
            return .guardPose

        case .knockedOut:
            let t = smooth(progress(0.52))
            return Fighter3DPose.guardPose.blended(to: .knockedOut, amount: t)
        }
    }

    private func progress(_ duration: TimeInterval) -> CGFloat {
        CGFloat(min(max(phaseElapsed / max(duration, 0.001), 0), 1))
    }

    private func apply(_ pose: Fighter3DPose) {
        skeletonRoot.position = SCNVector3(pose.rootX, pose.rootY, pose.rootZ)
        skeletonRoot.eulerAngles.x = Float(pose.rootPitch)
        skeletonRoot.eulerAngles.z = Float(pose.rootRoll)
        pelvis.eulerAngles = pose.pelvis
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
        leadAnkle.eulerAngles.x = -(pose.leadHip.x + pose.leadKnee.x)
        rearAnkle.eulerAngles.x = -(pose.rearHip.x + pose.rearKnee.x)
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
            x: 0.23 * buildScale,
            z: 0.22,
            material: skin,
            shoeMaterial: accent,
            to: pelvis
        )
        attachLeg(
            hip: rearHip,
            knee: rearKnee,
            ankle: rearAnkle,
            x: -0.23 * buildScale,
            z: -0.24,
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

private struct Fighter3DPose {
    var rootX: CGFloat = 0
    var rootY: CGFloat = 0
    var rootZ: CGFloat = 0
    var rootPitch: CGFloat = 0
    var rootRoll: CGFloat = 0
    var pelvis = SCNVector3Zero
    var spine = SCNVector3Zero
    var head = SCNVector3Zero
    var leadShoulder = SCNVector3Zero
    var leadElbow = SCNVector3Zero
    var rearShoulder = SCNVector3Zero
    var rearElbow = SCNVector3Zero
    var leadHip = SCNVector3Zero
    var leadKnee = SCNVector3Zero
    var rearHip = SCNVector3Zero
    var rearKnee = SCNVector3Zero

    var pelvisRoll: CGFloat {
        get { CGFloat(pelvis.z) }
        set { pelvis.z = Float(newValue) }
    }
    var spinePitch: CGFloat {
        get { CGFloat(spine.x) }
        set { spine.x = Float(newValue) }
    }
    var spineRoll: CGFloat {
        get { CGFloat(spine.z) }
        set { spine.z = Float(newValue) }
    }

    static let guardPose: Fighter3DPose = {
        var pose = Fighter3DPose()
        pose.rootY = -0.01
        pose.rootZ = -0.02
        pose.pelvis = SCNVector3(-0.04, 0.16, 0.02)
        pose.spine = SCNVector3(-0.08, -0.08, -0.02)
        pose.head = SCNVector3(0.08, 0, 0)
        pose.leadShoulder = SCNVector3(-0.60, 0.10, -0.20)
        pose.leadElbow = SCNVector3(-1.62, 0.05, -0.22)
        pose.rearShoulder = SCNVector3(-0.72, -0.08, 0.18)
        pose.rearElbow = SCNVector3(-1.72, -0.03, 0.24)
        pose.leadHip = SCNVector3(-0.22, 0, -0.07)
        pose.leadKnee = SCNVector3(0.46, 0, 0)
        pose.rearHip = SCNVector3(0.24, 0, 0.09)
        pose.rearKnee = SCNVector3(-0.50, 0, 0)
        return pose
    }()

    static func punchLoad(hand: PunchHand, technique: PunchTechnique) -> Fighter3DPose {
        var pose = guardPose
        let sign: Float = hand == .rear ? -1 : 1
        pose.rootY -= 0.055
        pose.rootZ -= 0.10
        pose.pelvis.y -= 0.26 * sign
        pose.spine.y -= 0.22 * sign
        pose.spine.x += technique == .uppercut ? 0.18 : 0.05
        if hand == .rear {
            pose.rearShoulder.x = -0.38
            pose.rearShoulder.y = -0.34
            pose.rearElbow.x = -1.82
            pose.rearHip.x += 0.13
            pose.rearKnee.x -= 0.16
        } else {
            pose.leadShoulder.x = -0.42
            pose.leadShoulder.y = 0.26
            pose.leadElbow.x = -1.72
            pose.leadHip.x += 0.10
        }
        return pose
    }

    static func punchStrike(
        hand: PunchHand,
        technique: PunchTechnique,
        power: CGFloat
    ) -> Fighter3DPose {
        var pose = guardPose
        let handSign: Float = hand == .rear ? 1 : -1
        pose.rootZ += 0.12 + power * 0.08
        pose.rootY += technique == .uppercut ? 0.10 : 0
        pose.pelvis.y += 0.36 * handSign * Float(power)
        pose.spine.y += 0.48 * handSign * Float(power)
        pose.spine.x -= technique == .straight ? 0.12 : 0.02
        if technique == .smash { pose.spine.z += 0.20 * handSign }
        if technique == .uppercut { pose.spine.x += 0.25 }

        if hand == .rear {
            pose.rearShoulder = technique == .uppercut
                ? SCNVector3(-1.12, 0.18, 0.12)
                : SCNVector3(-1.52, 0.02, 0.05)
            pose.rearElbow = technique == .smash
                ? SCNVector3(-0.28, 0, 0.46)
                : SCNVector3(-0.08, 0, 0.03)
            pose.rearHip.x -= 0.18
            pose.rearKnee.x += 0.08
        } else {
            pose.leadShoulder = technique == .uppercut
                ? SCNVector3(-1.08, -0.16, -0.10)
                : SCNVector3(-1.48, -0.02, -0.05)
            pose.leadElbow = technique == .smash
                ? SCNVector3(-0.24, 0, -0.42)
                : SCNVector3(-0.06, 0, -0.03)
            pose.leadHip.x -= 0.14
        }
        return pose
    }

    static func sway(direction: SwayDirection, performance: CGFloat) -> Fighter3DPose {
        var pose = guardPose
        let amount = max(performance, 0.72)
        switch direction {
        case .left:
            pose.rootX = -0.30 * amount
            pose.rootY -= 0.08
            pose.pelvis.z = 0.13
            pose.spine.z = 0.30
            pose.head.z = -0.12
        case .right:
            pose.rootX = 0.30 * amount
            pose.rootY -= 0.08
            pose.pelvis.z = -0.13
            pose.spine.z = -0.30
            pose.head.z = 0.12
        case .back:
            pose.rootZ = -0.32 * amount
            pose.pelvis.x = 0.10
            pose.spine.x = 0.34
            pose.head.x = -0.18
        case .forward:
            pose.rootZ = 0.22 * amount
            pose.rootY -= 0.16
            pose.pelvis.x = -0.16
            pose.spine.x = -0.28
            pose.head.x = 0.15
        }
        pose.leadKnee.x += 0.20
        pose.rearKnee.x -= 0.18
        return pose
    }

    static func hit(technique: PunchTechnique, strength: CGFloat) -> Fighter3DPose {
        var pose = guardPose
        pose.rootZ = -0.26 * strength
        pose.pelvis.x = 0.12
        pose.spine.x = technique == .uppercut ? -0.22 : 0.34
        pose.spine.z = technique == .smash ? -0.28 : -0.10
        pose.head.x = technique == .uppercut ? -0.42 : 0.28
        pose.head.z = technique == .smash ? -0.22 : -0.08
        pose.leadShoulder.x = -0.34
        pose.rearShoulder.x = -0.38
        pose.leadKnee.x += 0.18
        pose.rearKnee.x += 0.22
        return pose
    }

    static let knockedOut: Fighter3DPose = {
        var pose = guardPose
        pose.rootY = -0.75
        pose.rootZ = -0.18
        pose.rootPitch = .pi / 2.25
        pose.rootRoll = -0.22
        pose.spine.x = 0.28
        pose.leadShoulder.x = -0.18
        pose.rearShoulder.x = -0.12
        pose.leadKnee.x = 0.65
        pose.rearKnee.x = 0.52
        return pose
    }()

    func blended(to other: Fighter3DPose, amount: CGFloat) -> Fighter3DPose {
        let t = min(max(amount, 0), 1)
        return Fighter3DPose(
            rootX: mix(rootX, other.rootX, t),
            rootY: mix(rootY, other.rootY, t),
            rootZ: mix(rootZ, other.rootZ, t),
            rootPitch: mix(rootPitch, other.rootPitch, t),
            rootRoll: mix(rootRoll, other.rootRoll, t),
            pelvis: pelvis.mixed(with: other.pelvis, amount: t),
            spine: spine.mixed(with: other.spine, amount: t),
            head: head.mixed(with: other.head, amount: t),
            leadShoulder: leadShoulder.mixed(with: other.leadShoulder, amount: t),
            leadElbow: leadElbow.mixed(with: other.leadElbow, amount: t),
            rearShoulder: rearShoulder.mixed(with: other.rearShoulder, amount: t),
            rearElbow: rearElbow.mixed(with: other.rearElbow, amount: t),
            leadHip: leadHip.mixed(with: other.leadHip, amount: t),
            leadKnee: leadKnee.mixed(with: other.leadKnee, amount: t),
            rearHip: rearHip.mixed(with: other.rearHip, amount: t),
            rearKnee: rearKnee.mixed(with: other.rearKnee, amount: t)
        )
    }
}

private extension SCNVector3 {
    func mixed(with other: SCNVector3, amount: CGFloat) -> SCNVector3 {
        SCNVector3(
            Float(mix(CGFloat(x), CGFloat(other.x), amount)),
            Float(mix(CGFloat(y), CGFloat(other.y), amount)),
            Float(mix(CGFloat(z), CGFloat(other.z), amount))
        )
    }
}

private func mix(_ from: CGFloat, _ to: CGFloat, _ amount: CGFloat) -> CGFloat {
    from + (to - from) * amount
}

private func smooth(_ value: CGFloat) -> CGFloat {
    let t = min(max(value, 0), 1)
    return t * t * (3 - 2 * t)
}

private func snap(_ value: CGFloat) -> CGFloat {
    let t = min(max(value, 0), 1)
    return 1 - pow(1 - t, 4)
}
