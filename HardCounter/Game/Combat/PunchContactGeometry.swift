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
        contactPointOnFighter(
            attackerPosition: attackerPosition,
            attackerScale: attackerScale,
            aimDirection: aimDirection,
            defenderPosition: defenderPosition,
            defenderScale: defenderScale,
            profile: profile,
            reachScale: reachScale
        ) != nil
    }

    static func contactPointOnFighter(
        attackerPosition: CGPoint,
        attackerScale: CGFloat,
        aimDirection: CGVector,
        defenderPosition: CGPoint,
        defenderScale: CGFloat,
        profile: PunchProfile,
        reachScale: CGFloat
    ) -> CGPoint? {
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
        let progress = [
            torso.contactProgress(from: start, to: end),
            head.contactProgress(from: start, to: end)
        ].compactMap { $0 }.min()
        guard let progress else { return nil }
        return CGPoint(
            x: start.x + (end.x - start.x) * progress,
            y: start.y + (end.y - start.y) * progress
        )
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

    func contactProgress(from start: CGPoint, to end: CGPoint) -> CGFloat? {
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
        let startDistanceSquared = normalizedStart.x * normalizedStart.x
            + normalizedStart.y * normalizedStart.y
        if startDistanceSquared <= 1 { return 0 }
        guard lengthSquared > 0.0001 else { return nil }

        // Solve the segment/unit-circle intersection and use the first entry
        // point. This keeps the visual impact on the body surface instead of
        // letting it appear near the deepest point of the punch trajectory.
        let projection = normalizedStart.x * delta.dx
            + normalizedStart.y * delta.dy
        let discriminant = projection * projection
            - lengthSquared * (startDistanceSquared - 1)
        guard discriminant >= 0 else { return nil }
        let entryProgress = (-projection - sqrt(discriminant)) / lengthSquared
        guard (0...1).contains(entryProgress) else { return nil }
        return entryProgress
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
