import SceneKit
import SpriteKit

/// Frames the shared 3D exchange without owning ring or combat geometry.
final class Arena3DCameraController {
    private let cameraNode = SCNNode()
    private let wideScale: CGFloat
    private let closeScale: CGFloat
    private let distanceZoomCompression: CGFloat
    private let floorDepthVerticalFactor: CGFloat

    private(set) var currentScale: CGFloat
    private var baseScale: CGFloat
    private var focus = SIMD2<Float>.zero
    private var counterCloseUp: CounterCloseUp?

    private struct CounterCloseUp {
        let focus: SIMD2<Float>
        var elapsed: TimeInterval = 0
    }

    init(
        initialScale: CGFloat,
        closeScale: CGFloat,
        wideScale: CGFloat,
        distanceZoomCompression: CGFloat,
        floorDepthVerticalFactor: CGFloat
    ) {
        currentScale = initialScale
        baseScale = initialScale
        self.closeScale = closeScale
        self.wideScale = wideScale
        self.distanceZoomCompression = distanceZoomCompression
        self.floorDepthVerticalFactor = floorDepthVerticalFactor
    }

    /// Briefly favors the point of impact and tightens the lens. Gameplay and
    /// the regular two-fighter framing remain untouched underneath the effect.
    func playCounterCloseUp(at position: SCNVector3) {
        counterCloseUp = CounterCloseUp(
            focus: SIMD2<Float>(position.x, position.z)
        )
    }

    func attach(to scene: SCNScene, viewport: SK3DNode) {
        let camera = SCNCamera()
        camera.usesOrthographicProjection = true
        camera.orthographicScale = currentScale
        camera.zNear = 0.1
        camera.zFar = 100
        cameraNode.camera = camera
        cameraNode.position = SCNVector3(0, 5.4, 8.6)
        cameraNode.look(at: SCNVector3(0, 0.85, 0))
        scene.rootNode.addChildNode(cameraNode)
        viewport.pointOfView = cameraNode
    }

    func update(
        playerPosition: SCNVector3,
        opponentPosition: SCNVector3,
        viewportSize: CGSize,
        deltaTime: TimeInterval
    ) {
        let midpoint = SIMD2<Float>(
            (playerPosition.x + opponentPosition.x) * 0.5,
            (playerPosition.z + opponentPosition.z) * 0.5
        )
        let desiredFocus = SIMD2<Float>(
            min(max(midpoint.x, -3.45), 3.45),
            min(max(midpoint.y, -1.95), 1.95)
        )
        let horizontalSpan = CGFloat(abs(opponentPosition.x - playerPosition.x))
        let depthSpan = CGFloat(abs(opponentPosition.z - playerPosition.z))
        let aspect = max(viewportSize.width / max(viewportSize.height, 1), 1)
        let horizontalFit = (horizontalSpan + 1.18) / aspect
        let depthFit = depthSpan * floorDepthVerticalFactor + 1.58
        let fittedScale = max(closeScale, horizontalFit, depthFit)
        let compressedScale = closeScale
            + (fittedScale - closeScale) * distanceZoomCompression
        let desiredScale = min(max(compressedScale, closeScale), wideScale)

        let focusBlend: Float
        let zoomBlend: CGFloat
        if deltaTime <= 0 {
            focusBlend = 1
            zoomBlend = 1
        } else {
            focusBlend = Float(1 - exp(-deltaTime * 7.0))
            zoomBlend = CGFloat(1 - exp(-deltaTime * 2.8))
        }
        focus += (desiredFocus - focus) * focusBlend
        baseScale += (desiredScale - baseScale) * zoomBlend

        var presentedFocus = focus
        var closeUpAmount: CGFloat = 0
        if var closeUp = counterCloseUp {
            closeUp.elapsed += max(deltaTime, 0)
            let progress = min(closeUp.elapsed / CombatTuning.counterCloseUpDuration, 1)
            // A sharp six-frame punch-in followed by a longer ease-out avoids
            // making the camera feel detached from the actual strike.
            if progress < 0.20 {
                closeUpAmount = CGFloat(progress / 0.20)
            } else {
                let release = CGFloat((progress - 0.20) / 0.80)
                closeUpAmount = 1 - release * release
            }
            let focusAmount = Float(closeUpAmount * 0.78)
            presentedFocus += (closeUp.focus - presentedFocus) * focusAmount
            counterCloseUp = progress < 1 ? closeUp : nil
        }

        // Keep the reported scale on the underlying gameplay framing so input
        // velocity and contact conversions do not change during the close-up.
        currentScale = baseScale
        let presentedScale = baseScale
            * (1 - CombatTuning.counterCloseUpZoomAmount * closeUpAmount)
        cameraNode.camera?.orthographicScale = presentedScale
        cameraNode.position = SCNVector3(presentedFocus.x, 5.4, 8.6 + presentedFocus.y)
        cameraNode.look(at: SCNVector3(presentedFocus.x, 0.85, presentedFocus.y))
    }
}
