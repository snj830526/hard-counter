import CoreGraphics
import Foundation
import SceneKit

/// Presentation-only characteristics of the boxing-machine chassis. The
/// human-readable shuffle remains authored by the full-body solvers; these
/// values only constrain and weight that result for the mechanical rig.
struct Fighter3DMechanicalMotionProfile {
    let mass: CGFloat
    let strideScale: CGFloat
    let liftScale: CGFloat
    let suspensionTravel: CGFloat
    let chassisLag: CGFloat
    let jointStiffness: CGFloat

    static func profile(for style: Fighter3DMotionStyle) -> Self {
        switch style {
        case .allRounder:
            return Self(
                mass: 1,
                strideScale: 0.92,
                liftScale: 0.88,
                suspensionTravel: 1,
                chassisLag: 1,
                jointStiffness: 1
            )
        case .pressure:
            return Self(
                mass: 1.22,
                strideScale: 0.84,
                liftScale: 0.76,
                suspensionTravel: 1.18,
                chassisLag: 1.20,
                jointStiffness: 0.88
            )
        case .outBoxer:
            return Self(
                mass: 0.82,
                strideScale: 0.98,
                liftScale: 1.02,
                suspensionTravel: 0.82,
                chassisLag: 0.76,
                jointStiffness: 1.16
            )
        case .rival:
            return Self(
                mass: 1.10,
                strideScale: 0.88,
                liftScale: 0.84,
                suspensionTravel: 1.08,
                chassisLag: 1.08,
                jointStiffness: 0.94
            )
        }
    }
}

struct Fighter3DMechanicalMotionResult {
    let pose: Fighter3DPose
    let armActuatorScale: CGFloat
    let legActuatorScale: CGFloat
    let coreScale: CGFloat

    static let neutral = Fighter3DMechanicalMotionResult(
        pose: .guardPose,
        armActuatorScale: 1,
        legActuatorScale: 1,
        coreScale: 1
    )
}

/// Adds chassis inertia, servo limits and landing suspension without owning a
/// second walk clock. Every response is driven by the existing locomotion and
/// body-motion frames, so support-foot order and foot IK remain authoritative.
struct Fighter3DMechanicalMotionController {
    let profile: Fighter3DMechanicalMotionProfile

    private var chassisX: CGFloat = 0
    private var chassisZ: CGFloat = 0
    private var landingCompression: CGFloat = 0
    private var armActuatorScale: CGFloat = 1
    private var legActuatorScale: CGFloat = 1
    private var coreScale: CGFloat = 1

    init(style: Fighter3DMotionStyle) {
        profile = .profile(for: style)
    }

