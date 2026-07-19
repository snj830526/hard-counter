import CoreGraphics
import Foundation

struct FighterLocomotionFrame {
    var frontFootOffset: CGPoint
    var backFootOffset: CGPoint
    var pelvisCompression: CGFloat
    var pelvisPosition: CGPoint
    var pelvisRotation: CGFloat
    var upperBodyPosition: CGPoint
    var upperBodyRotation: CGFloat
    var frontAnkleLift: CGFloat
    var backAnkleLift: CGFloat
    var movementIntensity: CGFloat
    var forwardDrive: CGFloat
    var lateralDrive: CGFloat
    var landingAmount: CGFloat
    var stepProgress: CGFloat
    var frontFootInitiates: Bool
}

private struct FighterFootworkPresentation {
    let launchRange: ClosedRange<CGFloat>
    let followRange: ClosedRange<CGFloat>
    let amplitudeBase: CGFloat
    let amplitudeGain: CGFloat
    let strideScale: CGFloat
    let liftScale: CGFloat
    let crouchScale: CGFloat
    let loadScale: CGFloat
    let catchScale: CGFloat
    let upperBodyLag: CGFloat

    static func profile(for style: Fighter3DMotionStyle) -> Self {
        let mechanical = Fighter3DMechanicalMotionProfile.profile(for: style)
        switch style {
        case .allRounder:
            return Self(
                launchRange: 0.055...0.30,
                followRange: 0.54...0.80,
                amplitudeBase: 0.70,
                amplitudeGain: 1.02,
                strideScale: 1.45 * mechanical.strideScale,
                liftScale: 1.18 * mechanical.liftScale,
                crouchScale: 1.00,
                loadScale: 1.00,
                catchScale: 1.00,
                upperBodyLag: 1.00
            )
        case .pressure:
            return Self(
                launchRange: 0.07...0.33,
                followRange: 0.56...0.84,
                amplitudeBase: 0.76,
                amplitudeGain: 1.08,
                strideScale: 1.38 * mechanical.strideScale,
                liftScale: 0.95 * mechanical.liftScale,
                crouchScale: 1.22,
                loadScale: 1.24,
                catchScale: 1.18,
                upperBodyLag: 0.82
            )
        case .outBoxer:
            return Self(
                launchRange: 0.045...0.27,
                followRange: 0.48...0.72,
                amplitudeBase: 0.64,
                amplitudeGain: 1.10,
                strideScale: 1.62 * mechanical.strideScale,
                liftScale: 1.44 * mechanical.liftScale,
                crouchScale: 0.72,
                loadScale: 0.82,
                catchScale: 0.76,
                upperBodyLag: 1.26
            )
        case .rival:
            return Self(
                launchRange: 0.06...0.30,
                followRange: 0.54...0.81,
                amplitudeBase: 0.72,
                amplitudeGain: 1.04,
                strideScale: 1.46 * mechanical.strideScale,
                liftScale: 1.08 * mechanical.liftScale,
                crouchScale: 1.08,
                loadScale: 1.10,
                catchScale: 1.12,
                upperBodyLag: 0.92
            )
        }
    }
}

struct FighterLocomotionController {
    private let footwork: FighterFootworkPresentation
    private var clock: TimeInterval = 0
    private var displayedIntensity: CGFloat = 0
    private var frontFootPlantOffset = CGPoint.zero
    private var backFootPlantOffset = CGPoint.zero

    // These filters give the body a short chain of follow-through: the hips
    // initiate, the rib cage catches up, and the guard remains readable.
    private var displayedPelvisPosition = CGPoint.zero
    private var displayedPelvisRotation: CGFloat = 0
    private var displayedUpperPosition = CGPoint.zero
    private var displayedUpperRotation: CGFloat = 0

    init(style: Fighter3DMotionStyle) {
        footwork = .profile(for: style)
    }

