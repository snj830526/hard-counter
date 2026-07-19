import SceneKit
import UIKit

/// Owns the SceneKit hierarchy and materials for the shared boxing ring.
final class Arena3DRingNode: SCNNode {
    private let ringHalfWidth: Float
    private let ringHalfDepth: Float

    init(halfWidth: Float, halfDepth: Float) {
        ringHalfWidth = halfWidth
        ringHalfDepth = halfDepth
        super.init()
        buildRing()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { nil }

    private func buildRing() {
        let venueFloor = SCNNode(geometry: SCNPlane(width: 18, height: 12))
        venueFloor.geometry?.materials = [material(
            UIColor(red: 0.018, green: 0.025, blue: 0.032, alpha: 1),
            roughness: 0.96,
            metalness: 0.08
        )]
        venueFloor.eulerAngles.x = -.pi / 2
        venueFloor.position.y = -0.24
        addChildNode(venueFloor)

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
        addChildNode(apron)

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
        addChildNode(mat)

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
            addChildNode(panel)
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
            addChildNode(line)
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
            addChildNode(line)
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
            addChildNode(centerMark)
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
            addChildNode(edge)
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
            addChildNode(edge)
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
            addChildNode(rim)
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
            addChildNode(rim)
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
            addChildNode(base)

            let post = SCNNode(geometry: SCNBox(
                width: 0.18,
                height: 2.15,
                length: 0.18,
                chamferRadius: 0.035
            ))
            post.geometry?.materials = [postMaterial]
            post.position = SCNVector3(corner.x, 1.02, corner.z)
            addChildNode(post)

            let cap = SCNNode(geometry: SCNCylinder(radius: 0.145, height: 0.11))
            cap.geometry?.materials = [postMaterial]
            cap.position = SCNVector3(corner.x, 2.08, corner.z)
            addChildNode(cap)

            for height in [0.58 as Float, 1.04, 1.50] {
                let collar = SCNNode(geometry: SCNCylinder(radius: 0.13, height: 0.07))
                collar.geometry?.materials = [material(
                    cornerSignal,
                    roughness: 0.66,
                    metalness: 0.50,
                    emission: cornerSignal.withAlphaComponent(0.045)
                )]
                collar.position = SCNVector3(corner.x, height, corner.z)
                addChildNode(collar)
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
            addChildNode(pad)
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
                addChildNode(cylinder(
                    from: start,
                    to: end,
                    radius: 0.030,
                    material: ropeMaterial
                ))
            }
        }
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
