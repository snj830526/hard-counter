import SceneKit

/// Builds the low-poly presentation meshes independently from the animation
/// rig. Every mesh keeps the existing joint origins so appearance changes do
/// not alter combat motion, hit detection or network state.
enum Fighter3DMeshFactory {
    struct Section {
        let y: CGFloat
        let halfWidth: CGFloat
        let halfDepth: CGFloat
    }

    static func torso(
        proportions: Fighter3DAppearanceProfile,
        material: SCNMaterial
    ) -> SCNNode {
        facetedBody(
            sections: [
                Section(y: 0.03, halfWidth: proportions.torsoWidth * 0.31, halfDepth: proportions.torsoDepth * 0.48),
                Section(y: 0.30, halfWidth: proportions.torsoWidth * 0.36, halfDepth: proportions.torsoDepth * 0.52),
                Section(y: 0.67, halfWidth: max(proportions.torsoWidth * 0.50, proportions.chestWidth * 0.54), halfDepth: proportions.torsoDepth * 0.62),
                Section(y: 0.90, halfWidth: max(proportions.torsoWidth * 0.45, proportions.chestWidth * 0.50), halfDepth: proportions.torsoDepth * 0.52)
            ],
            sides: 8,
            material: material
        )
    }

    static func shorts(
        proportions: Fighter3DAppearanceProfile,
        material: SCNMaterial
    ) -> SCNNode {
        facetedBody(
            sections: [
                Section(y: -proportions.shortsHeight * 0.56, halfWidth: proportions.shortsWidth * 0.47, halfDepth: proportions.shortsDepth * 0.46),
                Section(y: -proportions.shortsHeight * 0.18, halfWidth: proportions.shortsWidth * 0.53, halfDepth: proportions.shortsDepth * 0.52),
                Section(y: proportions.shortsHeight * 0.44, halfWidth: proportions.shortsWidth * 0.47, halfDepth: proportions.shortsDepth * 0.46)
            ],
            sides: 8,
            material: material,
            angleOffset: .pi / 8
        )
    }

    static func head(
        proportions: Fighter3DAppearanceProfile,
        material: SCNMaterial
    ) -> SCNNode {
        let width = proportions.headWidthScale
        let height = proportions.headHeightScale
        let depth = proportions.headDepthScale
        return facetedBody(
            sections: [
                Section(y: -0.25 * height, halfWidth: 0.105 * width, halfDepth: 0.145 * depth),
                Section(y: -0.17 * height, halfWidth: 0.190 * width, halfDepth: 0.205 * depth),
                Section(y: 0.04 * height, halfWidth: 0.235 * width, halfDepth: 0.235 * depth),
                Section(y: 0.19 * height, halfWidth: 0.205 * width, halfDepth: 0.215 * depth),
                Section(y: 0.26 * height, halfWidth: 0.135 * width, halfDepth: 0.155 * depth)
            ],
            sides: 8,
            material: material,
            angleOffset: .pi / 8
        )
    }

    static func upperArm(length: CGFloat, radius: CGFloat, material: SCNMaterial) -> SCNNode {
        facetedBody(
            sections: [
                Section(y: 0, halfWidth: radius, halfDepth: radius * 0.96),
                Section(y: -length * 0.48, halfWidth: radius * 0.90, halfDepth: radius * 0.86),
                Section(y: -length, halfWidth: radius * 0.72, halfDepth: radius * 0.70)
            ],
            sides: 7,
            material: material
        )
    }

    static func forearm(length: CGFloat, radius: CGFloat, material: SCNMaterial) -> SCNNode {
        facetedBody(
            sections: [
                Section(y: 0, halfWidth: radius * 0.78, halfDepth: radius * 0.76),
                Section(y: -length * 0.45, halfWidth: radius, halfDepth: radius * 0.92),
                Section(y: -length, halfWidth: radius * 0.66, halfDepth: radius * 0.64)
            ],
            sides: 7,
            material: material
        )
    }

    static func thigh(length: CGFloat, radius: CGFloat, material: SCNMaterial) -> SCNNode {
        facetedBody(
            sections: [
                Section(y: 0, halfWidth: radius * 1.08, halfDepth: radius),
                Section(y: -length * 0.48, halfWidth: radius * 0.92, halfDepth: radius * 0.88),
                Section(y: -length, halfWidth: radius * 0.70, halfDepth: radius * 0.66)
            ],
            sides: 7,
            material: material
        )
    }

    static func calf(length: CGFloat, radius: CGFloat, material: SCNMaterial) -> SCNNode {
        facetedBody(
            sections: [
                Section(y: 0, halfWidth: radius * 0.72, halfDepth: radius * 0.68),
                Section(y: -length * 0.40, halfWidth: radius, halfDepth: radius * 0.90),
                Section(y: -length, halfWidth: radius * 0.56, halfDepth: radius * 0.54)
            ],
            sides: 7,
            material: material
        )
    }

