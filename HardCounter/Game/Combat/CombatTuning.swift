import CoreGraphics
import Foundation

enum CombatTuning {
    static let maximumHealth = 100
    static let maximumStamina: Double = 60
    static let normalDamage = 18
    static let counterDamage = 34

    static let straightStaminaCost: Double = 7
    static let smashStaminaCost: Double = 11
    static let uppercutStaminaCost: Double = 14
    static let swayStaminaCost: Double = 5
    static let counterStaminaRefund: Double = 3
    static let staminaRecoveryPerSecond: Double = 12
    static let staminaRecoveryDelay: TimeInterval = 0.70
    static let exhaustedStaminaRecoveryDelay: TimeInterval = 1.20
    static let lowStaminaFraction: Double = 0.25
    static let minimumExhaustedPerformance: Double = 0.20
    static let minimumExhaustedFootwork: CGFloat = 0.34

    static let punchStartup: TimeInterval = 0.16
    static let punchActive: TimeInterval = 0.07
    static let punchRecovery: TimeInterval = 0.28
    static let swayDuration: TimeInterval = 0.34
    static let swayEntryFraction: CGFloat = 0.22
    static let swayHoldFraction: CGFloat = 0.12
    static let swayEvadeStartup: TimeInterval = 0.05
    static let swayEvadeActiveDuration: TimeInterval = 0.19
    static let counterWindow: TimeInterval = 0.72
    static let punchInputBuffer: TimeInterval = 0.20
    static let swayPunchBufferGrace: TimeInterval = 0.10
    static let swayPunchCancelDelay: TimeInterval = 0.12
    static let swayDirectionInputGrace: TimeInterval = 0.22
    static let hitReaction: TimeInterval = 0.24
    static let counterHitReaction: TimeInterval = 0.48

    static let cpuInitialDelay: TimeInterval = 1.2

    static let hudTopPadding: CGFloat = 20
    static let hudHorizontalPadding: CGFloat = 24

    static let normalKnockback: CGFloat = 18
    static let counterKnockback: CGFloat = 52
    static let normalHitStop: TimeInterval = 0.032
    static let heavyHitStop: TimeInterval = 0.048
    static let cameraShakeDistance: CGFloat = 7
    static let normalCameraShakeDistance: CGFloat = 2.8
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

    static let playerMoveSpeed: CGFloat = 148
    static let playerDepthMoveSpeed: CGFloat = 110
    static let punchStartupFootworkMultiplier: CGFloat = 0.72
    static let punchActiveFootworkMultiplier: CGFloat = 0.48
    static let punchRecoveryFootworkMultiplier: CGFloat = 0.82
    static let swayFootworkMultiplier: CGFloat = 0
    static let movementAcceleration: CGFloat = 12.5
    static let movementTurnAcceleration: CGFloat = 18
    static let movementDeceleration: CGFloat = 14
    static let retreatSpeedMultiplier: CGFloat = 0.82
    static let lateralSpeedMultiplier: CGFloat = 0.90
    static let cpuMoveSpeed: CGFloat = 72
    static let cpuMovementAcceleration: CGFloat = 5.8
    static let cpuMovementTurnAcceleration: CGFloat = 7.2
    static let cpuMovementDeceleration: CGFloat = 7.8
    /// Contact geometry at perspective scale 1. The arm reaches from the
    /// attacker's ring anchor; the target radius belongs to the defender and
    /// must never be multiplied by the attacker's reach bonus.
    static let punchArmReachAtUnitScale: CGFloat = 72
    static let punchTargetRadiusAtUnitScale: CGFloat = 20
    static let retreatingPunchReachScale: CGFloat = 0.92
    static let drivingPunchReachScale: CGFloat = 1.08
    static let counterPunchReachScale: CGFloat = 1.14
    static let smashReachScale: CGFloat = 0.88
    static let uppercutReachScale: CGFloat = 0.78
    static let minimumFighterScreenSeparation: CGFloat = 56
    static let farPerspectiveScale: CGFloat = 0.62
    static let nearPerspectiveScale: CGFloat = 0.82
}
