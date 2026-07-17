import CoreGraphics

struct FighterStats: Equatable {
    let maximumHealth: Int
    let maximumStamina: Double
    let movementSpeedMultiplier: CGFloat

    static let standard = FighterStats(
        maximumHealth: CombatTuning.maximumHealth,
        maximumStamina: CombatTuning.maximumStamina,
        movementSpeedMultiplier: 1
    )

    var lowStaminaThreshold: Double {
        maximumStamina * CombatTuning.lowStaminaFraction
    }
}
