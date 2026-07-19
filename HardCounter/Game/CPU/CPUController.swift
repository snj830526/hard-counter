import CoreGraphics
import Foundation

struct CPUPerception {
    let time: TimeInterval
    let selfState: FighterCombatState
    let opponentState: FighterCombatState
    let towardOpponent: CGVector
    let screenTowardOpponent: CGVector
    let visibleDistance: CGFloat
    let preferredPunchRange: CGFloat
}

struct CPUController {
    private enum TacticalMode {
        case pressure
        case angle
        case reset
    }

    private let difficulty: CPUDifficultyProfile
    private var nextAttackTime: TimeInterval?
    private var nextMovementDecisionTime: TimeInterval = 0
    private var pendingDefenseAt: TimeInterval?
    private var pendingCounterAt: TimeInterval?
    private var observedCounterWindowEndsAt: TimeInterval = 0
    private var movementVector = CGVector.zero
    private var circlingDirection: CGFloat = 1
    private var lastOpponentPhase: FighterPhase = .idle
    private var lastSelfPhase: FighterPhase = .idle
    private var tacticalMode: TacticalMode = .angle
    private var tacticalModeEndsAt: TimeInterval = 0
    private var combinationStepsRemaining = 0

    init(difficulty: CPUDifficultyProfile = .challenger) {
        self.difficulty = difficulty
    }

    mutating func reset(at time: TimeInterval) {
        nextAttackTime = time + CombatTuning.cpuInitialDelay
        nextMovementDecisionTime = time
        pendingDefenseAt = nil
        pendingCounterAt = nil
        observedCounterWindowEndsAt = 0
        movementVector = .zero
        circlingDirection = Bool.random() ? 1 : -1
        lastOpponentPhase = .idle
        lastSelfPhase = .idle
        tacticalMode = .angle
        tacticalModeEndsAt = time
        combinationStepsRemaining = 0
    }

    mutating func combatAction(for perception: CPUPerception) -> CombatAction? {
        if nextAttackTime == nil { reset(at: perception.time) }
        observePlayerAttack(perception)
        scheduleCombinationIfAvailable(perception)
        lastOpponentPhase = perception.opponentState.phase
        lastSelfPhase = perception.selfState.phase

        if let counter = counterAction(for: perception) { return counter }
        if let defense = defenseAction(for: perception) { return defense }
        return pressureAttack(for: perception)
    }

    mutating func movement(for perception: CPUPerception) -> CGVector {
        guard perception.time >= nextMovementDecisionTime else { return movementVector }
        nextMovementDecisionTime = perception.time
            + Double.random(in: difficulty.movementDecisionInterval)

        let toward = normalized(perception.towardOpponent)
        if Double.random(in: 0...1) < 0.11 { circlingDirection *= -1 }
        let circle = CGVector(
            dx: -toward.dy * circlingDirection,
            dy: toward.dx * circlingDirection
        )
        let away = CGVector(dx: -toward.dx, dy: -toward.dy)
        let distanceScale = perception.visibleDistance / max(perception.preferredPunchRange, 1)
        let isTired = perception.selfState.stamina
            <= perception.selfState.stats.lowStaminaThreshold
        let opponentIsTired = perception.opponentState.stamina
            <= perception.opponentState.stats.lowStaminaThreshold
        let roll = Double.random(in: 0...1)

        if perception.time >= tacticalModeEndsAt {
            selectTacticalMode(
                at: perception.time,
                isTired: isTired,
                opponentIsTired: opponentIsTired,
                distanceScale: distanceScale
            )
        }

        if isTired {
            movementVector = roll < 0.58 ? away : (roll < 0.92 ? circle : .zero)
        } else if distanceScale > 1.35 {
            movementVector = tacticalMode == .reset
                ? circle
                : blended(toward, circle, circleAmount: tacticalMode == .angle ? 0.46 : 0.18)
        } else if distanceScale < 0.66 {
            switch tacticalMode {
            case .pressure:
                movementVector = roll < 0.62 ? circle : .zero
            case .angle:
                movementVector = roll < 0.76 ? circle : away
            case .reset:
                movementVector = roll < 0.72 ? away : circle
            }
        } else {
            let pressure = min(difficulty.pressureBias + (opponentIsTired ? 0.16 : 0), 0.82)
            switch tacticalMode {
            case .pressure:
                movementVector = roll < pressure
                    ? blended(toward, circle, circleAmount: 0.22)
                    : circle
            case .angle:
                movementVector = roll < 0.72 ? circle : (roll < 0.90 ? toward : .zero)
            case .reset:
                movementVector = roll < 0.62 ? away : (roll < 0.90 ? circle : .zero)
            }
        }
        return movementVector
    }

    private mutating func observePlayerAttack(_ perception: CPUPerception) {
        let attackJustStarted = perception.opponentState.phase == .punchStartup
            && lastOpponentPhase != .punchStartup
        guard attackJustStarted,
              perception.selfState.phase == .idle,
              perception.selfState.stamina >= CombatTuning.swayStaminaCost,
              Double.random(in: 0...1) < difficulty.defenseChance else { return }
        pendingDefenseAt = perception.time
            + Double.random(in: difficulty.defensiveReactionDelay)
    }

