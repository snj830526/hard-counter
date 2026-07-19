import Foundation

struct CPUDifficultyProfile {
    let attackInterval: ClosedRange<TimeInterval>
    let movementDecisionInterval: ClosedRange<TimeInterval>
    let defensiveReactionDelay: ClosedRange<TimeInterval>
    let counterReactionDelay: ClosedRange<TimeInterval>
    let defenseChance: Double
    let counterChance: Double
    let combinationChance: Double
    let proactiveSwayInterval: ClosedRange<TimeInterval>
    let proactiveSwayChance: Double
    let postExchangeResetDuration: ClosedRange<TimeInterval>
    let pressureBias: Double
    let staminaReserve: Double

    static let challenger = CPUDifficultyProfile(
        attackInterval: 1.18...2.00,
        movementDecisionInterval: 0.34...0.64,
        defensiveReactionDelay: 0.08...0.15,
        counterReactionDelay: 0.10...0.18,
        defenseChance: 0.34,
        counterChance: 0.44,
        combinationChance: 0.16,
        proactiveSwayInterval: 1.25...2.35,
        proactiveSwayChance: 0.72,
        postExchangeResetDuration: 1.05...1.70,
        pressureBias: 0.56,
        staminaReserve: 13
    )
}
