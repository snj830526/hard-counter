import Foundation

enum FighterID: CaseIterable {
    case player
    case cpu

    var opponent: FighterID { self == .player ? .cpu : .player }
}

enum CombatAction {
    case punch
    case sway(SwayDirection)
}

enum PunchHand {
    case lead
    case rear

    var opposite: PunchHand { self == .lead ? .rear : .lead }
}

enum SwayDirection {
    case left
    case right
    case back
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
    var phase: FighterPhase = .idle
    var phaseEndsAt: TimeInterval = 0
    var counterWindowEndsAt: TimeInterval = 0
    var nextPunchHand: PunchHand = .lead
    var activePunchHand: PunchHand = .lead
}

enum CombatEvent {
    case phaseChanged(FighterID, FighterPhase)
    case punchStarted(FighterID, PunchHand)
    case swayStarted(FighterID, SwayDirection)
    case hit(attacker: FighterID, defender: FighterID, kind: HitKind, damage: Int)
    case swayed(defender: FighterID)
    case healthChanged(FighterID, Int)
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
        guard winner == nil, state(for: fighter).phase == .idle else { return [] }

        switch action {
        case .punch:
            let hand = state(for: fighter).nextPunchHand
            states[fighter]?.activePunchHand = hand
            states[fighter]?.nextPunchHand = hand.opposite
            return [.punchStarted(fighter, hand)]
                + setPhase(.punchStartup, for: fighter, until: time + CombatTuning.punchStartup)
        case let .sway(direction):
            return [.swayStarted(fighter, direction)]
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
            [CombatEvent.healthChanged(fighter, CombatTuning.maximumHealth), .phaseChanged(fighter, .idle)]
        }
    }

    private mutating func advance(
        _ fighter: FighterID,
        at time: TimeInterval,
        canHit: (FighterID) -> Bool
    ) -> [CombatEvent] {
        switch state(for: fighter).phase {
        case .punchStartup:
            var events = setPhase(.punchActive, for: fighter, until: time + CombatTuning.punchActive)
            if canHit(fighter) {
                events += resolvePunch(from: fighter, at: time)
            }
            return events
        case .punchActive:
            return setPhase(.punchRecovery, for: fighter, until: time + CombatTuning.punchRecovery)
        case .punchRecovery, .swaying, .hit:
            return setPhase(.idle, for: fighter, until: 0)
        case .idle, .knockedOut:
            return []
        }
    }

    private mutating func resolvePunch(from attacker: FighterID, at time: TimeInterval) -> [CombatEvent] {
        let defender = attacker.opponent
        let defenderState = state(for: defender)

        if defenderState.phase == .swaying {
            states[defender]?.counterWindowEndsAt = time + CombatTuning.counterWindow
            return [.swayed(defender: defender)]
        }

        let isCounter = attacker == .player && time <= state(for: attacker).counterWindowEndsAt
        let kind: HitKind = isCounter ? .counter : .normal
        let damage = isCounter ? CombatTuning.counterDamage : CombatTuning.normalDamage
        let remainingHealth = max(0, defenderState.health - damage)
        states[defender]?.health = remainingHealth
        states[attacker]?.counterWindowEndsAt = 0

        var events: [CombatEvent] = [
            .hit(attacker: attacker, defender: defender, kind: kind, damage: damage),
            .healthChanged(defender, remainingHealth)
        ]

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
}
