import CoreGraphics
import Foundation

enum FighterMotionCurve {
    case linear
    case easeIn
    case easeOut
    case smooth
    case snap

    func transform(_ value: CGFloat) -> CGFloat {
        let t = min(max(value, 0), 1)
        switch self {
        case .linear:
            return t
        case .easeIn:
            return t * t * t
        case .easeOut:
            return 1 - pow(1 - t, 3)
        case .smooth:
            return t * t * (3 - 2 * t)
        case .snap:
            return 1 - pow(1 - t, 5)
        }
    }
}

struct FighterMotionFrame {
    var pose: FighterPose
    var rootPosition: CGPoint = .zero
    var rootRotation: CGFloat = 0
    var frontFootOffset: CGPoint = .zero
    var backFootOffset: CGPoint = .zero

    func blended(to other: FighterMotionFrame, amount: CGFloat) -> FighterMotionFrame {
        FighterMotionFrame(
            pose: pose.blended(to: other.pose, amount: amount),
            rootPosition: rootPosition.blended(to: other.rootPosition, amount: amount),
            rootRotation: blendAngle(rootRotation, other.rootRotation, amount: amount),
            frontFootOffset: frontFootOffset.blended(to: other.frontFootOffset, amount: amount),
            backFootOffset: backFootOffset.blended(to: other.backFootOffset, amount: amount)
        )
    }
}

struct FighterMotionKeyframe {
    let time: TimeInterval
    let frame: FighterMotionFrame
    let curve: FighterMotionCurve
}

struct FighterMotionClip {
    let duration: TimeInterval
    let keyframes: [FighterMotionKeyframe]
    let loops: Bool

    func sample(at elapsed: TimeInterval) -> FighterMotionFrame {
        guard let first = keyframes.first else {
            return FighterMotionFrame(pose: .guardPose)
        }
        let sampleTime: TimeInterval
        if loops, duration > 0 {
            sampleTime = elapsed.truncatingRemainder(dividingBy: duration)
        } else {
            sampleTime = min(max(elapsed, 0), duration)
        }
        guard sampleTime > first.time else { return first.frame }

        for index in 1..<keyframes.count {
            let next = keyframes[index]
            guard sampleTime <= next.time else { continue }
            let previous = keyframes[index - 1]
            let segmentDuration = max(next.time - previous.time, 0.0001)
            let rawAmount = CGFloat((sampleTime - previous.time) / segmentDuration)
            return previous.frame.blended(
                to: next.frame,
                amount: next.curve.transform(rawAmount)
            )
        }
        return keyframes.last?.frame ?? first.frame
    }
}

struct FighterMotionClipPlayer {
    private var actionClip: FighterMotionClip?
    private var actionElapsed: TimeInterval = 0
    private var guardElapsed: TimeInterval = 0

    var isPlayingAction: Bool { actionClip != nil }

    mutating func play(_ clip: FighterMotionClip) {
        actionClip = clip
        actionElapsed = 0
    }

    mutating func finishAction() {
        actionClip = nil
        actionElapsed = 0
    }

    mutating func reset() {
        actionClip = nil
        actionElapsed = 0
        guardElapsed = 0
    }

    mutating func update(
        phase: FighterPhase,
        deltaTime: TimeInterval
    ) -> FighterMotionFrame? {
        if let actionClip {
            actionElapsed = min(actionElapsed + deltaTime, actionClip.duration)
            return actionClip.sample(at: actionElapsed)
        }
        guard phase == .idle else { return nil }
        guardElapsed += deltaTime
        return FighterMotionLibrary.guardLoop.sample(at: guardElapsed)
    }
}

