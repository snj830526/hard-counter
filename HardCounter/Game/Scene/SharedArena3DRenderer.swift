import SceneKit
import SpriteKit

/// A presentation-only shared 3D stage used to validate the migration away
/// from separately composited fighter viewports. Gameplay remains authoritative
/// in CombatScene's existing 2D world coordinates.
final class SharedArena3DRenderer {
    let viewport: SK3DNode

    private let scene = SCNScene()
    private let fighterRoot = SCNNode()
    private let cameraNode = SCNNode()
    private let ringHalfWidth: Float = 4.4
    private let ringHalfDepth: Float = 2.55

    init(size: CGSize, player: FighterNode, opponent: FighterNode) {
        viewport = SK3DNode(viewportSize: size)
        viewport.scnScene = scene
        viewport.isPlaying = true
        viewport.loops = true
        viewport.isUserInteractionEnabled = false
        viewport.zPosition = -1
        scene.background.contents = ArenaVisualPalette.void

        scene.rootNode.addChildNode(fighterRoot)
        buildRing()
        buildLights()
        buildCamera()
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
        opponentWorldPosition: CGPoint
    ) {
        player.setThreeDStageTransform(position: stagePosition(playerWorldPosition))
        opponent.setThreeDStageTransform(position: stagePosition(opponentWorldPosition))
    }

    private func stagePosition(_ world: CGPoint) -> SCNVector3 {
        SCNVector3(
            Float(world.x / QuarterViewProjection.halfWidth) * ringHalfWidth,
            0,
            Float(world.y / QuarterViewProjection.halfDepth) * ringHalfDepth
        )
    }

    private func buildRing() {
        let matMaterial = material(
            UIColor(red: 0.075, green: 0.098, blue: 0.115, alpha: 1),
            roughness: 0.88,
            metalness: 0.20
        )
        let mat = SCNNode(geometry: SCNBox(
            width: CGFloat(ringHalfWidth * 2),
            height: 0.12,
            length: CGFloat(ringHalfDepth * 2),
            chamferRadius: 0.08
        ))
        mat.geometry?.materials = [matMaterial]
        mat.position.y = -0.08
        scene.rootNode.addChildNode(mat)

        let postMaterial = material(
            ArenaVisualPalette.gunmetal,
            roughness: 0.82,
            metalness: 0.72
        )
        let corners = [
            SCNVector3(-ringHalfWidth, 0, -ringHalfDepth),
            SCNVector3(ringHalfWidth, 0, -ringHalfDepth),
            SCNVector3(ringHalfWidth, 0, ringHalfDepth),
            SCNVector3(-ringHalfWidth, 0, ringHalfDepth)
        ]
        for corner in corners {
            let post = SCNNode(geometry: SCNBox(
                width: 0.18,
                height: 2.15,
                length: 0.18,
                chamferRadius: 0.035
            ))
            post.geometry?.materials = [postMaterial]
            post.position = SCNVector3(corner.x, 1.02, corner.z)
            scene.rootNode.addChildNode(post)
        }

        let ropeColors = [
            ArenaVisualPalette.cyanSignal,
            ArenaVisualPalette.magentaSignal,
            ArenaVisualPalette.greenSignal
        ]
        let ropeHeights: [Float] = [0.58, 1.04, 1.50]
        for (index, height) in ropeHeights.enumerated() {
            let ropeMaterial = material(
                ropeColors[index],
                roughness: 0.48,
                metalness: 0.35,
                emission: ropeColors[index].withAlphaComponent(0.22)
            )
            for edge in 0..<corners.count {
                let start = SCNVector3(corners[edge].x, height, corners[edge].z)
                let endCorner = corners[(edge + 1) % corners.count]
                let end = SCNVector3(endCorner.x, height, endCorner.z)
                scene.rootNode.addChildNode(cylinder(
                    from: start,
                    to: end,
                    radius: 0.025,
                    material: ropeMaterial
                ))
            }
        }
    }

    private func buildCamera() {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = 4.35
        camera.zNear = 0.1
        camera.zFar = 100
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(6.6, 5.4, 8.6)
        cameraNode.look(at: SCNVector3(0, 0.85, 0))
        scene.rootNode.addChildNode(cameraNode)
        viewport.pointOfView = cameraNode
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

    private func material(
        _ color: UIColor,
        roughness: CGFloat,
        metalness: CGFloat,
        emission: UIColor = .black
    ) -> SCNMaterial {
        let result = SCNMaterial()
        result.lightingModel = .physicallyBased
        result.diffuse.contents = color
        result.roughness.contents = roughness
        result.metalness.contents = metalness
        result.emission.contents = emission
        return result
    }

    private func cylinder(
        from start: SCNVector3,
        to end: SCNVector3,
        radius: CGFloat,
        material: SCNMaterial
    ) -> SCNNode {
        let delta = SCNVector3(end.x - start.x, end.y - start.y, end.z - start.z)
        let length = sqrt(delta.x * delta.x + delta.y * delta.y + delta.z * delta.z)
        let node = SCNNode(geometry: SCNCylinder(radius: radius, height: CGFloat(length)))
        node.geometry?.materials = [material]
        node.position = SCNVector3(
            (start.x + end.x) * 0.5,
            (start.y + end.y) * 0.5,
            (start.z + end.z) * 0.5
        )
        node.simdOrientation = simd_quatf(
            from: SIMD3<Float>(0, 1, 0),
            to: simd_normalize(SIMD3<Float>(delta.x, delta.y, delta.z))
        )
        return node
    }
}
