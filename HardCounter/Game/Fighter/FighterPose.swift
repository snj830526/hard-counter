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

    static let leadSmashWindUp = FighterPose(
        bodyX: -7, bodyY: -5, bodyRotation: -0.22, pelvisRotation: -0.14,
        frontUpper: 0.24, frontLower: 2.76,
        backUpper: 0.44, backLower: 2.60,
        frontLeg: 0.27, backLeg: -0.38,
        frontKnee: -0.27, backKnee: 0.29
    )

    static let leadSmash = FighterPose(
        bodyX: 13, bodyY: 7, bodyRotation: 0.36, pelvisRotation: 0.25,
        frontUpper: 1.24, frontLower: 0.52,
        backUpper: 0.52, backLower: 2.54,
        frontLeg: 0.04, backLeg: -0.49,
        frontKnee: -0.06, backKnee: 0.30
    )

    static let rearSmashWindUp = FighterPose(
        bodyX: -10, bodyY: -6, bodyRotation: -0.31, pelvisRotation: -0.20,
        frontUpper: 0.88, frontLower: 2.46,
        backUpper: -0.26, backLower: 2.88,
        frontLeg: 0.29, backLeg: -0.42,
        frontKnee: -0.29, backKnee: 0.32
    )

    static let rearSmash = FighterPose(
        bodyX: 16, bodyY: 9, bodyRotation: 0.44, pelvisRotation: 0.34,
        frontUpper: 0.76, frontLower: 2.56,
        backUpper: 1.20, backLower: 0.58,
        frontLeg: 0.01, backLeg: -0.53,
        frontKnee: -0.04, backKnee: 0.33
    )

    static let leadUppercutWindUp = FighterPose(
        bodyX: -4, bodyY: -5, bodyRotation: -0.10, pelvisRotation: -0.08,
        frontUpper: 0.48, frontLower: 2.76,
        backUpper: 0.43, backLower: 2.62,
        frontLeg: 0.27, backLeg: -0.36,
        frontKnee: -0.28, backKnee: 0.27
    )

    static let leadUppercut = FighterPose(
        bodyX: 7, bodyY: 8, bodyRotation: 0.13, pelvisRotation: 0.12,
        frontUpper: 0.54, frontLower: 2.56,
        backUpper: 0.48, backLower: 2.58,
        frontLeg: 0.05, backLeg: -0.44,
        frontKnee: -0.08, backKnee: 0.28
    )

    static let rearUppercutWindUp = FighterPose(
        bodyX: -6, bodyY: -6, bodyRotation: -0.16, pelvisRotation: -0.13,
        frontUpper: 0.88, frontLower: 2.48,
        backUpper: 0.20, backLower: 2.83,
        frontLeg: 0.28, backLeg: -0.41,
        frontKnee: -0.29, backKnee: 0.30
    )

    static let rearUppercut = FighterPose(
        bodyX: 9, bodyY: 10, bodyRotation: 0.18, pelvisRotation: 0.17,
        frontUpper: 0.78, frontLower: 2.55,
        backUpper: 0.43, backLower: 2.62,
        frontLeg: 0.03, backLeg: -0.49,
        frontKnee: -0.06, backKnee: 0.31
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
    static func sway(
        _ direction: SwayDirection,
        screenDirection: CGVector,
        facing: CGFloat,
        performance: CGFloat
    ) -> FighterPose {
        var pose: FighterPose
        let distance: CGFloat
        switch direction {
        case .left:
            pose = .swayLeft
            distance = 14
        case .right:
            pose = .swayRight
            distance = 14
        case .back:
            pose = .swayBack
            distance = 20
        case .forward:
            pose = .swayForward
            distance = 11
        }

        let localX = screenDirection.dx * facing
        let localY = screenDirection.dy
        let motionScale = 0.56 + min(max(performance, 0), 1) * 0.44
        pose.bodyX = localX * distance * motionScale
        pose.bodyY = localY * distance * 0.78 * motionScale

        let tilt: CGFloat = direction == .back ? 0.20 : 0.15
        // Depth-direction sways are sold mostly by projected translation. A
        // large 2D rotation here made up/down input look like a sideways fall.
        // animationRoot mirrors rotation as well as position. Use the opposite
        // local sign so the final on-screen lean follows the stick instead of
        // appearing to sway against it after facing is applied.
        pose.bodyRotation = (-localX * tilt - localY * 0.038) * motionScale
        pose.pelvisRotation = (localX * tilt * 0.34 + localY * 0.014) * motionScale
        return pose
    }

    static func punch(hand: PunchHand, profile: PunchProfile, isActive: Bool) -> FighterPose {
        var pose: FighterPose
        switch profile.technique {
        case .straight:
            if hand == .lead {
                pose = isActive ? .leadPunch : .leadWindUp
            } else {
                pose = isActive ? .rearPunch : .rearWindUp
            }
        case .smash:
            if hand == .lead {
                pose = isActive ? .leadSmash : .leadSmashWindUp
            } else {
                pose = isActive ? .rearSmash : .rearSmashWindUp
            }
        case .uppercut:
            if hand == .lead {
                pose = isActive ? .leadUppercut : .leadUppercutWindUp
            } else {
                pose = isActive ? .rearUppercut : .rearUppercutWindUp
            }
        }

        let power = CGFloat(profile.powerScale)
        let powerMotion = 0.78 + power * 0.24
        pose.bodyX *= powerMotion
        pose.bodyRotation *= 0.80 + power * 0.25
        pose.bodyRotation += CGFloat(profile.lateralDrive) * (isActive ? 0.055 : 0.025)

        switch profile.motion {
        case .quick:
            if profile.technique == .straight, hand == .lead {
                pose.bodyRotation *= 0.72
                if isActive {
                    pose.bodyX -= 2
                    pose.frontLeg = 0.14
                    pose.backLeg = -0.30
                    pose.frontKnee = -0.12
                    pose.backKnee = 0.18
                }
            } else if profile.technique == .smash, isActive {
                pose.bodyRotation *= 1.10
                pose.bodyY += 3
            } else if profile.technique == .uppercut, isActive {
                pose.bodyY += 3
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
                switch profile.technique {
                case .straight:
                    pose.bodyX += 13
                    pose.bodyRotation *= 1.30
                case .smash:
                    pose.bodyX += 9
                    pose.bodyY += 4
                    pose.bodyRotation *= 1.22
                case .uppercut:
                    pose.bodyX += 5
                    pose.bodyY += 7
                    pose.bodyRotation *= 1.16
                }
                pose.frontLeg = 0.02
                pose.backLeg = -0.52
                pose.frontKnee = -0.06
                pose.backKnee = 0.30
            } else {
                pose.bodyX -= profile.technique == .straight ? 7 : 4
                pose.bodyRotation *= profile.technique == .uppercut ? 1.12 : 1.24
                pose.frontLeg = 0.27
                pose.backLeg = -0.42
            }
        }
        return pose
    }
}
