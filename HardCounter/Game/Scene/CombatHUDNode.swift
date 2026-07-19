import SpriteKit
import UIKit

/// Owns combat gauges, labels, and the round-end overlay independently from
/// arena camera movement and combat orchestration.
final class CombatHUDNode: SKNode {
    let playerHealthBar: SKSpriteNode
    let cpuHealthBar: SKSpriteNode
    let playerHealthDamageBar = SKSpriteNode(
        color: ArenaVisualPalette.hudDamage,
        size: CGSize(width: 216, height: 12)
    )
    let cpuHealthDamageBar = SKSpriteNode(
        color: ArenaVisualPalette.hudDamage,
        size: CGSize(width: 216, height: 12)
    )
    let playerStaminaBar = SKSpriteNode(
        color: ArenaVisualPalette.hudStamina,
        size: CGSize(width: 216, height: 5)
    )
    let cpuStaminaBar = SKSpriteNode(
        color: ArenaVisualPalette.hudStamina,
        size: CGSize(width: 216, height: 5)
    )
    let statusLabel = CombatTypography.label(weight: .display)
    let playerName = CombatTypography.label(weight: .display)
    let cpuName = CombatTypography.label(weight: .display)
    private let playerDetail = CombatTypography.label(weight: .supporting)
    private let cpuDetail = CombatTypography.label(weight: .supporting)
    let roundEndOverlay = SKSpriteNode(
        color: SKColor.black.withAlphaComponent(0.58),
        size: .zero
    )
    let restartButton = SKShapeNode(
        rectOf: CGSize(width: 190, height: 52),
        cornerRadius: 12
    )
    let restartLabel = CombatTypography.label(weight: .display)

