import CoreGraphics

/// Presentation identity for a fighter. It is intentionally separate from
/// FighterStats so animation personality never changes combat balance by
/// accident.
enum Fighter3DMotionStyle {
    case allRounder
    case pressure
    case outBoxer
    case rival

    var profile: Fighter3DMotionProfile {
        switch self {
        case .allRounder:
            Fighter3DMotionProfile(
                guardHeight: 0,
                kneeBend: 1,
                guardTightness: 1,
                breathFrequency: 4.4,
                breathAmplitude: 1,
                strideLength: 1,
                strideCadence: 1,
                hipDrive: 1,
                reach: 1,
                swayRange: 1,
                recoveryWeight: 1,
                signatureTechnique: .uppercut
            )
        case .pressure:
            Fighter3DMotionProfile(
                guardHeight: -0.07,
                kneeBend: 1.18,
                guardTightness: 1.18,
                breathFrequency: 3.7,
                breathAmplitude: 0.78,
                strideLength: 0.82,
                strideCadence: 0.90,
                hipDrive: 1.24,
                reach: 0.92,
                swayRange: 0.84,
                recoveryWeight: 1.22,
                signatureTechnique: .smash
            )
        case .outBoxer:
            Fighter3DMotionProfile(
                guardHeight: 0.055,
                kneeBend: 0.82,
                guardTightness: 0.86,
                breathFrequency: 5.2,
                breathAmplitude: 1.24,
                strideLength: 1.22,
                strideCadence: 1.18,
                hipDrive: 0.86,
                reach: 1.14,
                swayRange: 1.18,
                recoveryWeight: 0.82,
                signatureTechnique: .straight
            )
        case .rival:
            Fighter3DMotionProfile(
                guardHeight: -0.025,
                kneeBend: 1.08,
                guardTightness: 1.08,
                breathFrequency: 4.0,
                breathAmplitude: 0.88,
                strideLength: 0.90,
                strideCadence: 0.96,
                hipDrive: 1.12,
                reach: 0.98,
                swayRange: 0.92,
                recoveryWeight: 1.12,
                signatureTechnique: .smash
            )
        }
    }
}

struct Fighter3DMotionProfile {
    let guardHeight: CGFloat
    let kneeBend: CGFloat
    let guardTightness: CGFloat
    let breathFrequency: CGFloat
    let breathAmplitude: CGFloat
    let strideLength: CGFloat
    let strideCadence: CGFloat
    let hipDrive: CGFloat
    let reach: CGFloat
    let swayRange: CGFloat
    let recoveryWeight: CGFloat
    let signatureTechnique: PunchTechnique
}
