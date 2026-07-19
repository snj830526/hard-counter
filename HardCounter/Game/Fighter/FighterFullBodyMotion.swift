import CoreGraphics
import Foundation

enum FighterSupportFoot: Equatable {
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
    /// The foot that opens this boxing step. The support foot changes after
    /// this foot lands, but the step order must remain stable for the whole
    /// push-travel-catch cycle.
    let initiatingFoot: FighterSupportFoot
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
        initiatingFoot: .both,
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
    private let cadence: CGFloat
    private var stepProgress: CGFloat = 1
    private var committedDirection = CGVector.zero
    private var committedIntensity: CGFloat = 0
    private var supportFoot: FighterSupportFoot = .both
    private var initiatingFoot: FighterSupportFoot = .both

    init(cadence: CGFloat = 1) {
        let authoredCadence = min(max(cadence, 0.72), 1.32)
        // Keep style identity without turning the out-boxer into a rapid
        // running cycle. Step shape carries most of the personality; cadence
        // only nudges the shared human-scale rhythm.
        self.cadence = 1 + (authoredCadence - 1) * 0.38
    }

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

        // At 90% both feet are back under the chassis and supportFoot(at:)
        // already reports `.both`. A new sharp direction can safely start a
        // fresh step here instead of carrying the previous initiating foot
        // into the next input segment. This is especially important for quick
        // left/right and diagonal changes in the footwork showcase.
        if stepProgress >= 0.90 {
            if intentAmount <= 0.025 {
                resetStep()
                return restingFrame(intent: movementIntent)
            }
            if committedIntensity > 0,
               dot(committedDirection, intentDirection) < 0.20 {
                beginStep(
                    direction: intentDirection,
                    intensity: intentAmount,
                    towardOpponent: towardOpponent
                )
            }
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

        // One full boxing shuffle now has enough time for two distinct weighty
        // footfalls: initiating foot, plant, then trailing foot. Root travel
        // speed remains stat-driven; only the presentation cadence slows down.
        let stepDuration = (1.24 - Double(committedIntensity) * 0.08)
            / Double(cadence)
        // Releasing movement means "finish the plant", not "freeze the old
        // foot choice". Speed up only the trailing landing portion so a short
        // neutral beat reaches two-foot support before the next direction.
        let landingCadence: CGFloat = intentAmount <= 0.025 && stepProgress >= 0.55
            ? 1.65 : 1
        stepProgress = min(
            stepProgress + CGFloat(deltaTime / max(stepDuration, 0.20))
                * landingCadence,
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
        let initialSupportFoot = supportFoot
        let displayedSupportFoot = supportFoot(at: stepProgress)
        let supportSign: CGFloat = initialSupportFoot == .lead ? -1 : 1
        let loading = pulse(stepProgress, start: 0, end: 0.26)
        let firstPlant = pulse(stepProgress, start: 0.28, end: 0.50)
        let trailingPlant = pulse(stepProgress, start: 0.64, end: 0.92)
        let landing = max(firstPlant * 0.76, trailingPlant)
        let weightTransfer = (loading - landing * 0.72) * supportSign
        let weightOnLead = min(max(0.5 + weightTransfer * 0.32, 0.14), 0.86)
        let center = CGPoint(
            x: local.lateral * drive * 0.15 + weightTransfer * 0.09,
            y: local.forward * drive * 0.12
        )
        let plantedness = min(max(
            1 - max(
                pulse(stepProgress, start: 0.08, end: 0.40),
                pulse(stepProgress, start: 0.54, end: 0.84)
            ) * 0.64,
            0
        ), 1)

        return FighterBodyMotionFrame(
            intendedMovement: movementIntent,
            resolvedMovement: resolved,
            stepDirection: committedDirection,
            stepIntensity: committedIntensity,
            localForward: local.forward,
            localLateral: local.lateral,
            supportFoot: displayedSupportFoot,
            initiatingFoot: initiatingFoot,
            weightOnLeadFoot: weightOnLead,
            centerOfMassOffset: center,
            compression: -(loading * 0.80 + landing * 0.52) * committedIntensity,
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
        // Choose the foot whose stance corner is already closest to the
        // requested direction. Looking only at the dominant axis made some
        // diagonals choose the rear foot even when the lead foot was clearly
        // on the outside of the turn.
        let leadStanceScore = local.forward * 1.05 + local.lateral
        let leadFootMoves = leadStanceScore >= 0
        supportFoot = leadFootMoves ? .rear : .lead
        initiatingFoot = leadFootMoves ? .lead : .rear
    }

    private mutating func resetStep() {
        stepProgress = 1
        committedDirection = .zero
        committedIntensity = 0
        supportFoot = .both
        initiatingFoot = .both
    }

    private func restingFrame(intent: CGVector) -> FighterBodyMotionFrame {
        FighterBodyMotionFrame(
            intendedMovement: intent,
            resolvedMovement: .zero,
            stepDirection: committedDirection,
            stepIntensity: committedIntensity,
            localForward: 0,
            localLateral: 0,
            supportFoot: .both,
            initiatingFoot: .both,
            weightOnLeadFoot: supportFoot == .lead ? 0.64 : (supportFoot == .rear ? 0.36 : 0.5),
            centerOfMassOffset: .zero,
            compression: 0,
            stepProgress: stepProgress,
            plantedness: 1
        )
    }

    /// A boxing step has two distinct plants. The original support foot holds
    /// while the initiating foot travels; once it lands, that foot becomes the
    /// base and the trailing foot catches up. Treating one foot as the support
    /// for the entire cycle made the trailing leg slide while still "planted".
    private func supportFoot(at progress: CGFloat) -> FighterSupportFoot {
        guard supportFoot != .both else { return .both }
        if progress < 0.50 { return supportFoot }
        if progress < 0.90 {
            return supportFoot == .lead ? .rear : .lead
        }
        return .both
    }

    private func mobilityScale(for phase: FighterPhase) -> CGFloat {
        switch phase {
        case .idle, .punchStartup, .punchActive, .punchRecovery: return 1
        case .swaying, .hit, .knockedOut: return 0
        }
    }

    private func movementEnvelope(at progress: CGFloat) -> CGFloat {
        // Load the hip and support knee before translating the ring root.
        // Starting root travel on the first step frame made a grounded boot
        // slide and let the torso appear to pull the legs behind it.
        if progress < 0.055 {
            return 0
        }
        if progress < 0.20 {
            return smooth((progress - 0.055) / 0.145) * 0.82
        }
        if progress < 0.54 {
            return 0.82 + smooth((progress - 0.20) / 0.34) * 0.23
        }
        if progress < 0.82 {
            return 1.05 - smooth((progress - 0.54) / 0.28) * 0.19
        }
        return 0.86 - smooth((progress - 0.82) / 0.18) * 0.32
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
