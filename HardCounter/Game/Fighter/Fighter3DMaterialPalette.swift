import SceneKit
import UIKit

/// Presentation-only materials derived from one fighter appearance. Keeping
/// these values together prevents geometry builders from independently tuning
/// the same skin or kit color.
struct Fighter3DMaterialPalette {
    let skin: SCNMaterial
    let shadowSkin: SCNMaterial
    let jointSkin: SCNMaterial
    let kit: SCNMaterial
    let accent: SCNMaterial
    let hair: SCNMaterial
    let eyeWhite: SCNMaterial

    init(appearance: FighterAppearance) {
        skin = Self.make(appearance.skinColor, roughness: 0.66, specular: 0.20)
        shadowSkin = Self.make(appearance.skinShadowColor, roughness: 0.72, specular: 0.14)
        jointSkin = Self.make(
            Self.blend(
                appearance.skinColor,
                appearance.skinShadowColor,
                amount: 0.30
            ),
            roughness: 0.96,
            specular: 0.02
        )
        kit = Self.make(appearance.kitColor, roughness: 0.80, specular: 0.10)
        accent = Self.make(
            appearance.accentColor,
            roughness: 0.48,
            specular: 0.32,
            emission: 0.025
        )
        hair = Self.make(appearance.hairColor, roughness: 0.94, specular: 0.04)
        eyeWhite = Self.make(
            UIColor(white: 0.92, alpha: 1),
            roughness: 0.74,
            specular: 0.08
        )
    }

    private static func make(
        _ color: UIColor,
        roughness: CGFloat,
        specular: CGFloat,
        emission: CGFloat = 0
    ) -> SCNMaterial {
        let result = SCNMaterial()
        result.diffuse.contents = color
        result.roughness.contents = roughness
        result.metalness.contents = 0.02
        result.specular.contents = UIColor(white: specular, alpha: 1)
        if emission > 0 {
            result.emission.contents = color
            result.emission.intensity = emission
        }
        result.lightingModel = .physicallyBased
        return result
    }

    private static func blend(
        _ first: UIColor,
        _ second: UIColor,
        amount: CGFloat
    ) -> UIColor {
        var firstRGBA = (r: CGFloat.zero, g: CGFloat.zero, b: CGFloat.zero, a: CGFloat.zero)
        var secondRGBA = (r: CGFloat.zero, g: CGFloat.zero, b: CGFloat.zero, a: CGFloat.zero)
        guard first.getRed(
            &firstRGBA.r,
            green: &firstRGBA.g,
            blue: &firstRGBA.b,
            alpha: &firstRGBA.a
        ), second.getRed(
            &secondRGBA.r,
            green: &secondRGBA.g,
            blue: &secondRGBA.b,
            alpha: &secondRGBA.a
        ) else { return first }

        let t = min(max(amount, 0), 1)
        return UIColor(
            red: firstRGBA.r + (secondRGBA.r - firstRGBA.r) * t,
            green: firstRGBA.g + (secondRGBA.g - firstRGBA.g) * t,
            blue: firstRGBA.b + (secondRGBA.b - firstRGBA.b) * t,
            alpha: firstRGBA.a + (secondRGBA.a - firstRGBA.a) * t
        )
    }
}
