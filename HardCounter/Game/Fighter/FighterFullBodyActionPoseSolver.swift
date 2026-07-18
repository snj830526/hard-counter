import CoreGraphics
import SceneKit

/// Semantic targets shared by every full-body action. An action describes
/// where the boxer's mass goes; the solver distributes that intent from the
/// legs through the pelvis, rib cage, head and guard as one connected chain.
struct FighterFullBodyActionFrame {
    let forward: CGFloat
    let lateral: CGFloat
    let intensity: CGFloat
    let compression: CGFloat
    let weightShift: CGFloat
    let reach: CGFloat

    static let neutral = FighterFullBodyActionFrame(
        forward: 0,
        lateral: 0,
        intensity: 0,
        compression: 0,
        weightShift: 0,
        reach: 0
    )
}

enum FighterFullBodyActionPoseSolver {
    /// Produces a boxing slip/duck without translating the spine away from the
    /// pelvis. The support leg accepts the mass first, then the pelvis carries
    /// the chest and guarded head along the requested analog direction.
    static func sway(
        frame: FighterFullBodyActionFrame,
        from guardPose: Fighter3DPose
    ) -> Fighter3DPose {
        var pose = guardPose
        let amount = min(max(frame.intensity, 0), 1.35)
        let lateral = frame.lateral * amount
        let forward = frame.forward * amount
        let sideLoad = frame.weightShift * amount
        let compression = frame.compression * amount

        // Feet and knees receive the movement before the torso. Positive
        // lateral intent loads the lead side in the rig's local stance.
        let leadLoad = max(sideLoad, 0) + max(forward, 0) * 0.25
        let rearLoad = max(-sideLoad, 0) + max(-forward, 0) * 0.20
        pose.rootY -= 0.11 * compression
        pose.leadHip.x -= Float(leadLoad * 0.055)
        pose.rearHip.x -= Float(rearLoad * 0.055)
        pose.leadKnee.x += Float(0.09 * compression + leadLoad * 0.15)
        pose.rearKnee.x += Float(0.09 * compression + rearLoad * 0.15)
        pose.leadAnklePitch += leadLoad * 0.035
        pose.rearAnklePitch += rearLoad * 0.035

        // The root displacement is deliberately smaller than the chest arc.
        // A sway is a weight transfer inside the stance, not a teleport.
        pose.rootX += lateral * 0.16
        pose.rootZ += forward * 0.17
        pose.pelvisRoll += lateral * 0.10
        pose.pelvis.x += Float(-forward * 0.12 + compression * 0.045)
        pose.pelvis.y += Float(lateral * 0.10)

        // Spine position remains untouched. Rotation around the connected
        // waist creates the visible arc and the head counters just enough to
        // keep the eyes on the opponent.
        pose.spineRoll += lateral * 0.24
        pose.spinePitch += -forward * 0.22 + compression * 0.035
        pose.spine.y -= Float(lateral * 0.065)
        pose.head.z -= Float(lateral * 0.13)
        pose.head.x += Float(forward * 0.10 - compression * 0.025)

        // Both gloves travel with the rib cage. Small asymmetric elbow folds
        // preserve a compact guard instead of leaving either hand behind.
        pose.leadShoulder.z -= Float(lateral * 0.055)
        pose.rearShoulder.z -= Float(lateral * 0.045)
        pose.leadElbow.z += Float(lateral * 0.035)
        pose.rearElbow.z += Float(lateral * 0.030)
        return pose
    }

    /// Connects an authored hand silhouette to the floor. Technique clips may
    /// choose different glove paths, but every strike must still load a leg,
    /// turn the hips, carry that turn through the ribs and recover over a base.
    static func strike(
        frame: FighterFullBodyActionFrame,
        hand: PunchHand,
        technique: PunchTechnique,
        to source: Fighter3DPose
    ) -> Fighter3DPose {
        var pose = source
        let amount = min(max(frame.intensity, 0), 1.35)
        let handSign: CGFloat = hand == .lead ? -1 : 1
        let transfer = frame.weightShift * amount
        let compression = frame.compression * amount
        let reach = frame.reach * amount

        let leadLoad = max(transfer, 0)
        let rearLoad = max(-transfer, 0)
        pose.rootY -= compression * 0.075
        pose.leadHip.x -= Float((compression * 0.035) + leadLoad * 0.045)
        pose.rearHip.x -= Float((compression * 0.035) + rearLoad * 0.045)
        pose.leadKnee.x += Float(compression * 0.13 + leadLoad * 0.10)
        pose.rearKnee.x += Float(compression * 0.13 + rearLoad * 0.10)

        // Rotation is distributed, never authored as an isolated shoulder
        // snap. The pelvis leads and the rib cage overtakes it near contact.
        pose.rootZ += frame.forward * reach * 0.075
        pose.pelvis.y += Float(handSign * reach * 0.13)
        pose.spine.y += Float(handSign * reach * 0.16)
        pose.pelvisRoll += frame.lateral * 0.045 * amount
        pose.spineRoll -= frame.lateral * 0.065 * amount

        switch technique {
        case .straight:
            pose.spinePitch -= reach * 0.045
            if hand == .rear { pose.rearAnklePitch += max(reach, 0) * 0.10 }
        case .smash:
            pose.rootRoll += handSign * reach * 0.055
            pose.spineRoll += handSign * reach * 0.085
        case .uppercut:
            // Load downward, then extend both legs under the rising fist.
            let rise = max(reach - compression * 0.35, 0)
            pose.rootY += rise * 0.085
            pose.spinePitch += rise * 0.075
            pose.leadKnee.x -= Float(rise * 0.055)
            pose.rearKnee.x -= Float(rise * 0.055)
        }
        return pose
    }
}
