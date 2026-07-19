import CoreGraphics

/// Owns every conversion between authoritative ring coordinates and the
/// currently active presentation. CombatScene should not branch on 2D/3D when
/// resolving controls, separation, hit range, or effect placement.
struct ArenaPresentationGeometry {
    let quarterProjection: QuarterViewProjection
    let arenaZoom: CGFloat
    let sharedArena: SharedArena3DRenderer?

    var usesSharedArena: Bool { sharedArena != nil }
    var fighterSeparationScale: CGFloat { usesSharedArena ? 2.15 : 1 }

    func worldDirection(forScreenVector vector: CGVector) -> CGVector {
        sharedArena?.worldDirection(forScreenVector: vector)
            ?? quarterProjection.worldDirection(forScreenVector: vector)
    }

    func screenDirection(forWorldVector vector: CGVector) -> CGVector {
        sharedArena?.screenDirection(forWorldVector: vector)
            ?? quarterProjection.screenVector(forWorldVector: vector)
    }

    func screenVector(forWorldVector vector: CGVector) -> CGVector {
        if let sharedArena {
            return sharedArena.screenDirection(forWorldVector: vector)
        }
        let projected = quarterProjection.screenVector(forWorldVector: vector)
        return CGVector(dx: projected.dx * arenaZoom, dy: projected.dy * arenaZoom)
    }

    func screenPoint(forWorldPosition position: CGPoint) -> CGPoint {
        sharedArena?.screenPoint(forWorldPosition: position)
            ?? quarterProjection.project(position)
    }

    func screenPointsPerWorldPoint(for worldUnit: CGVector) -> CGFloat {
        if let sharedArena {
            return sharedArena.screenPointsPerWorldPoint(for: worldUnit)
        }
        let projected = quarterProjection.screenVector(forWorldVector: worldUnit)
        return hypot(projected.dx, projected.dy) * arenaZoom
    }

    func sharedStageDistance(from start: CGPoint, to end: CGPoint) -> CGFloat? {
        sharedArena?.stageDistance(from: start, to: end)
    }

    func sharedBodyContactPoint(at position: CGPoint) -> CGPoint? {
        sharedArena?.bodyContactPoint(forWorldPosition: position)
    }
}
