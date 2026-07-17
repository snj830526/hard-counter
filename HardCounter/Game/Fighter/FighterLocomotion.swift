import CoreGraphics
import Foundation

struct FighterLocomotionFrame {
    var frontHipRotation: CGFloat
    var backHipRotation: CGFloat
    var frontHipX: CGFloat
    var backHipX: CGFloat
    var frontHipLift: CGFloat
    var backHipLift: CGFloat
    var frontKneeRotation: CGFloat
    var backKneeRotation: CGFloat
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
    private var displayedIntensity: CGFloat = 0
    private var stepIntensity: CGFloat = 0
    private var stepDirection = CGVector(dx: 1, dy: 0)
    private var frontFootInitiates = true
    private var previousInputDirection = CGVector(dx: 1, dy: 0)

    // These filters give the body a short chain of follow-through: the hips
    // initiate, the rib cage catches up, and the guard remains readable.
    private var displayedPelvisPosition = CGPoint.zero
    private var displayedPelvisRotation: CGFloat = 0
    private var displayedUpperPosition = CGPoint.zero
    private var displayedUpperRotation: CGFloat = 0

    mutating func update(
        movement: CGVector,
        facing: CGFloat,
        opponentDirection: CGVector,
        isNeutralPose: Bool,
        deltaTime: TimeInterval
    ) -> FighterLocomotionFrame {
        clock += deltaTime
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

        // A sharp turn lands the current shuffle first. Starting a completely
        // new arc on the same frame makes the feet cross and reads as skating.
        if directionChanged, stepProgress < 0.72 {
            stepProgress = 0.72
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
            let stepDuration = 0.43 - Double(stepIntensity) * 0.12
            stepProgress = min(stepProgress + CGFloat(deltaTime / stepDuration), 1)
        }
        if targetIntensity > 0.025 {
            previousInputDirection = inputDirection
        }

        let phase = stepProgress
        let launch = pulse(phase, start: 0.03, end: 0.53)
        let follow = pulse(phase, start: 0.44, end: 0.96)
        let launchLift = pow(launch, 1.30)
        let followLift = pow(follow, 1.38)
        let landing = pulse(phase, start: 0.32, end: 0.82)
        let preload = pulse(phase, start: 0, end: 0.34)

        let frontSlide = frontFootInitiates ? launch : follow
        let backSlide = frontFootInitiates ? follow : launch
        let frontLift = frontFootInitiates ? launchLift : followLift
        let backLift = frontFootInitiates ? followLift : launchLift

        // The fighters are intentionally small in the quarter view. A linear
        // one-to-one amplitude disappears at that scale, so decisive stick
        // input gets a stronger animation curve without increasing move speed.
        let motionAmplitude = 0.62 + stepIntensity * 0.88

        let localDirectionX = stepDirection.dx * facing
        let forwardDrive = stepDirection.dx * opponentDirection.dx
            + stepDirection.dy * opponentDirection.dy
        let horizontalTravel = abs(localDirectionX) > 0.18
            ? sign(localDirectionX)
            : sign(forwardDrive)
        let travel = horizontalTravel * motionAmplitude * 11.5

        // The non-initiating foot briefly moves against the root travel. This
        // visually pins it to the canvas while the other foot leaves the floor.
        let supportPlant = max(1 - smoothstep(0.36, 0.70, phase), 0)
        let frontSupport = frontFootInitiates ? 0 : supportPlant
        let backSupport = frontFootInitiates ? supportPlant : 0
        let frontTravel = travel * (frontSlide - frontSupport * 0.42)
        let backTravel = travel * (backSlide - backSupport * 0.42)

        let stanceFlex = 0.045 + displayedIntensity * 0.055
        let compression = -(preload * 1.70 + landing * 1.05) * motionAmplitude
        let supportSign: CGFloat = frontFootInitiates ? -1 : 1
        let weightLoad = supportSign * preload * motionAmplitude * 3.45
        let weightCatch = -supportSign * landing * motionAmplitude * 2.05
        let directionalLean = localDirectionX * displayedIntensity

        let idleAmount = isNeutralPose ? max(1 - displayedIntensity * 1.8, 0) : 0
        let breath = sin(CGFloat(clock) * 2.55)
        let guardPulse = sin(CGFloat(clock) * 5.10 + 0.35)

        let targetPelvisPosition = CGPoint(
            x: weightLoad + weightCatch,
            y: compression
        )
        let targetPelvisRotation = supportSign * (preload - landing * 0.55)
            * motionAmplitude * 0.045 - directionalLean * 0.030
        let targetUpperPosition = CGPoint(
            x: (weightLoad + weightCatch) * 0.72 + directionalLean * 2.35,
            y: compression * 0.72 + breath * idleAmount * 0.72
                + guardPulse * idleAmount * 0.18
        )
        let targetUpperRotation = -supportSign * (preload - landing * 0.45)
            * motionAmplitude * 0.036 - directionalLean * 0.046
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
            frontHipRotation: (frontSlide - backSlide * 0.20) * motionAmplitude * 0.22,
            backHipRotation: -(backSlide - frontSlide * 0.20) * motionAmplitude * 0.22,
            frontHipX: frontTravel,
            backHipX: backTravel,
            frontHipLift: frontLift * motionAmplitude * 5.4,
            backHipLift: backLift * motionAmplitude * 5.4,
            frontKneeRotation: -(stanceFlex
                + frontLift * motionAmplitude * 0.36
                + backLift * motionAmplitude * 0.035),
            backKneeRotation: stanceFlex
                + backLift * motionAmplitude * 0.36
                + frontLift * motionAmplitude * 0.035,
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
        displayedIntensity = 0
        stepIntensity = 0
        stepDirection = CGVector(dx: 1, dy: 0)
        frontFootInitiates = true
        previousInputDirection = CGVector(dx: 1, dy: 0)
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
        stepIntensity = max(intensity, 0.30)
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

    private func sign(_ value: CGFloat) -> CGFloat {
        value >= 0 ? 1 : -1
    }
}
