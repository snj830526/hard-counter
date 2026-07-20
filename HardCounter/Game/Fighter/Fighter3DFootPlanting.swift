import Foundation
import CoreGraphics
import SceneKit
import simd

/// Owns the complete lifetime of the 3D rig's world-space foot contacts. The
/// renderer supplies a finished pose and locomotion frame; this controller
/// alone decides when a boot remains planted, travels, or returns to stance.
final class Fighter3DFootPlantController {
    private let presentationRoot: SCNNode
    private let skeletonRoot: SCNNode
    private let pelvis: SCNNode
    private let leadHip: SCNNode
    private let leadKnee: SCNNode
    private let leadAnkle: SCNNode
    private let rearHip: SCNNode
    private let rearKnee: SCNNode
    private let rearAnkle: SCNNode
    private let soleClearance: CGFloat

    private var leadFootPlantTarget: SCNVector3?
    private var rearFootPlantTarget: SCNVector3?
    private var neutralLeadFootPosition: SCNVector3?
    private var neutralRearFootPosition: SCNVector3?
    private var leadFootStepStart: SCNVector3?
    private var rearFootStepStart: SCNVector3?
    private var previousStepProgress: CGFloat = 1
    private var previousInitiatingFoot: FighterSupportFoot = .both
    private var recoveringActionFootPlants = false

    private(set) var rigGroundingOffset: CGFloat = 0

    init(
        presentationRoot: SCNNode,
        skeletonRoot: SCNNode,
        pelvis: SCNNode,
        leadHip: SCNNode,
        leadKnee: SCNNode,
        leadAnkle: SCNNode,
        rearHip: SCNNode,
        rearKnee: SCNNode,
        rearAnkle: SCNNode,
        soleClearance: CGFloat
    ) {
        self.presentationRoot = presentationRoot
        self.skeletonRoot = skeletonRoot
        self.pelvis = pelvis
        self.leadHip = leadHip
        self.leadKnee = leadKnee
        self.leadAnkle = leadAnkle
        self.rearHip = rearHip
        self.rearKnee = rearKnee
        self.rearAnkle = rearAnkle
        self.soleClearance = soleClearance
    }

    func phaseDidChange(from previousPhase: FighterPhase, to newPhase: FighterPhase) {
        if newPhase == .idle,
           previousPhase == .swaying || previousPhase == .hit {
            leadFootStepStart = leadFootPlantTarget
            rearFootStepStart = rearFootPlantTarget
            recoveringActionFootPlants = true
        } else if newPhase != .idle {
            recoveringActionFootPlants = false
        }
    }

    func reset() {
        leadFootPlantTarget = nil
        rearFootPlantTarget = nil
        leadFootStepStart = nil
        rearFootStepStart = nil
        previousStepProgress = 1
        previousInitiatingFoot = .both
        recoveringActionFootPlants = false
    }

    func calibrateRigGrounding() {
        let leadPosition = leadAnkle.convertPosition(
            SCNVector3Zero,
            to: presentationRoot
        )
        let rearPosition = rearAnkle.convertPosition(
            SCNVector3Zero,
            to: presentationRoot
        )
        let lowestAnkle = CGFloat(min(leadPosition.y, rearPosition.y))
        rigGroundingOffset = max(soleClearance - lowestAnkle, 0)
    }

    func captureNeutralFootPositions() {
        var leadPosition = leadAnkle.convertPosition(
            SCNVector3Zero,
            to: skeletonRoot
        )
        var rearPosition = rearAnkle.convertPosition(
            SCNVector3Zero,
            to: skeletonRoot
        )
        let minimumHalfWidth: Float = 0.30
        let minimumHalfStagger: Float = 0.30
        leadPosition.x = max(abs(leadPosition.x), minimumHalfWidth)
        rearPosition.x = -max(abs(rearPosition.x), minimumHalfWidth)
        leadPosition.z = max(abs(leadPosition.z), minimumHalfStagger)
        rearPosition.z = -max(abs(rearPosition.z), minimumHalfStagger)
        leadPosition.y = 0
        rearPosition.y = 0
        neutralLeadFootPosition = leadPosition
        neutralRearFootPosition = rearPosition
    }

