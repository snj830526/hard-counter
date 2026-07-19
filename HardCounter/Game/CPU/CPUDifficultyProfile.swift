import Foundation

struct CPUDifficultyProfile {
    let attackInterval: ClosedRange<TimeInterval>
    let movementDecisionInterval: ClosedRange<TimeInterval>
    let defensiveReactionDelay: ClosedRange<TimeInterval>
    let counterReactionDelay: ClosedRange<TimeInterval>
    let punishReactionDelay: ClosedRange<TimeInterval>
    let defenseChance: Double
    let counterChance: Double
    let combinationChance: Double
    let proactiveSwayInterval: ClosedRange<TimeInterval>
    let proactiveSwayChance: Double
    let postExchangeResetDuration: ClosedRange<TimeInterval>
    let pressureBias: Double
    let staminaReserve: Double

    static let challenger = CPUDifficultyProfile(
        attackInterval: 1.02...1.62,
        movementDecisionInterval: 0.24...0.46,
        defensiveReactionDelay: 0.07...0.13,
        counterReactionDelay: 0.08...0.15,
        punishReactionDelay: 0.10...0.18,
        defenseChance: 0.48,
        counterChance: 0.62,
        combinationChance: 0.22,
        proactiveSwayInterval: 1.15...2.00,
        proactiveSwayChance: 0.76,
        postExchangeResetDuration: 0.85...1.35,
        pressureBias: 0.64,
        staminaReserve: 15
    )
}
