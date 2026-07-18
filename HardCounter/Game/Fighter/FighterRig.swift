import SpriteKit

final class FighterRig {
    let lineColor: SKColor
    let skinColor: SKColor
    let animationRoot = SKNode()
    let locomotionRoot = SKNode()
    let actionRoot = SKNode()
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

    private let appearance: FighterAppearance

    init(facing: CGFloat, appearance: FighterAppearance) {
        self.appearance = appearance
        lineColor = appearance.kitColor
        skinColor = appearance.skinColor

        let limbScale = appearance.bodyBuild.limbScale
        frontUpperArm = FighterGeometry.makeLimb(
            length: FighterGeometry.upperArmLength,
            topWidth: 12 * limbScale,
            bottomWidth: 9 * limbScale,
            color: appearance.skinColor
        )
        frontLowerArm = FighterGeometry.makeLimb(
            length: FighterGeometry.lowerArmLength,
            topWidth: 10 * limbScale,
            bottomWidth: 8 * limbScale,
            color: appearance.skinColor
        )
        backUpperArm = FighterGeometry.makeLimb(
            length: FighterGeometry.upperArmLength,
            topWidth: 11 * limbScale,
            bottomWidth: 8 * limbScale,
            color: appearance.skinColor.withAlphaComponent(0.82)
        )
        backLowerArm = FighterGeometry.makeLimb(
            length: FighterGeometry.lowerArmLength,
            topWidth: 9 * limbScale,
            bottomWidth: 7 * limbScale,
            color: appearance.skinColor.withAlphaComponent(0.82)
        )
        frontLeg = FighterGeometry.makeLimb(
            length: FighterGeometry.upperLegLength,
            topWidth: 16 * limbScale,
            bottomWidth: 12 * limbScale,
            color: appearance.skinColor
        )
        backLeg = FighterGeometry.makeLimb(
            length: FighterGeometry.upperLegLength,
            topWidth: 15 * limbScale,
            bottomWidth: 11 * limbScale,
            color: appearance.skinColor.withAlphaComponent(0.82)
        )
        frontLowerLeg = FighterGeometry.makeLimb(
            length: FighterGeometry.lowerLegLength,
            topWidth: 12 * limbScale,
            bottomWidth: 9 * limbScale,
            color: appearance.skinColor
        )
        backLowerLeg = FighterGeometry.makeLimb(
            length: FighterGeometry.lowerLegLength,
            topWidth: 11 * limbScale,
            bottomWidth: 8 * limbScale,
            color: appearance.skinColor.withAlphaComponent(0.82)
        )
        head = FighterGeometry.makePolygon([
            CGPoint(x: -12, y: -14), CGPoint(x: 7, y: -15),
            CGPoint(x: 14, y: -8), CGPoint(x: 15, y: 2),
            CGPoint(x: 9, y: 14), CGPoint(x: -6, y: 16),
            CGPoint(x: -14, y: 8), CGPoint(x: -15, y: -5)
        ])
        build(facing: facing)
    }

    private func build(facing: CGFloat) {
        animationRoot.xScale = facing
        animationRoot.addChild(locomotionRoot)
        locomotionRoot.addChild(actionRoot)
        actionRoot.addChild(body)
        body.addChild(pelvisMotionRoot)
        pelvisMotionRoot.addChild(pelvisPoseRoot)
        body.addChild(upperBodyMotionRoot)
        upperBodyMotionRoot.addChild(upperBodyPoseRoot)

        buildTorso()
        buildShorts()
        buildHead()

        attachArm(backUpperArm, lower: backLowerArm, z: -2)
        attachArm(frontUpperArm, lower: frontLowerArm, z: 2)
        addGlove(to: backLowerArm, alpha: 0.78)
        addGlove(to: frontLowerArm, alpha: 1)
        attachLeg(
            backLeg,
            lower: backLowerLeg,
            kneeRoot: backKneeMotionRoot,
            ankleRoot: backAnkleMotionRoot,
            to: backLegAnchor,
            x: -6,
            z: -2
        )
        attachLeg(
            frontLeg,
            lower: frontLowerLeg,
            kneeRoot: frontKneeMotionRoot,
            ankleRoot: frontAnkleMotionRoot,
            to: frontLegAnchor,
            x: 6,
            z: 1
        )
        addShoe(to: backAnkleMotionRoot, alpha: 0.78)
        addShoe(to: frontAnkleMotionRoot, alpha: 1)
    }