    func apply(
        phase: FighterPhase,
        phaseElapsed: TimeInterval,
        locomotionFrame: FighterLocomotionFrame?,
        bodyMotion: FighterBodyMotionFrame,
        pose: Fighter3DPose
    ) {
        guard phase != .knockedOut,
              let frame = locomotionFrame,
              let neutralLeadFootPosition,
              let neutralRearFootPosition else {
            return
        }

        let leadCurrent = leadAnkle.convertPosition(SCNVector3Zero, to: nil)
        let rearCurrent = rearAnkle.convertPosition(SCNVector3Zero, to: nil)
        var desiredLead = skeletonRoot.convertPosition(
            neutralLeadFootPosition,
            to: nil
        )
        var desiredRear = skeletonRoot.convertPosition(
            neutralRearFootPosition,
            to: nil
        )
        let groundHeight = presentationRoot.convertPosition(
            SCNVector3(0, Float(soleClearance), 0),
            to: nil
        ).y
        desiredLead.y = groundHeight
        desiredRear.y = groundHeight
        if leadFootPlantTarget == nil { leadFootPlantTarget = desiredLead }
        if rearFootPlantTarget == nil { rearFootPlantTarget = desiredRear }

        let beganNewStep = frame.stepProgress + 0.001 < previousStepProgress
            || bodyMotion.initiatingFoot != previousInitiatingFoot
        if beganNewStep, bodyMotion.initiatingFoot != .both {
            leadFootStepStart = leadFootPlantTarget ?? leadCurrent
            rearFootStepStart = rearFootPlantTarget ?? rearCurrent
        }

        if phase == .swaying || phase == .hit {
            leadFootPlantTarget = leadFootPlantTarget ?? leadCurrent
            rearFootPlantTarget = rearFootPlantTarget ?? rearCurrent
            leadFootStepStart = leadFootPlantTarget
            rearFootStepStart = rearFootPlantTarget
        } else if bodyMotion.initiatingFoot == .both {
            recoverOrPlantNeutral(
                phaseElapsed: phaseElapsed,
                leadCurrent: leadCurrent,
                rearCurrent: rearCurrent,
                desiredLead: desiredLead,
                desiredRear: desiredRear
            )
        } else {
            updateSteppingTargets(
                frame: frame,
                bodyMotion: bodyMotion,
                leadCurrent: leadCurrent,
                rearCurrent: rearCurrent,
                desiredLead: desiredLead,
                desiredRear: desiredRear
            )
        }

        leadFootPlantTarget = reachablePlantTarget(
            leadFootPlantTarget ?? leadCurrent,
            from: leadCurrent,
            groundHeight: groundHeight
        )
        rearFootPlantTarget = reachablePlantTarget(
            rearFootPlantTarget ?? rearCurrent,
            from: rearCurrent,
            groundHeight: groundHeight
        )
        solveAnatomicalLeg(
            hip: leadHip,
            knee: leadKnee,
            ankle: leadAnkle,
            worldTarget: leadFootPlantTarget ?? leadCurrent,
            anklePitch: pose.leadAnklePitch
        )
        solveAnatomicalLeg(
            hip: rearHip,
            knee: rearKnee,
            ankle: rearAnkle,
            worldTarget: rearFootPlantTarget ?? rearCurrent,
            anklePitch: pose.rearAnklePitch
        )
        previousStepProgress = frame.stepProgress
        previousInitiatingFoot = bodyMotion.initiatingFoot
    }

