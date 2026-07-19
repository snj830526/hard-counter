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
    var reachScale: Double = 1
}

enum PunchHand {
    case lead
    case rear

    var opposite: PunchHand { self == .lead ? .rear : .lead }
}

struct SwayDirection: Equatable {
    let forward: CGFloat
    let lateral: CGFloat

    static let left = SwayDirection(forward: 0, lateral: 1)
    static let right = SwayDirection(forward: 0, lateral: -1)
    static let back = SwayDirection(forward: -1, lateral: 0)
    static let forward = SwayDirection(forward: 1, lateral: 0)

    /// Maps a continuous lean to the strike whose loading path is closest to
    /// the stored body angle. Diagonals stay continuous visually; these broad
    /// sectors only select one of the three authored punch techniques.
    var followUpTechnique: PunchTechnique {
        if abs(lateral) > abs(forward) * 1.05 {
            return .smash
        }
        return forward > 0 ? .uppercut : .straight
    }
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
    let stats: FighterStats
    var health: Int
    var stamina: Double
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

    init(stats: FighterStats = .standard) {
        self.stats = stats
        health = stats.maximumHealth
        stamina = stats.maximumStamina
    }
}

enum CombatEvent {
    case phaseChanged(FighterID, FighterPhase)
    case punchStarted(FighterID, PunchHand, PunchProfile)
    case swayStarted(FighterID, SwayDirection, CGVector, Double)
    case punchMissed(FighterID, PunchProfile)
    case hit(
        attacker: FighterID,
        defender: FighterID,
        kind: HitKind,
        damage: Int,
        profile: PunchProfile
    )
    case swayed(defender: FighterID)
    case healthChanged(FighterID, Int)
    case staminaChanged(FighterID, Double)
    case roundEnded(winner: FighterID)
}

struct CombatEngine {
    private let fighterStats: [FighterID: FighterStats]
    private let fighterStyles: [FighterID: FighterCombatStyle]
    private(set) var states: [FighterID: FighterCombatState]
    private(set) var winner: FighterID?

    init(
        playerStats: FighterStats = .standard,
        cpuStats: FighterStats = .standard,
        playerStyle: FighterCombatStyle = .standard,
        cpuStyle: FighterCombatStyle = .standard
    ) {
        fighterStats = [.player: playerStats, .cpu: cpuStats]
        fighterStyles = [.player: playerStyle, .cpu: cpuStyle]
        states = [
            .player: FighterCombatState(stats: playerStats),
            .cpu: FighterCombatState(stats: cpuStats)
        ]
    }

    func state(for fighter: FighterID) -> FighterCombatState {
        states[fighter] ?? FighterCombatState(stats: fighterStats[fighter] ?? .standard)
    }

