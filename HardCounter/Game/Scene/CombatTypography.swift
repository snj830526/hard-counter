import SpriteKit

enum CombatTypography {
    static let display = "NEXONFootballGothicB"
    static let supporting = "NEXONFootballGothicL"

    static func label(weight: Weight) -> SKLabelNode {
        SKLabelNode(fontNamed: weight == .display ? display : supporting)
    }

    enum Weight {
        case display
        case supporting
    }
}
