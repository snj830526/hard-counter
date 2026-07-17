import SpriteKit

enum CombatControlInput {
    case movement(CGVector)
    case punch
    case sway
    case none
}

final class CombatControlsNode: SKNode {
    private let movementCaptureRadius: CGFloat = 92
    private let movementDeadZone: CGFloat = 9
    private let dpad = SKShapeNode(circleOfRadius: 58)
    private let dpadCenterDot = SKShapeNode(circleOfRadius: 12)
    private let punchButton = SKShapeNode(circleOfRadius: 39)
    private let swayButton = SKShapeNode(circleOfRadius: 34)
    private let punchLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let swayLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private var dpadCenter = CGPoint.zero
    private var punchCenter = CGPoint.zero
    private var swayCenter = CGPoint.zero

    override init() {
        super.init()
        zPosition = 100
        buildControls()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { nil }

    func layout(in size: CGSize, safeInsets: EdgeInsetsSnapshot) {
        dpadCenter = CGPoint(x: safeInsets.leading + 82, y: safeInsets.bottom + 72)
        punchCenter = CGPoint(x: size.width - safeInsets.trailing - 69, y: safeInsets.bottom + 77)
        swayCenter = CGPoint(x: size.width - safeInsets.trailing - 158, y: safeInsets.bottom + 58)

        dpad.position = dpadCenter
        dpadCenterDot.position = dpadCenter
        punchButton.position = punchCenter
        swayButton.position = swayCenter
        punchLabel.position = punchCenter
        swayLabel.position = swayCenter
    }

    func input(at point: CGPoint) -> CombatControlInput {
        if distance(from: point, to: punchCenter) <= 48 { return .punch }
        if distance(from: point, to: swayCenter) <= 43 { return .sway }

        let delta = CGVector(dx: point.x - dpadCenter.x, dy: point.y - dpadCenter.y)
        guard hypot(delta.dx, delta.dy) <= movementCaptureRadius else { return .none }
        return .movement(directionVector(for: delta))
    }

    func continuedMovement(at point: CGPoint) -> CGVector {
        directionVector(for: CGVector(dx: point.x - dpadCenter.x, dy: point.y - dpadCenter.y))
    }

    private func directionVector(for delta: CGVector) -> CGVector {
        let length = hypot(delta.dx, delta.dy)
        guard length >= movementDeadZone else { return .zero }
        return CGVector(dx: delta.dx / length, dy: delta.dy / length)
    }

    func showMovement(_ vector: CGVector?) {
        dpadCenterDot.removeAllActions()
        let offset = vector.map { CGVector(dx: $0.dx * 17, dy: $0.dy * 17) } ?? .zero
        dpadCenterDot.run(.move(to: CGPoint(x: dpadCenter.x + offset.dx, y: dpadCenter.y + offset.dy), duration: 0.06))
    }

    func flash(_ input: CombatControlInput) {
        let node: SKShapeNode
        switch input {
        case .punch: node = punchButton
        case .sway: node = swayButton
        default: return
        }
        node.removeAction(forKey: "press")
        node.run(.sequence([.scale(to: 0.88, duration: 0.045), .scale(to: 1, duration: 0.10)]), withKey: "press")
    }

    private func buildControls() {
        dpad.fillColor = SKColor.black.withAlphaComponent(0.38)
        dpad.strokeColor = SKColor.white.withAlphaComponent(0.34)
        dpad.lineWidth = 2
        addChild(dpad)

        for angle in stride(from: CGFloat(0), to: 2 * .pi, by: .pi / 2) {
            let arrow = SKShapeNode(path: arrowPath())
            arrow.fillColor = SKColor.white.withAlphaComponent(0.72)
            arrow.strokeColor = .clear
            arrow.zRotation = angle
            dpad.addChild(arrow)
        }

        dpadCenterDot.fillColor = SKColor.white.withAlphaComponent(0.28)
        dpadCenterDot.strokeColor = SKColor.white.withAlphaComponent(0.55)
        dpadCenterDot.lineWidth = 1
        addChild(dpadCenterDot)

        configureButton(punchButton, color: .systemOrange)
        configureButton(swayButton, color: .systemCyan)
        addChild(punchButton)
        addChild(swayButton)

        configureLabel(punchLabel, text: "PUNCH", size: 12)
        configureLabel(swayLabel, text: "SWAY", size: 10)
        addChild(punchLabel)
        addChild(swayLabel)
    }

    private func configureButton(_ button: SKShapeNode, color: SKColor) {
        button.fillColor = color.withAlphaComponent(0.72)
        button.strokeColor = color.withAlphaComponent(0.95)
        button.lineWidth = 3
        button.glowWidth = 2
    }

    private func configureLabel(_ label: SKLabelNode, text: String, size: CGFloat) {
        label.text = text
        label.fontSize = size
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 2
    }

    private func arrowPath() -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 28, y: 0))
        path.addLine(to: CGPoint(x: 17, y: 8))
        path.addLine(to: CGPoint(x: 17, y: -8))
        path.closeSubpath()
        return path
    }

    private func distance(from first: CGPoint, to second: CGPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }
}