    private func buildTorso() {
        let shoulder = appearance.bodyBuild.shoulderScale
        let waist = appearance.bodyBuild.waistScale
        torso = FighterGeometry.makePolygon([
            CGPoint(x: -12 * waist, y: 30), CGPoint(x: 12 * waist, y: 30),
            CGPoint(x: 17 * shoulder, y: 65), CGPoint(x: 23 * shoulder, y: 77),
            CGPoint(x: 15 * shoulder, y: 86), CGPoint(x: -16 * shoulder, y: 85),
            CGPoint(x: -23 * shoulder, y: 77), CGPoint(x: -17 * shoulder, y: 64)
        ])
        torso.fillColor = skinColor.withAlphaComponent(0.96)
        torso.strokeColor = .black.withAlphaComponent(0.76)
        torso.lineWidth = 2
        upperBodyPoseRoot.addChild(torso)

        let abdomen = FighterGeometry.makePolygon([
            CGPoint(x: -12 * waist, y: 20), CGPoint(x: 12 * waist, y: 20),
            CGPoint(x: 13 * waist, y: 37), CGPoint(x: -13 * waist, y: 37)
        ])
        abdomen.fillColor = appearance.skinShadowColor.withAlphaComponent(0.72)
        abdomen.strokeColor = .black.withAlphaComponent(0.48)
        abdomen.lineWidth = 1.2
        abdomen.zPosition = -0.2
        upperBodyPoseRoot.addChild(abdomen)

        chestFacet = FighterGeometry.makePolygon([
            CGPoint(x: -9 * waist, y: 38), CGPoint(x: 10 * waist, y: 37),
            CGPoint(x: 19 * shoulder, y: 76), CGPoint(x: 5, y: 68),
            CGPoint(x: 0, y: 51)
        ])
        chestFacet.fillColor = appearance.skinShadowColor.withAlphaComponent(0.52)
        chestFacet.strokeColor = .clear
        chestFacet.zPosition = 0.5
        upperBodyPoseRoot.addChild(chestFacet)

        let pectoralLine = SKShapeNode()
        let pectoralPath = CGMutablePath()
        pectoralPath.move(to: CGPoint(x: -14 * shoulder, y: 68))
        pectoralPath.addQuadCurve(
            to: CGPoint(x: 14 * shoulder, y: 67),
            control: CGPoint(x: 0, y: 62)
        )
        pectoralLine.path = pectoralPath
        pectoralLine.strokeColor = appearance.skinShadowColor.withAlphaComponent(0.62)
        pectoralLine.lineWidth = 1.3
        pectoralLine.zPosition = 0.8
        upperBodyPoseRoot.addChild(pectoralLine)

        let neck = FighterGeometry.makePolygon([
            CGPoint(x: -6, y: 80), CGPoint(x: 6, y: 80),
            CGPoint(x: 7, y: 99), CGPoint(x: -6, y: 98)
        ])
        neck.fillColor = skinColor.withAlphaComponent(0.92)
        neck.strokeColor = .black.withAlphaComponent(0.62)
        neck.lineWidth = 1.5
        neck.zPosition = -0.5
        upperBodyPoseRoot.addChild(neck)

        let shoulderFacet = FighterGeometry.makePolygon([
            CGPoint(x: -21 * shoulder, y: 73), CGPoint(x: 22 * shoulder, y: 72),
            CGPoint(x: 15 * shoulder, y: 85), CGPoint(x: -16 * shoulder, y: 84)
        ])
        shoulderFacet.fillColor = skinColor.withAlphaComponent(0.72)
        shoulderFacet.strokeColor = .clear
        shoulderFacet.zPosition = 0.7
        upperBodyPoseRoot.addChild(shoulderFacet)
    }

    private func buildShorts() {
        let waist = appearance.bodyBuild.waistScale
        let shorts = FighterGeometry.makePolygon([
            CGPoint(x: -18 * waist, y: 18), CGPoint(x: 18 * waist, y: 18),
            CGPoint(x: 17 * waist, y: 42), CGPoint(x: -16 * waist, y: 42)
        ])
        shorts.fillColor = lineColor
        shorts.strokeColor = .black.withAlphaComponent(0.78)
        shorts.lineWidth = 2
        shorts.zPosition = 3
        pelvisPoseRoot.addChild(shorts)

        let waistband = FighterGeometry.makePolygon([
            CGPoint(x: -17 * waist, y: 37), CGPoint(x: 17 * waist, y: 37),
            CGPoint(x: 17 * waist, y: 44), CGPoint(x: -16 * waist, y: 44)
        ])
        waistband.fillColor = appearance.accentColor
        waistband.strokeColor = .black.withAlphaComponent(0.55)
        waistband.lineWidth = 1
        waistband.zPosition = 4
        pelvisPoseRoot.addChild(waistband)

        let sidePanel = FighterGeometry.makePolygon([
            CGPoint(x: 9 * waist, y: 18), CGPoint(x: 17 * waist, y: 19),
            CGPoint(x: 16 * waist, y: 37), CGPoint(x: 11 * waist, y: 37)
        ])
        sidePanel.fillColor = appearance.accentColor.withAlphaComponent(0.88)
        sidePanel.strokeColor = .clear
        sidePanel.zPosition = 4
        pelvisPoseRoot.addChild(sidePanel)
    }

