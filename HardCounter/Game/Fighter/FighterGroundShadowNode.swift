import SpriteKit

/// Combines a tight contact patch with a soft directional shadow so the
/// SceneKit fighter reads as standing on the SpriteKit canvas.
final class FighterGroundShadowNode: SKNode {
    private let castShadow = SKShapeNode(ellipseOf: CGSize(width: 92, height: 16))
    private let contactShadow = SKShapeNode(ellipseOf: CGSize(width: 58, height: 11))
    private let leadFootContact = SKShapeNode(ellipseOf: CGSize(width: 25, height: 7))
    private let rearFootContact = SKShapeNode(ellipseOf: CGSize(width: 25, height: 7))

    override init() {
        super.init()

        castShadow.fillColor = .black.withAlphaComponent(0.19)
        castShadow.strokeColor = .clear
        castShadow.position = CGPoint(x: 12, y: -4)
        castShadow.zRotation = -0.10
        castShadow.glowWidth = 3
        addChild(castShadow)

        contactShadow.fillColor = .black.withAlphaComponent(0.42)
        contactShadow.strokeColor = .black.withAlphaComponent(0.10)
        contactShadow.lineWidth = 1
        contactShadow.glowWidth = 1.5
        contactShadow.zPosition = 1
        addChild(contactShadow)

        for (contact, x) in [(leadFootContact, CGFloat(-12)), (rearFootContact, CGFloat(12))] {
            contact.fillColor = .black.withAlphaComponent(0.58)
            contact.strokeColor = .clear
            contact.position = CGPoint(x: x, y: 1)
            contact.zPosition = 2
            addChild(contact)
        }
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { nil }

    func applyPerspective(scale: CGFloat, depthProgress: CGFloat) {
        xScale = scale
        yScale = scale * 0.72

        let nearness = 1 - min(max(depthProgress, 0), 1)
        castShadow.position = CGPoint(
            x: 9 + nearness * 5,
            y: -3 - nearness * 2
        )
        castShadow.alpha = 0.78 + nearness * 0.18
        contactShadow.xScale = 0.92 + nearness * 0.12
        leadFootContact.xScale = 0.92 + nearness * 0.10
        rearFootContact.xScale = 0.92 + nearness * 0.10
    }
}
