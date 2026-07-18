import CoreGraphics
import Foundation

enum FighterSupportFoot {
    case lead
    case rear
    case both
}

struct FighterBodyMotionFrame {
    let intendedMovement: CGVector
    let resolvedMovement: CGVector
    let stepDirection: CGVector
    let stepIntensity: CGFloat
    let localForward: CGFloat
    let localLateral: CGFloat
    let supportFoot: FighterSupportFoot
    let weightOnLeadFoot: CGFloat
    let centerOfMassOffset: CGPoint
    let compression: CGFloat
    let stepProgress: CGFloat
    let plantedness: CGFloat

    static let neutral = FighterBodyMotionFrame(
        intendedMovement: .zero,
        resolvedMovement: .zero,
        stepDirection: .zero,
        stepIntensity: 0,
        localForward: 0,
        localLateral: 0,
        supportFoot: .both,
        weightOnLeadFoot: 0.5,
        centerOfMassOffset: .zero,
        compression: 0,
        stepProgress: 1,
        plantedness: 1
    )
}

/// Owns the difference between what the player asks for and what the boxer's
/// current stance can physically perform. Position no longer follows the stick
/// directly: a planted support leg must load, push and recover before a sharp
/// reversal can become actual travel.
struct FighterFullBodyMotionController {
    private var stepProgress: CGFloat = 1
    private var committedDirection = CGVector.zero
    private var committedIntensity: CGFloat = 0
    private var supportFoot: FighterSupportFoot = .both

    mutating func update(
        movementIntent: CGVector,
        towardOpponent: CGVector,
        phase: FighterPhase,
        deltaTime: TimeInterval
    ) -> FighterBodyMotionFrame {
        let intentAmount = min(hypot(movementIntent.dx, movementIntent.dy), 1)
        let intentDirection = normalized(movementIntent)

        let mobility = mobilityScale(for: phase)
        guard mobility > 0 else {
            // Defensive actions and impacts establish a new support base.
            // Resuming a half-finished shuffle after a sway made the first
            // post-action frame look like the legs belonged to another clip.
            if phase == .swaying || phase == .hit || phase == .knockedOut {
                resetStep()
            }
            return restingFrame(intent: movementIntent)
        }

        if stepProgress >= 1 {
            guard intentAmount > 0.025 else {
                resetStep()
                return restingFrame(intent: movementIntent)
            }
            beginStep(
                direction: intentDirection,
                intensity: intentAmount,
                towardOpponent: towardOpponent
            )
        }

        let directionDot = intentAmount > 0.025
            ? dot(committedDirection, intentDirection) : 1
        let isSharpTurn = intentAmount > 0.025 && directionDot < 0.20
        if !isSharpTurn, intentAmount > 0.025 {
            // Gentle steering is possible while a foot is travelling. A sharp
            // reversal remains queued until both feet have recovered stance.
            let steering = 1 - CGFloat(exp(-4.2 * deltaTime))
            committedDirection = normalized(CGVector(
                dx: committedDirection.dx + (intentDirection.dx - committedDirection.dx) * steering,
                dy: committedDirection.dy + (intentDirection.dy - committedDirection.dy) * steering
            ))
        }

        let stepDuration = 0.36 - Double(committedIntensity) * 0.06
        stepProgress = min(
            stepProgress + CGFloat(deltaTime / max(stepDuration, 0.20)),
            1
        )
        let drive = movementEnvelope(at: stepProgress)
        let turnBrake: CGFloat = isSharpTurn
            ? 1 - 0.62 * smooth((stepProgress - 0.30) / 0.70) : 1
        let release: CGFloat = intentAmount > 0.025
            ? 1 : 1 - 0.74 * smooth((stepProgress - 0.38) / 0.62)
        let speed = committedIntensity * drive * turnBrake * release * mobility
        let resolved = CGVector(
            dx: committedDirection.dx * speed,
            dy: committedDirection.dy * speed
        )

        let local = localComponents(
            direction: committedDirection,
            towardOpponent: towardOpponent
        )
        let supportSign: CGFloat = supportFoot == .lead ? -1 : 1
        let loading = pulse(stepProgress, start: 0, end: 0.32)
        let landing = pulse(stepProgress, start: 0.58, end: 1)
        let weightTransfer = (loading - landing * 0.72) * supportSign
        let weightOnLead = min(max(0.5 + weightTransfer * 0.32, 0.14), 0.86)
        let center = CGPoint(
            x: local.lateral * drive * 0.12 + weightTransfer * 0.07,
            y: local.forward * drive * 0.09
        )
        let plantedness = min(max(
            1 - pulse(stepProgress, start: 0.14, end: 0.78) * 0.58,
            0
        ), 1)

        return FighterBodyMotionFrame(
            intendedMovement: movementIntent,
            resolvedMovement: resolved,
            stepDirection: committedDirection,
            stepIntensity: committedIntensity,
            localForward: local.forward,
            localLateral: local.lateral,
            supportFoot: supportFoot,
            weightOnLeadFoot: weightOnLead,
            centerOfMassOffset: center,
            compression: -(loading * 0.72 + landing * 0.46) * committedIntensity,
            stepProgress: stepProgress,
            plantedness: plantedness
        )
    }