    private func buildHead() {
        headAnchor.position = CGPoint(x: 0, y: 108)
        headAnchor.zPosition = 1

        let ear = SKShapeNode(circleOfRadius: 4.2)
        ear.position = CGPoint(x: -12, y: 0)
        ear.fillColor = appearance.skinShadowColor
        ear.strokeColor = .black.withAlphaComponent(0.62)
        ear.lineWidth = 1.2
        ear.zPosition = -1
        headAnchor.addChild(ear)

        head.position = .zero
        head.fillColor = skinColor
        head.strokeColor = .black.withAlphaComponent(0.78)
        head.lineWidth = 2
        headAnchor.addChild(head)
        upperBodyPoseRoot.addChild(headAnchor)

        faceFacet = FighterGeometry.makePolygon([
            CGPoint(x: 1, y: -13), CGPoint(x: 13, y: -6),
            CGPoint(x: 13, y: 4), CGPoint(x: 6, y: 13), CGPoint(x: -1, y: 8)
        ])
        faceFacet.fillColor = appearance.skinShadowColor.withAlphaComponent(0.44)
        faceFacet.strokeColor = .clear
        faceFacet.zPosition = 1
        headAnchor.addChild(faceFacet)

        let nose = FighterGeometry.makePolygon([
            CGPoint(x: 10, y: 4), CGPoint(x: 17, y: 0), CGPoint(x: 10, y: -3)
        ])
        nose.fillColor = skinColor
        nose.strokeColor = .black.withAlphaComponent(0.48)
        nose.lineWidth = 1
        nose.zPosition = 2
        faceFacet.addChild(nose)

        let brow = SKShapeNode()
        let browPath = CGMutablePath()
        browPath.move(to: CGPoint(x: 4, y: 5))
        browPath.addLine(to: CGPoint(x: 10, y: 4))
        brow.path = browPath
        brow.strokeColor = appearance.hairColor.withAlphaComponent(0.90)
        brow.lineWidth = 1.6
        brow.zPosition = 3
        faceFacet.addChild(brow)

        let eye = SKShapeNode(circleOfRadius: 1.2)
        eye.position = CGPoint(x: 8, y: 2.5)
        eye.fillColor = .black.withAlphaComponent(0.88)
        eye.strokeColor = .clear
        eye.zPosition = 3
        faceFacet.addChild(eye)

        let mouth = SKShapeNode()
        let mouthPath = CGMutablePath()
        mouthPath.move(to: CGPoint(x: 6, y: -7))
        mouthPath.addLine(to: CGPoint(x: 11, y: -7))
        mouth.path = mouthPath
        mouth.strokeColor = .black.withAlphaComponent(0.62)
        mouth.lineWidth = 1.2
        mouth.zPosition = 3
        faceFacet.addChild(mouth)

        addHair()
    }

    private func addHair() {
        let points: [CGPoint]
        switch appearance.hairStyle {
        case .cropped:
            points = [
                CGPoint(x: -13, y: 6), CGPoint(x: -7, y: 16),
                CGPoint(x: 8, y: 15), CGPoint(x: 12, y: 10),
                CGPoint(x: 4, y: 11), CGPoint(x: -4, y: 10)
            ]
        case .shaved:
            points = [
                CGPoint(x: -11, y: 9), CGPoint(x: -5, y: 15),
                CGPoint(x: 7, y: 14), CGPoint(x: 10, y: 11),
                CGPoint(x: 1, y: 12)
            ]
        case .swept:
            points = [
                CGPoint(x: -13, y: 7), CGPoint(x: -8, y: 17),
                CGPoint(x: 1, y: 20), CGPoint(x: 12, y: 15),
                CGPoint(x: 17, y: 11), CGPoint(x: 6, y: 12),
                CGPoint(x: -3, y: 10)
            ]
        }
        let hair = FighterGeometry.makePolygon(points)
        hair.fillColor = appearance.hairColor
        hair.strokeColor = .black.withAlphaComponent(0.72)
        hair.lineWidth = 1.4
        hair.zPosition = 4
        headAnchor.addChild(hair)
    }

