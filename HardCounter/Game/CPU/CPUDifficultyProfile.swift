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
        attackInterval: 0.62...1.08,
        movementDecisionInterval: 0.30...0.56,
        defensiveReactionDelay: 0.08...0.15,
        counterReactionDelay: 0.10...0.18,
        defenseChance: 0.18,
        counterChance: 0.30,
        combinationChance: 0.62,
        pressureBias: 0.78,
        staminaReserve: 13
    )
}