    mutating func update(
        input: FighterLocomotionInput,
        isNeutralPose: Bool,
        deltaTime: TimeInterval
    ) -> FighterLocomotionFrame {
        clock += deltaTime
        let movement = input.screenMovement
        let rootDisplacement = input.localRootDisplacement
        let facing = input.facing
        let opponentDirection = input.opponentDirection
        let bodyMotion = input.bodyMotion
        let stepProgress = bodyMotion.stepProgress
        let stepIntensity = bodyMotion.stepIntensity
        let stepDirection = normalized(
            bodyMotion.stepDirection,
            fallback: normalized(movement, fallback: CGVector(dx: facing, dy: 0))
        )
        let frontFootInitiates: Bool
        switch bodyMotion.initiatingFoot {
        case .lead: frontFootInitiates = true
        case .rear: frontFootInitiates = false
        case .both: frontFootInitiates = bodyMotion.weightOnLeadFoot <= 0.5
        }
        let commandedIntensity = min(hypot(movement.dx, movement.dy), 1)
        let measuredSpeed = hypot(rootDisplacement.dx, rootDisplacement.dy)
            / max(CGFloat(deltaTime), 0.001)
        let measuredIntensity = min(measuredSpeed / 96, 1)
        // Drive the feet primarily from actual root travel. A small command
        // floor lets the support leg preload immediately, while blocked or
        // heavily slowed movement no longer produces a full-speed shuffle.
        let targetIntensity = min(
            commandedIntensity,
            max(measuredIntensity, commandedIntensity * 0.28)
        )
        let visualResponse: CGFloat = targetIntensity > displayedIntensity ? 8.2 : 6.8
        displayedIntensity = damp(
            displayedIntensity,
            toward: targetIntensity,
            response: visualResponse,
            deltaTime: deltaTime
        )

        let phase = stepProgress
        // A boxing shuffle is not two walking arcs. Weight loads onto the
        // support leg first, the initiating foot travels and lands, then the
        // support foot catches up while the body settles over the new stance.
        let launchLift = pow(pulse(
            phase,
            start: footwork.launchRange.lowerBound,
            end: footwork.launchRange.upperBound
        ), 1.36)
        let followLift = pow(pulse(
            phase,
            start: footwork.followRange.lowerBound,
            end: footwork.followRange.upperBound
        ), 1.42)
        let firstPlant = pulse(phase, start: 0.28, end: 0.50)
        let trailingPlant = pulse(phase, start: 0.64, end: 0.92)
        let landing = max(firstPlant * 0.76, trailingPlant)
        let preload = pulse(phase, start: 0, end: 0.26)

        let frontLift = frontFootInitiates ? launchLift : followLift
        let backLift = frontFootInitiates ? followLift : launchLift

        // Even with the closer quarter-view framing, a linear one-to-one foot
        // offset reads as a slide. Decisive stick input gets a stronger step
        // silhouette without increasing the actual movement speed.
        let motionAmplitude = footwork.amplitudeBase
            + stepIntensity * footwork.amplitudeGain

        let localDirectionX = stepDirection.dx * facing
        let forwardDrive = stepDirection.dx * opponentDirection.dx
            + stepDirection.dy * opponentDirection.dy
        let lateralDrive = stepDirection.dx * -opponentDirection.dy
            + stepDirection.dy * opponentDirection.dx
        let directionalDepth = stepDirection.dy * displayedIntensity

        // Counter the fighter root's actual projected travel. Feet remain in
        // world space until their swing phase catches them back under the hips.
        frontFootPlantOffset.x -= rootDisplacement.dx
        frontFootPlantOffset.y -= rootDisplacement.dy
        backFootPlantOffset.x -= rootDisplacement.dx
        backFootPlantOffset.y -= rootDisplacement.dy
        frontFootPlantOffset = clampedFootOffset(frontFootPlantOffset)
        backFootPlantOffset = clampedFootOffset(backFootPlantOffset)

        let frontCatch = frontFootInitiates ? launchLift : followLift
        let backCatch = frontFootInitiates ? followLift : launchLift
        frontFootPlantOffset = damp(
            frontFootPlantOffset,
            toward: .zero,
            response: frontCatch * 42,
            deltaTime: deltaTime
        )
        backFootPlantOffset = damp(
            backFootPlantOffset,
            toward: .zero,
            response: backCatch * 42,
            deltaTime: deltaTime
        )

        if stepProgress >= 1, targetIntensity < 0.05 {
            frontFootPlantOffset = damp(
                frontFootPlantOffset,
                toward: .zero,
                response: 14,
                deltaTime: deltaTime
            )
            backFootPlantOffset = damp(
                backFootPlantOffset,
                toward: .zero,
                response: 14,
                deltaTime: deltaTime
            )
        }

        // Stay in a guarded crouch while travelling, then load a little more
        // before push-off and on landing. This is the low, weighty shuffle that
        // keeps the torso from looking bolted onto sliding legs.
        let guardedCrouch = displayedIntensity * 0.70 * footwork.crouchScale
        let compression = -(
            guardedCrouch
                + preload * 1.18 * footwork.loadScale
                + landing * 0.82 * footwork.catchScale
        ) * motionAmplitude
        let supportSign: CGFloat = frontFootInitiates ? -1 : 1
        let weightLoad = supportSign * preload * motionAmplitude
            * 3.25 * footwork.loadScale
        let weightCatch = -supportSign * landing * motionAmplitude
            * 2.05 * footwork.catchScale
        let directionalLean = localDirectionX * displayedIntensity
        let guardedForwardLoad = forwardDrive * displayedIntensity
        let guardedLateralLoad = lateralDrive * facing * displayedIntensity

        let idleAmount = isNeutralPose ? max(1 - displayedIntensity * 1.8, 0) : 0
        let breath = sin(CGFloat(clock) * 2.55)
        let guardPulse = sin(CGFloat(clock) * 5.10 + 0.35)

        let targetPelvisPosition = CGPoint(
            x: weightLoad + weightCatch + directionalLean * 3.20
                + guardedLateralLoad * 2.20,
            y: compression + directionalDepth * 1.35
        )
        let targetPelvisRotation = supportSign * (preload - landing * 0.55)
            * motionAmplitude * 0.056 - directionalLean * 0.038
        let targetUpperPosition = CGPoint(
            x: (weightLoad + weightCatch) * 0.68
                + directionalLean * 1.20 * footwork.upperBodyLag
                + guardedLateralLoad * 1.10 * footwork.upperBodyLag,
            y: compression * 0.68 + breath * idleAmount * 0.48
                + guardPulse * idleAmount * 0.10 + directionalDepth * 0.75
        )
        let targetUpperRotation = -supportSign * (preload - landing * 0.45)
            * motionAmplitude * 0.046 - directionalLean * 0.041
            - guardedLateralLoad * 0.030 + guardedForwardLoad * 0.018
            + breath * idleAmount * 0.004

        displayedPelvisPosition = damp(
            displayedPelvisPosition,
            toward: targetPelvisPosition,
            response: 16.0,
            deltaTime: deltaTime
        )
        displayedPelvisRotation = damp(
            displayedPelvisRotation,
            toward: targetPelvisRotation,
            response: 15.0,
            deltaTime: deltaTime
        )
        displayedUpperPosition = damp(
            displayedUpperPosition,
            toward: targetUpperPosition,
            response: 9.0,
            deltaTime: deltaTime
        )
        displayedUpperRotation = damp(
            displayedUpperRotation,
            toward: targetUpperRotation,
            response: 8.2,
            deltaTime: deltaTime
        )

        return FighterLocomotionFrame(
            frontFootOffset: CGPoint(
                x: frontFootPlantOffset.x
                    + localDirectionX * frontLift * motionAmplitude
                        * 5.40 * footwork.strideScale,
                y: frontFootPlantOffset.y + frontLift * motionAmplitude
                    * (7.4 + stepDirection.dy * 2.0) * footwork.liftScale
            ),
            backFootOffset: CGPoint(
                x: backFootPlantOffset.x
                    + localDirectionX * backLift * motionAmplitude
                        * 5.40 * footwork.strideScale,
                y: backFootPlantOffset.y + backLift * motionAmplitude
                    * (7.4 + stepDirection.dy * 2.0) * footwork.liftScale
            ),
            pelvisCompression: compression,
            pelvisPosition: displayedPelvisPosition,
            pelvisRotation: displayedPelvisRotation,
            upperBodyPosition: displayedUpperPosition,
            upperBodyRotation: displayedUpperRotation,
            frontAnkleLift: frontLift * motionAmplitude * 0.145 * footwork.liftScale,
            backAnkleLift: backLift * motionAmplitude * 0.145 * footwork.liftScale,
            movementIntensity: displayedIntensity,
            forwardDrive: forwardDrive,
            lateralDrive: lateralDrive,
            landingAmount: landing * motionAmplitude,
            stepProgress: stepProgress,
            frontFootInitiates: frontFootInitiates
        )
    }

