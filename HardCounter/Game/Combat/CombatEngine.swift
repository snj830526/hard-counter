import CoreGraphics
import Foundation

enum FighterID: CaseIterable {
    case player
    case cpu

    var opponent: FighterID { self == .player ? .cpu : .player }
}

enum CombatAction {
    case punch(PunchIntent)
    case sway(SwayIntent)
}

struct PunchIntent {
    var forwardDrive: Double
    var lateralDrive: Double
    var movementIntensity: Double

    static let neutral = PunchIntent(forwardDrive: 0, lateralDrive: 0, movementIntensity: 0)
}

enum PunchMotion: Equatable {
    case quick
    case retreating
    case driving
    case counter
}

enum PunchTechnique: Equatable {
    case straight
    case smash
    case uppercut
}

struct PunchProfile {
    var technique: PunchTechnique = .straight
    var motion: PunchMotion = .quick
    var powerScale: Double = 1
    var lateralDrive: Double = 0
    var startupScale: Double = 1
    var activeScale: Double = 1
    var recoveryScale: Double = 1
}

enum PunchHand {
    case lead
    case rear

    var opposite: PunchHand { self == .lead ? .rear : .lead }
}

enum SwayDirection: Equatable {
    case left
    case right
    case back
    case forward
}

struct SwayIntent {
    var direction: SwayDirection
    var isTowardOpponent: Bool
    var screenDirection: CGVector

    static let neutral = SwayIntent(
        direction: .back,
        isTowardOpponent: false,
        screenDirection: .zero
    )
}

enum FighterPhase: Equatable {
    case idle
    case punchStartup
    case punchActive
    case punchRecovery
    case swaying
    case hit
    case knockedOut
}

enum HitKind {
    case normal
    case counter
}

struct FighterCombatState {
    var health = CombatTuning.maximumHealth
    var stamina = CombatTuning.maximumStamina
    var staminaRecoveryBlockedUntil: TimeInterval = 0
    var lastStaminaUpdateAt: TimeInterval?
    var phase: FighterPhase = .idle
    var phaseEndsAt: TimeInterval = 0
    var counterWindowEndsAt: TimeInterval = 0
    var nextPunchHand: PunchHand = .lead
    var activePunchHand: PunchHand = .lead
    var activePunchProfile = PunchProfile()
    var lastPunchAt: TimeInterval?
    var activeSwayDirection: SwayDirection = .back
    var activeSwayCanEvade = true
    var activeSwayPerformance: Double = 1
    var swayWasSuccessful = false
    var swayStartedAt: TimeInterval = 0
}

enum CombatEvent {
    case phaseChanged(FighterID, FighterPhase)
    case punchStarted(FighterID, PunchHand, PunchProfile)
    case swayStarted(FighterID, SwayDirection, CGVector, Double)
    case hit(attacker: FighterID, defender: FighterID, kind: HitKind, damage: Int)
    case swayed(defender: FighterID)
    case healthChanged(FighterID, Int)
    case staminaChanged(FighterID, Double)
    case roundEnded(winner: FighterID)
}

struct CombatEngine {
    private(set) var states: [FighterID: FighterCombatState] = [
        .player: FighterCombatState(),
        .cpu: FighterCombatState()
    ]
    private(set) var winner: FighterID?

    func state(for fighter: FighterID) -> FighterCombatState {
        states[fighter] ?? FighterCombatState()
    }