enum FighterMotionLibrary {
    static let guardLoop: FighterMotionClip = {
        var inhale = FighterPose.guardPose
        inhale.bodyY = 0.8
        inhale.bodyRotation = 0.008
        inhale.frontUpper -= 0.018
        inhale.backUpper += 0.014

        var settle = FighterPose.guardPose
        settle.bodyY = -0.65
        settle.bodyRotation = -0.006
        settle.frontKnee -= 0.018
        settle.backKnee += 0.016

        return FighterMotionClip(
            duration: 1.24,
            keyframes: [
                FighterMotionKeyframe(
                    time: 0,
                    frame: FighterMotionFrame(pose: .guardPose),
                    curve: .linear
                ),
                FighterMotionKeyframe(
                    time: 0.31,
                    frame: FighterMotionFrame(pose: inhale),
                    curve: .smooth
                ),
                FighterMotionKeyframe(
                    time: 0.62,
                    frame: FighterMotionFrame(pose: .guardPose),
                    curve: .smooth
                ),
                FighterMotionKeyframe(
                    time: 0.93,
                    frame: FighterMotionFrame(pose: settle),
                    curve: .smooth
                ),
                FighterMotionKeyframe(
                    time: 1.24,
                    frame: FighterMotionFrame(pose: .guardPose),
                    curve: .smooth
                )
            ],
            loops: true
        )
    }()

    static func rearStraight(
        guardPose: FighterPose,
        loadPose: FighterPose,
        strikePose: FighterPose,
        startup: TimeInterval,
        active: TimeInterval,
        recovery: TimeInterval
    ) -> FighterMotionClip {
        let contactAt = startup + active * 0.42
        let followThroughAt = startup + active
        let settleAt = followThroughAt + recovery * 0.58
        let duration = startup + active + recovery

        var preloadPose = guardPose.blended(to: loadPose, amount: 0.62)
        preloadPose.bodyY -= 2.2
        preloadPose.frontKnee -= 0.035
        preloadPose.backKnee += 0.055

        var followPose = strikePose
        followPose.bodyX += 3
        followPose.bodyRotation += 0.045
        followPose.pelvisRotation += 0.035

        var settlePose = guardPose.blended(to: strikePose, amount: 0.16)
        settlePose.bodyY -= 1
        settlePose.frontKnee -= 0.02

        return FighterMotionClip(
            duration: duration,
            keyframes: [
                FighterMotionKeyframe(
                    time: 0,
                    frame: FighterMotionFrame(pose: guardPose),
                    curve: .linear
                ),
                FighterMotionKeyframe(
                    time: startup * 0.38,
                    frame: FighterMotionFrame(
                        pose: preloadPose,
                        rootPosition: CGPoint(x: -1.4, y: -0.8),
                        rootRotation: -0.012,
                        frontFootOffset: CGPoint(x: 1.4, y: 0.8),
                        backFootOffset: CGPoint(x: 0.5, y: 0.3)
                    ),
                    curve: .easeIn
                ),
                FighterMotionKeyframe(
                    time: startup,
                    frame: FighterMotionFrame(
                        pose: loadPose,
                        rootPosition: CGPoint(x: -2.2, y: -1.2),
                        rootRotation: -0.020,
                        frontFootOffset: CGPoint(x: 2.2, y: 1.2),
                        backFootOffset: CGPoint(x: 0.7, y: 0.4)
                    ),
                    curve: .smooth
                ),
                FighterMotionKeyframe(
                    time: contactAt,
                    frame: FighterMotionFrame(
                        pose: strikePose,
                        rootPosition: CGPoint(x: 5.8, y: 0.5),
                        rootRotation: 0.018,
                        frontFootOffset: CGPoint(x: -5.8, y: -0.5),
                        backFootOffset: CGPoint(x: -1.5, y: -0.2)
                    ),
                    curve: .snap
                ),
                FighterMotionKeyframe(
                    time: followThroughAt,
                    frame: FighterMotionFrame(
                        pose: followPose,
                        rootPosition: CGPoint(x: 7.2, y: -0.3),
                        rootRotation: 0.026,
                        frontFootOffset: CGPoint(x: -7.2, y: 0.3),
                        backFootOffset: CGPoint(x: -2.4, y: 0.1)
                    ),
                    curve: .easeOut
                ),
                FighterMotionKeyframe(
                    time: settleAt,
                    frame: FighterMotionFrame(
                        pose: settlePose,
                        rootPosition: CGPoint(x: 1.8, y: -0.8),
                        rootRotation: -0.006,
                        frontFootOffset: CGPoint(x: -1.8, y: 0.8),
                        backFootOffset: CGPoint(x: -0.8, y: 0.4)
                    ),
                    curve: .smooth
                ),
                FighterMotionKeyframe(
                    time: duration,
                    frame: FighterMotionFrame(pose: guardPose),
                    curve: .smooth
                )
            ],
            loops: false
        )
    }

