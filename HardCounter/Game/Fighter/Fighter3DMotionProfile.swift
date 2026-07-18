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
                guardLean: 0,
                kneeBend: 1,
                guardTightness: 1,
                guardClosure: 0,
                leadGuardReach: 0.04,
                guardAsymmetry: 0.03,
                forwardBias: 0,
                stanceDepth: 1,
                breathFrequency: 4.4,
                breathAmplitude: 1,
                idleWeightShift: 0.72,
                guardRhythm: 1,
                footLift: 1,
                strideLength: 1,
                strideCadence: 1,
                footworkBounce: 1,
                hipDrive: 1,
                reach: 1,
                swayRange: 1,
                recoveryWeight: 1,
                signatureAccent: 1.18,
                signatureTechnique: .uppercut
            )
        case .pressure:
            Fighter3DMotionProfile(
                guardHeight: -0.07,
                guardLean: -0.08,
                kneeBend: 1.18,
                guardTightness: 1.18,
                guardClosure: 0.06,
                leadGuardReach: -0.02,
                guardAsymmetry: 0,
                forwardBias: 0.080,
                stanceDepth: 0.76,
                breathFrequency: 3.7,
                breathAmplitude: 0.78,
                idleWeightShift: 0.34,
                guardRhythm: 0.62,
                footLift: 0.74,
                strideLength: 0.70,
                strideCadence: 0.78,
                footworkBounce: 0.48,
                hipDrive: 1.34,
                reach: 0.88,
                swayRange: 0.76,
                recoveryWeight: 1.30,
                signatureAccent: 1.28,
                signatureTechnique: .smash
            )
        case .outBoxer:
            Fighter3DMotionProfile(
                guardHeight: 0.055,
                guardLean: 0.045,
                kneeBend: 0.82,
                guardTightness: 0.96,
                guardClosure: 0.35,
                leadGuardReach: 0.06,
                guardAsymmetry: 0.04,
                forwardBias: -0.065,
                stanceDepth: 1.30,
                breathFrequency: 5.2,
                breathAmplitude: 1.24,
                idleWeightShift: 1.18,
                guardRhythm: 1.36,
                footLift: 1.26,
                strideLength: 1.34,
                strideCadence: 1.28,
                footworkBounce: 1.42,
                hipDrive: 0.80,
                reach: 1.18,
                swayRange: 1.28,
                recoveryWeight: 0.76,
                signatureAccent: 1.18,
                signatureTechnique: .straight
            )
        case .rival:
            Fighter3DMotionProfile(
                guardHeight: -0.025,
                guardLean: -0.05,
                kneeBend: 1.08,
                guardTightness: 1.08,
                guardClosure: 0.04,
                leadGuardReach: 0.01,
                guardAsymmetry: 0.02,
                forwardBias: 0.035,
                stanceDepth: 0.90,
                breathFrequency: 4.0,
                breathAmplitude: 0.88,
                idleWeightShift: 0.52,
                guardRhythm: 0.82,
                footLift: 0.88,
                strideLength: 0.90,
                strideCadence: 0.96,
                footworkBounce: 0.78,
                hipDrive: 1.12,
                reach: 0.98,
                swayRange: 0.92,
                recoveryWeight: 1.12,
                signatureAccent: 1.10,
                signatureTechnique: .smash
            )
        }
    }
}

struct Fighter3DMotionProfile {
    let guardHeight: CGFloat
    let guardLean: CGFloat
    let kneeBend: CGFloat
    let guardTightness: CGFloat
    let guardClosure: CGFloat
    let leadGuardReach: CGFloat
    let guardAsymmetry: CGFloat
    let forwardBias: CGFloat
    let stanceDepth: CGFloat
    let breathFrequency: CGFloat
    let breathAmplitude: CGFloat
    let idleWeightShift: CGFloat
    let guardRhythm: CGFloat
    let footLift: CGFloat
    let strideLength: CGFloat
    let strideCadence: CGFloat
    let footworkBounce: CGFloat
    let hipDrive: CGFloat
    let reach: CGFloat
    let swayRange: CGFloat
    let recoveryWeight: CGFloat
    let signatureAccent: CGFloat
    let signatureTechnique: PunchTechnique
}
