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
}

struct FighterLocomotionController {
    private var clock: TimeInterval = 0
    private var stepProgress: CGFloat = 1
    private var stepPlaybackRate: CGFloat = 1
    private var displayedIntensity: CGFloat = 0
    private var stepIntensity: CGFloat = 0
    private var stepDirection = CGVector(dx: 1, dy: 0)
    private var frontFootInitiates = true
    private var previousInputDirection = CGVector(dx: 1, dy: 0)
    private var frontFootPlantOffset = CGPoint.zero
    private var backFootPlantOffset = CGPoint.zero

    // These filters give the body a short chain of follow-through: the hips
    // initiate, the rib cage catches up, and the guard remains readable.
    private var displayedPelvisPosition = CGPoint.zero
    private var displayedPelvisRotation: CGFloat = 0
    private var displayedUpperPosition = CGPoint.zero
    private var displayedUpperRotation: CGFloat = 0

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
        let targetIntensity = min(hypot(movement.dx, movement.dy), 1)
        let visualResponse: CGFloat = targetIntensity > displayedIntensity ? 14.5 : 17.0
        displayedIntensity = damp(
            displayedIntensity,
            toward: targetIntensity,
            response: visualResponse,
            deltaTime: deltaTime
        )

        var inputDirection = previousInputDirection
        if targetIntensity > 0.025 {
            inputDirection = CGVector(
                dx: movement.dx / targetIntensity,
                dy: movement.dy / targetIntensity
            )
        }

        let directionDot = inputDirection.dx * stepDirection.dx
            + inputDirection.dy * stepDirection.dy
        let directionChanged = targetIntensity > 0.05 && directionDot < 0.35

        if targetIntensity > 0.05, stepProgress < 1 {
            // The root can turn continuously under an analog stick. Let the
            // current step arc follow that turn instead of holding a rigid
            // direction until the next footfall.
            let turnResponse: CGFloat = directionDot < 0 ? 10.5 : 7.5
            let blend = 1 - CGFloat(exp(-Double(turnResponse) * deltaTime))
            let blendedDirection = CGVector(
                dx: stepDirection.dx + (inputDirection.dx - stepDirection.dx) * blend,
                dy: stepDirection.dy + (inputDirection.dy - stepDirection.dy) * blend
            )
            let blendedLength = max(hypot(blendedDirection.dx, blendedDirection.dy), 0.001)
            stepDirection = CGVector(
                dx: blendedDirection.dx / blendedLength,
                dy: blendedDirection.dy / blendedLength
            )
        }

        // Finish a sharp turn quickly without jumping the animation clock.
        // Skipping directly to the landing phase produced a one-frame foot pop.
        if directionChanged, stepProgress < 1 {
            stepPlaybackRate = 2.15
        }

        if targetIntensity > 0.045, stepProgress >= 1 {
            beginStep(
                direction: inputDirection,
                intensity: targetIntensity,
                facing: facing,
                opponentDirection: opponentDirection
            )
        }

        if stepProgress < 1 {
            let stepDuration = 0.46 - Double(stepIntensity) * 0.08
            stepProgress = min(
                stepProgress + CGFloat(deltaTime / stepDuration) * stepPlaybackRate,
                1
            )
            if stepProgress >= 1 {
                stepPlaybackRate = 1
            }
        }
        if targetIntensity > 0.025 {
            previousInputDirection = inputDirection
        }

        let phase = stepProgress
        // A boxing shuffle is not two walking arcs. Weight loads onto the
        // support leg first, the initiating foot travels and lands, then the
        // support foot catches up while the body settles over the new stance.
        let launchLift = pow(pulse(phase, start: 0.11, end: 0.43), 1.28)
        let followLift = pow(pulse(phase, start: 0.51, end: 0.86), 1.34)
        let landing = pulse(phase, start: 0.30, end: 0.88)
        let preload = pulse(phase, start: 0, end: 0.30)

        let frontLift = frontFootInitiates ? launchLift : followLift
        let backLift = frontFootInitiates ? followLift : launchLift

