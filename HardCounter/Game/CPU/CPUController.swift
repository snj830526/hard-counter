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
    private var nextProactiveSwayTime: TimeInterval = 0
    private var pendingDefenseAt: TimeInterval?
    private var pendingCounterAt: TimeInterval?
    private var observedCounterWindowEndsAt: TimeInterval = 0
    private var movementVector = CGVector.zero
    private var circlingDirection: CGFloat = 1
    private var lastOpponentPhase: FighterPhase = .idle
    private var lastSelfPhase: FighterPhase = .idle
    private var tacticalMode: TacticalMode = .angle
    private var tacticalModeEndsAt: TimeInterval = 0
    private var hasInitiatedAttack = false
    private var shouldSetUpNextAttackWithSway = false

    init(difficulty: CPUDifficultyProfile = .challenger) {
        self.difficulty = difficulty
    }

    mutating func reset(at time: TimeInterval) {
        nextAttackTime = time + CombatTuning.cpuInitialDelay
        nextMovementDecisionTime = time
        nextProactiveSwayTime = time + Double.random(in: difficulty.proactiveSwayInterval)
        pendingDefenseAt = nil
        pendingCounterAt = nil
        observedCounterWindowEndsAt = 0
        movementVector = .zero
        circlingDirection = Bool.random() ? 1 : -1
        lastOpponentPhase = .idle
        lastSelfPhase = .idle
        tacticalMode = .pressure
        tacticalModeEndsAt = time
        hasInitiatedAttack = false
        shouldSetUpNextAttackWithSway = false
    }

    mutating func combatAction(for perception: CPUPerception) -> CombatAction? {
        if nextAttackTime == nil { reset(at: perception.time) }
        observePlayerAttack(perception)
        schedulePunishIfAvailable(perception)
        scheduleCombinationIfAvailable(perception)
        lastOpponentPhase = perception.opponentState.phase
        lastSelfPhase = perception.selfState.phase

        if let counter = counterAction(for: perception) { return counter }
        if !hasInitiatedAttack {
            // The opening belongs to the CPU: close the gap and throw before
            // considering reactive defense, so a passive player is pressured.
            return pressureAttack(for: perception)
        }
        if let defense = defenseAction(for: perception) { return defense }
        if let sway = proactiveSwayAction(for: perception) { return sway }
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
        let attackIsDue = perception.time >= (nextAttackTime ?? .infinity)

        if perception.time >= tacticalModeEndsAt {
            selectTacticalMode(
                at: perception.time,
                isTired: isTired,
                opponentIsTired: opponentIsTired,
                distanceScale: distanceScale
            )
        }

        let opponentIsRecovering = perception.opponentState.phase == .punchRecovery

        if isTired {
            movementVector = roll < 0.58 ? away : (roll < 0.92 ? circle : .zero)
        } else if opponentIsRecovering, distanceScale > 0.70 {
            // Do not give away a missed punch recovery by circling or pulling
            // back. Close on a shallow angle so the punish can connect.
            movementVector = blended(toward, circle, circleAmount: 0.10)
        } else if attackIsDue,
                  distanceScale > 0.92,
                  (!hasInitiatedAttack || tacticalMode == .pressure) {
            // Once an attack is due, take the initiative and finish closing
            // distance instead of circling forever just outside punch range.
            movementVector = blended(toward, circle, circleAmount: 0.12)
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
                movementVector = blended(away, circle, circleAmount: 0.22)
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
                movementVector = distanceScale < 1.15
                    ? blended(away, circle, circleAmount: 0.22)
                    : circle
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
              perception.visibleDistance <= perception.preferredPunchRange * 1.22,
              Double.random(in: 0...1) < difficulty.defenseChance else { return }
        pendingDefenseAt = perception.time
            + Double.random(in: difficulty.defensiveReactionDelay)
    }

    private mutating func schedulePunishIfAvailable(_ perception: CPUPerception) {
        let opponentEnteredRecovery = perception.opponentState.phase == .punchRecovery
            && lastOpponentPhase != .punchRecovery
        guard opponentEnteredRecovery,
              perception.selfState.phase == .idle,
              perception.selfState.stamina > difficulty.staminaReserve,
              perception.visibleDistance <= perception.preferredPunchRange * 1.18 else { return }

        let punishAt = perception.time
            + Double.random(in: difficulty.punishReactionDelay)
        nextAttackTime = min(nextAttackTime ?? punishAt, punishAt)
        shouldSetUpNextAttackWithSway = false
        tacticalMode = .pressure
        tacticalModeEndsAt = max(tacticalModeEndsAt, perception.time + 0.72)
    }

    private mutating func scheduleCombinationIfAvailable(_ perception: CPUPerception) {
        let justRecovered = lastSelfPhase == .punchRecovery
            && perception.selfState.phase == .idle
        guard justRecovered else { return }
        let canContinue = perception.selfState.stamina > difficulty.staminaReserve
            && perception.visibleDistance <= perception.preferredPunchRange * 1.10
        guard canContinue,
              Double.random(in: 0...1) < difficulty.combinationChance else {
            beginPostExchangeReset(at: perception.time)
            return
        }
        tacticalMode = .pressure
        tacticalModeEndsAt = max(tacticalModeEndsAt, perception.time + 0.9)
        let followUp = perception.time + Double.random(in: 0.18...0.32)
        nextAttackTime = min(nextAttackTime ?? followUp, followUp)
    }

    private mutating func beginPostExchangeReset(at time: TimeInterval) {
        tacticalMode = .reset
        let resetEndsAt = time + Double.random(in: difficulty.postExchangeResetDuration)
        tacticalModeEndsAt = resetEndsAt
        shouldSetUpNextAttackWithSway = true
        nextProactiveSwayTime = min(nextProactiveSwayTime, time + 0.16)
        nextAttackTime = max(nextAttackTime ?? resetEndsAt, resetEndsAt + 0.22)
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
        nextProactiveSwayTime = perception.time
            + Double.random(in: difficulty.proactiveSwayInterval)
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
              perception.selfState.phase == .idle,
              !shouldSetUpNextAttackWithSway,
              tacticalMode != .reset || perception.time >= tacticalModeEndsAt else { return nil }
        guard perception.visibleDistance <= perception.preferredPunchRange * 1.10 else {
            // Keep the attack ready while footwork closes the final gap.
            self.nextAttackTime = perception.time
            return nil
        }
        guard perception.selfState.stamina >= CombatTuning.straightStaminaCost else {
            self.nextAttackTime = perception.time + 0.45
            return nil
        }

        scheduleNextAttack(after: perception.time)
        hasInitiatedAttack = true
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

    private mutating func proactiveSwayAction(
        for perception: CPUPerception
    ) -> CombatAction? {
        guard perception.time >= nextProactiveSwayTime,
              perception.selfState.phase == .idle,
              perception.selfState.stamina >= CombatTuning.swayStaminaCost,
              perception.visibleDistance <= perception.preferredPunchRange * 1.45 else {
            return nil
        }
        nextProactiveSwayTime = perception.time
            + Double.random(in: difficulty.proactiveSwayInterval)
        let setupIsRequired = shouldSetUpNextAttackWithSway
        guard setupIsRequired
                || Double.random(in: 0...1) < difficulty.proactiveSwayChance else { return nil }
        shouldSetUpNextAttackWithSway = false

        let toward = normalized(perception.screenTowardOpponent)
        let usesPullback = tacticalMode == .reset || Double.random(in: 0...1) < 0.28
        if usesPullback {
            tacticalMode = .reset
            tacticalModeEndsAt = max(tacticalModeEndsAt, perception.time + 0.72)
            return .sway(SwayIntent(
                direction: .back,
                isTowardOpponent: false,
                screenDirection: CGVector(dx: -toward.dx, dy: -toward.dy)
            ))
        }

        let side: CGFloat = Bool.random() ? 1 : -1
        tacticalMode = .angle
        tacticalModeEndsAt = max(tacticalModeEndsAt, perception.time + 0.72)
        return .sway(SwayIntent(
            direction: side > 0 ? .left : .right,
            isTowardOpponent: false,
            screenDirection: CGVector(
                dx: -toward.dy * side,
                dy: toward.dx * side
            )
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
