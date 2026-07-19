import CoreGraphics
import SceneKit

/// Semantic targets shared by every full-body action. An action describes
/// where the boxer's mass goes; the solver distributes that intent from the
/// legs through the pelvis, rib cage, head and guard as one connected chain.
struct FighterFullBodyActionFrame {
    let forward: CGFloat
    let lateral: CGFloat
    let screenHorizontal: CGFloat
    let screenVertical: CGFloat
    let intensity: CGFloat
    let compression: CGFloat
    let weightShift: CGFloat
    let reach: CGFloat

    static let neutral = FighterFullBodyActionFrame(
        forward: 0,
        lateral: 0,
        screenHorizontal: 0,
        screenVertical: 0,
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
        let amount = min(max(
            frame.intensity * CombatTuning.swayMotionAmplitude,
            0
        ), 1.48)
        let lateral = frame.lateral * amount
        let forward = frame.forward * amount
        // The shared 3D viewport mirrors its camera-space horizontal motion
        // relative to the SpriteKit stick vector. Keep this correction in one
        // canonical value so root travel and the connected torso lean agree.
        let screenHorizontal = -frame.screenHorizontal * amount
        let sideLoad = frame.weightShift * amount
        let compression = frame.compression * amount

        // Feet and knees receive the movement before the torso. Positive
        // lateral intent loads the lead side in the rig's local stance.
        let leadLoad = max(sideLoad, 0) + max(forward, 0) * 0.25
        let rearLoad = max(-sideLoad, 0) + max(-forward, 0) * 0.20
        // Camera-space displacement is canonical and never depends on which
        // side of the ring owns the fighter. Anatomical forward/lateral values
        // only decide how the planted legs and torso carry that displacement.
        pose.rootY += frame.screenVertical * amount * 0.28
        pose.rootY -= 0.14 * compression
        pose.leadHip.x -= Float(leadLoad * 0.055)
        pose.rearHip.x -= Float(rearLoad * 0.055)
        pose.leadKnee.x += Float(0.09 * compression + leadLoad * 0.15)
        pose.rearKnee.x += Float(0.09 * compression + rearLoad * 0.15)
        pose.leadAnklePitch += leadLoad * 0.035
        pose.rearAnklePitch += rearLoad * 0.035

        // The root displacement is deliberately smaller than the chest arc.
        // A sway is a weight transfer inside the stance, not a teleport.
        // Root position belongs to the renderer's parent coordinate space.
        // Local lateral still owns only the anatomical weight transfer.
        pose.rootX += screenHorizontal * 0.30
        pose.rootZ += forward * 0.22
        // The visible lean follows the stick in camera space. SceneKit's
        // positive Z rotation leans an upright chain toward screen-left, so
        // use the inverse screen sign here instead of fighter-local lateral.
        // Local lateral remains responsible only for anatomical leg loading.
        pose.pelvisRoll -= screenHorizontal * 0.13
        pose.pelvis.x += Float(-forward * 0.16 + compression * 0.055)
        pose.pelvis.y += Float(lateral * 0.14)

        // Spine position remains untouched. Rotation around the connected
        // waist creates the visible arc and the head counters just enough to
        // keep the eyes on the opponent.
        pose.spineRoll -= screenHorizontal * 0.24
        pose.spinePitch += -forward * 0.29 + compression * 0.045
        pose.spine.y -= Float(lateral * 0.085)
        pose.head.z += Float(screenHorizontal * 0.17)
        pose.head.x += Float(forward * 0.13 - compression * 0.032)

        // Both gloves travel with the rib cage. Small asymmetric elbow folds
        // preserve a compact guard instead of leaving either hand behind.
        pose.leadShoulder.z += Float(screenHorizontal * 0.055)
        pose.rearShoulder.z += Float(screenHorizontal * 0.045)
        pose.leadElbow.z -= Float(screenHorizontal * 0.035)
        pose.rearElbow.z -= Float(screenHorizontal * 0.030)
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
        let amount = min(max(
            frame.intensity * CombatTuning.punchMotionAmplitude,
            0
        ), 1.48)
        let handSign: CGFloat = hand == .lead ? -1 : 1
        let transfer = frame.weightShift * amount
        let compression = frame.compression * amount
        let reach = frame.reach * amount

        let leadLoad = max(transfer, 0)
        let rearLoad = max(-transfer, 0)
        pose.rootY -= compression * 0.10
        pose.leadHip.x -= Float((compression * 0.035) + leadLoad * 0.045)
        pose.rearHip.x -= Float((compression * 0.035) + rearLoad * 0.045)
        pose.leadKnee.x += Float(compression * 0.13 + leadLoad * 0.10)
        pose.rearKnee.x += Float(compression * 0.13 + rearLoad * 0.10)

        // Rotation is distributed, never authored as an isolated shoulder
        // snap. The pelvis leads and the rib cage overtakes it near contact.
        pose.rootZ += frame.forward * reach * 0.105
        pose.pelvis.y += Float(handSign * reach * 0.18)
        pose.spine.y += Float(handSign * reach * 0.23)
        pose.pelvisRoll += frame.lateral * 0.060 * amount
        pose.spineRoll -= frame.lateral * 0.085 * amount

        switch technique {
        case .straight:
            pose.spinePitch += reach * 0.070
            if hand == .rear { pose.rearAnklePitch += max(reach, 0) * 0.14 }
        case .smash:
            pose.rootRoll += handSign * reach * 0.035
            pose.spineRoll += handSign * reach * 0.065
        case .uppercut:
            // Load downward, then extend both legs under the rising fist.
            let rise = max(reach - compression * 0.35, 0)
            pose.rootY += rise * 0.12
            pose.spinePitch += rise * 0.11
            pose.leadKnee.x -= Float(rise * 0.070)
            pose.rearKnee.x -= Float(rise * 0.070)
        }
        if reach > 0 {
            solveStrikingArm(
                in: &pose,
                hand: hand,
                technique: technique,
                reach: min(reach, 1)
            )
        }
        return pose
    }

