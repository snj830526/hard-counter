import CoreGraphics

/// Ring size and camera values that are tuned as one gameplay presentation.
enum ArenaViewTuning {
    static let ringHalfWidth: CGFloat = 270
    static let ringHalfDepth: CGFloat = 152

    static let startingHorizontalOffset: CGFloat = 174
    static let startingDepthOffset: CGFloat = 34

    static let baseZoom: CGFloat = 1.80
    static let farZoom: CGFloat = 1.52
    static let closeZoom: CGFloat = 2.12
    static let closeSeparation: CGFloat = 70
    static let farSeparation: CGFloat = 250
    static let zoomResponse: CGFloat = 3.8

    static let fighterScaleBoost: CGFloat = 1.25
    static let playerFocusWeight: CGFloat = 0.58
    static let cameraFollowResponse: CGFloat = 6.4
    static let horizontalFitFraction: CGFloat = 0.76
    static let verticalFitFraction: CGFloat = 0.58
}
