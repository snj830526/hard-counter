import SpriteKit

enum CombatControlInput {
    case movement(CGVector)
    case punch
    case sway
    case none
}

final class CombatControlsNode: SKNode {
    private let movementDeadZone: CGFloat = 9
    private let movementFullSpeedRadius: CGFloat = 58
    private let dpad = SKShapeNode(circleOfRadius: 58)
    private let dpadCenterDot = SKShapeNode(circleOfRadius: 12)
    private let punchButton = SKShapeNode(path: CombatControlsNode.octagonPath(radius: 39))
    private let swayButton = SKShapeNode(path: CombatControlsNode.octagonPath(radius: 34))
    private let punchLabel = CombatTypography.label(weight: .display)
    private let swayLabel = CombatTypography.label(weight: .display)
    private var dpadCenter = CGPoint.zero
    private var punchCenter = CGPoint.zero
    private var swayCenter = CGPoint.zero
    private var movementCaptureFrame = CGRect.zero
    private var homeDpadCenter = CGPoint.zero
    private var isMovementActive = false

    override init() {
        super.init()
        zPosition = 100
        buildControls()
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { nil }

    func layout(in size: CGSize, safeInsets: EdgeInsetsSnapshot) {
        homeDpadCenter = CGPoint(x: safeInsets.leading + 82, y: safeInsets.bottom + 72)
        if !isMovementActive { dpadCenter = homeDpadCenter }
        punchCenter = CGPoint(x: size.width - safeInsets.trailing - 69, y: safeInsets.bottom + 77)
        swayCenter = CGPoint(x: size.width - safeInsets.trailing - 158, y: safeInsets.bottom + 58)
        movementCaptureFrame = CGRect(
            x: 0,
            y: 0,
            width: min(size.width * 0.42, homeDpadCenter.x + 140),
            height: min(size.height * 0.62, homeDpadCenter.y + 140)
        )

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

        guard movementCaptureFrame.contains(point) else { return .none }
        return .movement(.zero)
    }

    func beginMovement(at point: CGPoint) -> CGVector {
        isMovementActive = true
        dpadCenter = point
        dpad.position = dpadCenter
        dpadCenterDot.position = dpadCenter
        return .zero
    }

    func continuedMovement(at point: CGPoint) -> CGVector {
        directionVector(for: CGVector(dx: point.x - dpadCenter.x, dy: point.y - dpadCenter.y))
    }

    func endMovement() {
        isMovementActive = false
        dpadCenter = homeDpadCenter
        dpad.position = dpadCenter
        dpadCenterDot.position = dpadCenter
    }

    private func directionVector(for delta: CGVector) -> CGVector {
        let length = hypot(delta.dx, delta.dy)
        guard length >= movementDeadZone else { return .zero }

        let availableTravel = movementFullSpeedRadius - movementDeadZone
        let linearAmount = min(max((length - movementDeadZone) / availableTravel, 0), 1)
        // A slightly eager response keeps small corrections available without
        // making the outer half of the stick feel slow.
        let speedAmount = CGFloat(pow(Double(linearAmount), 0.86))
        return CGVector(
            dx: delta.dx / length * speedAmount,
            dy: delta.dy / length * speedAmount
        )
    }

    func showMovement(_ vector: CGVector?) {
        dpadCenterDot.removeAllActions()
        let offset = vector.map { CGVector(dx: $0.dx * 22, dy: $0.dy * 22) } ?? .zero
        dpadCenterDot.position = CGPoint(x: dpadCenter.x + offset.dx, y: dpadCenter.y + offset.dy)
    }

    func flash(_ input: CombatControlInput) {
        let node: SKShapeNode
        switch input {
        case .punch: node = punchButton
        case .sway: node = swayButton
        default: return
        }
        node.removeAction(forKey: "press")
        node.setScale(0.90)
        let release = SKAction.scale(to: 1, duration: 0.08)
        release.timingMode = .easeOut
        node.run(release, withKey: "press")
    }

    private func buildControls() {
        dpad.fillColor = ArenaVisualPalette.void.withAlphaComponent(0.68)
        dpad.strokeColor = ArenaVisualPalette.whiteMark.withAlphaComponent(0.24)
        dpad.lineWidth = 1.5
        addChild(dpad)

        let dpadInner = SKShapeNode(circleOfRadius: 43)
        dpadInner.fillColor = .clear
        dpadInner.strokeColor = ArenaVisualPalette.cyanSignal.withAlphaComponent(0.24)
        dpadInner.lineWidth = 1
        dpad.addChild(dpadInner)

        for angle in stride(from: CGFloat(0), to: 2 * .pi, by: .pi / 2) {
            let notch = SKShapeNode(rectOf: CGSize(width: 14, height: 3), cornerRadius: 1.5)
            notch.position = CGPoint(x: cos(angle) * 49, y: sin(angle) * 49)
            notch.zRotation = angle
            notch.fillColor = ArenaVisualPalette.whiteMark.withAlphaComponent(0.58)
            notch.strokeColor = .clear
            dpad.addChild(notch)
        }

        dpadCenterDot.fillColor = ArenaVisualPalette.raisedMetal.withAlphaComponent(0.88)
        dpadCenterDot.strokeColor = ArenaVisualPalette.whiteMark.withAlphaComponent(0.52)
        dpadCenterDot.lineWidth = 1.5
        addChild(dpadCenterDot)

        configureButton(punchButton, color: ArenaVisualPalette.amberSignal, radius: 39)
        configureButton(swayButton, color: ArenaVisualPalette.cyanSignal, radius: 34)
        addChild(punchButton)
        addChild(swayButton)

        configureLabel(punchLabel, text: "PUNCH", size: 12)
        configureLabel(swayLabel, text: "SWAY", size: 10)
        addChild(punchLabel)
        addChild(swayLabel)
    }

    private func configureButton(
        _ button: SKShapeNode,
        color: SKColor,
        radius: CGFloat
    ) {
        button.fillColor = ArenaVisualPalette.carbon.withAlphaComponent(0.92)
        button.strokeColor = color.withAlphaComponent(0.82)
        button.lineWidth = 2

        let face = SKShapeNode(path: Self.octagonPath(radius: radius - 6))
        face.fillColor = color.withAlphaComponent(0.42)
        face.strokeColor = ArenaVisualPalette.whiteMark.withAlphaComponent(0.18)
        face.lineWidth = 1
        face.zPosition = 0.5
        button.addChild(face)

        let sheen = SKShapeNode(rectOf: CGSize(width: radius * 0.9, height: 2), cornerRadius: 1)
        sheen.position.y = radius * 0.5
        sheen.fillColor = SKColor.white.withAlphaComponent(0.22)
        sheen.strokeColor = .clear
        sheen.zPosition = 0.8
        button.addChild(sheen)
    }

    private func configureLabel(_ label: SKLabelNode, text: String, size: CGFloat) {
        label.text = text
        label.fontSize = size
        label.fontColor = .white
        label.horizontalAlignmentMode = .center
        label.verticalAlignmentMode = .center
        label.zPosition = 2
    }

    private static func octagonPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let cut = radius * 0.42
        path.move(to: CGPoint(x: -cut, y: -radius))
        path.addLine(to: CGPoint(x: cut, y: -radius))
        path.addLine(to: CGPoint(x: radius, y: -cut))
        path.addLine(to: CGPoint(x: radius, y: cut))
        path.addLine(to: CGPoint(x: cut, y: radius))
        path.addLine(to: CGPoint(x: -cut, y: radius))
        path.addLine(to: CGPoint(x: -radius, y: cut))
        path.addLine(to: CGPoint(x: -radius, y: -cut))
        path.closeSubpath()
        return path
    }

    private func distance(from first: CGPoint, to second: CGPoint) -> CGFloat {
        hypot(first.x - second.x, first.y - second.y)
    }
}