    mutating func applyAuthoritativeState(
        playerHealth: Int,
        cpuHealth: Int,
        playerStamina: Double,
        cpuStamina: Double,
        winner newWinner: FighterID?
    ) -> [CombatEvent] {
        var events: [CombatEvent] = []
        let values: [(FighterID, Int, Double)] = [
            (.player, playerHealth, playerStamina),
            (.cpu, cpuHealth, cpuStamina)
        ]
        for (fighter, health, stamina) in values {
            if state(for: fighter).health != health {
                states[fighter]?.health = health
                events.append(.healthChanged(fighter, health))
            }
            if abs(state(for: fighter).stamina - stamina) > 0.05 {
                states[fighter]?.stamina = stamina
                events.append(.staminaChanged(fighter, stamina))
            }
        }
        if winner == nil, let newWinner {
            winner = newWinner
            states[newWinner.opponent]?.phase = .knockedOut
            events.append(.phaseChanged(newWinner.opponent, .knockedOut))
            events.append(.roundEnded(winner: newWinner))
        }
        return events
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
                time: time,
                style: fighterStyles[fighter] ?? .standard
            )
            states[fighter]?.activePunchHand = hand
            states[fighter]?.activePunchProfile = profile
            if profile.motion == .counter {
                states[fighter]?.counterWindowEndsAt = 0
            }
            states[fighter]?.nextPunchHand = hand.opposite
            states[fighter]?.lastPunchAt = time
            let staminaEvent = spendStamina(
                staminaCost(for: technique)
                    * (fighterStyles[fighter] ?? .standard)
                        .modifier(for: technique, motion: profile.motion)
                        .stamina,
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
        states = Dictionary(uniqueKeysWithValues: FighterID.allCases.map { fighter in
            (fighter, FighterCombatState(stats: fighterStats[fighter] ?? .standard))
        })
        return FighterID.allCases.flatMap { fighter in
            let state = state(for: fighter)
            return [
                CombatEvent.healthChanged(fighter, state.stats.maximumHealth),
                .staminaChanged(fighter, state.stats.maximumStamina),
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
            } else {
                events.append(.punchMissed(fighter, profile))
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
        let profile = state(for: attacker).activePunchProfile

        let swayElapsed = time - defenderState.swayStartedAt
        let isInsideSwayWindow = swayElapsed >= CombatTuning.swayEvadeStartup
            && swayElapsed <= CombatTuning.swayEvadeStartup
                + CombatTuning.swayEvadeActiveDuration
                    * (0.55 + defenderState.activeSwayPerformance * 0.45)
        let isValidSwayDirection = defenderState.activeSwayCanEvade
        if defenderState.phase == .swaying, isInsideSwayWindow, isValidSwayDirection {
            states[defender]?.counterWindowEndsAt = time + CombatTuning.counterWindow
            states[defender]?.swayWasSuccessful = true
            return [
                .swayed(defender: defender),
                .punchMissed(attacker, profile)
            ]
        }

        let isCounter = profile.motion == .counter
        let kind: HitKind = isCounter ? .counter : .normal
        let damage = isCounter
            ? max(
                1,
                Int(
                    (Double(CombatTuning.counterDamage)
                        * min(profile.powerScale / 1.25, 1.12)).rounded()
                )
            )
            : max(1, Int((Double(CombatTuning.normalDamage) * profile.powerScale).rounded()))
        let remainingHealth = max(0, defenderState.health - damage)
        states[defender]?.health = remainingHealth

        var events: [CombatEvent] = [
            .hit(
                attacker: attacker,
                defender: defender,
                kind: kind,
                damage: damage,
                profile: profile
            ),
            .healthChanged(defender, remainingHealth)
        ]

        if kind == .counter {
            let maximumStamina = state(for: attacker).stats.maximumStamina
            let refundedStamina = min(
                state(for: attacker).stamina + CombatTuning.counterStaminaRefund,
                maximumStamina
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
        time: TimeInterval,
        style: FighterCombatStyle
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
        let styleModifier = style.modifier(for: technique, motion: motion)

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
        let powerScale = basePowerScale * performance * styleModifier.power
        let fatigueRecoveryScale = 1 + (1 - performance) * 1.65
        let fatigueStartupScale = 1 + (1 - performance) * 0.65
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
            techniqueActiveScale = 2.00
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
                    * fatigueStartupScale * techniqueStartupScale * styleModifier.startup,
                activeScale: techniqueActiveScale * styleModifier.active,
                recoveryScale: (hand == .lead ? 0.82 : 1.02)
                    * fatigueRecoveryScale * techniqueRecoveryScale * styleModifier.recovery,
                reachScale: styleModifier.reach
            )
        case .retreating:
            return PunchProfile(
                technique: technique,
                motion: motion,
                powerScale: powerScale * 0.92,
                lateralDrive: intent.lateralDrive,
                startupScale: 0.84 * fatigueStartupScale * techniqueStartupScale * styleModifier.startup,
                activeScale: techniqueActiveScale * styleModifier.active,
                recoveryScale: 0.86 * fatigueRecoveryScale * techniqueRecoveryScale * styleModifier.recovery,
                reachScale: styleModifier.reach
            )
        case .driving:
            return PunchProfile(
                technique: technique,
                motion: motion,
                powerScale: powerScale,
                lateralDrive: intent.lateralDrive,
                startupScale: (hand == .lead ? 0.88 : 1.05)
                    * fatigueStartupScale * techniqueStartupScale * styleModifier.startup,
                activeScale: techniqueActiveScale * styleModifier.active,
                recoveryScale: (hand == .lead ? 0.94 : 1.12)
                    * fatigueRecoveryScale * techniqueRecoveryScale * styleModifier.recovery,
                reachScale: styleModifier.reach
            )
        case .counter:
            return PunchProfile(
                technique: technique,
                motion: motion,
                powerScale: powerScale,
                lateralDrive: intent.lateralDrive,
                startupScale: 0.68 * fatigueStartupScale * techniqueStartupScale * styleModifier.startup,
                activeScale: techniqueActiveScale * styleModifier.active,
                recoveryScale: 1.08 * fatigueRecoveryScale * techniqueRecoveryScale * styleModifier.recovery,
                reachScale: styleModifier.reach
            )
        }
    }

    private func punchTechnique(for state: FighterCombatState) -> PunchTechnique {
        guard state.phase == .swaying else { return .straight }
        return state.activeSwayDirection.followUpTechnique
    }

    private func staminaCost(for technique: PunchTechnique) -> Double {
        switch technique {
        case .straight: return CombatTuning.straightStaminaCost
        case .smash: return CombatTuning.smashStaminaCost
        case .uppercut: return CombatTuning.uppercutStaminaCost
        }
    }

    private func staminaPerformance(for state: FighterCombatState) -> Double {
        let lowStaminaThreshold = state.stats.lowStaminaThreshold
        guard state.stamina < lowStaminaThreshold else { return 1 }
        let fraction = max(state.stamina / lowStaminaThreshold, 0)
        let minimum = CombatTuning.minimumExhaustedPerformance
        return minimum + fraction * (1 - minimum)
    }

    private mutating func spendStamina(
        _ amount: Double,
        for fighter: FighterID,
        at time: TimeInterval
    ) -> CombatEvent {
        let remaining = max(state(for: fighter).stamina - amount, 0)
        states[fighter]?.stamina = remaining
        let recoveryDelay = remaining == 0
            ? CombatTuning.exhaustedStaminaRecoveryDelay
            : CombatTuning.staminaRecoveryDelay
        states[fighter]?.staminaRecoveryBlockedUntil = time + recoveryDelay
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
              currentState.stamina < currentState.stats.maximumStamina else { return [] }
        let recovered = min(
            currentState.stamina
                + (time - recoveryStart) * CombatTuning.staminaRecoveryPerSecond,
            currentState.stats.maximumStamina
        )
        states[fighter]?.stamina = recovered
        return [.staminaChanged(fighter, recovered)]
    }
}
