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

        // The locomotion planner owns the only step clock. Solve the travelling
        // foot from that clock so its knee and hip cannot animate on a second,
        // unrelated cadence while the fighter root is moving.
        let swing = stepSwing(at: body.stepProgress) * body.stepIntensity
        let travel = body.localForward * swing * 0.15
        let lift = swing * (0.055 + abs(body.localLateral) * 0.015)
        if body.supportFoot == .rear {
            solveLeg(
                hip: &pose.leadHip,
                knee: &pose.leadKnee,
                anklePitch: &pose.leadAnklePitch,
                footOffset: CGPoint(x: travel, y: lift),
                amount: 0.68
            )
            pose.leadHip.z += Float(body.localLateral * swing * 0.075)
            pose.rearHip.z -= Float(body.localLateral * swing * 0.025)
        } else if body.supportFoot == .lead {
            solveLeg(
                hip: &pose.rearHip,
                knee: &pose.rearKnee,
                anklePitch: &pose.rearAnklePitch,
                footOffset: CGPoint(x: travel, y: lift),
                amount: 0.68
            )
            pose.rearHip.z += Float(body.localLateral * swing * 0.075)
            pose.leadHip.z -= Float(body.localLateral * swing * 0.025)
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

    private static func solveLeg(
        hip: inout SCNVector3,
        knee: inout SCNVector3,
        anklePitch: inout CGFloat,
        footOffset: CGPoint,
        amount: CGFloat
    ) {
        let solution = FighterLegIK.solve(
            upperAngle: CGFloat(hip.x),
            kneeAngle: CGFloat(knee.x),
            bendDirection: 1,
            footOffset: footOffset,
            upperLength: 0.66,
            lowerLength: 0.64
        )
        hip.x += Float(solution.hipCorrection * amount)
        knee.x += Float(solution.kneeCorrection * amount)
        // Keep the sole near the canvas while the two-bone chain changes.
        anklePitch -= (solution.hipCorrection + solution.kneeCorrection) * amount
    }

    private static func stepSwing(at progress: CGFloat) -> CGFloat {
        guard progress > 0.10, progress < 0.82 else { return 0 }
        return sin((progress - 0.10) / 0.72 * .pi)
    }
}
