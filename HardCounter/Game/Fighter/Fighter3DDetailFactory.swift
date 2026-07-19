import SceneKit

/// Adds armour, actuators and sensors to the stable animation rig. These nodes
/// do not own combat state and can be changed without touching motion playback.
enum Fighter3DDetailFactory {
    static func attachHipArmor(
        _ style: FighterKitStyle,
        proportions: Fighter3DAppearanceProfile,
        palette: Fighter3DMaterialPalette,
        to pelvis: SCNNode
    ) {
        let waistBearing = Fighter3DMeshFactory.cylinder(
            radius: proportions.shortsWidth * 0.36,
            height: style == .pressure ? 0.14 : 0.10,
            material: palette.shadowSkin
        )
        waistBearing.eulerAngles.x = .pi / 2
        waistBearing.position = SCNVector3(0, 0.19, 0)
        pelvis.addChildNode(waistBearing)

        let beltArmor = Fighter3DMeshFactory.box(
            width: proportions.shortsWidth + 0.045,
            height: style == .pressure ? 0.14 : 0.10,
            length: proportions.shortsDepth + 0.035,
            chamfer: 0.025,
            material: palette.accent
        )
        beltArmor.position.y = 0.14
        pelvis.addChildNode(beltArmor)

        switch style {
        case .classic:
            let gyro = Fighter3DMeshFactory.cylinder(
                radius: 0.075,
                height: 0.035,
                material: palette.eyeWhite
            )
            gyro.eulerAngles.x = .pi / 2
            gyro.position = SCNVector3(0, -0.04, proportions.shortsDepth / 2 + 0.025)
            pelvis.addChildNode(gyro)
        case .pressure:
            for side: CGFloat in [-1, 1] {
                let panel = Fighter3DMeshFactory.box(
                    width: 0.15,
                    height: 0.34,
                    length: 0.055,
                    chamfer: 0.025,
                    material: palette.skin
                )
                panel.position = SCNVector3(
                    side * (proportions.shortsWidth / 2 - 0.065),
                    -0.07,
                    proportions.shortsDepth / 2 + 0.025
                )
                panel.eulerAngles.z = Float(-side * 0.08)
                pelvis.addChildNode(panel)
            }
        case .speed:
            let centerRail = Fighter3DMeshFactory.box(
                width: 0.075,
                height: 0.31,
                length: 0.045,
                chamfer: 0.01,
                material: palette.eyeWhite
            )
            centerRail.position = SCNVector3(0, -0.06, proportions.shortsDepth / 2 + 0.025)
            pelvis.addChildNode(centerRail)
            for side: CGFloat in [-1, 1] {
                let stabilizer = Fighter3DMeshFactory.box(
                    width: 0.045,
                    height: 0.22,
                    length: proportions.shortsDepth + 0.06,
                    chamfer: 0.012,
                    material: palette.accent
                )
                stabilizer.position = SCNVector3(
                    side * (proportions.shortsWidth / 2 + 0.012),
                    -0.04,
                    0
                )
                pelvis.addChildNode(stabilizer)
            }
        }
    }

    static func attachTorsoArmor(
        _ style: FighterKitStyle,
        proportions: Fighter3DAppearanceProfile,
        palette: Fighter3DMaterialPalette,
        to spine: SCNNode
    ) -> SCNNode {
        let front = proportions.torsoDepth * 0.63 + 0.025
        let coreRadius: CGFloat = style == .pressure ? 0.105 : 0.080
        let core = Fighter3DMeshFactory.cylinder(
            radius: coreRadius,
            height: 0.045,
            material: palette.eyeWhite
        )
        core.eulerAngles.x = .pi / 2
        core.position = SCNVector3(0, style == .speed ? 0.52 : 0.45, front)
        spine.addChildNode(core)

        switch style {
        case .classic:
            for side: CGFloat in [-1, 1] {
                let chestPlate = Fighter3DMeshFactory.box(
                    width: proportions.chestWidth * 0.42,
                    height: 0.34,
                    length: 0.065,
                    chamfer: 0.045,
                    material: palette.kit
                )
                chestPlate.position = SCNVector3(
                    side * proportions.chestWidth * 0.23,
                    0.59,
                    front
                )
                chestPlate.eulerAngles.z = Float(-side * 0.13)
                spine.addChildNode(chestPlate)
            }
        case .pressure:
            let breastplate = Fighter3DMeshFactory.box(
                width: proportions.chestWidth * 1.03,
                height: 0.44,
                length: 0.10,
                chamfer: 0.065,
                material: palette.kit
            )
            breastplate.position = SCNVector3(0, 0.58, front)
            spine.addChildNode(breastplate)
            for side: CGFloat in [-1, 1] {
                let bolt = Fighter3DMeshFactory.cylinder(
                    radius: 0.045,
                    height: 0.04,
                    material: palette.accent
                )
                bolt.eulerAngles.x = .pi / 2
                bolt.position = SCNVector3(side * proportions.chestWidth * 0.34, 0.66, front + 0.07)
                spine.addChildNode(bolt)
            }
        case .speed:
            let keel = Fighter3DMeshFactory.box(
                width: 0.15,
                height: 0.57,
                length: 0.07,
                chamfer: 0.025,
                material: palette.kit
            )
            keel.position = SCNVector3(0, 0.55, front)
            spine.addChildNode(keel)
            for side: CGFloat in [-1, 1] {
                let rib = Fighter3DMeshFactory.box(
                    width: proportions.chestWidth * 0.38,
                    height: 0.095,
                    length: 0.05,
                    chamfer: 0.018,
                    material: palette.accent
                )
                rib.position = SCNVector3(side * 0.19, 0.62 + side * 0.11, front)
                rib.eulerAngles.z = Float(-side * 0.30)
                spine.addChildNode(rib)
            }
        }
        return core
    }

