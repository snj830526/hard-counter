import CoreGraphics

enum PunchContactGeometry {
    static func intersectsFighter(
        attackerPosition: CGPoint,
        attackerScale: CGFloat,
        aimDirection: CGVector,
        defenderPosition: CGPoint,
        defenderScale: CGFloat,
        profile: PunchProfile,
        reachScale: CGFloat
    ) -> Bool {
        let fallback = CGVector(
            dx: defenderPosition.x - attackerPosition.x,
            dy: defenderPosition.y - attackerPosition.y
        )
        let aim = normalized(aimDirection, fallback: fallback)
        let reach = CombatTuning.punchArmReachAtUnitScale
            * attackerScale
            * reachScale

        let start: CGPoint
        let end: CGPoint
        switch profile.technique {
        case .straight:
            start = CGPoint(x: attackerPosition.x, y: attackerPosition.y + 66 * attackerScale)
            end = start.offset(by: aim, distance: reach)
        case .smash:
            start = CGPoint(x: attackerPosition.x, y: attackerPosition.y + 76 * attackerScale)
            end = start
                .offset(by: aim, distance: reach)
                .translated(dx: 0, dy: -18 * attackerScale)
        case .uppercut:
            start = CGPoint(x: attackerPosition.x, y: attackerPosition.y + 38 * attackerScale)
            end = start
                .offset(by: aim, distance: reach)
                .translated(dx: 0, dy: 48 * attackerScale)
        }

        let targetRadius = CombatTuning.punchTargetRadiusAtUnitScale * defenderScale
        let torso = HitEllipse(
            center: CGPoint(
                x: defenderPosition.x,
                y: defenderPosition.y + 57 * defenderScale
            ),
            radiusX: targetRadius,
            radiusY: targetRadius * 2.0
        )
        let head = HitEllipse(
            center: CGPoint(
                x: defenderPosition.x,
                y: defenderPosition.y + 91 * defenderScale
            ),
            radiusX: targetRadius * 0.92,
            radiusY: targetRadius
        )
        return torso.intersectsSegment(from: start, to: end)
            || head.intersectsSegment(from: start, to: end)
    }

    private static func normalized(_ vector: CGVector, fallback: CGVector) -> CGVector {
        let length = hypot(vector.dx, vector.dy)
        if length > 0.001 {
            return CGVector(dx: vector.dx / length, dy: vector.dy / length)
        }
        let fallbackLength = hypot(fallback.dx, fallback.dy)
        guard fallbackLength > 0.001 else { return CGVector(dx: 1, dy: 0) }
        return CGVector(dx: fallback.dx / fallbackLength, dy: fallback.dy / fallbackLength)
    }
}

private struct HitEllipse {
    let center: CGPoint
    let radiusX: CGFloat
    let radiusY: CGFloat

    func intersectsSegment(from start: CGPoint, to end: CGPoint) -> Bool {
        let normalizedStart = CGPoint(
            x: (start.x - center.x) / max(radiusX, 0.001),
            y: (start.y - center.y) / max(radiusY, 0.001)
        )
        let normalizedEnd = CGPoint(
            x: (end.x - center.x) / max(radiusX, 0.001),
            y: (end.y - center.y) / max(radiusY, 0.001)
        )
        let delta = CGVector(
            dx: normalizedEnd.x - normalizedStart.x,
            dy: normalizedEnd.y - normalizedStart.y
        )
        let lengthSquared = delta.dx * delta.dx + delta.dy * delta.dy
        let closestProgress: CGFloat
        if lengthSquared <= 0.0001 {
            closestProgress = 0
        } else {
            closestProgress = min(max(
                -(normalizedStart.x * delta.dx + normalizedStart.y * delta.dy)
                    / lengthSquared,
                0
            ), 1)
        }
        let closest = CGPoint(
            x: normalizedStart.x + delta.dx * closestProgress,
            y: normalizedStart.y + delta.dy * closestProgress
        )
        return closest.x * closest.x + closest.y * closest.y <= 1
    }
}

private extension CGPoint {
    func offset(by direction: CGVector, distance: CGFloat) -> CGPoint {
        CGPoint(x: x + direction.dx * distance, y: y + direction.dy * distance)
    }

    func translated(dx: CGFloat, dy: CGFloat) -> CGPoint {
        CGPoint(x: x + dx, y: y + dy)
    }
}