    mutating func reset() {
        clock = 0
        displayedIntensity = 0
        frontFootPlantOffset = .zero
        backFootPlantOffset = .zero
        displayedPelvisPosition = .zero
        displayedPelvisRotation = 0
        displayedUpperPosition = .zero
        displayedUpperRotation = 0
    }

    private func damp(
        _ value: CGFloat,
        toward target: CGFloat,
        response: CGFloat,
        deltaTime: TimeInterval
    ) -> CGFloat {
        let blend = 1 - CGFloat(exp(-Double(response) * deltaTime))
        return value + (target - value) * blend
    }

    private func damp(
        _ value: CGPoint,
        toward target: CGPoint,
        response: CGFloat,
        deltaTime: TimeInterval
    ) -> CGPoint {
        CGPoint(
            x: damp(value.x, toward: target.x, response: response, deltaTime: deltaTime),
            y: damp(value.y, toward: target.y, response: response, deltaTime: deltaTime)
        )
    }

    private func smoothstep(_ edge0: CGFloat, _ edge1: CGFloat, _ value: CGFloat) -> CGFloat {
        guard edge1 > edge0 else { return value >= edge1 ? 1 : 0 }
        let amount = min(max((value - edge0) / (edge1 - edge0), 0), 1)
        return amount * amount * (3 - 2 * amount)
    }

