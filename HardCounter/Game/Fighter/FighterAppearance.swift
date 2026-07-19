import CoreGraphics
import UIKit

enum FighterBodyBuild: Equatable {
    case balanced
    case heavyweight
    case lean

    var shoulderScale: CGFloat {
        switch self {
        case .balanced: 1
        case .heavyweight: 1.15
        case .lean: 0.90
        }
    }

    var limbScale: CGFloat {
        switch self {
        case .balanced: 1
        case .heavyweight: 1.14
        case .lean: 0.88
        }
    }

    var waistScale: CGFloat {
        switch self {
        case .balanced: 1
        case .heavyweight: 1.10
        case .lean: 0.90
        }
    }
}

enum FighterHairStyle: Equatable {
    case cropped
    case shaved
    case swept
}

enum FighterKitStyle: Equatable {
    case classic
    case pressure
    case speed
}

enum FighterFaceStyle: Equatable {
    case focused
    case rugged
    case sharp
    case veteran
}

struct FighterAppearance {
    let skinColor: UIColor
    let skinShadowColor: UIColor
    let kitColor: UIColor
    let accentColor: UIColor
    let hairColor: UIColor
    let bodyBuild: FighterBodyBuild
    let hairStyle: FighterHairStyle
    let kitStyle: FighterKitStyle
    let faceStyle: FighterFaceStyle

    static let cpuRival = FighterAppearance(
        skinColor: UIColor(red: 0.68, green: 0.40, blue: 0.24, alpha: 1),
        skinShadowColor: UIColor(red: 0.39, green: 0.20, blue: 0.13, alpha: 1),
        kitColor: .systemOrange,
        accentColor: UIColor(red: 0.20, green: 0.11, blue: 0.06, alpha: 1),
        hairColor: UIColor(red: 0.10, green: 0.07, blue: 0.05, alpha: 1),
        bodyBuild: .balanced,
        hairStyle: .cropped,
        kitStyle: .classic,
        faceStyle: .veteran
    )
}