    private mutating func scheduleCombinationIfAvailable(_ perception: CPUPerception) {
        let justRecovered = lastSelfPhase == .punchRecovery
            && perception.selfState.phase == .idle
        guard justRecovered,
              perception.selfState.stamina > difficulty.staminaReserve,
              perception.visibleDistance <= perception.preferredPunchRange * 1.10 else { return }
        let continuesCombination = combinationStepsRemaining > 0
        guard continuesCombination
                || Double.random(in: 0...1) < difficulty.combinationChance else { return }
        if continuesCombination {
            combinationStepsRemaining -= 1
        } else {
            combinationStepsRemaining = Double.random(in: 0...1) < 0.28 ? 1 : 0
        }
        tacticalMode = .pressure
        tacticalModeEndsAt = max(tacticalModeEndsAt, perception.time + 0.9)
        let followUp = perception.time + Double.random(in: 0.18...0.32)
        nextAttackTime = min(nextAttackTime ?? followUp, followUp)
    }

    private mutating func counterAction(
        for perception: CPUPerception
    ) -> CombatAction? {
        let hasCounterWindow = perception.selfState.counterWindowEndsAt > perception.time
        let isNewCounterWindow = perception.selfState.counterWindowEndsAt
            != observedCounterWindowEndsAt
        if hasCounterWindow, isNewCounterWindow {
            observedCounterWindowEndsAt = perception.selfState.counterWindowEndsAt
            if Double.random(in: 0...1) < difficulty.counterChance {
                pendingCounterAt = perception.time
                    + Double.random(in: difficulty.counterReactionDelay)
            } else {
                pendingCounterAt = nil
            }
        }
        guard let pendingCounterAt,
              perception.time >= pendingCounterAt else { return nil }
        self.pendingCounterAt = nil
        guard perception.selfState.phase == .idle
                || perception.selfState.phase == .swaying else { return nil }
        scheduleNextAttack(after: perception.time)
        return .punch(PunchIntent(
            forwardDrive: 0.36,
            lateralDrive: 0,
            movementIntensity: 0.55
        ))
    }

    private mutating func defenseAction(
        for perception: CPUPerception
    ) -> CombatAction? {
        guard let pendingDefenseAt,
              perception.time >= pendingDefenseAt else { return nil }
        self.pendingDefenseAt = nil
        guard perception.selfState.phase == .idle,
              perception.opponentState.phase == .punchStartup else { return nil }

        let toward = normalized(perception.screenTowardOpponent)
        let side: CGFloat = Bool.random() ? 1 : -1
        let lateral = CGVector(dx: -toward.dy * side, dy: toward.dx * side)
        return .sway(SwayIntent(
            direction: side > 0 ? .left : .right,
            isTowardOpponent: false,
            screenDirection: lateral
        ))
    }

    private mutating func pressureAttack(
        for perception: CPUPerception
    ) -> CombatAction? {
        guard let nextAttackTime,
              perception.time >= nextAttackTime,
              perception.selfState.phase == .idle else { return nil }
        guard perception.visibleDistance <= perception.preferredPunchRange * 1.08 else {
            self.nextAttackTime = perception.time + 0.22
            return nil
        }
        guard perception.selfState.stamina >= CombatTuning.straightStaminaCost else {
            self.nextAttackTime = perception.time + 0.45
            return nil
        }

        scheduleNextAttack(after: perception.time)
        let distanceScale = perception.visibleDistance / max(perception.preferredPunchRange, 1)
        let forwardDrive = distanceScale > 0.88 ? 0.46 : 0.12
        let lateralDrive = tacticalMode == .angle
            ? Double.random(in: -0.34...0.34) : Double.random(in: -0.12...0.12)
        return .punch(PunchIntent(
            forwardDrive: Double(forwardDrive),
            lateralDrive: lateralDrive,
            movementIntensity: Double(min(distanceScale, 1))
        ))
    }

    private mutating func scheduleNextAttack(after time: TimeInterval) {
        nextAttackTime = time + Double.random(in: difficulty.attackInterval)
    }

    private func normalized(_ vector: CGVector) -> CGVector {
        let length = hypot(vector.dx, vector.dy)
        guard length > 0.001 else { return CGVector(dx: -1, dy: 0) }
        return CGVector(dx: vector.dx / length, dy: vector.dy / length)
    }

    private mutating func selectTacticalMode(
        at time: TimeInterval,
        isTired: Bool,
        opponentIsTired: Bool,
        distanceScale: CGFloat
    ) {
        let roll = Double.random(in: 0...1)
        if isTired {
            tacticalMode = roll < 0.74 ? .reset : .angle
        } else if opponentIsTired {
            tacticalMode = roll < 0.72 ? .pressure : .angle
        } else if distanceScale > 1.35 {
            tacticalMode = roll < 0.62 ? .pressure : .angle
        } else if roll < 0.46 {
            tacticalMode = .pressure
        } else if roll < 0.84 {
            tacticalMode = .angle
        } else {
            tacticalMode = .reset
        }
        tacticalModeEndsAt = time + Double.random(in: 1.15...2.45)
        if Bool.random() { circlingDirection *= -1 }
    }

    private func blended(
        _ primary: CGVector,
        _ secondary: CGVector,
        circleAmount: CGFloat
    ) -> CGVector {
        normalized(CGVector(
            dx: primary.dx * (1 - circleAmount) + secondary.dx * circleAmount,
            dy: primary.dy * (1 - circleAmount) + secondary.dy * circleAmount
        ))
    }
}
