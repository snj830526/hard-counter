import SceneKit
import UIKit

/// Presentation-only materials for a purpose-built boxing machine. The old
/// field names remain stable for the rig builders, but they now describe
/// painted armour, recessed mechanics and luminous fight identifiers rather
/// than human skin, hair and fabric.
struct Fighter3DMaterialPalette {
    let skin: SCNMaterial
    let shadowSkin: SCNMaterial
    let jointSkin: SCNMaterial
    let kit: SCNMaterial
    let accent: SCNMaterial
    let hair: SCNMaterial
    let eyeWhite: SCNMaterial

    init(appearance: FighterAppearance) {
        let armour = Self.mixed(
            appearance.kitColor,
            with: UIColor(red: 0.54, green: 0.59, blue: 0.64, alpha: 1),
            amount: 0.34
        )
        let insetMetal = UIColor(red: 0.075, green: 0.090, blue: 0.115, alpha: 1)
        let jointMetal = UIColor(red: 0.025, green: 0.032, blue: 0.045, alpha: 1)
        skin = Self.make(armour, roughness: 0.34, specular: 0.72, metalness: 0.78)
        shadowSkin = Self.make(insetMetal, roughness: 0.46, specular: 0.58, metalness: 0.86)
        jointSkin = Self.make(
            jointMetal,
            roughness: 0.38,
            specular: 0.66,
            metalness: 0.92
        )
        kit = Self.make(
            appearance.kitColor,
            roughness: 0.30,
            specular: 0.78,
            metalness: 0.72
        )
        accent = Self.make(
            appearance.accentColor,
            roughness: 0.24,
            specular: 0.88,
            metalness: 0.64,
            emission: 0.20
        )
        hair = Self.make(insetMetal, roughness: 0.32, specular: 0.74, metalness: 0.90)
        eyeWhite = Self.make(
            appearance.kitColor,
            roughness: 0.14,
            specular: 0.92,
            metalness: 0.18,
            emission: 0.78
        )
    }

    private static func make(
        _ color: UIColor,
        roughness: CGFloat,
        specular: CGFloat,
        metalness: CGFloat,
        emission: CGFloat = 0
    ) -> SCNMaterial {
        let result = SCNMaterial()
        result.diffuse.contents = color
        result.roughness.contents = roughness
        result.metalness.contents = metalness
        result.specular.contents = UIColor(white: specular, alpha: 1)
        if emission > 0 {
            result.emission.contents = color
            result.emission.intensity = emission
        }
        result.lightingModel = .physicallyBased
        return result
    }

    private static func mixed(
        _ source: UIColor,
        with target: UIColor,
        amount: CGFloat
    ) -> UIColor {
        var sr: CGFloat = 0
        var sg: CGFloat = 0
        var sb: CGFloat = 0
        var sa: CGFloat = 0
        var tr: CGFloat = 0
        var tg: CGFloat = 0
        var tb: CGFloat = 0
        var ta: CGFloat = 0
        source.getRed(&sr, green: &sg, blue: &sb, alpha: &sa)
        target.getRed(&tr, green: &tg, blue: &tb, alpha: &ta)
        let t = min(max(amount, 0), 1)
        return UIColor(
            red: sr + (tr - sr) * t,
            green: sg + (tg - sg) * t,
            blue: sb + (tb - sb) * t,
            alpha: sa + (ta - sa) * t
        )
    }

}