    init(
        playerName: String,
        playerColor: SKColor,
        playerDetail: String? = nil,
        opponentName: String,
        opponentColor: SKColor,
        opponentDetail: String? = nil
    ) {
        playerHealthBar = SKSpriteNode(
            color: ArenaVisualPalette.hudHealth,
            size: CGSize(width: 216, height: 12)
        )
        cpuHealthBar = SKSpriteNode(
            color: ArenaVisualPalette.hudHealth,
            size: CGSize(width: 216, height: 12)
        )
        super.init()

        addHealthBarBackground(for: playerHealthBar)
        addHealthBarBackground(for: cpuHealthBar)
        addStaminaBarBackground(for: playerStaminaBar, name: "playerStaminaBackground")
        addStaminaBarBackground(for: cpuStaminaBar, name: "cpuStaminaBackground")
        playerHealthBar.anchorPoint = CGPoint(x: 0, y: 0.5)
        cpuHealthBar.anchorPoint = CGPoint(x: 1, y: 0.5)
        playerHealthDamageBar.anchorPoint = CGPoint(x: 0, y: 0.5)
        cpuHealthDamageBar.anchorPoint = CGPoint(x: 1, y: 0.5)
        playerStaminaBar.anchorPoint = CGPoint(x: 0, y: 0.5)
        cpuStaminaBar.anchorPoint = CGPoint(x: 1, y: 0.5)
        playerHealthDamageBar.zPosition = 9.7
        cpuHealthDamageBar.zPosition = 9.7
        addChild(playerHealthDamageBar)
        addChild(cpuHealthDamageBar)
        addChild(playerHealthBar)
        addChild(cpuHealthBar)
        addChild(playerStaminaBar)
        addChild(cpuStaminaBar)
        decorateGaugeFill(playerHealthBar)
        decorateGaugeFill(cpuHealthBar)
        decorateGaugeFill(playerStaminaBar)
        decorateGaugeFill(cpuStaminaBar)
        decorateDamageTrack(playerHealthDamageBar, facesRight: true)
        decorateDamageTrack(cpuHealthDamageBar, facesRight: false)

        statusLabel.fontSize = 26
        statusLabel.fontColor = .white
        statusLabel.verticalAlignmentMode = .center
        statusLabel.zPosition = 20
        addChild(statusLabel)

        configureNameLabel(
            self.playerName,
            text: playerName,
            alignment: .left,
            color: playerColor
        )
        configureNameLabel(
            cpuName,
            text: opponentName,
            alignment: .right,
            color: opponentColor
        )
        configureDetailLabel(self.playerDetail, text: playerDetail, alignment: .left)
        configureDetailLabel(cpuDetail, text: opponentDetail, alignment: .right)
        addChild(self.playerName)
        addChild(cpuName)
        addChild(self.playerDetail)
        addChild(cpuDetail)

        roundEndOverlay.zPosition = 150
        roundEndOverlay.isHidden = true
        addChild(roundEndOverlay)

        restartButton.fillColor = ArenaVisualPalette.carbon.withAlphaComponent(0.96)
        restartButton.strokeColor = ArenaVisualPalette.amberSignal.withAlphaComponent(0.92)
        restartButton.lineWidth = 2
        restartButton.zPosition = 160
        restartButton.isHidden = true
        addChild(restartButton)

        restartLabel.text = "PLAY AGAIN"
        restartLabel.fontSize = 18
        restartLabel.fontColor = .white
        restartLabel.verticalAlignmentMode = .center
        restartLabel.zPosition = 1
        restartButton.addChild(restartLabel)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { nil }

    func layout(in size: CGSize, safeInsets: UIEdgeInsets, roundEnded: Bool) {
        let left = safeInsets.left + CombatTuning.hudHorizontalPadding
        let right = size.width - safeInsets.right - CombatTuning.hudHorizontalPadding
        let top = size.height - safeInsets.top - CombatTuning.hudTopPadding

        childNode(withName: "playerHealthBackground")?.position = CGPoint(x: left + 108, y: top)
        childNode(withName: "cpuHealthBackground")?.position = CGPoint(x: right - 108, y: top)
        childNode(withName: "playerStaminaBackground")?.position = CGPoint(x: left + 108, y: top - 18)
        childNode(withName: "cpuStaminaBackground")?.position = CGPoint(x: right - 108, y: top - 18)
        playerHealthBar.position = CGPoint(x: left, y: top)
        cpuHealthBar.position = CGPoint(x: right, y: top)
        playerHealthDamageBar.position = CGPoint(x: left, y: top)
        cpuHealthDamageBar.position = CGPoint(x: right, y: top)
        playerStaminaBar.position = CGPoint(x: left, y: top - 18)
        cpuStaminaBar.position = CGPoint(x: right, y: top - 18)
        playerName.position = CGPoint(x: left, y: top - 37)
        cpuName.position = CGPoint(x: right, y: top - 37)
        playerDetail.position = CGPoint(x: left, y: top - 50)
        cpuDetail.position = CGPoint(x: right, y: top - 50)
        statusLabel.position = CGPoint(
            x: size.width / 2,
            y: roundEnded ? size.height * 0.59 : top - 31
        )
        roundEndOverlay.size = size
        roundEndOverlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        restartButton.position = CGPoint(x: size.width / 2, y: size.height * 0.43)
    }

    private func addHealthBarBackground(for bar: SKSpriteNode) {
        let background = SKSpriteNode(color: .clear, size: CGSize(width: 230, height: 20))
        background.name = bar === playerHealthBar ? "playerHealthBackground" : "cpuHealthBackground"
        background.zPosition = 9
        addGaugeFrame(
            to: background,
            size: background.size,
            signal: bar === playerHealthBar
                ? ArenaVisualPalette.hudPlayerAccent : ArenaVisualPalette.hudOpponentAccent,
            accentOnLeft: bar === playerHealthBar
        )
        addChild(background)
        bar.zPosition = 10
    }

    private func addStaminaBarBackground(for bar: SKSpriteNode, name: String) {
        let background = SKSpriteNode(
            color: .clear,
            size: CGSize(width: 230, height: 9)
        )
        background.name = name
        background.zPosition = 9
        let signal = name.hasPrefix("player")
            ? ArenaVisualPalette.hudPlayerAccent : ArenaVisualPalette.hudOpponentAccent
        addGaugeFrame(
            to: background,
            size: CGSize(width: 226, height: 8),
            signal: signal,
            accentOnLeft: name.hasPrefix("player")
        )
        addChild(background)
        bar.zPosition = 10
    }

    private func addGaugeFrame(
        to background: SKSpriteNode,
        size: CGSize,
        signal: SKColor,
        accentOnLeft: Bool
    ) {
        let inset: CGFloat = size.height >= 16 ? 5 : 2
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -size.width / 2 + inset, y: -size.height / 2))
        path.addLine(to: CGPoint(x: size.width / 2 - inset, y: -size.height / 2))
        path.addLine(to: CGPoint(x: size.width / 2, y: -size.height / 2 + inset))
        path.addLine(to: CGPoint(x: size.width / 2, y: size.height / 2 - inset))
        path.addLine(to: CGPoint(x: size.width / 2 - inset, y: size.height / 2))
        path.addLine(to: CGPoint(x: -size.width / 2 + inset, y: size.height / 2))
        path.addLine(to: CGPoint(x: -size.width / 2, y: size.height / 2 - inset))
        path.addLine(to: CGPoint(x: -size.width / 2, y: -size.height / 2 + inset))
        path.closeSubpath()

