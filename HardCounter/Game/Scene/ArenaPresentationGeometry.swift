import CoreGraphics

/// Owns every conversion between authoritative ring coordinates and the
/// currently active presentation. CombatScene should not branch on 2D/3D when
/// resolving controls, separation, hit range, or effect placement.
struct ArenaPresentationGeometry {
    let quarterProjection: QuarterViewProjection
    let arenaZoom: CGFloat
    let combatArena: CombatArena3DRenderer?

    var usesThreeDArena: Bool { combatArena != nil }
    var fighterSeparationScale: CGFloat { usesThreeDArena ? 2.15 : 1 }

    func worldDirection(forScreenVector vector: CGVector) -> CGVector {
        combatArena?.worldDirection(forScreenVector: vector)
            ?? quarterProjection.worldDirection(forScreenVector: vector)
    }

    func screenDirection(forWorldVector vector: CGVector) -> CGVector {
        combatArena?.screenDirection(forWorldVector: vector)
            ?? quarterProjection.screenVector(forWorldVector: vector)
    }

    func screenVector(forWorldVector vector: CGVector) -> CGVector {
        if let combatArena {
            return combatArena.screenDirection(forWorldVector: vector)
        }
        let projected = quarterProjection.screenVector(forWorldVector: vector)
        return CGVector(dx: projected.dx * arenaZoom, dy: projected.dy * arenaZoom)
    }

    func screenPoint(forWorldPosition position: CGPoint) -> CGPoint {
        combatArena?.screenPoint(forWorldPosition: position)
            ?? quarterProjection.project(position)
    }

    func screenPointsPerWorldPoint(for worldUnit: CGVector) -> CGFloat {
        if let combatArena {
            return combatArena.screenPointsPerWorldPoint(for: worldUnit)
        }
        let projected = quarterProjection.screenVector(forWorldVector: worldUnit)
        return hypot(projected.dx, projected.dy) * arenaZoom
    }

    func threeDMinimumWorldSeparation(along direction: CGVector) -> CGFloat? {
        combatArena?.minimumWorldFighterSeparation(along: direction)
    }

}
