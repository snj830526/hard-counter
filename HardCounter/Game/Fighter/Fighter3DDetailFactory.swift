import SceneKit

/// Adds small appearance details to the stable animation rig. These nodes do
/// not own combat state and can be changed without touching motion playback.
enum Fighter3DDetailFactory {
    static func attachKit(
        _ style: FighterKitStyle,
        proportions: Fighter3DAppearanceProfile,
        palette: Fighter3DMaterialPalette,
        to pelvis: SCNNode
    ) {
        let waistbandHeight: CGFloat = style == .pressure ? 0.12 : 0.085
        let waistband = Fighter3DMeshFactory.box(
            width: proportions.shortsWidth + 0.035,
            height: waistbandHeight,
            length: proportions.shortsDepth + 0.025,
            chamfer: 0.025,
            material: palette.accent
        )
        waistband.position.y = 0.16
        pelvis.addChildNode(waistband)

        switch style {
        case .classic:
            let frontPatch = Fighter3DMeshFactory.box(
                width: 0.13,
                height: 0.16,
                length: 0.025,
                chamfer: 0.01,
                material: palette.accent
            )
            frontPatch.position = SCNVector3(0, -0.06, proportions.shortsDepth / 2 + 0.015)
            pelvis.addChildNode(frontPatch)
        case .pressure:
            for side: CGFloat in [-1, 1] {
                let panel = Fighter3DMeshFactory.box(
                    width: 0.105,
                    height: 0.31,
                    length: 0.025,
                    chamfer: 0.015,
                    material: palette.accent
                )
                panel.position = SCNVector3(
                    side * (proportions.shortsWidth / 2 - 0.07),
                    -0.06,
                    proportions.shortsDepth / 2 + 0.015
                )
                pelvis.addChildNode(panel)
            }
        case .speed:
            for side: CGFloat in [-1, 1] {
                let stripe = Fighter3DMeshFactory.box(
                    width: 0.045,
                    height: 0.30,
                    length: proportions.shortsDepth + 0.02,
                    chamfer: 0.01,
                    material: palette.accent
                )
                stripe.position = SCNVector3(
                    side * (proportions.shortsWidth / 2 + 0.006),
                    -0.04,
                    0
                )
                pelvis.addChildNode(stripe)
            }
        }
    }

    static func attachHair(
        _ style: FighterHairStyle,
        proportions: Fighter3DAppearanceProfile,
        palette: Fighter3DMaterialPalette,
        to head: SCNNode
    ) {
        let hairRoot = SCNNode()
        hairRoot.scale = SCNVector3(
            proportions.headWidthScale,
            proportions.headHeightScale,
            proportions.headDepthScale
        )
        head.addChildNode(hairRoot)

        switch style {
        case .cropped:
            let cap = Fighter3DMeshFactory.sphere(radius: 0.255, material: palette.hair)
            cap.scale = SCNVector3(0.90, 0.40, 0.94)
            cap.position.y = 0.17
            hairRoot.addChildNode(cap)

            let hairline = Fighter3DMeshFactory.box(
                width: 0.34,
                height: 0.08,
                length: 0.07,
                chamfer: 0.025,
                material: palette.hair
            )
            hairline.position = SCNVector3(0, 0.15, 0.215)
            hairRoot.addChildNode(hairline)
        case .shaved:
            let scalp = Fighter3DMeshFactory.sphere(radius: 0.252, material: palette.hair)
            scalp.scale = SCNVector3(0.89, 0.16, 0.92)
            scalp.position.y = 0.22
            hairRoot.addChildNode(scalp)
        case .swept:
            let cap = Fighter3DMeshFactory.sphere(radius: 0.258, material: palette.hair)
            cap.scale = SCNVector3(0.92, 0.46, 0.96)
            cap.position.y = 0.17
            cap.eulerAngles.z = -0.10
            hairRoot.addChildNode(cap)

            let sweep = Fighter3DMeshFactory.box(
                width: 0.29,
                height: 0.11,
                length: 0.10,
                chamfer: 0.035,
                material: palette.hair
            )
            sweep.position = SCNVector3(0.075, 0.20, 0.225)
            sweep.eulerAngles.z = -0.30
            hairRoot.addChildNode(sweep)
        }
    }

