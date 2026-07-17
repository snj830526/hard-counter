import CoreGraphics
import Foundation

enum CombatTuning {
    static let maximumHealth = 100
    static let normalDamage = 18
    static let counterDamage = 34

    static let punchStartup: TimeInterval = 0.28
    static let punchActive: TimeInterval = 0.10
    static let punchRecovery: TimeInterval = 0.42
    static let swayDuration: TimeInterval = 0.42
    static let counterWindow: TimeInterval = 0.72
    static let punchInputBuffer: TimeInterval = 0.20
    static let hitReaction: TimeInterval = 0.24
    static let counterHitReaction: TimeInterval = 0.48

    static let cpuInitialDelay: TimeInterval = 1.2
    static let cpuAttackInterval: ClosedRange<TimeInterval> = 1.35...2.15

    static let hudTopPadding: CGFloat = 20
    static let hudHorizontalPadding: CGFloat = 24

    static let normalKnockback: CGFloat = 18
    static let counterKnockback: CGFloat = 52
    static let cameraShakeDistance: CGFloat = 7
    static let cameraShakeDuration: TimeInterval = 0.20
    static let counterHitStop: TimeInterval = 0.075

    static let idleMotionHalfCycle: TimeInterval = 0.62
    static let idleReturnDuration: TimeInterval = 0.16
    static let knockoutDuration: TimeInterval = 0.52
    static let poseResetDuration: TimeInterval = 0.01
    static let healthBarAnimationDuration: TimeInterval = 0.18
    static let impactAnimationDuration: TimeInterval = 0.16
    static let statusFadeDuration: TimeInterval = 0.15
    static let counterReadyDuration: TimeInterval = 0.55
    static let counterTitleInDuration: TimeInterval = 0.12
    static let counterTitleHoldDuration: TimeInterval = 0.35
    static let counterTitleOutDuration: TimeInterval = 0.20

    static let playerMoveSpeed: CGFloat = 155
    static let playerDepthMoveSpeed: CGFloat = 112
    static let punchStartupFootworkMultiplier: CGFloat = 0.72
    static let punchActiveFootworkMultiplier: CGFloat = 0.48
    static let punchRecoveryFootworkMultiplier: CGFloat = 0.82
    static let swayFootworkMultiplier: CGFloat = 0.28
    static let movementAcceleration: CGFloat = 8.5
    static let movementTurnAcceleration: CGFloat = 13.5
    static let movementDeceleration: CGFloat = 11
    static let retreatSpeedMultiplier: CGFloat = 0.82
    static let lateralSpeedMultiplier: CGFloat = 0.90
    static let cpuMoveSpeed: CGFloat = 78
    static let cpuMovementDecisionInterval: ClosedRange<TimeInterval> = 0.55...1.05
    static let punchReachAtUnitScale: CGFloat = 112
    static let minimumFighterSeparation: CGFloat = 58
    static let ringNearInset: CGFloat = 48
    static let ringFarInsetRatio: CGFloat = 0.17
    static let ringNearYRatio: CGFloat = 0.25
    static let ringFarYRatio: CGFloat = 0.61
    static let farPerspectiveScale: CGFloat = 0.62
    static let nearPerspectiveScale: CGFloat = 0.82
}
