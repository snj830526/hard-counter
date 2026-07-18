import CoreGraphics

/// Geometry-only proportions for the presentation rig. Segment lengths remain
/// shared so a character's style cannot open gaps between connected joints.
struct Fighter3DAppearanceProfile {
    let torsoWidth: CGFloat
    let torsoDepth: CGFloat
    let chestWidth: CGFloat
    let shortsWidth: CGFloat
    let shortsHeight: CGFloat
    let shortsDepth: CGFloat
    let shoulderOffset: CGFloat
    let hipOffset: CGFloat
    let limbRadiusScale: CGFloat
    let gloveRadius: CGFloat
    let gloveWidthScale: CGFloat
    let gloveHeightScale: CGFloat
    let gloveDepthScale: CGFloat
    let shoeWidth: CGFloat
    let shoeHeight: CGFloat
    let shoeLength: CGFloat
    let cuffScale: CGFloat

    init(appearance: FighterAppearance) {
        switch appearance.bodyBuild {
        case .balanced:
            torsoWidth = 0.82
            torsoDepth = 0.38
            chestWidth = 0.70
            shoulderOffset = 0.46
            hipOffset = 0.20
            limbRadiusScale = 1
        case .heavyweight:
            torsoWidth = 0.94
            torsoDepth = 0.46
            chestWidth = 0.84
            shoulderOffset = 0.53
            hipOffset = 0.23
            limbRadiusScale = 1.12
        case .lean:
            torsoWidth = 0.72
            torsoDepth = 0.33
            chestWidth = 0.62
            shoulderOffset = 0.41
            hipOffset = 0.17
            limbRadiusScale = 0.89
        }

        switch appearance.kitStyle {
        case .classic:
            shortsWidth = 0.58
            shortsHeight = 0.40
            shortsDepth = 0.42
            gloveRadius = 0.17
            gloveWidthScale = 1
            gloveHeightScale = 0.90
            gloveDepthScale = 1.18
            shoeWidth = 0.22
            shoeHeight = 0.13
            shoeLength = 0.39
            cuffScale = 1
        case .pressure:
            shortsWidth = 0.70
            shortsHeight = 0.46
            shortsDepth = 0.49
            gloveRadius = 0.185
            gloveWidthScale = 1.12
            gloveHeightScale = 0.98
            gloveDepthScale = 1.18
            shoeWidth = 0.25
            shoeHeight = 0.16
            shoeLength = 0.37
            cuffScale = 1.18
        case .speed:
            shortsWidth = 0.50
            shortsHeight = 0.37
            shortsDepth = 0.36
            gloveRadius = 0.155
            gloveWidthScale = 0.92
            gloveHeightScale = 0.84
            gloveDepthScale = 1.34
            shoeWidth = 0.19
            shoeHeight = 0.12
            shoeLength = 0.44
            cuffScale = 0.86
        }
    }
}
