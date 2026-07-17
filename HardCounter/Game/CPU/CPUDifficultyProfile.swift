import Foundation

struct CPUDifficultyProfile {
    let attackInterval: ClosedRange<TimeInterval>
    let movementDecisionInterval: ClosedRange<TimeInterval>
    let defensiveReactionDelay: ClosedRange<TimeInterval>
    let counterReactionDelay: ClosedRange<TimeInterval>
    let defenseChance: Double
    let counterChance: Double
    let combinationChance: Double
    let pressureBias: Double
    let staminaReserve: Double

    static let challenger = CPUDifficultyProfile(
        attackInterval: 1.28...2.02,
        movementDecisionInterval: 0.48...0.86,
        defensiveReactionDelay: 0.04...0.07,
        counterReactionDelay: 0.07...0.12,
        defenseChance: 0.42,
        counterChance: 0.68,
        combinationChance: 0.22,
        pressureBias: 0.58,
        staminaReserve: 11
    )
}