    private func attachArm(_ upper: SKNode, lower: SKNode, z: CGFloat) {
        upper.position = CGPoint(x: 0, y: 79)
        upper.zPosition = z
        lower.position = CGPoint(x: 0, y: -FighterGeometry.upperArmLength)
        upper.addChild(lower)
        addJoint(
            to: upper,
            at: CGPoint(x: 0, y: -FighterGeometry.upperArmLength),
            radius: 5 * appearance.bodyBuild.limbScale,
            alpha: z < 0 ? 0.82 : 1
        )
        upperBodyPoseRoot.addChild(upper)
    }

    private func attachLeg(
        _ leg: SKNode,
        lower: SKNode,
        kneeRoot: SKNode,
        ankleRoot: SKNode,
        to anchor: SKNode,
        x: CGFloat,
        z: CGFloat
    ) {
        anchor.position = CGPoint(x: x, y: 36)
        anchor.zPosition = z
        leg.position = .zero
        kneeRoot.position = CGPoint(x: 0, y: -FighterGeometry.upperLegLength)
        lower.position = .zero
        ankleRoot.position = CGPoint(x: 0, y: -FighterGeometry.lowerLegLength)
        lower.addChild(ankleRoot)
        kneeRoot.addChild(lower)
        leg.addChild(kneeRoot)
        addJoint(
            to: kneeRoot,
            at: .zero,
            radius: 6 * appearance.bodyBuild.limbScale,
            alpha: z < 0 ? 0.82 : 1
        )
        anchor.addChild(leg)
        pelvisPoseRoot.addChild(anchor)
    }

    private func addGlove(to lowerArm: SKNode, alpha: CGFloat) {
        let gloveScale = appearance.bodyBuild == .heavyweight ? 1.08 : 1.0
        let glove = FighterGeometry.makePolygon([
            CGPoint(x: -8 * gloveScale, y: 7), CGPoint(x: 6 * gloveScale, y: 8),
            CGPoint(x: 11 * gloveScale, y: 1), CGPoint(x: 8 * gloveScale, y: -9),
            CGPoint(x: -5 * gloveScale, y: -10), CGPoint(x: -10 * gloveScale, y: -3)
        ])
        glove.position = CGPoint(x: 0, y: -FighterGeometry.lowerArmLength + 1)
        glove.fillColor = lineColor.withAlphaComponent(alpha)
        glove.strokeColor = .black.withAlphaComponent(0.80)
        glove.lineWidth = 2
        glove.zPosition = 4
        lowerArm.addChild(glove)

        let cuff = FighterGeometry.makePolygon([
            CGPoint(x: -6, y: 5), CGPoint(x: 6, y: 5),
            CGPoint(x: 6, y: 12), CGPoint(x: -6, y: 12)
        ])
        cuff.fillColor = appearance.accentColor.withAlphaComponent(alpha)
        cuff.strokeColor = .black.withAlphaComponent(0.55)
        cuff.lineWidth = 1
        cuff.zPosition = 5
        glove.addChild(cuff)
    }

    private func addShoe(to ankle: SKNode, alpha: CGFloat) {
        let boot = FighterGeometry.makePolygon([
            CGPoint(x: -6, y: -3), CGPoint(x: 8, y: -4),
            CGPoint(x: 10, y: 8), CGPoint(x: -5, y: 12)
        ])
        boot.fillColor = appearance.accentColor.withAlphaComponent(alpha)
        boot.strokeColor = .black.withAlphaComponent(0.72)
        boot.lineWidth = 1.4
        ankle.addChild(boot)

        let shoe = FighterGeometry.makePolygon([
            CGPoint(x: -5, y: 0), CGPoint(x: 17, y: -3),
            CGPoint(x: 21, y: 5), CGPoint(x: 16, y: 9), CGPoint(x: -5, y: 9)
        ])
        shoe.fillColor = lineColor.withAlphaComponent(alpha)
        shoe.strokeColor = .black.withAlphaComponent(0.78)
        shoe.lineWidth = 2
        shoe.zPosition = 1
        ankle.addChild(shoe)
    }

    private func addJoint(
        to parent: SKNode,
        at position: CGPoint,
        radius: CGFloat,
        alpha: CGFloat
    ) {
        let joint = SKShapeNode(circleOfRadius: radius)
        joint.position = position
        joint.fillColor = skinColor.withAlphaComponent(alpha)
        joint.strokeColor = .black.withAlphaComponent(0.58)
        joint.lineWidth = 1.2
        joint.zPosition = 2
        parent.addChild(joint)
    }
}
