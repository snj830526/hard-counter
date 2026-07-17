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
    private var gaitPhase: CGFloat = 0
    private var displayedIntensity: CGFloat = 0
    private var lastMoveDirection = CGVector(dx: 1, dy: 0)

    mutating func update(
        movement: CGVector,
        facing: CGFloat,
        opponentDirection: CGVector,
        isNeutralPose: Bool,
        deltaTime: TimeInterval
    ) -> FighterLocomotionFrame {
        clock += deltaTime
        let targetIntensity = min(hypot(movement.dx, movement.dy), 1)
        let visualResponse: CGFloat = targetIntensity > displayedIntensity ? 10.5 : 12.5
        let blend = 1 - CGFloat(exp(-Double(visualResponse) * deltaTime))
        displayedIntensity += (targetIntensity - displayedIntensity) * blend

        if targetIntensity > 0.025 {
            lastMoveDirection = CGVector(
                dx: movement.dx / targetIntensity,
                dy: movement.dy / targetIntensity
            )
        }
        if displayedIntensity > 0.015 {
            gaitPhase += CGFloat(deltaTime) * (5.2 + displayedIntensity * 3.2)
        }

        let localDirectionX = lastMoveDirection.dx * facing
        let step = sin(gaitPhase)
        let firstSlide = CGFloat(pow(Double(max(step, 0)), 1.55))
        let followSlide = CGFloat(pow(Double(max(-step, 0)), 1.55))
        let forwardDrive = lastMoveDirection.dx * opponentDirection.dx
            + lastMoveDirection.dy * opponentDirection.dy
        let lateralDrive = lastMoveDirection.dx * -opponentDirection.dy
            + lastMoveDirection.dy * opponentDirection.dx
        let frontFootInitiates = abs(forwardDrive) >= abs(lateralDrive)
            ? forwardDrive >= 0
            : lateralDrive * facing >= 0
        let frontSlide = frontFootInitiates ? firstSlide : followSlide
        let backSlide = frontFootInitiates ? followSlide : firstSlide
        let stride = displayedIntensity * 0.20
        let horizontalTravel = abs(localDirectionX) > 0.18
            ? (localDirectionX >= 0 ? CGFloat(1) : CGFloat(-1))
            : (forwardDrive >= 0 ? CGFloat(1) : CGFloat(-1))
        let rootTravel = horizontalTravel * displayedIntensity * 5.5
        let stanceFlex = 0.025 + displayedIntensity * 0.035
        let shufflePulse = min(firstSlide + followSlide, 1)
        let pelvisCompression = -shufflePulse * displayedIntensity * 0.85
        let idleAmount = isNeutralPose ? 1 - displayedIntensity : 0
        let breath = sin(CGFloat(clock) * 2.7)
        let guardPulse = sin(CGFloat(clock) * 5.4)
        let supportBias = frontSlide - backSlide
        let weightTransfer = -supportBias * displayedIntensity * 1.55
        let directionalLean = localDirectionX * displayedIntensity

        return FighterLocomotionFrame(
            frontHipRotation: (frontSlide - backSlide * 0.28) * stride,
            backHipRotation: -(backSlide - frontSlide * 0.28) * stride,
            frontHipX: rootTravel * (frontSlide - backSlide * 0.22),
            backHipX: rootTravel * (backSlide - frontSlide * 0.22),
            frontHipLift: frontSlide * displayedIntensity * 4.0,
            backHipLift: backSlide * displayedIntensity * 4.0,
            frontKneeRotation: -(stanceFlex
                + frontSlide * displayedIntensity * 0.30
                + backSlide * displayedIntensity * 0.035),
            backKneeRotation: stanceFlex
                + backSlide * displayedIntensity * 0.30
                + frontSlide * displayedIntensity * 0.035,
            pelvisCompression: pelvisCompression,
            pelvisPosition: CGPoint(x: weightTransfer, y: pelvisCompression),
            pelvisRotation: supportBias * displayedIntensity * 0.016
                - directionalLean * 0.022,
            upperBodyPosition: CGPoint(
                x: weightTransfer * 0.58 + directionalLean * 1.5,
                y: pelvisCompression * 0.62
                    + breath * idleAmount * 0.85 + guardPulse * idleAmount * 0.25
            ),
            upperBodyRotation: -supportBias * displayedIntensity * 0.014
                - directionalLean * 0.034
                + breath * idleAmount * 0.008,
            frontAnkleLift: frontSlide * displayedIntensity * 0.025,
            backAnkleLift: backSlide * displayedIntensity * 0.025
        )
    }

    mutating func reset() {
        clock = 0
        gaitPhase = 0
        displayedIntensity = 0
        lastMoveDirection = CGVector(dx: 1, dy: 0)
    }
}