    mutating func reset() {
        resetStep()
    }

    private mutating func beginStep(
        direction: CGVector,
        intensity: CGFloat,
        towardOpponent: CGVector
    ) {
        stepProgress = 0
        committedDirection = normalized(direction)
        committedIntensity = max(intensity, 0.28)
        let local = localComponents(
            direction: committedDirection,
            towardOpponent: towardOpponent
        )
        let leadFootMoves = abs(local.forward) >= abs(local.lateral)
            ? local.forward >= 0
            : local.lateral >= 0
        supportFoot = leadFootMoves ? .rear : .lead
    }

    private mutating func resetStep() {
        stepProgress = 1
        committedDirection = .zero
        committedIntensity = 0
        supportFoot = .both
    }

    private func restingFrame(intent: CGVector) -> FighterBodyMotionFrame {
        FighterBodyMotionFrame(
            intendedMovement: intent,
            resolvedMovement: .zero,
            stepDirection: committedDirection,
            stepIntensity: committedIntensity,
            localForward: 0,
            localLateral: 0,
            supportFoot: supportFoot,
            weightOnLeadFoot: supportFoot == .lead ? 0.64 : (supportFoot == .rear ? 0.36 : 0.5),
            centerOfMassOffset: .zero,
            compression: 0,
            stepProgress: stepProgress,
            plantedness: 1
        )
    }

    private func mobilityScale(for phase: FighterPhase) -> CGFloat {
        switch phase {
        case .idle, .punchStartup, .punchActive, .punchRecovery: return 1
        case .swaying, .hit, .knockedOut: return 0
        }
    }

    private func movementEnvelope(at progress: CGFloat) -> CGFloat {
        if progress < 0.16 {
            return 0.22 + smooth(progress / 0.16) * 0.50
        }
        if progress < 0.54 {
            return 0.72 + smooth((progress - 0.16) / 0.38) * 0.28
        }
        if progress < 0.82 {
            return 1 - smooth((progress - 0.54) / 0.28) * 0.20
        }
        return 0.80 - smooth((progress - 0.82) / 0.18) * 0.28
    }

    private func localComponents(
        direction: CGVector,
        towardOpponent: CGVector
    ) -> (forward: CGFloat, lateral: CGFloat) {
        let forward = normalized(towardOpponent)
        let left = CGVector(dx: -forward.dy, dy: forward.dx)
        return (dot(direction, forward), dot(direction, left))
    }

    private func normalized(_ vector: CGVector) -> CGVector {
        let length = hypot(vector.dx, vector.dy)
        guard length > 0.001 else { return .zero }
        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
    }

    private func dot(_ lhs: CGVector, _ rhs: CGVector) -> CGFloat {
        lhs.dx * rhs.dx + lhs.dy * rhs.dy
    }

    private func smooth(_ value: CGFloat) -> CGFloat {
        let t = min(max(value, 0), 1)
        return t * t * (3 - 2 * t)
    }

    private func pulse(_ value: CGFloat, start: CGFloat, end: CGFloat) -> CGFloat {
        guard value > start, value < end else { return 0 }
        return sin((value - start) / (end - start) * .pi)
    }
}