    static func straightHit(
        from startPose: FighterPose,
        kind: HitKind,
        profile: PunchProfile
    ) -> FighterMotionClip {
        let duration = kind == .counter
            ? CombatTuning.counterHitReactionAnimationDuration
            : CombatTuning.hitReaction
        let distance = (kind == .counter
            ? CombatTuning.counterKnockback
            : CombatTuning.normalKnockback)
            * CGFloat(0.78 + min(max(profile.powerScale, 0.65), 1.30) * 0.22)

        var recoilPose = FighterPose.guardPose
        recoilPose.bodyX = -11
        recoilPose.bodyY = 1.5
        recoilPose.bodyRotation = -0.20
        recoilPose.pelvisRotation = -0.055
        recoilPose.frontUpper = 0.72
        recoilPose.backUpper = 0.26
        recoilPose.frontKnee = -0.25
        recoilPose.backKnee = 0.27

        var catchPose = FighterPose.guardPose
        catchPose.bodyX = 2
        catchPose.bodyY = -2
        catchPose.bodyRotation = 0.035
        catchPose.frontKnee = -0.22
        catchPose.backKnee = 0.24

        return FighterMotionClip(
            duration: duration,
            keyframes: [
                FighterMotionKeyframe(
                    time: 0,
                    frame: FighterMotionFrame(pose: startPose),
                    curve: .linear
                ),
                FighterMotionKeyframe(
                    time: duration * 0.18,
                    frame: FighterMotionFrame(
                        pose: recoilPose,
                        rootPosition: CGPoint(x: -distance, y: 1),
                        rootRotation: -0.11,
                        frontFootOffset: CGPoint(x: distance, y: -1),
                        backFootOffset: CGPoint(x: distance * 0.72, y: -0.5)
                    ),
                    curve: .snap
                ),
                FighterMotionKeyframe(
                    time: duration * 0.46,
                    frame: FighterMotionFrame(
                        pose: catchPose,
                        rootPosition: CGPoint(x: distance * 0.08, y: -1.5),
                        rootRotation: 0.018,
                        frontFootOffset: CGPoint(x: -distance * 0.08, y: 1.5),
                        backFootOffset: CGPoint(x: -distance * 0.04, y: 0.7)
                    ),
                    curve: .easeOut
                ),
                FighterMotionKeyframe(
                    time: duration,
                    frame: FighterMotionFrame(pose: .guardPose),
                    curve: .smooth
                )
            ],
            loops: false
        )
    }
}

private extension FighterPose {
    func blended(to other: FighterPose, amount: CGFloat) -> FighterPose {
        FighterPose(
            bodyX: mix(bodyX, other.bodyX, amount),
            bodyY: mix(bodyY, other.bodyY, amount),
            bodyRotation: blendAngle(bodyRotation, other.bodyRotation, amount: amount),
            pelvisRotation: blendAngle(pelvisRotation, other.pelvisRotation, amount: amount),
            frontUpper: blendAngle(frontUpper, other.frontUpper, amount: amount),
            frontLower: blendAngle(frontLower, other.frontLower, amount: amount),
            backUpper: blendAngle(backUpper, other.backUpper, amount: amount),
            backLower: blendAngle(backLower, other.backLower, amount: amount),
            frontLeg: blendAngle(frontLeg, other.frontLeg, amount: amount),
            backLeg: blendAngle(backLeg, other.backLeg, amount: amount),
            frontKnee: blendAngle(frontKnee, other.frontKnee, amount: amount),
            backKnee: blendAngle(backKnee, other.backKnee, amount: amount)
        )
    }
}

private extension CGPoint {
    func blended(to other: CGPoint, amount: CGFloat) -> CGPoint {
        CGPoint(
            x: mix(x, other.x, amount),
            y: mix(y, other.y, amount)
        )
    }
}

private func mix(_ from: CGFloat, _ to: CGFloat, _ amount: CGFloat) -> CGFloat {
    from + (to - from) * amount
}

private func blendAngle(_ from: CGFloat, _ to: CGFloat, amount: CGFloat) -> CGFloat {
    from + atan2(sin(to - from), cos(to - from)) * amount
}
