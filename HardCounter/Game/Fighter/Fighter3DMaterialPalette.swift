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
            appearance.skinColor,
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

}