    static func attachFace(
        _ style: FighterFaceStyle,
        proportions: Fighter3DAppearanceProfile,
        palette: Fighter3DMaterialPalette,
        to head: SCNNode
    ) {
        for side: CGFloat in [-1, 1] {
            let eye = Fighter3DMeshFactory.sphere(radius: 0.034, material: palette.eyeWhite)
            eye.scale = SCNVector3(1, 0.60, 0.42)
            eye.position = SCNVector3(
                side * 0.075 * proportions.headWidthScale,
                0.035 * proportions.headHeightScale,
                0.230 * proportions.headDepthScale
            )
            head.addChildNode(eye)

            let pupil = Fighter3DMeshFactory.sphere(radius: 0.015, material: palette.hair)
            pupil.scale = SCNVector3(0.72, 0.72, 0.36)
            pupil.position = SCNVector3(
                side * 0.075 * proportions.headWidthScale,
                0.035 * proportions.headHeightScale,
                0.248 * proportions.headDepthScale
            )
            head.addChildNode(pupil)

            let brow = Fighter3DMeshFactory.box(
                width: style == .rugged ? 0.105 : 0.085,
                height: style == .rugged ? 0.030 : 0.022,
                length: 0.022,
                chamfer: 0.008,
                material: palette.hair
            )
            brow.position = SCNVector3(
                side * 0.075 * proportions.headWidthScale,
                0.098 * proportions.headHeightScale,
                0.226 * proportions.headDepthScale
            )
            brow.eulerAngles.z = Float(side * (style == .sharp ? 0.18 : 0.08))
            head.addChildNode(brow)

            let ear = Fighter3DMeshFactory.sphere(radius: 0.042, material: palette.shadowSkin)
            ear.scale = SCNVector3(0.52, 1, 0.62)
            ear.position = SCNVector3(
                side * 0.235 * proportions.headWidthScale,
                -0.015,
                0
            )
            head.addChildNode(ear)
        }

        let nose = Fighter3DMeshFactory.sphere(radius: 0.042, material: palette.skin)
        nose.scale = SCNVector3(0.62, 0.90, 0.72)
        nose.position = SCNVector3(
            0,
            -0.018 * proportions.headHeightScale,
            0.252 * proportions.headDepthScale
        )
        head.addChildNode(nose)

        let mouth = Fighter3DMeshFactory.box(
            width: 0.105,
            height: 0.018,
            length: 0.022,
            chamfer: 0.006,
            material: palette.shadowSkin
        )
        mouth.position = SCNVector3(0, -0.112, 0.225)
        head.addChildNode(mouth)

        switch style {
        case .focused:
            let noseBridge = Fighter3DMeshFactory.box(
                width: 0.030,
                height: 0.085,
                length: 0.025,
                chamfer: 0.008,
                material: palette.shadowSkin
            )
            noseBridge.position = SCNVector3(0, 0.035, 0.235)
            head.addChildNode(noseBridge)
        case .rugged, .veteran:
            let chinGuard = Fighter3DMeshFactory.box(
                width: 0.17,
                height: 0.10,
                length: 0.035,
                chamfer: 0.025,
                material: palette.hair
            )
            chinGuard.position = SCNVector3(0, -0.178, 0.188)
            head.addChildNode(chinGuard)
        case .sharp:
            let cheekMark = Fighter3DMeshFactory.box(
                width: 0.075,
                height: 0.020,
                length: 0.025,
                chamfer: 0.006,
                material: palette.accent
            )
            cheekMark.position = SCNVector3(0.105, -0.070, 0.222)
            cheekMark.eulerAngles.z = -0.32
            head.addChildNode(cheekMark)
        }
    }
}
