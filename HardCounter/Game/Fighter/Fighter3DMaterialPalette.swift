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
    let secondaryArmor: SCNMaterial
    let marking: SCNMaterial

    init(appearance: FighterAppearance) {
        let frameMetal = Self.mixed(
            appearance.kitColor,
            with: UIColor(red: 0.25, green: 0.29, blue: 0.34, alpha: 1),
            amount: 0.88
        )
        let insetMetal = UIColor(red: 0.040, green: 0.050, blue: 0.067, alpha: 1)
        let jointMetal = UIColor(red: 0.025, green: 0.032, blue: 0.045, alpha: 1)
        let pearlArmor = Self.mixed(
            appearance.kitColor,
            with: UIColor(red: 0.82, green: 0.86, blue: 0.88, alpha: 1),
            amount: 0.68
        )
        skin = Self.make(
            frameMetal,
            roughness: 0.68,
            specular: 0.50,
            metalness: 0.88,
            clearCoat: 0.04
        )
        shadowSkin = Self.make(
            insetMetal,
            roughness: 0.92,
            specular: 0.12,
            metalness: 0.22
        )
        jointSkin = Self.make(
            jointMetal,
            roughness: 0.36,
            specular: 0.72,
            metalness: 0.94,
            clearCoat: 0.18
        )
        kit = Self.make(
            appearance.kitColor,
            roughness: 0.16,
            specular: 0.94,
            metalness: 0.68,
            clearCoat: 0.92,
            clearCoatRoughness: 0.07
        )
        accent = Self.make(
            appearance.accentColor,
            roughness: 0.58,
            specular: 0.48,
            metalness: 0.72,
            clearCoat: 0.10
        )
        hair = Self.make(
            insetMetal,
            roughness: 0.12,
            specular: 0.96,
            metalness: 0.96,
            clearCoat: 0.72,
            clearCoatRoughness: 0.05
        )
        eyeWhite = Self.make(
            appearance.kitColor,
            roughness: 0.10,
            specular: 0.98,
            metalness: 0.12,
            clearCoat: 1,
            clearCoatRoughness: 0.03,
            emission: 0.92
        )
        secondaryArmor = Self.make(
            pearlArmor,
            roughness: 0.27,
            specular: 0.86,
            metalness: 0.62,
            clearCoat: 0.68,
            clearCoatRoughness: 0.12
        )
        marking = Self.make(
            UIColor(red: 0.88, green: 0.90, blue: 0.86, alpha: 1),
            roughness: 0.48,
            specular: 0.38,
            metalness: 0.18
        )
    }

    private static func make(
        _ color: UIColor,
        roughness: CGFloat,
        specular: CGFloat,
        metalness: CGFloat,
        clearCoat: CGFloat = 0,
        clearCoatRoughness: CGFloat = 0.18,
        emission: CGFloat = 0
    ) -> SCNMaterial {
        let result = SCNMaterial()
        result.diffuse.contents = color
        result.roughness.contents = roughness
        result.metalness.contents = metalness
        result.specular.contents = UIColor(white: specular, alpha: 1)
        result.clearCoat.contents = clearCoat
        result.clearCoatRoughness.contents = clearCoatRoughness
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