    private static func solveStrikingArm(
        in pose: inout Fighter3DPose,
        hand: PunchHand,
        technique: PunchTechnique,
        reach: CGFloat
    ) {
        let target: CGPoint
        switch technique {
        case .straight:
            target = CGPoint(x: -1.075, y: -0.055)
        case .smash:
            target = CGPoint(x: -0.92, y: 0.085)
        case .uppercut:
            target = CGPoint(x: -0.79, y: 0.145)
        }

        var shoulder = hand == .lead ? pose.leadShoulder : pose.rearShoulder
        var elbow = hand == .lead ? pose.leadElbow : pose.rearElbow
        let current = armEndpoint(
            shoulderAngle: CGFloat(shoulder.x),
            elbowAngle: CGFloat(elbow.x)
        )
        let desired = CGPoint(
            x: current.x + (target.x - current.x) * reach,
            y: current.y + (target.y - current.y) * reach
        )
        let solution = solveArm(target: desired, bendDirection: -1)
        shoulder.x = Float(solution.shoulder)
        elbow.x = Float(solution.elbow)
        if hand == .lead {
            pose.leadShoulder = shoulder
            pose.leadElbow = elbow
        } else {
            pose.rearShoulder = shoulder
            pose.rearElbow = elbow
        }
    }

    private static func solveArm(
        target: CGPoint,
        bendDirection: CGFloat
    ) -> (shoulder: CGFloat, elbow: CGFloat) {
        let upper: CGFloat = 0.58
        let lower: CGFloat = 0.54
        let minimumReach = abs(upper - lower) + 0.02
        let maximumReach = upper + lower - 0.025
        let distance = max(hypot(target.x, target.y), 0.001)
        let reach = min(max(distance, minimumReach), maximumReach)
        let scale = reach / distance
        let clamped = CGPoint(x: target.x * scale, y: target.y * scale)
        let cosine = min(max(
            (reach * reach - upper * upper - lower * lower)
                / (2 * upper * lower),
            -1
        ), 1)
        let elbow = acos(cosine) * (bendDirection < 0 ? -1 : 1)
        let direction = atan2(clamped.x, -clamped.y)
        let shoulder = direction - atan2(
            lower * sin(elbow),
            upper + lower * cos(elbow)
        )
        return (shoulder, elbow)
    }

    private static func armEndpoint(
        shoulderAngle: CGFloat,
        elbowAngle: CGFloat
    ) -> CGPoint {
        let upper: CGFloat = 0.58
        let lower: CGFloat = 0.54
        return CGPoint(
            x: upper * sin(shoulderAngle)
                + lower * sin(shoulderAngle + elbowAngle),
            y: -upper * cos(shoulderAngle)
                - lower * cos(shoulderAngle + elbowAngle)
        )
    }
}