    static func joint(radius: CGFloat, material: SCNMaterial) -> SCNNode {
        let geometry = SCNSphere(radius: radius)
        geometry.segmentCount = 7
        geometry.materials = [material]
        let result = SCNNode(geometry: geometry)
        result.scale = SCNVector3(1, 0.88, 0.94)
        return result
    }

    static func glove(
        radius: CGFloat,
        widthScale: CGFloat,
        heightScale: CGFloat,
        depthScale: CGFloat,
        side: CGFloat,
        material: SCNMaterial
    ) -> SCNNode {
        let root = SCNNode()
        let palm = facetedBody(
            sections: [
                Section(y: radius * 0.70, halfWidth: radius * 0.62 * widthScale, halfDepth: radius * 0.72 * depthScale),
                Section(y: radius * 0.12, halfWidth: radius * widthScale, halfDepth: radius * depthScale),
                Section(y: -radius * 0.68, halfWidth: radius * 0.72 * widthScale, halfDepth: radius * 0.78 * depthScale)
            ],
            sides: 8,
            material: material,
            angleOffset: .pi / 8
        )
        palm.scale.y = Float(heightScale)
        root.addChildNode(palm)

        let thumb = facetedBody(
            sections: [
                Section(y: radius * 0.26, halfWidth: radius * 0.38, halfDepth: radius * 0.42),
                Section(y: -radius * 0.34, halfWidth: radius * 0.30, halfDepth: radius * 0.34)
            ],
            sides: 6,
            material: material
        )
        thumb.position = SCNVector3(side * radius * 0.72, -radius * 0.10, radius * 0.12)
        thumb.eulerAngles.z = Float(-side * 0.52)
        root.addChildNode(thumb)
        return root
    }

    private static func facetedBody(
        sections: [Section],
        sides: Int,
        material: SCNMaterial,
        angleOffset: CGFloat = 0
    ) -> SCNNode {
        precondition(sections.count >= 2 && sides >= 3)
        let rings = sections.map { section in
            (0..<sides).map { index -> SCNVector3 in
                let angle = angleOffset + CGFloat(index) * 2 * .pi / CGFloat(sides)
                return SCNVector3(
                    cos(angle) * section.halfWidth,
                    section.y,
                    sin(angle) * section.halfDepth
                )
            }
        }

        var vertices: [SCNVector3] = []
        var normals: [SCNVector3] = []
        var indices: [Int32] = []

        func appendTriangle(_ a: SCNVector3, _ b: SCNVector3, _ c: SCNVector3) {
            let normal = normalized(cross(subtract(b, a), subtract(c, a)))
            let base = Int32(vertices.count)
            vertices.append(contentsOf: [a, b, c])
            normals.append(contentsOf: [normal, normal, normal])
            indices.append(contentsOf: [base, base + 1, base + 2])
        }

        for ringIndex in 0..<(rings.count - 1) {
            for sideIndex in 0..<sides {
                let next = (sideIndex + 1) % sides
                let lowerA = rings[ringIndex][sideIndex]
                let lowerB = rings[ringIndex][next]
                let upperA = rings[ringIndex + 1][sideIndex]
                let upperB = rings[ringIndex + 1][next]
                appendTriangle(lowerA, lowerB, upperB)
                appendTriangle(lowerA, upperB, upperA)
            }
        }

        let bottomCenter = SCNVector3(0, sections[0].y, 0)
        let topCenter = SCNVector3(0, sections[sections.count - 1].y, 0)
        for sideIndex in 0..<sides {
            let next = (sideIndex + 1) % sides
            appendTriangle(bottomCenter, rings[0][next], rings[0][sideIndex])
            appendTriangle(topCenter, rings[rings.count - 1][sideIndex], rings[rings.count - 1][next])
        }

        let sources = [
            SCNGeometrySource(vertices: vertices),
            SCNGeometrySource(normals: normals)
        ]
        let element = SCNGeometryElement(indices: indices, primitiveType: .triangles)
        let geometry = SCNGeometry(sources: sources, elements: [element])
        geometry.materials = [material]
        return SCNNode(geometry: geometry)
    }

    private static func subtract(_ lhs: SCNVector3, _ rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(lhs.x - rhs.x, lhs.y - rhs.y, lhs.z - rhs.z)
    }

    private static func cross(_ lhs: SCNVector3, _ rhs: SCNVector3) -> SCNVector3 {
        SCNVector3(
            lhs.y * rhs.z - lhs.z * rhs.y,
            lhs.z * rhs.x - lhs.x * rhs.z,
            lhs.x * rhs.y - lhs.y * rhs.x
        )
    }

    private static func normalized(_ vector: SCNVector3) -> SCNVector3 {
        let length = max(sqrt(vector.x * vector.x + vector.y * vector.y + vector.z * vector.z), 0.0001)
        return SCNVector3(vector.x / length, vector.y / length, vector.z / length)
    }
}
