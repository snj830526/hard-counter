import CoreGraphics

enum FighterTransitionStyle {
    case settle
    case anticipation
    case strike
    case evasive
}

struct FighterPose {
    var bodyX: CGFloat = 0
    var bodyY: CGFloat = 0
    var bodyRotation: CGFloat = 0
    var pelvisRotation: CGFloat = 0
    var frontUpper: CGFloat
    var frontLower: CGFloat
    var backUpper: CGFloat
    var backLower: CGFloat
    var frontLeg: CGFloat
    var backLeg: CGFloat
    var frontKnee: CGFloat = -0.12
    var backKnee: CGFloat = 0.14

    static let guardPose = FighterPose(
        frontUpper: 0.90, frontLower: 2.45,
        backUpper: 0.45, backLower: 2.60,
        frontLeg: 0.18, backLeg: -0.26,
        frontKnee: -0.16, backKnee: 0.18
    )

    static let leadWindUp = FighterPose(
        bodyX: -5, bodyRotation: -0.08, pelvisRotation: -0.025,
        frontUpper: 0.42, frontLower: 2.58,
        backUpper: 0.45, backLower: 2.60,
        frontLeg: 0.22, backLeg: -0.32,
        frontKnee: -0.18, backKnee: 0.20
    )

    static let leadPunch = FighterPose(
        bodyX: 12, bodyRotation: 0.09, pelvisRotation: 0.035,
        frontUpper: 1.48, frontLower: 0.02,
        backUpper: 0.45, backLower: 2.60,
        frontLeg: 0.10, backLeg: -0.36,
        frontKnee: -0.10, backKnee: 0.20
    )

    static let rearWindUp = FighterPose(
        bodyX: -8, bodyRotation: -0.18, pelvisRotation: -0.11,
        frontUpper: 0.90, frontLower: 2.45,
        backUpper: -0.18, backLower: 2.82,
        frontLeg: 0.23, backLeg: -0.36,
        frontKnee: -0.18, backKnee: 0.23
    )

    static let rearPunch = FighterPose(
        bodyX: 16, bodyRotation: 0.16, pelvisRotation: 0.14,
        frontUpper: 0.72, frontLower: 2.58,
        backUpper: 1.52, backLower: 0.04,
        frontLeg: 0.08, backLeg: -0.42,
        frontKnee: -0.10, backKnee: 0.24
    )

    static let swayBack = FighterPose(
        bodyX: -20, bodyRotation: -0.20, pelvisRotation: 0.055,
        frontUpper: 0.82, frontLower: 2.50,
        backUpper: 0.39, backLower: 2.66,
        frontLeg: 0.23, backLeg: -0.34,
        frontKnee: -0.20, backKnee: 0.21
    )

    static let swayLeft = FighterPose(
        bodyX: -12, bodyRotation: 0.24, pelvisRotation: -0.075,
        frontUpper: 0.84, frontLower: 2.50,
        backUpper: 0.40, backLower: 2.64,
        frontLeg: 0.20, backLeg: -0.31,
        frontKnee: -0.22, backKnee: 0.18
    )

    static let swayRight = FighterPose(
        bodyX: 12, bodyRotation: -0.26, pelvisRotation: 0.08,
        frontUpper: 0.82, frontLower: 2.56,
        backUpper: 0.43, backLower: 2.57,
        frontLeg: 0.12, backLeg: -0.28,
        frontKnee: -0.14, backKnee: 0.22
    )

    static let swayForward = FighterPose(
        bodyX: 8, bodyRotation: 0.08, pelvisRotation: 0.045,
        frontUpper: 0.80, frontLower: 2.52,
        backUpper: 0.38, backLower: 2.66,
        frontLeg: 0.12, backLeg: -0.33,
        frontKnee: -0.16, backKnee: 0.20
    )
}

enum FighterPoseResolver {
    static func sway(_ direction: SwayDirection) -> FighterPose {
        switch direction {
        case .left: return .swayLeft
        case .right: return .swayRight
        case .back: return .swayBack
        case .forward: return .swayForward
        }
    }

    static func punch(hand: PunchHand, profile: PunchProfile, isActive: Bool) -> FighterPose {
        var pose: FighterPose
        if hand == .lead {
            pose = isActive ? .leadPunch : .leadWindUp
        } else {
            pose = isActive ? .rearPunch : .rearWindUp
        }

        let power = CGFloat(profile.powerScale)
        let powerMotion = 0.78 + power * 0.24
        pose.bodyX *= powerMotion
        pose.bodyRotation *= 0.80 + power * 0.25
        pose.bodyRotation += CGFloat(profile.lateralDrive) * (isActive ? 0.055 : 0.025)

        switch profile.motion {
        case .quick:
            if hand == .lead {
                pose.bodyRotation *= 0.72
                if isActive {
                    pose.bodyX -= 2
                    pose.frontLeg = 0.14
                    pose.backLeg = -0.30
                    pose.frontKnee = -0.12
                    pose.backKnee = 0.18
                }
            }
        case .retreating:
            pose.bodyRotation *= 0.68
            pose.bodyX -= isActive ? 7 : 3
            pose.frontLeg = 0.24
            pose.backLeg = -0.25
            pose.frontKnee = -0.20
            pose.backKnee = 0.14
            if isActive {
                if hand == .lead {
                    pose.frontLower = 0.11
                } else {
                    pose.backLower = 0.13
                }
            }
        case .driving:
            if isActive {
                pose.bodyX += hand == .lead ? 6 : 10
                pose.bodyRotation *= hand == .lead ? 1.08 : 1.20
                pose.frontLeg = 0.04
                pose.backLeg = -0.48
                pose.frontKnee = -0.08
                pose.backKnee = 0.27
            } else {
                pose.bodyX -= 4
                pose.bodyRotation *= 1.14
                pose.backLeg -= 0.06
            }
        case .counter:
            if isActive {
                pose.bodyX += 13
                pose.bodyRotation *= 1.30
                pose.frontLeg = 0.02
                pose.backLeg = -0.52
                pose.frontKnee = -0.06
                pose.backKnee = 0.30
            } else {
                pose.bodyX -= 7
                pose.bodyRotation *= 1.24
                pose.frontLeg = 0.27
                pose.backLeg = -0.42
            }
        }
        return pose
    }
}