    mutating func request(_ action: CombatAction, by fighter: FighterID, at time: TimeInterval) -> [CombatEvent] {
        guard winner == nil else { return [] }

        switch action {
        case let .punch(intent):
            let currentState = state(for: fighter)
            let canTransitionFromSway = currentState.phase == .swaying
                && (currentState.swayWasSuccessful
                    || time >= currentState.swayStartedAt + CombatTuning.swayPunchCancelDelay)
            guard currentState.phase == .idle || canTransitionFromSway else { return [] }
            let technique = punchTechnique(for: currentState)
            let hand = state(for: fighter).nextPunchHand
            let profile = makePunchProfile(
                hand: hand,
                technique: technique,
                intent: intent,
                state: state(for: fighter),
                time: time
            )
            states[fighter]?.activePunchHand = hand
            states[fighter]?.activePunchProfile = profile
            states[fighter]?.nextPunchHand = hand.opposite
            states[fighter]?.lastPunchAt = time
            let staminaEvent = spendStamina(
                staminaCost(for: technique),
                for: fighter,
                at: time
            )
            return [staminaEvent, .punchStarted(fighter, hand, profile)]
                + setPhase(
                    .punchStartup,
                    for: fighter,
                    until: time + CombatTuning.punchStartup * profile.startupScale
                )
        case let .sway(intent):
            guard state(for: fighter).phase == .idle else { return [] }
            let performance = staminaPerformance(for: state(for: fighter))
            states[fighter]?.activeSwayDirection = intent.direction
            states[fighter]?.activeSwayCanEvade = !intent.isTowardOpponent
            states[fighter]?.activeSwayPerformance = performance
            states[fighter]?.swayWasSuccessful = false
            states[fighter]?.swayStartedAt = time
            let staminaEvent = spendStamina(
                CombatTuning.swayStaminaCost,
                for: fighter,
                at: time
            )
            return [
                staminaEvent,
                .swayStarted(fighter, intent.direction, intent.screenDirection, performance)
            ]
                + setPhase(.swaying, for: fighter, until: time + CombatTuning.swayDuration)
        }
    }

    mutating func update(
        at time: TimeInterval,
        canHit: (FighterID) -> Bool = { _ in true }
    ) -> [CombatEvent] {
        guard winner == nil else { return [] }
        var events: [CombatEvent] = []

        for fighter in FighterID.allCases {
            events += recoverStamina(for: fighter, at: time)
            var safetyCount = 0
            while state(for: fighter).phase != .idle,
                  state(for: fighter).phase != .knockedOut,
                  time >= state(for: fighter).phaseEndsAt,
                  safetyCount < 4 {
                safetyCount += 1
                events += advance(fighter, at: state(for: fighter).phaseEndsAt, canHit: canHit)
                if winner != nil { return events }
            }
        }

        return events
    }

    mutating func reset() -> [CombatEvent] {
        winner = nil
        states = [.player: FighterCombatState(), .cpu: FighterCombatState()]
        return FighterID.allCases.flatMap { fighter in
            [
                CombatEvent.healthChanged(fighter, CombatTuning.maximumHealth),
                .staminaChanged(fighter, CombatTuning.maximumStamina),
                .phaseChanged(fighter, .idle)
            ]
        }
    }

    private mutating func advance(
        _ fighter: FighterID,
        at time: TimeInterval,
        canHit: (FighterID) -> Bool
    ) -> [CombatEvent] {
        switch state(for: fighter).phase {
        case .punchStartup:
            let profile = state(for: fighter).activePunchProfile
            var events = setPhase(
                .punchActive,
                for: fighter,
                until: time + CombatTuning.punchActive * profile.activeScale
            )
            if canHit(fighter) {
                events += resolvePunch(from: fighter, at: time)
            }
            return events
        case .punchActive:
            let profile = state(for: fighter).activePunchProfile
            return setPhase(
                .punchRecovery,
                for: fighter,
                until: time + CombatTuning.punchRecovery * profile.recoveryScale
            )
        case .punchRecovery, .swaying, .hit:
            return setPhase(.idle, for: fighter, until: 0)
        case .idle, .knockedOut:
            return []
        }
    }