    private func pulse(_ value: CGFloat, start: CGFloat, end: CGFloat) -> CGFloat {
        guard value > start, value < end else { return 0 }
        let amount = (value - start) / (end - start)
        return sin(amount * .pi)
    }

    private func clampedFootOffset(_ offset: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(offset.x, -19), 19),
            y: min(max(offset.y, -11), 11)
        )
    }

    private func normalized(_ vector: CGVector, fallback: CGVector) -> CGVector {
        let length = hypot(vector.dx, vector.dy)
        guard length > 0.001 else { return fallback }
        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
    }
}

struct FighterLegSolution {
    let hipCorrection: CGFloat
    let kneeCorrection: CGFloat
}

enum FighterLegIK {
    static func solve(
        upperAngle: CGFloat,
        kneeAngle: CGFloat,
        bendDirection: CGFloat,
        footOffset: CGPoint,
        upperLength: CGFloat,
        lowerLength: CGFloat
    ) -> FighterLegSolution {
        let baseFoot = endpoint(
            upperAngle: upperAngle,
            kneeAngle: kneeAngle,
            upperLength: upperLength,
            lowerLength: lowerLength
        )
        var target = CGPoint(
            x: baseFoot.x + footOffset.x,
            y: baseFoot.y + footOffset.y
        )

        let minimumReach = abs(upperLength - lowerLength) + 0.01
        let maximumReach = upperLength + lowerLength - 0.05
        let targetDistance = max(hypot(target.x, target.y), 0.001)
        let clampedDistance = min(max(targetDistance, minimumReach), maximumReach)
        if abs(clampedDistance - targetDistance) > 0.001 {
            let scale = clampedDistance / targetDistance
            target.x *= scale
            target.y *= scale
        }

        let cosine = min(max(
            (clampedDistance * clampedDistance - upperLength * upperLength
                - lowerLength * lowerLength) / (2 * upperLength * lowerLength),
            -1
        ), 1)
        // A two-bone chain has two valid solutions for the same foot target.
        // Choose the anatomical forward bend explicitly instead of deriving it
        // from a pose angle that may describe the rear leg on the other side.
        let bendMagnitude = min(acos(cosine), 0.72)
        let bendSign: CGFloat = bendDirection < 0 ? -1 : 1
        let solvedKnee = bendMagnitude * bendSign
        let targetDirection = atan2(target.x, -target.y)
        let solvedUpper = targetDirection - atan2(
            lowerLength * sin(solvedKnee),
            upperLength + lowerLength * cos(solvedKnee)
        )

        return FighterLegSolution(
            hipCorrection: solvedUpper - upperAngle,
            kneeCorrection: solvedKnee - kneeAngle
        )
    }

    private static func endpoint(
        upperAngle: CGFloat,
        kneeAngle: CGFloat,
        upperLength: CGFloat,
        lowerLength: CGFloat
    ) -> CGPoint {
        CGPoint(
            x: upperLength * sin(upperAngle)
                + lowerLength * sin(upperAngle + kneeAngle),
            y: -upperLength * cos(upperAngle)
                - lowerLength * cos(upperAngle + kneeAngle)
        )
    }
}
