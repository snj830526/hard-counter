import SwiftUI
import UIKit

enum FighterProfile: String, CaseIterable, Identifiable {
    case allRounder
    case pressure
    case outBoxer

    var id: String { rawValue }

    var name: String {
        switch self {
        case .allRounder: "JIN"
        case .pressure: "MASON"
        case .outBoxer: "LEO"
        }
    }

    var title: String {
        switch self {
        case .allRounder: "COUNTER UNIT"
        case .pressure: "HYDRAULIC PRESS"
        case .outBoxer: "VELOCITY FRAME"
        }
    }

    var styleName: String {
        switch self {
        case .allRounder: "BALANCED FRAME"
        case .pressure: "HEAVY PRESSURE"
        case .outBoxer: "LIGHTWEIGHT SPEED"
        }
    }

    var combatTraitName: String {
        switch self {
        case .allRounder: "Counter boost · Efficient uppercut"
        case .pressure: "Heavy smash · High energy cost"
        case .outBoxer: "Fast straight · Extended reach"
        }
    }

    var color: UIColor {
        switch self {
        case .allRounder: .systemCyan
        case .pressure: .systemRed
        case .outBoxer: .systemIndigo
        }
    }

    var healthPreview: Double {
        min(Double(stats.maximumHealth) / 125, 1)
    }

    var staminaPreview: Double {
        min(stats.maximumStamina / 75, 1)
    }

    var speedPreview: Double {
        min(Double(stats.movementSpeedMultiplier) / 1.18, 1)
    }

    var swiftUIColor: Color { Color(uiColor: color) }

    var motionStyle: Fighter3DMotionStyle {
        switch self {
        case .allRounder: .allRounder
        case .pressure: .pressure
        case .outBoxer: .outBoxer
        }
    }

    var combatStyle: FighterCombatStyle {
        switch self {
        case .allRounder: .balancedCounter
        case .pressure: .pressure
        case .outBoxer: .outBoxer
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
        }
    }

    var stats: FighterStats {
        switch self {
        case .allRounder:
            FighterStats(
                maximumHealth: 100,
                maximumStamina: 60,
                movementSpeedMultiplier: 1
            )
        case .pressure:
            FighterStats(
                maximumHealth: 106,
                maximumStamina: 50,
                movementSpeedMultiplier: 0.88
            )
        case .outBoxer:
            FighterStats(
                maximumHealth: 92,
                maximumStamina: 68,
                movementSpeedMultiplier: 1.12
            )
        }
    }
}
