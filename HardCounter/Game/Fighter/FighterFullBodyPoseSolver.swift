import CoreGraphics
import SceneKit

/// Converts one coherent body state into a connected joint chain. Motion
/// sources describe balance and support; they no longer offset hips, spine,
/// shoulders and head independently.
enum FighterFullBodyPoseSolver {
    static func apply(
        body: FighterBodyMotionFrame,
        to source: Fighter3DPose
    ) -> Fighter3DPose {
        var pose = source
        let weightBias = (body.weightOnLeadFoot - 0.5) * 2
        let compression = max(-body.compression, 0)
        let freeFootAmount = 1 - body.plantedness

        // 1. Center of mass and pelvis establish the motion.
        pose.rootX += body.centerOfMassOffset.x
        pose.rootZ += body.centerOfMassOffset.y
        pose.rootY -= compression * 0.045
        pose.pelvisRoll += weightBias * 0.075
        pose.pelvis.x += Float(compression * 0.045)

        // 2. The support leg catches the mass while the free leg is allowed to
        // travel. Both knees remain anatomically forward through sanitization.
        let leadSupport: CGFloat = body.supportFoot == .lead ? 1.0 : 0.35
        let rearSupport: CGFloat = body.supportFoot == .rear ? 1.0 : 0.35
        pose.leadKnee.x += Float(compression * 0.16 * leadSupport)
        pose.rearKnee.x += Float(compression * 0.16 * rearSupport)
        pose.leadHip.x -= Float(compression * 0.045 * leadSupport)
        pose.rearHip.x -= Float(compression * 0.045 * rearSupport)
        if body.supportFoot == .lead {
            pose.rearAnklePitch += freeFootAmount * 0.055
        } else if body.supportFoot == .rear {
            pose.leadAnklePitch += freeFootAmount * 0.055
        }

        // 3. Rib cage and head counter the pelvis instead of being translated
        // separately. This preserves the waist connection in every action.
        pose.spineRoll -= weightBias * 0.055
        pose.spine.x -= Float(compression * 0.025)
        pose.head.z += Float(weightBias * 0.032)

        // 4. The guard follows the rib cage with a smaller delay/amplitude.
        pose.leadShoulder.z -= Float(weightBias * 0.025)
        pose.rearShoulder.z -= Float(weightBias * 0.020)
        pose.leadElbow.z += Float(weightBias * 0.014)
        pose.rearElbow.z += Float(weightBias * 0.012)
        return pose
    }
}
