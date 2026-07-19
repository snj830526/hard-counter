import SceneKit
import SpriteKit

/// Coordinates the 3D combat presentation while gameplay remains authoritative
/// in CombatScene's ring coordinates. Ring construction and camera work are
/// delegated so this type stays focused on fighter transforms and hit geometry.
final class CombatArena3DRenderer {
    let viewport: SK3DNode

    private let scene = SCNScene()
    private let fighterRoot = SCNNode()
    private let ringHalfWidth: Float = 4.4
    private let ringHalfDepth: Float = 2.55
    /// Keep the broadcast lens inside a restrained range. The previous
    /// 1.48...4.0 span made close exchanges feel oversized and long range
    /// movement look as though the arena suddenly receded from the viewer.
    private let wideCameraScale: CGFloat = 3.30
    private let closeCameraScale: CGFloat = 1.72
    private let distanceZoomCompression: CGFloat = 0.72
    /// Keeps fighters at their pre-camera-work screen size while allowing the
    /// ring itself to fill roughly twice as much of the display.
    private let fighterPresentationScale: Float = 1.72 / 3.25
    private let floorDepthVerticalFactor: CGFloat = 0.884
    private lazy var cameraController = Arena3DCameraController(
        initialScale: 1.92,
        closeScale: closeCameraScale,
        wideScale: wideCameraScale,
        distanceZoomCompression: distanceZoomCompression,
        floorDepthVerticalFactor: floorDepthVerticalFactor
    )

    init(size: CGSize, player: FighterNode, opponent: FighterNode) {
        viewport = SK3DNode(viewportSize: size)
        viewport.scnScene = scene
        viewport.isPlaying = true
        viewport.loops = true
        viewport.isUserInteractionEnabled = false
        viewport.zPosition = -1
        scene.background.contents = ArenaVisualPalette.void

        scene.rootNode.addChildNode(fighterRoot)
        let ring = Arena3DRingNode(
            halfWidth: ringHalfWidth,
            halfDepth: ringHalfDepth
        )
        scene.rootNode.addChildNode(ring)
        buildLights()
        cameraController.attach(to: scene, viewport: viewport)
        player.attachThreeDPresentation(to: fighterRoot)
        opponent.attachThreeDPresentation(to: fighterRoot)
    }

    func layout(size: CGSize) {
        viewport.viewportSize = size
        viewport.position = CGPoint(x: size.width * 0.5, y: size.height * 0.5)
    }

    func update(
        player: FighterNode,
        opponent: FighterNode,
        playerWorldPosition: CGPoint,
        opponentWorldPosition: CGPoint,
        deltaTime: TimeInterval
    ) {
        let playerStage = stagePosition(playerWorldPosition)
        let opponentStage = stagePosition(opponentWorldPosition)
        player.setThreeDStageTransform(
            position: playerStage,
            scale: fighterPresentationScale
        )
        opponent.setThreeDStageTransform(
            position: opponentStage,
            scale: fighterPresentationScale
        )
        cameraController.update(
            playerPosition: playerStage,
            opponentPosition: opponentStage,
            viewportSize: viewport.viewportSize,
            deltaTime: deltaTime
        )
    }

    func screenPoint(forWorldPosition world: CGPoint) -> CGPoint {
        let stage = stagePosition(world)
        let projected = viewport.projectPoint(SIMD3<Float>(stage.x, stage.y, stage.z))
        return CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
    }

    func bodyContactPoint(for fighter: FighterNode, technique: PunchTechnique) -> CGPoint {
        project(fighter.threeDBodyWorldPosition(for: technique))
    }

    func damageEffectPoint(for fighter: FighterNode) -> CGPoint {
        project(fighter.threeDDamageWorldPosition())
    }

    func worldDistance(
        forStageDistance targetDistance: CGFloat,
        alongWorldDirection direction: CGVector
    ) -> CGFloat? {
        let stageUnit = CGVector(
            dx: direction.dx / QuarterViewProjection.halfWidth * CGFloat(ringHalfWidth),
            dy: direction.dy / QuarterViewProjection.halfDepth * CGFloat(ringHalfDepth)
        )
        let stageLength = hypot(stageUnit.dx, stageUnit.dy)
        guard stageLength > 0.001 else { return nil }
        return targetDistance / stageLength
    }

    func minimumWorldFighterSeparation(along direction: CGVector) -> CGFloat? {
        worldDistance(
            forStageDistance: CGFloat(fighterPresentationScale),
            alongWorldDirection: direction
        )
    }

