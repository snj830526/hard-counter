import SwiftUI
import UIKit

struct FighterBalance: Equatable {
    static let totalBudget = 300
    static let maximumAttribute = 180

    let health: Int
    let stamina: Int
    let speed: Int

    var total: Int { health + stamina + speed }

    var isValid: Bool {
        total == Self.totalBudget
            && [health, stamina, speed].allSatisfy { (0...Self.maximumAttribute).contains($0) }
    }
}

enum FighterProfile: String, CaseIterable, Identifiable {
    case allRounder
    case pressure
    case outBoxer
    case endurance
    case burst
    case tactician

    var id: String { rawValue }

    var name: String {
        switch self {
        case .allRounder: "JIN"
        case .pressure: "MASON"
        case .outBoxer: "LEO"
        case .endurance: "NOVA"
        case .burst: "RYU"
        case .tactician: "SORA"
        }
    }

    var title: String {
        switch self {
        case .allRounder: "COUNTER SPECIALIST"
        case .pressure: "PRESSURE FIGHTER"
        case .outBoxer: "OUT-BOXING SPECIALIST"
        case .endurance: "ENDURANCE SPECIALIST"
        case .burst: "EXPLOSIVE STRIKER"
        case .tactician: "RING TACTICIAN"
        }
    }

    var styleName: String {
        switch self {
        case .allRounder: "ALL-ROUND BOXER"
        case .pressure: "PRESSURE BOXER"
        case .outBoxer: "OUT-BOXER"
        case .endurance: "VOLUME BOXER"
        case .burst: "BURST PUNCHER"
        case .tactician: "SLIP COUNTER"
        }
    }

    var combatTraitName: String {
        switch self {
        case .allRounder: "Counter boost · Efficient uppercut"
        case .pressure: "Heavy smash · High energy cost"
        case .outBoxer: "Fast straight · Extended reach"
        case .endurance: "Low energy cost · Lower burst power"
        case .burst: "Explosive opener · Heavy recovery"
        case .tactician: "Quick counter · Modest raw damage"
        }
    }

    var color: UIColor {
        switch self {
        case .allRounder: .systemCyan
        case .pressure: .systemRed
        case .outBoxer: .systemIndigo
        case .endurance: UIColor(red: 0.12, green: 0.72, blue: 0.46, alpha: 1)
        case .burst: UIColor(red: 0.96, green: 0.48, blue: 0.10, alpha: 1)
        case .tactician: UIColor(red: 0.78, green: 0.24, blue: 0.58, alpha: 1)
        }
    }

    /// Every selectable fighter spends the same 300-point budget.
    var balance: FighterBalance {
        let value: FighterBalance
        switch self {
        case .allRounder: value = FighterBalance(health: 100, stamina: 100, speed: 100)
        case .pressure: value = FighterBalance(health: 130, stamina: 90, speed: 80)
        case .outBoxer: value = FighterBalance(health: 82, stamina: 98, speed: 120)
        case .endurance: value = FighterBalance(health: 92, stamina: 128, speed: 80)
        case .burst: value = FighterBalance(health: 110, stamina: 75, speed: 115)
        case .tactician: value = FighterBalance(health: 86, stamina: 119, speed: 95)
        }
        assert(value.isValid)
        return value
    }

    var healthPreview: Double { Double(balance.health) / Double(FighterBalance.maximumAttribute) }
    var staminaPreview: Double { Double(balance.stamina) / Double(FighterBalance.maximumAttribute) }
    var speedPreview: Double { Double(balance.speed) / Double(FighterBalance.maximumAttribute) }
    var swiftUIColor: Color { Color(uiColor: color) }

    var motionStyle: Fighter3DMotionStyle {
        switch self {
        case .allRounder, .tactician: .allRounder
        case .pressure, .endurance: .pressure
        case .outBoxer, .burst: .outBoxer
        }
    }

    var combatStyle: FighterCombatStyle {
        switch self {
        case .allRounder: .balancedCounter
        case .pressure: .pressure
        case .outBoxer: .outBoxer
        case .endurance: .endurance
        case .burst: .burst
        case .tactician: .tactician
        }
    }

