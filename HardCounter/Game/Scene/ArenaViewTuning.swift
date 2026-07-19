import CoreGraphics

/// Ring size and camera values that are tuned as one gameplay presentation.
enum ArenaViewTuning {
    static let ringHalfWidth: CGFloat = 270
    static let ringHalfDepth: CGFloat = 152

    static let startingHorizontalOffset: CGFloat = 174
    static let startingDepthOffset: CGFloat = 34

    static let baseZoom: CGFloat = 1.80
    // Keep both fighters large enough for guard and weight shifts to read at
    // normal exchange distance. Close framing begins before clinch range so a
    // successful sway-counter feels urgent instead of happening far away.
    static let farZoom: CGFloat = 1.72
    static let closeZoom: CGFloat = 2.62
    static let containmentMinimumZoom: CGFloat = 1.05
    static let closeSeparation: CGFloat = 118
    static let farSeparation: CGFloat = 238
    static let zoomResponse: CGFloat = 5.2

    static let fighterScaleBoost: CGFloat = 1.43
    static let playerFocusWeight: CGFloat = 0.58
    static let cameraFollowResponse: CGFloat = 6.4
    static let cameraDeadZoneWidthFraction: CGFloat = 0.13
    static let cameraDeadZoneHeightFraction: CGFloat = 0.11
    static let horizontalFitFraction: CGFloat = 0.82
    static let verticalFitFraction: CGFloat = 0.66

    // Camera fitting uses the visible low-poly silhouette around the fighter's
    // floor anchor, not just the distance between the two anchors. Values are
    // measured in the unscaled FighterNode presentation space.
    static let fighterVisibleHalfWidth: CGFloat = 48
    static let fighterVisibleBottom: CGFloat = 9
    static let fighterVisibleTop: CGFloat = 116
    static let cameraHorizontalSafetyMargin: CGFloat = 28
    static let cameraBottomSafetyMargin: CGFloat = 20
    static let cameraTopSafetyMargin: CGFloat = 48
}