    /// Resolves a punch in the same horizontal stage plane that renders both
    /// fighters. A forward/lateral test is used instead of a generous radial
    /// distance so a nearby opponent behind the committed punch cannot be hit.
    func punchContactPoint(
        attackerWorldPosition: CGPoint,
        defenderWorldPosition: CGPoint,
        committedScreenAim: CGVector,
        defender: FighterNode,
        profile: PunchProfile,
        reachScale: CGFloat
    ) -> CGPoint? {
        let attacker = stagePosition(attackerWorldPosition)
        let defenderPosition = stagePosition(defenderWorldPosition)
        let delta = SIMD2<Float>(
            defenderPosition.x - attacker.x,
            defenderPosition.z - attacker.z
        )
        let screenAimLength = hypot(committedScreenAim.dx, committedScreenAim.dy)
        guard simd_length(delta) > 0.001, screenAimLength > 0.001 else { return nil }

        let worldAim = worldDirection(forScreenVector: committedScreenAim)
        var stageAim = SIMD2<Float>(
            Float(worldAim.dx / QuarterViewProjection.halfWidth) * ringHalfWidth,
            Float(worldAim.dy / QuarterViewProjection.halfDepth) * ringHalfDepth
        )
        guard simd_length(stageAim) > 0.001 else { return nil }
        stageAim = simd_normalize(stageAim)

        let forward = simd_dot(delta, stageAim)
        let lateral = abs(delta.x * stageAim.y - delta.y * stageAim.x)
        let armReach: CGFloat
        let targetForwardRadius: CGFloat
        let targetHalfWidth: CGFloat
        switch profile.technique {
        case .straight:
            armReach = 1.16
            targetForwardRadius = 0.22
            targetHalfWidth = 0.34
        case .smash:
            armReach = 1.30
            targetForwardRadius = 0.26
            targetHalfWidth = 0.50
        case .uppercut:
            armReach = 1.34
            targetForwardRadius = 0.24
            targetHalfWidth = 0.42
        }
        let presentationScale = CGFloat(fighterPresentationScale)
        // The fist travels by the scaled arm reach, then meets the near face
        // of the defender's visible body volume. Keeping the target radius
        // outside reachScale prevents a long-reach style from silently making
        // the opponent larger while still accepting surface-level contact.
        let maximumForward = (
            armReach * reachScale + targetForwardRadius
        ) * presentationScale
        guard CGFloat(forward) >= -0.04 * presentationScale,
              CGFloat(forward) <= maximumForward,
              CGFloat(lateral) <= targetHalfWidth * presentationScale else { return nil }
        return bodyContactPoint(for: defender, technique: profile.technique)
    }

    func worldDirection(forScreenVector vector: CGVector) -> CGVector {
        let magnitude = min(hypot(vector.dx, vector.dy), 1)
        guard magnitude > 0.001 else { return .zero }
        let xPoints = screenPointsPerWorldPointX
        let yPoints = screenPointsPerWorldPointY
        let world = CGVector(
            dx: vector.dx / max(xPoints, 0.001),
            dy: -vector.dy / max(yPoints, 0.001)
        )
        let length = hypot(world.dx, world.dy)
        guard length > 0.001 else { return .zero }
        return CGVector(
            dx: world.dx / length * magnitude,
            dy: world.dy / length * magnitude
        )
    }

    func screenDirection(forWorldVector vector: CGVector) -> CGVector {
        let x = vector.dx * screenPointsPerWorldPointX
        let y = -vector.dy * screenPointsPerWorldPointY
        return CGVector(dx: x, dy: y)
    }

    func screenPointsPerWorldPoint(for worldUnit: CGVector) -> CGFloat {
        hypot(
            worldUnit.dx * screenPointsPerWorldPointX,
            worldUnit.dy * screenPointsPerWorldPointY
        )
    }

    private var screenPointsPerWorldPointX: CGFloat {
        viewport.viewportSize.height / cameraController.currentScale
            * CGFloat(ringHalfWidth) / QuarterViewProjection.halfWidth
    }

    private var screenPointsPerWorldPointY: CGFloat {
        viewport.viewportSize.height / cameraController.currentScale
            * CGFloat(ringHalfDepth) / QuarterViewProjection.halfDepth
            * floorDepthVerticalFactor
    }

    private func stagePosition(_ world: CGPoint) -> SCNVector3 {
        SCNVector3(
            Float(world.x / QuarterViewProjection.halfWidth) * ringHalfWidth,
            0,
            Float(world.y / QuarterViewProjection.halfDepth) * ringHalfDepth
        )
    }

    private func project(_ worldPosition: SCNVector3) -> CGPoint {
        let projected = viewport.projectPoint(SIMD3<Float>(
            worldPosition.x,
            worldPosition.y,
            worldPosition.z
        ))
        return CGPoint(x: CGFloat(projected.x), y: CGFloat(projected.y))
    }

    private func buildLights() {
        let key = SCNNode()
        key.light = SCNLight()
        key.light?.type = .omni
        key.light?.intensity = 980
        key.light?.color = ArenaVisualPalette.overheadLight
        key.light?.castsShadow = true
        key.light?.shadowRadius = 7
        key.position = SCNVector3(-3.5, 7.2, 5.4)
        scene.rootNode.addChildNode(key)

        let fill = SCNNode()
        fill.light = SCNLight()
        fill.light?.type = .ambient
        fill.light?.intensity = 360
        fill.light?.color = UIColor(white: 0.55, alpha: 1)
        scene.rootNode.addChildNode(fill)
    }

}