    mutating func update(
        pose source: Fighter3DPose,
        locomotion: FighterLocomotionFrame,
        body: FighterBodyMotionFrame,
        phase: FighterPhase,
        phaseElapsed: TimeInterval,
        deltaTime: TimeInterval
    ) -> Fighter3DMechanicalMotionResult {
        let movement = locomotion.movementIntensity
        let supportAuthority: CGFloat = body.supportFoot == .both ? 0.72 : 1
        let lag = profile.chassisLag * profile.mass
        let targetX = -locomotion.lateralDrive * movement * 0.042 * lag
        let targetZ = -locomotion.forwardDrive * movement * 0.035 * lag
        chassisX = damp(
            chassisX,
            toward: targetX,
            response: 7.2 / profile.mass,
            deltaTime: deltaTime
        )
        chassisZ = damp(
            chassisZ,
            toward: targetZ,
            response: 6.4 / profile.mass,
            deltaTime: deltaTime
        )

        let landingTarget = min(locomotion.landingAmount, 1.35)
            * supportAuthority
            * profile.suspensionTravel
        let landingResponse = landingTarget > landingCompression
            ? 30 * profile.jointStiffness
            : 7.5 / profile.mass
        landingCompression = damp(
            landingCompression,
            toward: landingTarget,
            response: landingResponse,
            deltaTime: deltaTime
        )

        var pose = source
        if phase != .knockedOut {
            // Mechanical inertia belongs above the hips. Offsetting the rig
            // root made both hips travel while IK held the soles in place, so
            // the legs appeared to wobble and the upper body seemed to tow
            // them around the ring. The pelvis now follows the driven legs;
            // only the rib cage trails by a restrained amount.
            pose.spineX += chassisX * 0.62
            pose.spineZ += chassisZ * 0.62
            pose.rootY -= landingCompression * 0.040
            pose.pelvis.x += Float(landingCompression * 0.035)
            pose.spine.x -= Float(landingCompression * 0.018)
            pose.leadKnee.x += Float(landingCompression * 0.045)
            pose.rearKnee.x += Float(landingCompression * 0.045)
        }
        pose = mechanicallyLimited(pose)

        let armTarget: CGFloat
        switch phase {
        case .punchStartup: armTarget = 0.88
        case .punchActive: armTarget = 1.18
        case .punchRecovery: armTarget = 1.05
        case .swaying: armTarget = 0.94
        case .hit: armTarget = 0.90
        case .idle, .knockedOut: armTarget = 1
        }
        armActuatorScale = damp(
            armActuatorScale,
            toward: armTarget,
            response: 24 * profile.jointStiffness,
            deltaTime: deltaTime
        )

        let kneeLoad = min(
            (abs(CGFloat(pose.leadKnee.x)) + abs(CGFloat(pose.rearKnee.x))) * 0.10
                + landingCompression * 0.06,
            0.20
        )
        legActuatorScale = damp(
            legActuatorScale,
            toward: 1 - kneeLoad,
            response: 20 * profile.jointStiffness,
            deltaTime: deltaTime
        )

        let idlePulse = sin(CGFloat(phaseElapsed) * 3.8) * 0.018
        let actionPulse: CGFloat = phase == .punchActive
            ? 0.16 : (phase == .swaying ? 0.07 : 0)
        let coreTarget = 1 + idlePulse + actionPulse + landingCompression * 0.035
        coreScale = damp(
            coreScale,
            toward: coreTarget,
            response: 18 * profile.jointStiffness,
            deltaTime: deltaTime
        )

        return Fighter3DMechanicalMotionResult(
            pose: pose,
            armActuatorScale: armActuatorScale,
            legActuatorScale: legActuatorScale,
            coreScale: coreScale
        )
    }

    mutating func reset() {
        chassisX = 0
        chassisZ = 0
        landingCompression = 0
        armActuatorScale = 1
        legActuatorScale = 1
        coreScale = 1
    }

    /// Servo stops are deliberately tighter than the final anatomical safety
    /// net, but still preserve the same bend direction and useful boxing range.
    private func mechanicallyLimited(_ source: Fighter3DPose) -> Fighter3DPose {
        var pose = source
        let flexionLimit = Float(0.58 / profile.jointStiffness)
        let kneeMaximum = Float(0.92 / profile.jointStiffness)
        let hipTwistLimit = Float(0.20 / profile.jointStiffness)
        let hipSplayLimit = Float(0.085 / profile.jointStiffness)

        pose.leadHip.x = clamp(pose.leadHip.x, -flexionLimit, flexionLimit)
        pose.rearHip.x = clamp(pose.rearHip.x, -flexionLimit, flexionLimit)
        pose.leadHip.y = clamp(pose.leadHip.y, -hipSplayLimit, hipSplayLimit)
        pose.rearHip.y = clamp(pose.rearHip.y, -hipSplayLimit, hipSplayLimit)
        pose.leadHip.z = clamp(pose.leadHip.z, -hipTwistLimit, hipTwistLimit)
        pose.rearHip.z = clamp(pose.rearHip.z, -hipTwistLimit, hipTwistLimit)
        pose.leadKnee.x = clamp(pose.leadKnee.x, 0.09, kneeMaximum)
        pose.rearKnee.x = clamp(pose.rearKnee.x, 0.09, kneeMaximum)
        pose.leadAnklePitch = clamp(pose.leadAnklePitch, -0.18, 0.23)
        pose.rearAnklePitch = clamp(pose.rearAnklePitch, -0.18, 0.23)
        return pose
    }

    private func damp(
        _ value: CGFloat,
        toward target: CGFloat,
        response: CGFloat,
        deltaTime: TimeInterval
    ) -> CGFloat {
        let amount = 1 - CGFloat(exp(-Double(response) * deltaTime))
        return value + (target - value) * amount
    }

    private func clamp(_ value: Float, _ minimum: Float, _ maximum: Float) -> Float {
        min(max(value, minimum), maximum)
    }

    private func clamp(_ value: CGFloat, _ minimum: CGFloat, _ maximum: CGFloat) -> CGFloat {
        min(max(value, minimum), maximum)
    }
}