    static func attachHelmet(
        _ style: FighterHairStyle,
        proportions: Fighter3DAppearanceProfile,
        palette: Fighter3DMaterialPalette,
        to head: SCNNode
    ) {
        let helmetRoot = SCNNode()
        helmetRoot.scale = SCNVector3(
            proportions.headWidthScale,
            proportions.headHeightScale,
            proportions.headDepthScale
        )
        head.addChildNode(helmetRoot)

        switch style {
        case .cropped:
            let crown = Fighter3DMeshFactory.box(
                width: 0.34,
                height: 0.12,
                length: 0.34,
                chamfer: 0.045,
                material: palette.skin
            )
            crown.position = SCNVector3(0, 0.20, 0)
            helmetRoot.addChildNode(crown)

            let sensorBar = Fighter3DMeshFactory.box(
                width: 0.22,
                height: 0.035,
                length: 0.045,
                chamfer: 0.012,
                material: palette.eyeWhite
            )
            sensorBar.position = SCNVector3(0, 0.23, 0.205)
            helmetRoot.addChildNode(sensorBar)
        case .shaved:
            let reinforcedCrown = Fighter3DMeshFactory.box(
                width: 0.39,
                height: 0.15,
                length: 0.38,
                chamfer: 0.065,
                material: palette.kit
            )
            reinforcedCrown.position = SCNVector3(0, 0.19, -0.005)
            helmetRoot.addChildNode(reinforcedCrown)

            for side: CGFloat in [-1, 1] {
                let templeGuard = Fighter3DMeshFactory.box(
                    width: 0.075,
                    height: 0.25,
                    length: 0.27,
                    chamfer: 0.025,
                    material: palette.hair
                )
                templeGuard.position = SCNVector3(side * 0.205, 0.035, 0)
                helmetRoot.addChildNode(templeGuard)
            }
        case .swept:
            let crown = Fighter3DMeshFactory.box(
                width: 0.30,
                height: 0.105,
                length: 0.32,
                chamfer: 0.035,
                material: palette.skin
            )
            crown.position = SCNVector3(0, 0.19, 0)
            helmetRoot.addChildNode(crown)

            let antenna = Fighter3DMeshFactory.box(
                width: 0.045,
                height: 0.29,
                length: 0.075,
                chamfer: 0.012,
                material: palette.eyeWhite
            )
            antenna.position = SCNVector3(0.10, 0.34, -0.02)
            antenna.eulerAngles.z = -0.24
            helmetRoot.addChildNode(antenna)
        }
    }

    static func attachSensorFace(
        _ style: FighterFaceStyle,
        proportions: Fighter3DAppearanceProfile,
        palette: Fighter3DMaterialPalette,
        to head: SCNNode
    ) {
        let visorWidth: CGFloat = style == .rugged || style == .veteran ? 0.35 : 0.30
        let visor = Fighter3DMeshFactory.box(
            width: visorWidth * proportions.headWidthScale,
            height: style == .sharp ? 0.055 : 0.075,
            length: 0.045,
            chamfer: 0.016,
            material: palette.eyeWhite
        )
        visor.position = SCNVector3(
            0,
            0.045 * proportions.headHeightScale,
            0.235 * proportions.headDepthScale
        )
        head.addChildNode(visor)

        let facePlate = Fighter3DMeshFactory.box(
            width: 0.27 * proportions.headWidthScale,
            height: 0.16,
            length: 0.055,
            chamfer: 0.028,
            material: palette.shadowSkin
        )
        facePlate.position = SCNVector3(0, -0.105, 0.218 * proportions.headDepthScale)
        head.addChildNode(facePlate)

        switch style {
        case .focused:
            let centerSensor = Fighter3DMeshFactory.box(
                width: 0.035,
                height: 0.105,
                length: 0.035,
                chamfer: 0.010,
                material: palette.accent
            )
            centerSensor.position = SCNVector3(0, -0.045, 0.255)
            head.addChildNode(centerSensor)
        case .rugged, .veteran:
            let ramGuard = Fighter3DMeshFactory.box(
                width: 0.30,
                height: 0.12,
                length: 0.10,
                chamfer: 0.025,
                material: palette.kit
            )
            ramGuard.position = SCNVector3(0, -0.185, 0.18)
            head.addChildNode(ramGuard)
        case .sharp:
            let rangeFinder = Fighter3DMeshFactory.box(
                width: 0.095,
                height: 0.055,
                length: 0.055,
                chamfer: 0.012,
                material: palette.accent
            )
            rangeFinder.position = SCNVector3(0.125, -0.055, 0.25)
            rangeFinder.eulerAngles.z = -0.22
            head.addChildNode(rangeFinder)
        }
    }
}
