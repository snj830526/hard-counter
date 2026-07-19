import CoreGraphics
import SceneKit

/// Builds the presentation-only sway clip from canonical screen input. Combat
/// evasion rules remain in SwayInputResolver/CombatEngine; this type owns only
/// the deterministic screen-to-body pose conversion used by the 3D rig.
enum Fighter3DSwayMotionComposer {
    struct Components {
        let forward: CGFloat
        let lateral: CGFloat
        let screenHorizontal: CGFloat
        let screenVertical: CGFloat
    }

    static func components(
        direction: SwayDirection,
        screenDirection: CGVector
    ) -> Components {
        let swayLength = max(hypot(
            screenDirection.dx,
            screenDirection.dy
        ), 0.001)
        let sway = CGVector(
            dx: screenDirection.dx / swayLength,
            dy: screenDirection.dy / swayLength
        )
        return Components(
            forward: direction.forward,
            lateral: direction.lateral,
            screenHorizontal: sway.dx,
            screenVertical: sway.dy
        )
    }

    static func makeClip(
        direction: SwayDirection,
        screenDirection: CGVector,
        performance rawPerformance: CGFloat,
        motionProfile: Fighter3DMotionProfile,
        guardPose: Fighter3DPose,
        applyGuardIdentity: (inout Fighter3DPose) -> Void
    ) -> Fighter3DMotionClip {
        let components = components(
            direction: direction,
            screenDirection: screenDirection
        )
        let performance = min(max(rawPerformance, 0.72), 1.20)
        let loadFrame = FighterFullBodyActionFrame(
            forward: components.forward * 0.22,
            lateral: -components.lateral * 0.18,
            screenHorizontal: -components.screenHorizontal * 0.18,
            screenVertical: -components.screenVertical * 0.18,
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
            screenHorizontal: components.screenHorizontal,
            screenVertical: components.screenVertical,
            intensity: performance * motionProfile.swayRange,
            compression: 0.44
                + max(components.forward, 0) * 0.24
                + abs(components.lateral) * 0.10,
            weightShift: components.lateral,
            reach: 0
        )
        var evadePose = FighterFullBodyActionPoseSolver.sway(
            frame: evadeFrame,
            from: guardPose
        )
        applyGuardIdentity(&evadePose)

        let apexFrame = FighterFullBodyActionFrame(
            forward: components.forward * 1.12,
            lateral: components.lateral * 1.14,
            screenHorizontal: components.screenHorizontal * 1.14,
            screenVertical: components.screenVertical * 1.14,
            intensity: performance * motionProfile.swayRange,
            compression: 0.52
                + max(components.forward, 0) * 0.28
                + abs(components.lateral) * 0.12,
            weightShift: components.lateral,
            reach: 0
        )
        var apexPose = FighterFullBodyActionPoseSolver.sway(
            frame: apexFrame,
            from: guardPose
        )
        applyGuardIdentity(&apexPose)

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
}