    private func recoverOrPlantNeutral(
        phaseElapsed: TimeInterval,
        leadCurrent: SCNVector3,
        rearCurrent: SCNVector3,
        desiredLead: SCNVector3,
        desiredRear: SCNVector3
    ) {
        if recoveringActionFootPlants {
            let recovery = min(max(CGFloat(phaseElapsed / 0.22), 0), 1)
            leadFootPlantTarget = steppingTarget(
                from: leadFootStepStart ?? leadFootPlantTarget ?? leadCurrent,
                toward: desiredLead,
                progress: recovery,
                lift: 0
            )
            rearFootPlantTarget = steppingTarget(
                from: rearFootStepStart ?? rearFootPlantTarget ?? rearCurrent,
                toward: desiredRear,
                progress: recovery,
                lift: 0
            )
            if recovery >= 1 {
                recoveringActionFootPlants = false
                leadFootStepStart = desiredLead
                rearFootStepStart = desiredRear
            }
        } else {
            leadFootPlantTarget = desiredLead
            rearFootPlantTarget = desiredRear
            leadFootStepStart = desiredLead
            rearFootStepStart = desiredRear
        }
    }

    private func updateSteppingTargets(
        frame: FighterLocomotionFrame,
        bodyMotion: FighterBodyMotionFrame,
        leadCurrent: SCNVector3,
        rearCurrent: SCNVector3,
        desiredLead: SCNVector3,
        desiredRear: SCNVector3
    ) {
        let leadStart = leadFootStepStart ?? leadFootPlantTarget ?? leadCurrent
        let rearStart = rearFootStepStart ?? rearFootPlantTarget ?? rearCurrent
        let scale = CGFloat(max(abs(presentationRoot.presentation.scale.x), 0.01))
        let advance = max(frame.forwardDrive, 0) * bodyMotion.stepIntensity
        // Predict the next support point in rig-local forward space. Waiting
        // for `desiredLead/Rear` alone means waiting for the arena root to move,
        // so the torso necessarily leads the boot. The initiating leg now gets
        // a real forward plant target before any root translation occurs.
        let leadLongDestination = advancedPlantDestination(
            desiredLead,
            distance: advance * 0.74
        )
        let leadCatchDestination = advancedPlantDestination(
            desiredLead,
            distance: advance * 0.36
        )
        let rearLongDestination = advancedPlantDestination(
            desiredRear,
            distance: advance * 0.74
        )
        let rearCatchDestination = advancedPlantDestination(
            desiredRear,
            distance: advance * 0.36
        )
        let initiatingSwing = min(max(
            (frame.stepProgress - 0.055) / 0.305,
            0
        ), 1)
        switch bodyMotion.initiatingFoot {
        case .lead:
            if frame.stepProgress >= 0.055, frame.stepProgress <= 0.36 {
                leadFootPlantTarget = steppingTarget(
                    from: leadStart,
                    toward: leadLongDestination,
                    progress: initiatingSwing,
                    lift: frame.frontAnkleLift * scale
                )
            }
            if frame.stepProgress >= 0.54, frame.stepProgress <= 0.86 {
                rearFootPlantTarget = steppingTarget(
                    from: rearStart,
                    toward: rearCatchDestination,
                    progress: (frame.stepProgress - 0.54) / 0.32,
                    lift: frame.backAnkleLift * scale
                )
            }
        case .rear:
            if frame.stepProgress >= 0.055, frame.stepProgress <= 0.36 {
                rearFootPlantTarget = steppingTarget(
                    from: rearStart,
                    toward: rearLongDestination,
                    progress: initiatingSwing,
                    lift: frame.backAnkleLift * scale
                )
            }
            if frame.stepProgress >= 0.54, frame.stepProgress <= 0.86 {
                leadFootPlantTarget = steppingTarget(
                    from: leadStart,
                    toward: leadCatchDestination,
                    progress: (frame.stepProgress - 0.54) / 0.32,
                    lift: frame.frontAnkleLift * scale
                )
            }
        case .both:
            break
        }
    }

    private func advancedPlantDestination(
        _ neutralWorldPosition: SCNVector3,
        distance: CGFloat
    ) -> SCNVector3 {
        guard distance > 0.001 else { return neutralWorldPosition }
        var local = skeletonRoot.convertPosition(
            neutralWorldPosition,
            from: nil
        )
        local.z += Float(distance)
        return skeletonRoot.convertPosition(local, to: nil)
    }

