import CoreGraphics

enum Fighter3DMotionCurve {
    case linear
    case smooth
    case explosive
    case settle
    case hold

    func transform(_ value: CGFloat) -> CGFloat {
        let t = min(max(value, 0), 1)
        switch self {
        case .linear:
            return t
        case .smooth:
            return t * t * (3 - 2 * t)
        case .explosive:
            return 1 - pow(1 - t, 4)
        case .settle:
            let eased = 1 - pow(1 - t, 3)
            return eased * eased * (3 - 2 * eased)
        case .hold:
            return t >= 1 ? 1 : 0
        }
    }
}

struct Fighter3DMotionKeyframe {
    let position: CGFloat
    let pose: Fighter3DPose
    let arrivalCurve: Fighter3DMotionCurve
}

struct Fighter3DMotionClip {
    let keyframes: [Fighter3DMotionKeyframe]

    func sample(at progress: CGFloat) -> Fighter3DPose {
        guard let first = keyframes.first else { return .guardPose }
        let value = min(max(progress, 0), 1)
        guard value > first.position else { return first.pose }

        for index in 1..<keyframes.count {
            let previous = keyframes[index - 1]
            let next = keyframes[index]
            guard value <= next.position else { continue }
            let duration = max(next.position - previous.position, 0.001)
            let localProgress = (value - previous.position) / duration
            return previous.pose.blended(
                to: next.pose,
                amount: next.arrivalCurve.transform(localProgress)
            )
        }
        return keyframes.last?.pose ?? first.pose
    }
}