        // The fighters are intentionally small in the quarter view. A linear
        // one-to-one amplitude disappears at that scale, so decisive stick
        // input gets a stronger animation curve without increasing move speed.
        let motionAmplitude = 0.62 + stepIntensity * 0.88

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
            response: frontCatch * 28,
            deltaTime: deltaTime
        )
        backFootPlantOffset = damp(
            backFootPlantOffset,
            toward: .zero,
            response: backCatch * 28,
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
        let guardedCrouch = displayedIntensity * 0.72
        let compression = -(
            guardedCrouch + preload * 1.45 + landing * 0.90
        ) * motionAmplitude
        let supportSign: CGFloat = frontFootInitiates ? -1 : 1
        let weightLoad = supportSign * preload * motionAmplitude * 3.45
        let weightCatch = -supportSign * landing * motionAmplitude * 2.05
        let directionalLean = localDirectionX * displayedIntensity
        let guardedForwardLoad = forwardDrive * displayedIntensity
        let guardedLateralLoad = lateralDrive * facing * displayedIntensity

        let idleAmount = isNeutralPose ? max(1 - displayedIntensity * 1.8, 0) : 0
        let breath = sin(CGFloat(clock) * 2.55)
        let guardPulse = sin(CGFloat(clock) * 5.10 + 0.35)

        let targetPelvisPosition = CGPoint(
            x: weightLoad + weightCatch + guardedLateralLoad * 1.25,
            y: compression + directionalDepth * 0.55
        )
        let targetPelvisRotation = supportSign * (preload - landing * 0.55)
            * motionAmplitude * 0.045 - directionalLean * 0.030
        let targetUpperPosition = CGPoint(
            x: (weightLoad + weightCatch) * 0.72 + directionalLean * 1.75
                + guardedLateralLoad * 1.15,
            y: compression * 0.72 + breath * idleAmount * 0.72
                + guardPulse * idleAmount * 0.18 + directionalDepth * 0.95
        )
        let targetUpperRotation = -supportSign * (preload - landing * 0.45)
            * motionAmplitude * 0.036 - directionalLean * 0.032
            - guardedLateralLoad * 0.022 + guardedForwardLoad * 0.012
            + breath * idleAmount * 0.007

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
                    + localDirectionX * frontLift * motionAmplitude * 3.2,
                y: frontFootPlantOffset.y + frontLift * motionAmplitude
                    * (5.4 + stepDirection.dy * 1.6)
            ),
            backFootOffset: CGPoint(
                x: backFootPlantOffset.x
                    + localDirectionX * backLift * motionAmplitude * 3.2,
                y: backFootPlantOffset.y + backLift * motionAmplitude
                    * (5.4 + stepDirection.dy * 1.6)
            ),
            pelvisCompression: compression,
            pelvisPosition: displayedPelvisPosition,
            pelvisRotation: displayedPelvisRotation,
            upperBodyPosition: displayedUpperPosition,
            upperBodyRotation: displayedUpperRotation,
            frontAnkleLift: frontLift * motionAmplitude * 0.075,
            backAnkleLift: backLift * motionAmplitude * 0.075
        )
    }

    mutating func reset() {
        clock = 0
        stepProgress = 1
        stepPlaybackRate = 1
        displayedIntensity = 0
        stepIntensity = 0
        stepDirection = CGVector(dx: 1, dy: 0)
        frontFootInitiates = true
        previousInputDirection = CGVector(dx: 1, dy: 0)
        frontFootPlantOffset = .zero
        backFootPlantOffset = .zero
        displayedPelvisPosition = .zero
        displayedPelvisRotation = 0
        displayedUpperPosition = .zero
        displayedUpperRotation = 0
    }

    private mutating func beginStep(
        direction: CGVector,
        intensity: CGFloat,
        facing: CGFloat,
        opponentDirection: CGVector
    ) {
        stepProgress = 0
        stepPlaybackRate = 1
        stepIntensity = max(intensity, 0.42)
        stepDirection = direction

        let forwardDrive = direction.dx * opponentDirection.dx
            + direction.dy * opponentDirection.dy
        let lateralDrive = direction.dx * -opponentDirection.dy
            + direction.dy * opponentDirection.dx
        frontFootInitiates = abs(forwardDrive) >= abs(lateralDrive)
            ? forwardDrive >= 0
            : lateralDrive * facing >= 0
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
