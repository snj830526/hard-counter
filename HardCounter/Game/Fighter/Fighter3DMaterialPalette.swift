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
        let paintedArmor = Self.mixed(
            appearance.kitColor,
            with: UIColor.white,
            amount: 0.14
        )
        let frameMetal = appearance.machineColors.frame
        let insetMetal = Self.mixed(
            appearance.machineColors.frame,
            with: UIColor(red: 0.40, green: 0.43, blue: 0.48, alpha: 1),
            amount: 0.40
        )
        let jointMetal = Self.mixed(
            appearance.machineColors.frame,
            with: UIColor(red: 0.48, green: 0.50, blue: 0.54, alpha: 1),
            amount: 0.52
        )
        let accentPaint = Self.mixed(
            appearance.accentColor,
            with: UIColor.white,
            amount: 0.20
        )
        let secondaryArmor = Self.mixed(
            appearance.machineColors.secondaryArmor,
            with: UIColor.white,
            amount: 0.08
        )
        skin = Self.makeMatte(frameMetal)
        shadowSkin = Self.makeMatte(insetMetal)
        jointSkin = Self.makeMatte(jointMetal)
        kit = Self.makeMatte(paintedArmor)
        accent = Self.makeMatte(accentPaint)
        hair = Self.makeMatte(insetMetal)
        eyeWhite = Self.makeSignal(appearance.machineColors.signal)
        self.secondaryArmor = Self.makeMatte(secondaryArmor)
        marking = Self.makeMatte(appearance.machineColors.marking)
    }

    /// Powder-coated armour uses diffuse-only lighting. PBR metalness still
    /// produces bright facets on the low-poly mesh even at high roughness, so
    /// the non-luminous machine surfaces deliberately use Lambert shading.
    private static func makeMatte(_ color: UIColor) -> SCNMaterial {
        let result = SCNMaterial()
        result.diffuse.contents = color
        result.ambient.contents = color.withAlphaComponent(0.42)
        result.specular.contents = UIColor.black
        result.reflective.contents = UIColor.black
        result.metalness.contents = 0
        result.roughness.contents = 1
        result.clearCoat.contents = 0
        // A small albedo floor keeps saturated powder coats readable against
        // the dark arena without creating a highlight or a luminous outline.
        result.emission.contents = color
        result.emission.intensity = 0.12
        result.lightingModel = .lambert
        return result
    }

    /// Sensors are the only self-lit surfaces; they do not carry a glossy
    /// highlight, keeping the armour/signal material boundary unambiguous.
    private static func makeSignal(_ color: UIColor) -> SCNMaterial {
        let result = SCNMaterial()
        result.diffuse.contents = color
        result.emission.contents = color
        result.emission.intensity = 0.76
        result.specular.contents = UIColor.black
        result.reflective.contents = UIColor.black
        result.lightingModel = .constant
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
