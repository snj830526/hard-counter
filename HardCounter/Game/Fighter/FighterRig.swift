import SpriteKit

final class FighterRig {
    let lineColor: SKColor
    let animationRoot = SKNode()
    let locomotionRoot = SKNode()
    let body = SKNode()
    let pelvisMotionRoot = SKNode()
    let pelvisPoseRoot = SKNode()
    let upperBodyMotionRoot = SKNode()
    let upperBodyPoseRoot = SKNode()
    let frontLegAnchor = SKNode()
    let backLegAnchor = SKNode()
    let frontKneeMotionRoot = SKNode()
    let backKneeMotionRoot = SKNode()
    let frontAnkleMotionRoot = SKNode()
    let backAnkleMotionRoot = SKNode()
    let headAnchor = SKNode()

    let frontUpperArm: SKNode
    let frontLowerArm: SKNode
    let backUpperArm: SKNode
    let backLowerArm: SKNode
    let frontLeg: SKNode
    let backLeg: SKNode
    let frontLowerLeg: SKNode
    let backLowerLeg: SKNode
    let head: SKShapeNode
    private(set) var torso = SKShapeNode()
    private(set) var chestFacet = SKShapeNode()
    private(set) var faceFacet = SKShapeNode()

    init(facing: CGFloat, color: SKColor) {
        lineColor = color
        frontUpperArm = FighterGeometry.makeLimb(length: FighterGeometry.upperArmLength, topWidth: 12, bottomWidth: 9, color: FighterGeometry.skinColor)
        frontLowerArm = FighterGeometry.makeLimb(length: FighterGeometry.lowerArmLength, topWidth: 10, bottomWidth: 8, color: FighterGeometry.skinColor)
        backUpperArm = FighterGeometry.makeLimb(length: FighterGeometry.upperArmLength, topWidth: 11, bottomWidth: 8, color: FighterGeometry.skinColor.withAlphaComponent(0.82))
        backLowerArm = FighterGeometry.makeLimb(length: FighterGeometry.lowerArmLength, topWidth: 9, bottomWidth: 7, color: FighterGeometry.skinColor.withAlphaComponent(0.82))
        frontLeg = FighterGeometry.makeLimb(length: FighterGeometry.upperLegLength, topWidth: 16, bottomWidth: 12, color: FighterGeometry.skinColor)
        backLeg = FighterGeometry.makeLimb(length: FighterGeometry.upperLegLength, topWidth: 15, bottomWidth: 11, color: FighterGeometry.skinColor.withAlphaComponent(0.82))
        frontLowerLeg = FighterGeometry.makeLimb(length: FighterGeometry.lowerLegLength, topWidth: 12, bottomWidth: 9, color: FighterGeometry.skinColor)
        backLowerLeg = FighterGeometry.makeLimb(length: FighterGeometry.lowerLegLength, topWidth: 11, bottomWidth: 8, color: FighterGeometry.skinColor.withAlphaComponent(0.82))
        head = FighterGeometry.makePolygon(
            FighterGeometry.regularPolygon(radius: 15.5, sides: 8, startAngle: .pi / 2)
        )
        build(facing: facing)
    }