    private mutating func resolvePunch(from attacker: FighterID, at time: TimeInterval) -> [CombatEvent] {
        let defender = attacker.opponent
        let defenderState = state(for: defender)

        let swayElapsed = time - defenderState.swayStartedAt
        let isInsideSwayWindow = swayElapsed >= CombatTuning.swayEvadeStartup
            && swayElapsed <= CombatTuning.swayEvadeStartup
                + CombatTuning.swayEvadeActiveDuration
                    * (0.55 + defenderState.activeSwayPerformance * 0.45)
        let isValidSwayDirection = defenderState.activeSwayCanEvade
        if defenderState.phase == .swaying, isInsideSwayWindow, isValidSwayDirection {
            states[defender]?.counterWindowEndsAt = time + CombatTuning.counterWindow
            states[defender]?.swayWasSuccessful = true
            return [.swayed(defender: defender)]
        }

        let counterWindowEndsAt = state(for: attacker).counterWindowEndsAt
        let isCounter = attacker == .player && counterWindowEndsAt > 0 && time <= counterWindowEndsAt
        let kind: HitKind = isCounter ? .counter : .normal
        let profile = state(for: attacker).activePunchProfile
        let damage = isCounter
            ? max(
                1,
                Int(
                    (Double(CombatTuning.counterDamage)
                        * min(profile.powerScale / 1.25, 1)).rounded()
                )
            )
            : max(1, Int((Double(CombatTuning.normalDamage) * profile.powerScale).rounded()))
        let remainingHealth = max(0, defenderState.health - damage)
        states[defender]?.health = remainingHealth
        states[attacker]?.counterWindowEndsAt = 0

        var events: [CombatEvent] = [
            .hit(attacker: attacker, defender: defender, kind: kind, damage: damage),
            .healthChanged(defender, remainingHealth)
        ]

        if kind == .counter {
            let refundedStamina = min(
                state(for: attacker).stamina + CombatTuning.counterStaminaRefund,
                CombatTuning.maximumStamina
            )
            states[attacker]?.stamina = refundedStamina
            events.append(.staminaChanged(attacker, refundedStamina))
        }

        if remainingHealth == 0 {
            winner = attacker
            events += setPhase(.knockedOut, for: defender, until: .infinity)
            events.append(.roundEnded(winner: attacker))
        } else {
            let duration = kind == .counter ? CombatTuning.counterHitReaction : CombatTuning.hitReaction
            events += setPhase(.hit, for: defender, until: time + duration)
        }
        return events
    }

    private mutating func setPhase(
        _ phase: FighterPhase,
        for fighter: FighterID,
        until endTime: TimeInterval
    ) -> [CombatEvent] {
        states[fighter]?.phase = phase
        states[fighter]?.phaseEndsAt = endTime
        return [.phaseChanged(fighter, phase)]
    }

    private func makePunchProfile(
        hand: PunchHand,
        technique: PunchTechnique,
        intent: PunchIntent,
        state: FighterCombatState,
        time: TimeInterval
    ) -> PunchProfile {
        let hasCounter = state.counterWindowEndsAt > 0 && time <= state.counterWindowEndsAt
        let rhythmScale: Double
        if let lastPunchAt = state.lastPunchAt {
            let interval = time - lastPunchAt
            if interval < 0.68 {
                rhythmScale = 0.82
            } else if interval <= 1.20 {
                rhythmScale = 1.06
            } else {
                rhythmScale = 0.94
            }
        } else {
            rhythmScale = 0.96
        }

        let motion: PunchMotion
        if hasCounter {
            motion = .counter
        } else if intent.forwardDrive > 0.28 {
            motion = .driving
        } else if intent.forwardDrive < -0.24 {
            motion = .retreating
        } else {
            motion = .quick
        }

        let handScale = hand == .lead ? 0.86 : 1.06
        let techniquePowerScale: Double
        switch technique {
        case .straight: techniquePowerScale = 1
        case .smash: techniquePowerScale = 1.10
        case .uppercut: techniquePowerScale = 1.12
        }
        let forwardScale = 1 + max(intent.forwardDrive, 0) * 0.16
            + min(intent.forwardDrive, 0) * 0.12
        let movementControl = 1 - min(abs(intent.lateralDrive), 1) * 0.035
        let basePowerScale = hasCounter
            ? 1.25
            : min(
                max(
                    handScale * rhythmScale * forwardScale * movementControl
                        * techniquePowerScale,
                    0.66
                ),
                1.28
            )
        let performance = staminaPerformance(for: state)
        let powerScale = basePowerScale * performance
        let fatigueRecoveryScale = 1 + (1 - performance) * 1.15
        let fatigueStartupScale = 1 + (1 - performance) * 0.32
        let techniqueStartupScale: Double
        let techniqueActiveScale: Double
        let techniqueRecoveryScale: Double
        switch technique {
        case .straight:
            techniqueStartupScale = 1
            techniqueActiveScale = 1
            techniqueRecoveryScale = 1
        case .smash:
            techniqueStartupScale = 0.94
            techniqueActiveScale = 2.20
            techniqueRecoveryScale = 1.08
        case .uppercut:
            techniqueStartupScale = 1.05
            techniqueActiveScale = 1.40
            techniqueRecoveryScale = 1.16
        }

        switch motion {
        case .quick:
            return PunchProfile(
                technique: technique,
                motion: motion,
                powerScale: powerScale,
                lateralDrive: intent.lateralDrive,
                startupScale: (hand == .lead ? 0.80 : 0.96)
                    * fatigueStartupScale * techniqueStartupScale,
                activeScale: techniqueActiveScale,
                recoveryScale: (hand == .lead ? 0.82 : 1.02)
                    * fatigueRecoveryScale * techniqueRecoveryScale
            )
        case .retreating:
            return PunchProfile(
                technique: technique,
                motion: motion,
                powerScale: powerScale * 0.92,
                lateralDrive: intent.lateralDrive,
                startupScale: 0.84 * fatigueStartupScale * techniqueStartupScale,
                activeScale: techniqueActiveScale,
                recoveryScale: 0.86 * fatigueRecoveryScale * techniqueRecoveryScale
            )
        case .driving:
            return PunchProfile(
                technique: technique,
                motion: motion,
                powerScale: powerScale,
                lateralDrive: intent.lateralDrive,
                startupScale: (hand == .lead ? 0.88 : 1.05)
                    * fatigueStartupScale * techniqueStartupScale,
                activeScale: techniqueActiveScale,
                recoveryScale: (hand == .lead ? 0.94 : 1.12)
                    * fatigueRecoveryScale * techniqueRecoveryScale
            )
        case .counter:
            return PunchProfile(
                technique: technique,
                motion: motion,
                powerScale: powerScale,
                lateralDrive: intent.lateralDrive,
                startupScale: 0.68 * fatigueStartupScale * techniqueStartupScale,
                activeScale: techniqueActiveScale,
                recoveryScale: 1.08 * fatigueRecoveryScale * techniqueRecoveryScale
            )
        }
    }

