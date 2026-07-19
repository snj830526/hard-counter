import CoreGraphics

/// Geometry-only proportions for the presentation rig. Segment lengths remain
/// shared so a character's style cannot open gaps between connected joints.
struct Fighter3DAppearanceProfile {
    let torsoWidth: CGFloat
    let torsoDepth: CGFloat
    let chestWidth: CGFloat
    let headWidthScale: CGFloat
    let headHeightScale: CGFloat
    let headDepthScale: CGFloat
    let neckRadius: CGFloat
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
            headWidthScale = 0.88
            headHeightScale = 1.10
            headDepthScale = 0.92
            neckRadius = 0.11
            shoulderOffset = 0.46
            hipOffset = 0.20
            limbRadiusScale = 1
        case .heavyweight:
            torsoWidth = 1.08
            torsoDepth = 0.54
            chestWidth = 0.96
            headWidthScale = 1.08
            headHeightScale = 0.94
            headDepthScale = 1.05
            neckRadius = 0.15
            shoulderOffset = 0.60
            hipOffset = 0.26
            limbRadiusScale = 1.28
        case .lean:
            torsoWidth = 0.62
            torsoDepth = 0.29
            chestWidth = 0.52
            headWidthScale = 0.74
            headHeightScale = 1.22
            headDepthScale = 0.84
            neckRadius = 0.08
            shoulderOffset = 0.36
            hipOffset = 0.15
            limbRadiusScale = 0.78
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
            shortsWidth = 0.80
            shortsHeight = 0.50
            shortsDepth = 0.56
            gloveRadius = 0.21
            gloveWidthScale = 1.22
            gloveHeightScale = 1.06
            gloveDepthScale = 1.22
            shoeWidth = 0.29
            shoeHeight = 0.18
            shoeLength = 0.40
            cuffScale = 1.34
        case .speed:
            shortsWidth = 0.43
            shortsHeight = 0.34
            shortsDepth = 0.31
            gloveRadius = 0.14
            gloveWidthScale = 0.82
            gloveHeightScale = 0.78
            gloveDepthScale = 1.48
            shoeWidth = 0.17
            shoeHeight = 0.105
            shoeLength = 0.49
            cuffScale = 0.72
        }
    }
}
