import Foundation

/// Deterministic combat identity. Presentation remains in
/// Fighter3DMotionProfile; this type only owns small rule multipliers.
struct FighterCombatStyle {
    enum Archetype {
        case standard
        case balancedCounter
        case pressure
        case outBoxer
        case rival
    }

    let archetype: Archetype

    static let standard = FighterCombatStyle(archetype: .standard)
    static let balancedCounter = FighterCombatStyle(archetype: .balancedCounter)
    static let pressure = FighterCombatStyle(archetype: .pressure)
    static let outBoxer = FighterCombatStyle(archetype: .outBoxer)
    static let rival = FighterCombatStyle(archetype: .rival)

    func modifier(
        for technique: PunchTechnique,
        motion: PunchMotion
    ) -> FighterTechniqueModifier {
        var modifier = FighterTechniqueModifier.standard

        switch archetype {
        case .standard:
            break
        case .balancedCounter:
            if technique == .uppercut {
                modifier.stamina *= 0.92
                modifier.recovery *= 0.96
            }
            if motion == .counter {
                modifier.power *= 1.06
                modifier.startup *= 0.94
                modifier.recovery *= 0.92
            }
        case .pressure:
            if technique == .smash {
                modifier.power *= 1.06
                modifier.reach *= 0.96
                modifier.stamina *= 1.18
                modifier.recovery *= 1.14
            } else if technique == .straight {
                modifier.power *= 0.94
                modifier.startup *= 1.04
            }
        case .outBoxer:
            if technique == .straight {
                modifier.power *= 0.92
                modifier.startup *= 0.88
                modifier.recovery *= 0.90
                modifier.stamina *= 0.92
                modifier.reach *= 1.08
            } else {
                modifier.power *= 0.90
                modifier.recovery *= 1.12
                modifier.stamina *= 1.08
            }
        case .rival:
            if technique == .smash {
                modifier.power *= 1.03
                modifier.recovery *= 1.03
            }
        }
        return modifier
    }
}

struct FighterTechniqueModifier {
    var power: Double
    var startup: Double
    var active: Double
    var recovery: Double
    var stamina: Double
    var reach: Double

    static let standard = FighterTechniqueModifier(
        power: 1,
        startup: 1,
        active: 1,
        recovery: 1,
        stamina: 1,
        reach: 1
    )
}