    private func punchTechnique(for state: FighterCombatState) -> PunchTechnique {
        guard state.phase == .swaying else { return .straight }
        switch state.activeSwayDirection {
        case .left, .right: return .smash
        case .forward: return .uppercut
        case .back: return .straight
        }
    }

    private func staminaCost(for technique: PunchTechnique) -> Double {
        switch technique {
        case .straight: return CombatTuning.straightStaminaCost
        case .smash: return CombatTuning.smashStaminaCost
        case .uppercut: return CombatTuning.uppercutStaminaCost
        }
    }

    private func staminaPerformance(for state: FighterCombatState) -> Double {
        guard state.stamina < CombatTuning.lowStaminaThreshold else { return 1 }
        let fraction = max(state.stamina / CombatTuning.lowStaminaThreshold, 0)
        return 0.45 + fraction * 0.55
    }

    private mutating func spendStamina(
        _ amount: Double,
        for fighter: FighterID,
        at time: TimeInterval
    ) -> CombatEvent {
        let remaining = max(state(for: fighter).stamina - amount, 0)
        states[fighter]?.stamina = remaining
        states[fighter]?.staminaRecoveryBlockedUntil = time + CombatTuning.staminaRecoveryDelay
        states[fighter]?.lastStaminaUpdateAt = time
        return .staminaChanged(fighter, remaining)
    }

    private mutating func recoverStamina(
        for fighter: FighterID,
        at time: TimeInterval
    ) -> [CombatEvent] {
        let currentState = state(for: fighter)
        guard currentState.phase != .knockedOut else { return [] }
        guard let lastUpdate = currentState.lastStaminaUpdateAt else {
            states[fighter]?.lastStaminaUpdateAt = time
            return []
        }
        states[fighter]?.lastStaminaUpdateAt = time
        let recoveryStart = max(lastUpdate, currentState.staminaRecoveryBlockedUntil)
        guard time > recoveryStart,
              currentState.stamina < CombatTuning.maximumStamina else { return [] }
        let recovered = min(
            currentState.stamina
                + (time - recoveryStart) * CombatTuning.staminaRecoveryPerSecond,
            CombatTuning.maximumStamina
        )
        states[fighter]?.stamina = recovered
        return [.staminaChanged(fighter, recovered)]
    }
}