    private func build(facing: CGFloat) {
        animationRoot.xScale = facing
        animationRoot.addChild(locomotionRoot)
        locomotionRoot.addChild(body)
        body.addChild(pelvisMotionRoot)
        pelvisMotionRoot.addChild(pelvisPoseRoot)
        body.addChild(upperBodyMotionRoot)
        upperBodyMotionRoot.addChild(upperBodyPoseRoot)

        torso = FighterGeometry.makePolygon([
            CGPoint(x: -12, y: 31), CGPoint(x: 12, y: 31),
            CGPoint(x: 18, y: 67), CGPoint(x: 22, y: 78),
            CGPoint(x: 14, y: 85), CGPoint(x: -17, y: 84),
            CGPoint(x: -22, y: 76), CGPoint(x: -17, y: 65)
        ])
        torso.fillColor = lineColor.withAlphaComponent(0.88)
        torso.strokeColor = .black.withAlphaComponent(0.72)
        torso.lineWidth = 2
        upperBodyPoseRoot.addChild(torso)

        let abdomen = FighterGeometry.makePolygon([
            CGPoint(x: -12, y: 18), CGPoint(x: 12, y: 18),
            CGPoint(x: 11, y: 36), CGPoint(x: -11, y: 36)
        ])
        abdomen.fillColor = lineColor.withAlphaComponent(0.84)
        abdomen.strokeColor = .black.withAlphaComponent(0.58)
        abdomen.lineWidth = 1.5
        abdomen.zPosition = -0.2
        upperBodyPoseRoot.addChild(abdomen)

        chestFacet = FighterGeometry.makePolygon([
            CGPoint(x: -10, y: 36), CGPoint(x: 11, y: 35),
            CGPoint(x: 19, y: 76), CGPoint(x: 4, y: 68), CGPoint(x: 0, y: 51)
        ])
        chestFacet.fillColor = lineColor.withAlphaComponent(0.45)
        chestFacet.strokeColor = .clear
        chestFacet.zPosition = 0.5
        upperBodyPoseRoot.addChild(chestFacet)

        let neck = FighterGeometry.makePolygon([
            CGPoint(x: -6, y: 80), CGPoint(x: 6, y: 80),
            CGPoint(x: 7, y: 98), CGPoint(x: -6, y: 97)
        ])
        neck.fillColor = FighterGeometry.skinColor.withAlphaComponent(0.88)
        neck.strokeColor = .black.withAlphaComponent(0.62)
        neck.lineWidth = 1.5
        neck.zPosition = -0.5
        upperBodyPoseRoot.addChild(neck)

        let shoulderFacet = FighterGeometry.makePolygon([
            CGPoint(x: -20, y: 73), CGPoint(x: 21, y: 72),
            CGPoint(x: 14, y: 85), CGPoint(x: -17, y: 84)
        ])
        shoulderFacet.fillColor = lineColor.withAlphaComponent(0.74)
        shoulderFacet.strokeColor = .clear
        shoulderFacet.zPosition = 0.7
        upperBodyPoseRoot.addChild(shoulderFacet)

        let shorts = FighterGeometry.makePolygon([
            CGPoint(x: -17, y: 20), CGPoint(x: 17, y: 20),
            CGPoint(x: 15, y: 41), CGPoint(x: -15, y: 41)
        ])
        shorts.fillColor = lineColor
        shorts.strokeColor = .black.withAlphaComponent(0.75)
        shorts.lineWidth = 2
        shorts.zPosition = 3
        pelvisPoseRoot.addChild(shorts)

        headAnchor.position = CGPoint(x: 0, y: 108)
        headAnchor.zPosition = 1
        head.position = .zero
        head.fillColor = FighterGeometry.skinColor
        head.strokeColor = .black.withAlphaComponent(0.75)
        head.lineWidth = 2
        headAnchor.addChild(head)
        upperBodyPoseRoot.addChild(headAnchor)

        faceFacet = FighterGeometry.makePolygon([
            CGPoint(x: 1, y: -14), CGPoint(x: 14, y: -3),
            CGPoint(x: 5, y: 13), CGPoint(x: -1, y: 8)
        ])
        faceFacet.fillColor = FighterGeometry.skinColor.withAlphaComponent(0.48)
        faceFacet.strokeColor = .clear
        faceFacet.zPosition = 1
        headAnchor.addChild(faceFacet)

        attachArm(backUpperArm, lower: backLowerArm, z: -2)
        attachArm(frontUpperArm, lower: frontLowerArm, z: 2)
        addGlove(to: backLowerArm, alpha: 0.78)
        addGlove(to: frontLowerArm, alpha: 1)
        attachLeg(backLeg, lower: backLowerLeg, kneeRoot: backKneeMotionRoot, ankleRoot: backAnkleMotionRoot, to: backLegAnchor, x: -6, z: -2)
        attachLeg(frontLeg, lower: frontLowerLeg, kneeRoot: frontKneeMotionRoot, ankleRoot: frontAnkleMotionRoot, to: frontLegAnchor, x: 6, z: 1)
        addShoe(to: backAnkleMotionRoot, alpha: 0.78)
        addShoe(to: frontAnkleMotionRoot, alpha: 1)
    }

    private func attachArm(_ upper: SKNode, lower: SKNode, z: CGFloat) {
        upper.position = CGPoint(x: 0, y: 79)
        upper.zPosition = z
        lower.position = CGPoint(x: 0, y: -FighterGeometry.upperArmLength)
        upper.addChild(lower)
        addJoint(to: upper, at: CGPoint(x: 0, y: -FighterGeometry.upperArmLength), radius: 5, alpha: z < 0 ? 0.82 : 1)
        upperBodyPoseRoot.addChild(upper)
    }

    private func attachLeg(_ leg: SKNode, lower: SKNode, kneeRoot: SKNode, ankleRoot: SKNode, to anchor: SKNode, x: CGFloat, z: CGFloat) {
        anchor.position = CGPoint(x: x, y: 36)
        anchor.zPosition = z
        leg.position = .zero
        kneeRoot.position = CGPoint(x: 0, y: -FighterGeometry.upperLegLength)
        lower.position = .zero
        ankleRoot.position = CGPoint(x: 0, y: -FighterGeometry.lowerLegLength)
        lower.addChild(ankleRoot)
        kneeRoot.addChild(lower)
        leg.addChild(kneeRoot)
        addJoint(to: kneeRoot, at: .zero, radius: 6, alpha: z < 0 ? 0.82 : 1)
        anchor.addChild(leg)
        pelvisPoseRoot.addChild(anchor)
    }

    private func addGlove(to lowerArm: SKNode, alpha: CGFloat) {
        let glove = FighterGeometry.makePolygon(
            FighterGeometry.regularPolygon(radius: 10, sides: 6, startAngle: 0)
        )
        glove.position = CGPoint(x: 0, y: -FighterGeometry.lowerArmLength + 1)
        glove.fillColor = lineColor.withAlphaComponent(alpha)
        glove.strokeColor = .black.withAlphaComponent(0.75)
        glove.lineWidth = 2
        glove.zPosition = 4
        lowerArm.addChild(glove)
    }

    private func addShoe(to ankle: SKNode, alpha: CGFloat) {
        let shoe = FighterGeometry.makePolygon([
            CGPoint(x: -5, y: 2), CGPoint(x: 17, y: -2),
            CGPoint(x: 20, y: 7), CGPoint(x: -5, y: 10)
        ])
        shoe.fillColor = lineColor.withAlphaComponent(alpha)
        shoe.strokeColor = .black.withAlphaComponent(0.75)
        shoe.lineWidth = 2
        ankle.addChild(shoe)
    }

    private func addJoint(to parent: SKNode, at position: CGPoint, radius: CGFloat, alpha: CGFloat) {
        let joint = SKShapeNode(circleOfRadius: radius)
        joint.position = position
        joint.fillColor = FighterGeometry.skinColor.withAlphaComponent(alpha)
        joint.strokeColor = .black.withAlphaComponent(0.58)
        joint.lineWidth = 1.2
        joint.zPosition = 2
        parent.addChild(joint)
    }
}