    var appearance: FighterAppearance {
        switch self {
        case .allRounder:
            FighterAppearance(
                skinColor: UIColor(red: 0.82, green: 0.60, blue: 0.42, alpha: 1),
                skinShadowColor: UIColor(red: 0.52, green: 0.32, blue: 0.22, alpha: 1),
                kitColor: color,
                accentColor: UIColor(red: 0.02, green: 0.20, blue: 0.26, alpha: 1),
                hairColor: UIColor(red: 0.08, green: 0.07, blue: 0.07, alpha: 1),
                bodyBuild: .balanced,
                hairStyle: .cropped,
                kitStyle: .classic,
                faceStyle: .focused
            )
        case .pressure:
            FighterAppearance(
                skinColor: UIColor(red: 0.43, green: 0.25, blue: 0.16, alpha: 1),
                skinShadowColor: UIColor(red: 0.22, green: 0.12, blue: 0.08, alpha: 1),
                kitColor: color,
                accentColor: UIColor(red: 0.30, green: 0.02, blue: 0.04, alpha: 1),
                hairColor: UIColor(red: 0.08, green: 0.055, blue: 0.04, alpha: 1),
                bodyBuild: .heavyweight,
                hairStyle: .shaved,
                kitStyle: .pressure,
                faceStyle: .rugged
            )
        case .outBoxer:
            FighterAppearance(
                skinColor: UIColor(red: 0.72, green: 0.47, blue: 0.30, alpha: 1),
                skinShadowColor: UIColor(red: 0.42, green: 0.24, blue: 0.16, alpha: 1),
                kitColor: color,
                accentColor: UIColor(red: 0.12, green: 0.05, blue: 0.32, alpha: 1),
                hairColor: UIColor(red: 0.16, green: 0.09, blue: 0.055, alpha: 1),
                bodyBuild: .lean,
                hairStyle: .swept,
                kitStyle: .speed,
                faceStyle: .sharp
            )
        case .endurance:
            FighterAppearance(
                skinColor: UIColor(red: 0.64, green: 0.42, blue: 0.28, alpha: 1),
                skinShadowColor: UIColor(red: 0.36, green: 0.22, blue: 0.15, alpha: 1),
                kitColor: color,
                accentColor: UIColor(red: 0.03, green: 0.24, blue: 0.15, alpha: 1),
                hairColor: UIColor(red: 0.05, green: 0.045, blue: 0.04, alpha: 1),
                bodyBuild: .balanced,
                hairStyle: .shaved,
                kitStyle: .pressure,
                faceStyle: .veteran
            )
        case .burst:
            FighterAppearance(
                skinColor: UIColor(red: 0.76, green: 0.50, blue: 0.33, alpha: 1),
                skinShadowColor: UIColor(red: 0.44, green: 0.27, blue: 0.17, alpha: 1),
                kitColor: color,
                accentColor: UIColor(red: 0.30, green: 0.12, blue: 0.02, alpha: 1),
                hairColor: UIColor(red: 0.12, green: 0.045, blue: 0.02, alpha: 1),
                bodyBuild: .heavyweight,
                hairStyle: .cropped,
                kitStyle: .speed,
                faceStyle: .rugged
            )
        case .tactician:
            FighterAppearance(
                skinColor: UIColor(red: 0.88, green: 0.66, blue: 0.49, alpha: 1),
                skinShadowColor: UIColor(red: 0.55, green: 0.37, blue: 0.26, alpha: 1),
                kitColor: color,
                accentColor: UIColor(red: 0.24, green: 0.04, blue: 0.17, alpha: 1),
                hairColor: UIColor(red: 0.07, green: 0.045, blue: 0.055, alpha: 1),
                bodyBuild: .lean,
                hairStyle: .swept,
                kitStyle: .classic,
                faceStyle: .focused
            )
        }
    }

    var stats: FighterStats {
        FighterStats(
            maximumHealth: balance.health,
            maximumStamina: Double(balance.stamina) * 0.60,
            movementSpeedMultiplier: CGFloat(balance.speed) / 100
        )
    }
}
