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
        attackInterval: 0.86...1.54,
        movementDecisionInterval: 0.42...0.76,
        defensiveReactionDelay: 0.08...0.15,
        counterReactionDelay: 0.10...0.18,
        defenseChance: 0.27,
        counterChance: 0.43,
        combinationChance: 0.48,
        pressureBias: 0.66,
        staminaReserve: 13
    )
}
