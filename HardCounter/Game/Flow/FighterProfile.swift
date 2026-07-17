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
        case .allRounder: "THE COUNTER"
        case .pressure: "IRON PRESSURE"
        case .outBoxer: "BLUE FLASH"
        }
    }

    var styleName: String {
        switch self {
        case .allRounder: "밸런스"
        case .pressure: "인파이터"
        case .outBoxer: "아웃복서"
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
                maximumHealth: 118,
                maximumStamina: 52,
                movementSpeedMultiplier: 0.90
            )
        case .outBoxer:
            FighterStats(
                maximumHealth: 88,
                maximumStamina: 72,
                movementSpeedMultiplier: 1.13
            )
        }
    }
}
