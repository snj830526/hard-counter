import CoreGraphics
import SceneKit

struct Fighter3DPose {
    var rootX: CGFloat = 0
    var rootY: CGFloat = 0
    var rootZ: CGFloat = 0
    var rootPitch: CGFloat = 0
    var rootRoll: CGFloat = 0
    var spineX: CGFloat = 0
    var spineY: CGFloat = 0
    var spineZ: CGFloat = 0
    var leadAnklePitch: CGFloat = 0
    var rearAnklePitch: CGFloat = 0
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
        pose.leadHip = SCNVector3(-0.16, 0, 0)
        pose.leadKnee = SCNVector3(0.36, 0, 0)
        pose.rearHip = SCNVector3(-0.12, 0, 0)
        pose.rearKnee = SCNVector3(0.34, 0, 0)
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
            pose.rearKnee.x += 0.12
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
        pose.rearKnee.x += 0.12
        return pose
    }

    static func hit(technique: PunchTechnique, strength: CGFloat) -> Fighter3DPose {
        var pose = guardPose
        let amount = min(max(strength, 0.65), 1.35)
        pose.leadShoulder.x = -0.34
        pose.rearShoulder.x = -0.38
        switch technique {
        case .straight:
            pose.rootZ = -0.28 * amount
            pose.rootY -= 0.035 * amount
            pose.pelvis.x = 0.14
            pose.spine.x = 0.34
            pose.spine.z = -0.10
            pose.head.x = 0.30
            pose.head.z = -0.08
            pose.leadHip.x += 0.12
            pose.rearHip.x += 0.16
            pose.leadKnee.x += 0.20
            pose.rearKnee.x += 0.25
        case .smash:
            pose.rootX = -0.17 * amount
            pose.rootZ = -0.20 * amount
            pose.rootRoll = -0.16 * amount
            pose.pelvis.y -= 0.18
            pose.pelvis.z = -0.16
            pose.spine.y -= 0.30
            pose.spine.z = -0.36
            pose.head.y = 0.18
            pose.head.z = -0.28
            pose.leadHip.x += 0.20
            pose.rearHip.x += 0.08
            pose.leadKnee.x += 0.26
            pose.rearKnee.x += 0.16
        case .uppercut:
            pose.rootY = 0.12 * amount
            pose.rootZ = -0.15 * amount
            pose.pelvis.x = -0.10
            pose.spine.x = -0.31
            pose.head.x = -0.46
            pose.leadShoulder.x = -0.48
            pose.rearShoulder.x = -0.46
            pose.leadHip.x -= 0.10
            pose.rearHip.x -= 0.08
            pose.leadKnee.x = max(pose.leadKnee.x - 0.13, 0.12)
            pose.rearKnee.x = max(pose.rearKnee.x - 0.10, 0.12)
        }
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
        pose.rearKnee.x = 0.62
        return pose
    }()

    /// Adds presentation personality without changing combat timing, damage or
    /// hit geometry. The latter remain owned by CombatEngine.
    func styled(
        with profile: Fighter3DMotionProfile,
        technique: PunchTechnique? = nil,
        signatureIntensity: CGFloat = 0
    ) -> Fighter3DPose {
        var pose = self
        pose.rootY += profile.guardHeight
        pose.spine.x += Float(profile.guardLean)

        pose.leadKnee.x *= Float(profile.kneeBend)
        pose.rearKnee.x *= Float(profile.kneeBend)

        let guardShift = Float(profile.guardTightness - 1)
        pose.leadShoulder.x -= guardShift * 0.10
        pose.rearShoulder.x -= guardShift * 0.10
        pose.leadElbow.x -= guardShift * 0.16
        pose.rearElbow.x -= guardShift * 0.16

        if technique == nil {
            pose.rootZ += profile.forwardBias
            pose.leadShoulder.x -= Float(profile.leadGuardReach * 0.35)
            pose.leadElbow.x += Float(profile.leadGuardReach * 1.15)
            pose.leadShoulder.y += Float(profile.leadGuardReach * 0.30)

            let asymmetry = Float(profile.guardAsymmetry)
            pose.leadShoulder.x += asymmetry * 0.45
            pose.leadElbow.x += asymmetry * 0.55
            pose.rearShoulder.x -= asymmetry * 0.40
            pose.rearElbow.x -= asymmetry * 0.55
        }

        pose.pelvis.y *= Float(profile.hipDrive)
        pose.spine.y *= Float(profile.hipDrive)
        if pose.rootZ > 0 {
            pose.rootZ *= profile.reach
        }

        if technique == profile.signatureTechnique, signatureIntensity > 0 {
            let accent = signatureIntensity * profile.signatureAccent
            switch profile.signatureTechnique {
            case .straight:
                pose.rootZ += 0.045 * accent
                pose.spine.x -= Float(0.055 * accent)
                pose.leadShoulder.x -= Float(0.045 * accent)
                pose.rearShoulder.x -= Float(0.045 * accent)
            case .smash:
                pose.pelvis.y *= Float(1 + 0.10 * accent)
                pose.spine.y *= Float(1 + 0.14 * accent)
                pose.spine.z *= Float(1 + 0.18 * accent)
                pose.rootY -= 0.025 * accent
            case .uppercut:
                if signatureIntensity < 0.60 {
                    pose.rootY -= 0.035 * accent
                    pose.spine.x += Float(0.055 * accent)
                    pose.leadKnee.x += Float(0.075 * accent)
                    pose.rearKnee.x += Float(0.075 * accent)
                } else {
                    pose.rootY += 0.070 * accent
                    pose.spine.x += Float(0.11 * accent)
                    pose.leadKnee.x -= Float(0.055 * accent)
                    pose.rearKnee.x -= Float(0.055 * accent)
                }
            }
        }
        return pose
    }

    func styledSway(with profile: Fighter3DMotionProfile) -> Fighter3DPose {
        var pose = styled(with: profile)
        pose.rootX *= profile.swayRange
        pose.rootZ *= profile.swayRange
        pose.spineX *= profile.swayRange
        pose.spineY *= profile.swayRange
        pose.spineZ *= profile.swayRange
        pose.spine.z *= Float(profile.swayRange)
        return pose
    }

    /// SwayDirection selects the boxing pose, while the continuous stick
    /// vector owns its visible travel. Keeping those responsibilities separate
    /// prevents arbitrary direction changes as the fighters rotate in the ring.
    func aligned(
        toScreenDirection direction: CGVector,
        swayDirection: SwayDirection,
        facingDirection: CGVector
    ) -> Fighter3DPose {
        let length = hypot(direction.dx, direction.dy)
        guard length > 0.001 else { return self }

        var pose = self
        let unit = CGVector(dx: direction.dx / length, dy: direction.dy / length)
        let travel: CGFloat
        switch swayDirection {
        case .back: travel = 0.32
        case .forward: travel = 0.22
        case .left, .right: travel = 0.30
        }
        let offset = Fighter3DSwayAlignment.torsoOffset(
            screenDirection: unit,
            facingDirection: facingDirection,
            pelvisYaw: CGFloat(pose.pelvis.y),
            travel: travel
        )

        // The torso node lives below the fighter's yawed skeleton and pelvis.
        // Convert the desired screen-horizontal travel back into that local
        // X/Z plane so diagonal facing never mirrors or suppresses the sway.
        pose.rootX = 0
        pose.spineX = offset.localX
        pose.spineY = offset.localY
        pose.spineZ = offset.localZ

        // Lean across the screen in the same direction as the stick. The hips
        // counter only slightly so the waist remains connected.
        pose.spine.z = Float(-unit.dx * 0.30 - unit.dy * 0.06)
        pose.pelvis.z = Float(unit.dx * 0.10 + unit.dy * 0.02)
        pose.head.z = Float(unit.dx * 0.10)
        return pose
    }

    /// Final anatomical guardrail. Procedural layers may add rotations, but a
    /// rendered legs must always bend in the same anatomical direction.
    func sanitized() -> Fighter3DPose {
        var pose = self
        pose.rootX = clamp(pose.rootX, minimum: -0.52, maximum: 0.52)
        pose.rootY = clamp(pose.rootY, minimum: -0.82, maximum: 0.20)
        pose.rootZ = clamp(pose.rootZ, minimum: -0.48, maximum: 0.42)
        pose.rootPitch = clamp(pose.rootPitch, minimum: -0.42, maximum: 1.52)
        pose.rootRoll = clamp(pose.rootRoll, minimum: -0.58, maximum: 0.58)
        pose.spineX = clamp(pose.spineX, minimum: -0.28, maximum: 0.28)
        pose.spineY = clamp(pose.spineY, minimum: -0.16, maximum: 0.16)
        pose.spineZ = clamp(pose.spineZ, minimum: -0.28, maximum: 0.28)
        pose.leadAnklePitch = clamp(pose.leadAnklePitch, minimum: -0.20, maximum: 0.26)
        pose.rearAnklePitch = clamp(pose.rearAnklePitch, minimum: -0.20, maximum: 0.26)

        pose.pelvis = pose.pelvis.clamped(
            x: -0.42...0.42,
            y: -0.72...0.72,
            z: -0.38...0.38
        )
        pose.spine = pose.spine.clamped(
            x: -0.52...0.58,
            y: -0.92...0.92,
            z: -0.52...0.52
        )
        pose.head = pose.head.clamped(
            x: -0.52...0.52,
            y: -0.48...0.48,
            z: -0.38...0.38
        )

        pose.leadShoulder = pose.leadShoulder.clamped(
            x: -1.68...0.10,
            y: -0.82...0.82,
            z: -0.72...0.72
        )
        pose.rearShoulder = pose.rearShoulder.clamped(
            x: -1.68...0.10,
            y: -0.82...0.82,
            z: -0.72...0.72
        )
        pose.leadElbow = pose.leadElbow.clamped(
            x: -2.06...0.10,
            y: -0.62...0.62,
            z: -0.72...0.72
        )
        pose.rearElbow = pose.rearElbow.clamped(
            x: -2.06...0.10,
            y: -0.62...0.62,
            z: -0.72...0.72
        )

        pose.leadHip = pose.leadHip.clamped(
            x: -0.62...0.62,
            y: -0.10...0.10,
            z: -0.035...0.035
        )
        pose.rearHip = pose.rearHip.clamped(
            x: -0.62...0.62,
            y: -0.10...0.10,
            z: -0.035...0.035
        )
        pose.leadKnee = pose.leadKnee.clamped(
            x: 0.08...0.96,
            y: -0.02...0.02,
            z: -0.02...0.02
        )
        pose.rearKnee = pose.rearKnee.clamped(
            x: 0.08...0.96,
            y: -0.02...0.02,
            z: -0.02...0.02
        )
        return pose
    }

    func blended(to other: Fighter3DPose, amount: CGFloat) -> Fighter3DPose {
        let t = min(max(amount, 0), 1)
        return Fighter3DPose(
            rootX: mix3D(rootX, other.rootX, t),
            rootY: mix3D(rootY, other.rootY, t),
            rootZ: mix3D(rootZ, other.rootZ, t),
            rootPitch: mix3D(rootPitch, other.rootPitch, t),
            rootRoll: mix3D(rootRoll, other.rootRoll, t),
            spineX: mix3D(spineX, other.spineX, t),
            spineY: mix3D(spineY, other.spineY, t),
            spineZ: mix3D(spineZ, other.spineZ, t),
            leadAnklePitch: mix3D(leadAnklePitch, other.leadAnklePitch, t),
            rearAnklePitch: mix3D(rearAnklePitch, other.rearAnklePitch, t),
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

    /// Adds only the locomotion deltas that must survive an action transition.
    /// Punch and sway poses keep their authored hip drive while a foot that was
    /// already travelling is allowed to land instead of snapping to guard.
    func applyingLocomotion(
        _ locomotion: Fighter3DPose,
        relativeTo reference: Fighter3DPose,
        upperBodyAmount: CGFloat = 0
    ) -> Fighter3DPose {
        var pose = self
        pose.rootY += locomotion.rootY - reference.rootY
        pose.rootRoll += locomotion.rootRoll - reference.rootRoll
        pose.pelvis.z += locomotion.pelvis.z - reference.pelvis.z
        pose.leadHip.x += locomotion.leadHip.x - reference.leadHip.x
        pose.rearHip.x += locomotion.rearHip.x - reference.rearHip.x
        pose.leadKnee.x += locomotion.leadKnee.x - reference.leadKnee.x
        pose.rearKnee.x += locomotion.rearKnee.x - reference.rearKnee.x
        pose.leadAnklePitch += locomotion.leadAnklePitch
        pose.rearAnklePitch += locomotion.rearAnklePitch

        let upper = min(max(upperBodyAmount, 0), 1)
        pose.spineX += (locomotion.spineX - reference.spineX) * upper
        pose.spineY += (locomotion.spineY - reference.spineY) * upper
        pose.spineZ += (locomotion.spineZ - reference.spineZ) * upper
        pose.spine.z += (locomotion.spine.z - reference.spine.z) * Float(upper)
        return pose
    }

    /// Presentation-only exhaustion layer. CombatEngine remains the owner of
    /// speed and power; this makes its low-stamina penalties readable in the rig.
    func fatigued(amount: CGFloat, breath: CGFloat) -> Fighter3DPose {
        let fatigue = min(max(amount, 0), 1)
        guard fatigue > 0.001 else { return self }
        var pose = self
        pose.rootY -= fatigue * 0.060
        pose.rootY += breath * fatigue * 0.016
        pose.rootZ -= fatigue * 0.035
        pose.pelvis.x -= Float(fatigue * 0.060)
        pose.spine.x -= Float(fatigue * 0.13)
        pose.spine.z += Float(breath * fatigue * 0.035)
        pose.head.x += Float(fatigue * 0.075)
        pose.leadShoulder.x += Float(fatigue * 0.20)
        pose.rearShoulder.x += Float(fatigue * 0.20)
        pose.leadElbow.x += Float(fatigue * 0.28)
        pose.rearElbow.x += Float(fatigue * 0.28)
        pose.leadHip.x += Float(fatigue * 0.10)
        pose.rearHip.x += Float(fatigue * 0.10)
        pose.leadKnee.x += Float(fatigue * 0.12)
        pose.rearKnee.x += Float(fatigue * 0.12)
        return pose
    }
}

extension SCNVector3 {
    func mixed(with other: SCNVector3, amount: CGFloat) -> SCNVector3 {
        SCNVector3(
            Float(mix3D(CGFloat(x), CGFloat(other.x), amount)),
            Float(mix3D(CGFloat(y), CGFloat(other.y), amount)),
            Float(mix3D(CGFloat(z), CGFloat(other.z), amount))
        )
    }

    func clamped(
        x xRange: ClosedRange<Float>,
        y yRange: ClosedRange<Float>,
        z zRange: ClosedRange<Float>
    ) -> SCNVector3 {
        SCNVector3(
            clamp(x, minimum: xRange.lowerBound, maximum: xRange.upperBound),
            clamp(y, minimum: yRange.lowerBound, maximum: yRange.upperBound),
            clamp(z, minimum: zRange.lowerBound, maximum: zRange.upperBound)
        )
    }
}

func clamp<T: Comparable>(
    _ value: T,
    minimum: T,
    maximum: T
) -> T {
    min(max(value, minimum), maximum)
}

private func mix3D(_ from: CGFloat, _ to: CGFloat, _ amount: CGFloat) -> CGFloat {
    from + (to - from) * amount
}
