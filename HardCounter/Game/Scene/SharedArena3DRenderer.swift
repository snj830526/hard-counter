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
    private var currentCameraScale: CGFloat = 1.92
    private var cameraFocus = SIMD2<Float>.zero

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
        updateCameraWork(
            playerPosition: playerStage,
            opponentPosition: opponentStage,
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
        let baseReach: CGFloat
        let targetHalfWidth: CGFloat
        switch profile.technique {
        case .straight:
            baseReach = 1.16
            targetHalfWidth = 0.34
        case .smash:
            // Technique reach multipliers are applied by CombatScene. These
            // bases keep the final reach just beyond the shared arena's
            // no-overlap distance, including the visually deeper ring axis.
            baseReach = 1.30
            targetHalfWidth = 0.50
        case .uppercut:
            baseReach = 1.34
            targetHalfWidth = 0.42
        }
        let presentationScale = CGFloat(fighterPresentationScale)
        guard CGFloat(forward) >= -0.04 * presentationScale,
              CGFloat(forward) <= baseReach * presentationScale * reachScale,
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
        viewport.viewportSize.height / currentCameraScale
            * CGFloat(ringHalfWidth) / QuarterViewProjection.halfWidth
    }

    private var screenPointsPerWorldPointY: CGFloat {
        viewport.viewportSize.height / currentCameraScale
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

    private func buildRing() {
        let venueFloor = SCNNode(geometry: SCNPlane(width: 18, height: 12))
        venueFloor.geometry?.materials = [material(
            UIColor(red: 0.018, green: 0.025, blue: 0.032, alpha: 1),
            roughness: 0.96,
            metalness: 0.08
        )]
        venueFloor.eulerAngles.x = -.pi / 2
        venueFloor.position.y = -0.24
        scene.rootNode.addChildNode(venueFloor)

        let apron = SCNNode(geometry: SCNBox(
            width: CGFloat(ringHalfWidth * 2 + 0.42),
            height: 0.28,
            length: CGFloat(ringHalfDepth * 2 + 0.42),
            chamferRadius: 0.10
        ))
        apron.geometry?.materials = [material(
            ArenaVisualPalette.gunmetal,
            roughness: 0.84,
            metalness: 0.66
        )]
        apron.position.y = -0.20
        scene.rootNode.addChildNode(apron)

        let matMaterial = material(
            UIColor(red: 0.082, green: 0.094, blue: 0.104, alpha: 1),
            roughness: 0.94,
            metalness: 0.12
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

        let panelColors = [
            UIColor(red: 0.072, green: 0.082, blue: 0.090, alpha: 1),
            UIColor(red: 0.083, green: 0.094, blue: 0.101, alpha: 1)
        ]
        for index in 0..<4 {
            let panel = SCNNode(geometry: SCNBox(
                width: 2.15,
                height: 0.010,
                length: CGFloat(ringHalfDepth * 2 - 0.36),
                chamferRadius: 0.018
            ))
            panel.geometry?.materials = [material(
                panelColors[index % panelColors.count],
                roughness: 0.96,
                metalness: 0.10
            )]
            panel.position = SCNVector3(-3.3 + Float(index) * 2.2, -0.014, 0)
            scene.rootNode.addChildNode(panel)
        }

        let seamMaterial = material(
            UIColor(red: 0.14, green: 0.16, blue: 0.17, alpha: 1),
            roughness: 0.92,
            metalness: 0.18
        )
        // Wide matte deck panels replace the luminous debug grid. Their seams
        // are visible under the fighters without competing with silhouettes.
        for x in stride(from: -2.2 as Float, through: 2.2, by: 2.2) {
            let line = SCNNode(geometry: SCNBox(
                width: 0.018,
                height: 0.009,
                length: CGFloat(ringHalfDepth * 2 - 0.34),
                chamferRadius: 0.004
            ))
            line.geometry?.materials = [seamMaterial]
            line.position = SCNVector3(x, 0.002, 0)
            scene.rootNode.addChildNode(line)
        }
        for z in [-1.28 as Float, 1.28] {
            let line = SCNNode(geometry: SCNBox(
                width: CGFloat(ringHalfWidth * 2 - 0.34),
                height: 0.009,
                length: 0.018,
                chamferRadius: 0.004
            ))
            line.geometry?.materials = [seamMaterial]
            line.position = SCNVector3(0, 0.002, z)
            scene.rootNode.addChildNode(line)
        }

        let markingMaterial = material(
            UIColor(red: 0.018, green: 0.34, blue: 0.40, alpha: 1),
            roughness: 0.76,
            metalness: 0.10,
            emission: UIColor(red: 0.001, green: 0.012, blue: 0.014, alpha: 1)
        )
        for radius in [0.42 as CGFloat, 0.76] {
            let centerMark = SCNNode(geometry: SCNTorus(
                ringRadius: radius,
                pipeRadius: radius == 0.42 ? 0.012 : 0.018
            ))
            centerMark.geometry?.materials = [markingMaterial]
            centerMark.position.y = 0.008
            scene.rootNode.addChildNode(centerMark)
        }

        // A restrained inset safety boundary makes the playable surface read
        // immediately without covering the mat with luminous graph paper.
        let boundaryInset: Float = 0.30
        for z in [-ringHalfDepth + boundaryInset, ringHalfDepth - boundaryInset] {
            let edge = SCNNode(geometry: SCNBox(
                width: CGFloat((ringHalfWidth - boundaryInset) * 2),
                height: 0.010,
                length: 0.020,
                chamferRadius: 0.004
            ))
            edge.geometry?.materials = [markingMaterial]
            edge.position = SCNVector3(0, 0.009, z)
            scene.rootNode.addChildNode(edge)
        }
        for x in [-ringHalfWidth + boundaryInset, ringHalfWidth - boundaryInset] {
            let edge = SCNNode(geometry: SCNBox(
                width: 0.020,
                height: 0.010,
                length: CGFloat((ringHalfDepth - boundaryInset) * 2),
                chamferRadius: 0.004
            ))
            edge.geometry?.materials = [markingMaterial]
            edge.position = SCNVector3(x, 0.009, 0)
            scene.rootNode.addChildNode(edge)
        }

        let rimMaterial = material(
            ArenaVisualPalette.raisedMetal,
            roughness: 0.80,
            metalness: 0.62,
            emission: .black
        )
        for z in [-ringHalfDepth - 0.13, ringHalfDepth + 0.13] {
            let rim = SCNNode(geometry: SCNBox(
                width: CGFloat(ringHalfWidth * 2 + 0.34),
                height: 0.055,
                length: 0.075,
                chamferRadius: 0.018
            ))
            rim.geometry?.materials = [rimMaterial]
            rim.position = SCNVector3(0, -0.015, z)
            scene.rootNode.addChildNode(rim)
        }
        for x in [-ringHalfWidth - 0.13, ringHalfWidth + 0.13] {
            let rim = SCNNode(geometry: SCNBox(
                width: 0.075,
                height: 0.055,
                length: CGFloat(ringHalfDepth * 2 + 0.34),
                chamferRadius: 0.018
            ))
            rim.geometry?.materials = [rimMaterial]
            rim.position = SCNVector3(x, -0.015, 0)
            scene.rootNode.addChildNode(rim)
        }

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
        for (cornerIndex, corner) in corners.enumerated() {
            let cornerSignal = cornerIndex == 0 || cornerIndex == 3
                ? ArenaVisualPalette.cyanSignal : ArenaVisualPalette.amberSignal
            let base = SCNNode(geometry: SCNBox(
                width: 0.42,
                height: 0.18,
                length: 0.42,
                chamferRadius: 0.055
            ))
            base.geometry?.materials = [postMaterial]
            base.position = SCNVector3(corner.x, 0.01, corner.z)
            scene.rootNode.addChildNode(base)

            let post = SCNNode(geometry: SCNBox(
                width: 0.18,
                height: 2.15,
                length: 0.18,
                chamferRadius: 0.035
            ))
            post.geometry?.materials = [postMaterial]
            post.position = SCNVector3(corner.x, 1.02, corner.z)
            scene.rootNode.addChildNode(post)

            let cap = SCNNode(geometry: SCNCylinder(radius: 0.145, height: 0.11))
            cap.geometry?.materials = [postMaterial]
            cap.position = SCNVector3(corner.x, 2.08, corner.z)
            scene.rootNode.addChildNode(cap)

            for height in [0.58 as Float, 1.04, 1.50] {
                let collar = SCNNode(geometry: SCNCylinder(radius: 0.13, height: 0.07))
                collar.geometry?.materials = [material(
                    cornerSignal,
                    roughness: 0.66,
                    metalness: 0.50,
                    emission: cornerSignal.withAlphaComponent(0.045)
                )]
                collar.position = SCNVector3(corner.x, height, corner.z)
                scene.rootNode.addChildNode(collar)
            }

            let pad = SCNNode(geometry: SCNBox(
                width: 0.30,
                height: 0.62,
                length: 0.30,
                chamferRadius: 0.07
            ))
            pad.geometry?.materials = [material(
                ArenaVisualPalette.carbon,
                roughness: 0.90,
                metalness: 0.30,
                emission: cornerSignal.withAlphaComponent(0.018)
            )]
            pad.position = SCNVector3(corner.x, 1.06, corner.z)
            scene.rootNode.addChildNode(pad)
        }

        let ropeColors = [
            UIColor(red: 0.025, green: 0.48, blue: 0.56, alpha: 1),
            UIColor(red: 0.28, green: 0.34, blue: 0.36, alpha: 1),
            UIColor(red: 0.025, green: 0.48, blue: 0.56, alpha: 1)
        ]
        let ropeEmissions = [
            UIColor(red: 0.002, green: 0.038, blue: 0.046, alpha: 1),
            UIColor(red: 0.010, green: 0.013, blue: 0.014, alpha: 1),
            UIColor(red: 0.002, green: 0.038, blue: 0.046, alpha: 1)
        ]
        let ropeHeights: [Float] = [0.58, 1.04, 1.50]
        for (index, height) in ropeHeights.enumerated() {
            let ropeMaterial = material(
                ropeColors[index],
                roughness: 0.68,
                metalness: 0.42,
                emission: ropeEmissions[index]
            )
            for edge in 0..<corners.count {
                let start = SCNVector3(corners[edge].x, height, corners[edge].z)
                let endCorner = corners[(edge + 1) % corners.count]
                let end = SCNVector3(endCorner.x, height, endCorner.z)
                scene.rootNode.addChildNode(cylinder(
                    from: start,
                    to: end,
                    radius: 0.030,
                    material: ropeMaterial
                ))
            }
        }
    }

    private func buildCamera() {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = currentCameraScale
        camera.zNear = 0.1
        camera.zFar = 100
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 5.4, 8.6)
        cameraNode.look(at: SCNVector3(0, 0.85, 0))
        scene.rootNode.addChildNode(cameraNode)
        viewport.pointOfView = cameraNode
    }

    private func updateCameraWork(
        playerPosition: SCNVector3,
        opponentPosition: SCNVector3,
        deltaTime: TimeInterval
    ) {
        let midpoint = SIMD2<Float>(
            (playerPosition.x + opponentPosition.x) * 0.5,
            (playerPosition.z + opponentPosition.z) * 0.5
        )
        // The midpoint is the only pan target. Zoom is solved independently
        // from the horizontal and depth spans so both fighters remain inside
        // frame without making the camera orbit or tilt.
        let desiredFocus = SIMD2<Float>(
            min(max(midpoint.x, -3.45), 3.45),
            min(max(midpoint.y, -1.95), 1.95)
        )
        let horizontalSpan = CGFloat(abs(opponentPosition.x - playerPosition.x))
        let depthSpan = CGFloat(abs(opponentPosition.z - playerPosition.z))
        let aspect = max(viewport.viewportSize.width / max(viewport.viewportSize.height, 1), 1)
        let horizontalFit = (horizontalSpan + 1.18) / aspect
        let depthFit = depthSpan * floorDepthVerticalFactor + 1.58
        let fittedScale = max(closeCameraScale, horizontalFit, depthFit)
        let compressedScale = closeCameraScale
            + (fittedScale - closeCameraScale) * distanceZoomCompression
        let desiredScale = min(max(compressedScale, closeCameraScale), wideCameraScale)

        let focusBlend: Float
        let zoomBlend: CGFloat
        if deltaTime <= 0 {
            focusBlend = 1
            zoomBlend = 1
        } else {
            focusBlend = Float(1 - exp(-deltaTime * 7.0))
            zoomBlend = CGFloat(1 - exp(-deltaTime * 2.8))
        }
        cameraFocus += (desiredFocus - cameraFocus) * focusBlend
        currentCameraScale += (desiredScale - currentCameraScale) * zoomBlend
        cameraNode.camera?.orthographicScale = currentCameraScale
        cameraNode.position = SCNVector3(
            cameraFocus.x,
            5.4,
            8.6 + cameraFocus.y
        )
        cameraNode.look(at: SCNVector3(cameraFocus.x, 0.85, cameraFocus.y))
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
