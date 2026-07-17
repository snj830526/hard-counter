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
        switch self {
        case .allRounder: 0.78
        case .pressure: 0.96
        case .outBoxer: 0.64
        }
    }

    var staminaPreview: Double {
        switch self {
        case .allRounder: 0.78
        case .pressure: 0.66
        case .outBoxer: 0.92
        }
    }

    var speedPreview: Double {
        switch self {
        case .allRounder: 0.76
        case .pressure: 0.62
        case .outBoxer: 0.96
        }
    }

    var swiftUIColor: Color { Color(uiColor: color) }
}