    private func solveAnatomicalLeg(
        hip: SCNNode,
        knee: SCNNode,
        ankle: SCNNode,
        worldTarget: SCNVector3,
        anklePitch: CGFloat
    ) {
        let targetPosition = pelvis.convertPosition(worldTarget, from: nil)
        let target = SIMD3<Float>(
            targetPosition.x,
            targetPosition.y,
            targetPosition.z
        )
        let origin = SIMD3<Float>(
            hip.position.x,
            hip.position.y,
            hip.position.z
        )
        let displacement = target - origin
        let rawDistance = simd_length(displacement)
        guard rawDistance > 0.001 else { return }

        let thighLength: Float = 0.66
        let shinLength: Float = 0.64
        let minimumReach = abs(thighLength - shinLength) + 0.001
        let maximumReach = thighLength + shinLength - 0.012
        let distance = min(max(rawDistance, minimumReach), maximumReach)
        let legAxis = simd_normalize(displacement)
        let alongAxis = (
            thighLength * thighLength - shinLength * shinLength
                + distance * distance
        ) / (2 * distance)
        let bendHeight = sqrt(max(
            thighLength * thighLength - alongAxis * alongAxis,
            0
        ))

        let anatomicalForward = SIMD3<Float>(0, 0, 1)
        var kneePole = anatomicalForward
            - legAxis * simd_dot(anatomicalForward, legAxis)
        if simd_length_squared(kneePole) < 0.0001 {
            kneePole = SIMD3<Float>(0, 1, 0)
                - legAxis * simd_dot(SIMD3<Float>(0, 1, 0), legAxis)
        }
        kneePole = simd_normalize(kneePole)

        let kneePosition = origin + legAxis * alongAxis + kneePole * bendHeight
        let upperDirection = simd_normalize(kneePosition - origin)
        let lowerDirection = simd_normalize(target - kneePosition)
        let boneDown = SIMD3<Float>(0, -1, 0)

        let hipOrientation = simd_quatf(from: boneDown, to: upperDirection)
        hip.simdOrientation = hipOrientation
        let lowerInHipSpace = hipOrientation.inverse.act(lowerDirection)
        let kneeOrientation = simd_quatf(from: boneDown, to: lowerInHipSpace)
        knee.simdOrientation = kneeOrientation

        let desiredFootOrientation = simd_quatf(
            angle: Float(anklePitch),
            axis: SIMD3<Float>(1, 0, 0)
        )
        ankle.simdOrientation = (hipOrientation * kneeOrientation).inverse
            * desiredFootOrientation
    }

    private func steppingTarget(
        from start: SCNVector3,
        toward destination: SCNVector3,
        progress: CGFloat,
        lift: CGFloat
    ) -> SCNVector3 {
        let t = min(max(progress, 0), 1)
        let amount = 1 - pow(1 - t, 1.45)
        return SCNVector3(
            start.x + (destination.x - start.x) * Float(amount),
            start.y + (destination.y - start.y) * Float(amount) + Float(max(lift, 0)),
            start.z + (destination.z - start.z) * Float(amount)
        )
    }

    private func reachablePlantTarget(
        _ target: SCNVector3,
        from current: SCNVector3,
        groundHeight: Float
    ) -> SCNVector3 {
        let scale = max(abs(presentationRoot.presentation.scale.x), 0.01)
        // Forward plants intentionally need more room than neutral recovery.
        // Regular lateral/retreat targets stay inside the old range, while the
        // explicit advance target can now use the rig's available leg reach.
        let maximumPlanarCorrection = 0.65 * scale
        let dx = target.x - current.x
        let dz = target.z - current.z
        let distance = hypot(dx, dz)
        var result = target
        if distance > maximumPlanarCorrection {
            let retained = maximumPlanarCorrection / distance
            result.x = current.x + dx * retained
            result.z = current.z + dz * retained
        }
        result.y = max(result.y, groundHeight)
        return result
    }
}