        let panel = SKShapeNode(path: path)
        panel.strokeColor = ArenaVisualPalette.whiteMark.withAlphaComponent(0.20)
        panel.fillColor = ArenaVisualPalette.void.withAlphaComponent(0.88)
        panel.lineWidth = 1
        panel.zPosition = 0.5
        background.addChild(panel)

        let signalRail = SKSpriteNode(
            color: signal.withAlphaComponent(0.78),
            size: CGSize(width: size.width - inset * 4, height: size.height >= 16 ? 2 : 1)
        )
        signalRail.position.y = -size.height / 2 + 1
        signalRail.zPosition = 1.2
        background.addChild(signalRail)

        let cap = SKSpriteNode(color: signal, size: CGSize(width: 3, height: max(size.height - 4, 2)))
        cap.position.x = (accentOnLeft ? -1 : 1) * (size.width / 2 - inset - 1)
        cap.zPosition = 2.4
        background.addChild(cap)
    }

    private func decorateGaugeFill(_ bar: SKSpriteNode) {
        let highlight = SKSpriteNode(
            color: SKColor.white.withAlphaComponent(0.09),
            size: CGSize(width: bar.size.width, height: 1)
        )
        highlight.position.y = bar.size.height * 0.5 - 0.5
        highlight.zPosition = 1
        bar.addChild(highlight)
    }

    /// The full-width damage track sits behind the live health fill. Damage
    /// exposes this red warning surface instead of disappearing into a black
    /// panel, making both the lost amount and the depletion direction obvious.
    private func decorateDamageTrack(
        _ track: SKSpriteNode,
        facesRight: Bool
    ) {
        track.colorBlendFactor = 1
        for index in 0..<12 {
            let slash = SKSpriteNode(
                color: ArenaVisualPalette.hudDamage.withAlphaComponent(0.64),
                size: CGSize(width: 2, height: 16)
            )
            let offset = CGFloat(index) * 18 + 9
            slash.position.x = facesRight ? offset : -offset
            slash.zRotation = facesRight ? -0.58 : 0.58
            slash.zPosition = 1
            track.addChild(slash)
        }
    }

    private func configureNameLabel(
        _ label: SKLabelNode,
        text: String,
        alignment: SKLabelHorizontalAlignmentMode,
        color: SKColor
    ) {
        label.text = text
        label.fontSize = 15
        label.fontColor = SKColor.white.withAlphaComponent(0.94)
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .bottom
        label.zPosition = 20

        let marker = SKSpriteNode(color: color, size: CGSize(width: 18, height: 2))
        marker.position = CGPoint(
            x: alignment == .left ? 9 : -9,
            y: -5
        )
        marker.zPosition = -1
        label.addChild(marker)
    }

    private func configureDetailLabel(
        _ label: SKLabelNode,
        text: String?,
        alignment: SKLabelHorizontalAlignmentMode
    ) {
        label.text = text
        label.fontSize = 8
        label.fontColor = SKColor.white.withAlphaComponent(0.46)
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .bottom
        label.zPosition = 20
        label.isHidden = text == nil
    }

}
