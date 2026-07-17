import SpriteKit
import UIKit

final class CombatScene: SKScene {
    private let arenaNode = SKNode()
    private let ringNode = BoxingRingNode()
    private let player = FighterNode(facingRight: true, color: .systemCyan)
    private let cpu = FighterNode(facingRight: false, color: .systemOrange)
    private let playerShadow = SKShapeNode(ellipseOf: CGSize(width: 84, height: 18))
    private let cpuShadow = SKShapeNode(ellipseOf: CGSize(width: 84, height: 18))
    private let playerHealthBar = SKSpriteNode(color: .systemCyan, size: CGSize(width: 220, height: 14))
    private let cpuHealthBar = SKSpriteNode(color: .systemOrange, size: CGSize(width: 220, height: 14))
    private let statusLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let playerName = SKLabelNode(fontNamed: "Menlo-Bold")
    private let cpuName = SKLabelNode(fontNamed: "Menlo-Bold")
    private let roundLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let roundEndOverlay = SKSpriteNode(color: SKColor.black.withAlphaComponent(0.58), size: .zero)
    private let restartButton = SKShapeNode(rectOf: CGSize(width: 190, height: 52), cornerRadius: 12)
    private let restartLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let controls = CombatControlsNode()
    private let haptics = HapticController()

    private var engine = CombatEngine()
    private var cpuController = CPUController()
    private var gameTime: TimeInterval = 0
    private var safeInsets = UIEdgeInsets.zero
    private var didSetUp = false
    private var lastUpdateTime: TimeInterval?
    private var playerArenaPosition = CGPoint.zero
    private var cpuArenaPosition = CGPoint.zero
    private var movementTouches: [ObjectIdentifier: CGVector] = [:]
    private var smoothedPlayerMovement = CGVector.zero
    private var bufferedPlayerPunch: PunchIntent?
    private var bufferedPunchExpiresAt: TimeInterval = 0
    private var pendingPlayerSway = false

    override init(size: CGSize) {
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.035, green: 0.045, blue: 0.075, alpha: 1)
    }

    override convenience init() {
        self.init(size: CGSize(width: 844, height: 390))
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        guard !didSetUp else { return }
        didSetUp = true
        view.isMultipleTouchEnabled = true
        buildScene()
        cpuController.reset(at: gameTime)
        haptics.prepare()
        layoutScene()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        if didSetUp { layoutScene() }
    }

    func updateSafeAreaInsets(_ insets: EdgeInsetsSnapshot) {
        safeInsets = UIEdgeInsets(top: insets.top, left: insets.leading, bottom: insets.bottom, right: insets.trailing)
        if didSetUp { layoutScene() }
    }

    override func update(_ currentTime: TimeInterval) {
        let deltaTime = min(max(currentTime - (lastUpdateTime ?? currentTime), 0), 0.05)
        lastUpdateTime = currentTime
        gameTime = currentTime
        updateMovement(deltaTime: deltaTime)

        if pendingPlayerSway {
            pendingPlayerSway = false
            handle(engine.request(.sway(selectedSwayDirection()), by: .player, at: currentTime))
        }

        let fightersAreInRange = isWithinPunchRange()
        handle(engine.update(at: currentTime, canHit: { _ in fightersAreInRange }))
        processBufferedPunch(at: currentTime)

        if cpuController.shouldPunch(at: currentTime, state: engine.state(for: .cpu)) {
            handle(engine.request(.punch(.neutral), by: .cpu, at: currentTime))
        }
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if engine.winner != nil {
            guard touches.contains(where: { restartButton.frame.contains($0.location(in: self)) }) else { return }
            restartButton.removeAction(forKey: "press")
            restartButton.run(.sequence([
                .scale(to: 0.94, duration: 0.045),
                .scale(to: 1, duration: 0.08),
                .run { [weak self] in self?.resetRound() }
            ]), withKey: "press")
            return
        }

        for touch in touches {
            let input = controls.input(at: touch.location(in: self))
            switch input {
            case let .movement(vector):
                movementTouches[ObjectIdentifier(touch)] = vector
                refreshMovementIndicator()
            case .punch:
                controls.flash(input)
                let intent = playerPunchIntent()
                let events = engine.request(.punch(intent), by: .player, at: gameTime)
                if events.isEmpty {
                    bufferedPlayerPunch = intent
                    bufferedPunchExpiresAt = gameTime + CombatTuning.punchInputBuffer
                } else {
                    bufferedPlayerPunch = nil
                }
                handle(events)
            case .sway:
                controls.flash(input)
                pendingPlayerSway = true
            case .none:
                break
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let identifier = ObjectIdentifier(touch)
            guard movementTouches[identifier] != nil else { continue }
            movementTouches[identifier] = controls.continuedMovement(at: touch.location(in: self))
        }
        refreshMovementIndicator()
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        endMovementTouches(touches)
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        endMovementTouches(touches)
    }

    private func buildScene() {
        addChild(arenaNode)
        arenaNode.addChild(ringNode)
        configureShadow(playerShadow)
        configureShadow(cpuShadow)
        arenaNode.addChild(playerShadow)
        arenaNode.addChild(cpuShadow)
        player.zPosition = 10
        cpu.zPosition = 10
        arenaNode.addChild(player)
        arenaNode.addChild(cpu)

        addHealthBarBackground(for: playerHealthBar)
        addHealthBarBackground(for: cpuHealthBar)
        playerHealthBar.anchorPoint = CGPoint(x: 0, y: 0.5)
        cpuHealthBar.anchorPoint = CGPoint(x: 1, y: 0.5)
        addChild(playerHealthBar)
        addChild(cpuHealthBar)

        statusLabel.fontSize = 26
        statusLabel.fontColor = .white
        statusLabel.verticalAlignmentMode = .center
        statusLabel.zPosition = 20
        addChild(statusLabel)

        configureNameLabel(playerName, text: "PLAYER 01", alignment: .left, color: .systemCyan)
        configureNameLabel(cpuName, text: "CPU RIVAL", alignment: .right, color: .systemOrange)
        roundLabel.text = "ROUND 1"
        roundLabel.fontSize = 11
        roundLabel.fontColor = SKColor.white.withAlphaComponent(0.66)
        roundLabel.horizontalAlignmentMode = .center
        roundLabel.zPosition = 20
        addChild(playerName)
        addChild(cpuName)
        addChild(roundLabel)
        addChild(controls)

        roundEndOverlay.zPosition = 150
        roundEndOverlay.isHidden = true
        addChild(roundEndOverlay)

        restartButton.fillColor = .systemOrange
        restartButton.strokeColor = SKColor.white.withAlphaComponent(0.9)
        restartButton.lineWidth = 2
        restartButton.zPosition = 160
        restartButton.isHidden = true
        addChild(restartButton)

        restartLabel.text = "다시 하기"
        restartLabel.fontSize = 18
        restartLabel.fontColor = .white
        restartLabel.verticalAlignmentMode = .center
        restartLabel.zPosition = 1
        restartButton.addChild(restartLabel)
    }

    private func addHealthBarBackground(for bar: SKSpriteNode) {
        let background = SKSpriteNode(color: SKColor.white.withAlphaComponent(0.13), size: CGSize(width: 228, height: 22))
        background.name = bar === playerHealthBar ? "playerHealthBackground" : "cpuHealthBackground"
        background.zPosition = 9
        addChild(background)
        bar.zPosition = 10
    }

    private func configureShadow(_ shadow: SKShapeNode) {
        shadow.fillColor = .black.withAlphaComponent(0.34)
        shadow.strokeColor = .clear
        shadow.zPosition = 5
    }

    private func configureNameLabel(
        _ label: SKLabelNode,
        text: String,
        alignment: SKLabelHorizontalAlignmentMode,
        color: SKColor
    ) {
        label.text = text
        label.fontSize = 12
        label.fontColor = color
        label.horizontalAlignmentMode = alignment
        label.verticalAlignmentMode = .bottom
        label.zPosition = 20
    }

    private func layoutScene() {
        let left = safeInsets.left + CombatTuning.hudHorizontalPadding
        let right = size.width - safeInsets.right - CombatTuning.hudHorizontalPadding
        let top = size.height - safeInsets.top - CombatTuning.hudTopPadding
        ringNode.rebuild(in: size, safeInsets: EdgeInsetsSnapshot(
            top: safeInsets.top,
            leading: safeInsets.left,
            bottom: safeInsets.bottom,
            trailing: safeInsets.right
        ))

        if playerArenaPosition == .zero || cpuArenaPosition == .zero {
            let nearY = max(safeInsets.bottom + 70, size.height * CombatTuning.ringNearYRatio)
            let farY = size.height * CombatTuning.ringFarYRatio
            playerArenaPosition = CGPoint(x: size.width * 0.30, y: nearY + 8)
            cpuArenaPosition = CGPoint(x: size.width * 0.70, y: farY - 8)
        }
        clampAndRenderFighters()

        childNode(withName: "playerHealthBackground")?.position = CGPoint(x: left + 110, y: top)
        childNode(withName: "cpuHealthBackground")?.position = CGPoint(x: right - 110, y: top)
        playerHealthBar.position = CGPoint(x: left, y: top)
        cpuHealthBar.position = CGPoint(x: right, y: top)
        playerName.position = CGPoint(x: left, y: top - 23)
        cpuName.position = CGPoint(x: right, y: top - 23)
        roundLabel.position = CGPoint(x: size.width / 2, y: top + 1)
        if engine.winner == nil {
            statusLabel.position = CGPoint(x: size.width / 2, y: top - 31)
        } else {
            statusLabel.position = CGPoint(x: size.width / 2, y: size.height * 0.59)
        }

        roundEndOverlay.size = size
        roundEndOverlay.position = CGPoint(x: size.width / 2, y: size.height / 2)
        restartButton.position = CGPoint(x: size.width / 2, y: size.height * 0.43)

        controls.layout(in: size, safeInsets: EdgeInsetsSnapshot(
            top: safeInsets.top,
            leading: safeInsets.left,
            bottom: safeInsets.bottom,
            trailing: safeInsets.right
        ))
    }

    private func updateMovement(deltaTime: TimeInterval) {
        guard engine.winner == nil, deltaTime > 0 else {
            player.updateLocomotion(movement: .zero, deltaTime: deltaTime)
            cpu.updateLocomotion(movement: .zero, deltaTime: deltaTime)
            return
        }

        let phaseMultiplier = playerFootworkMultiplier()
        let targetMovement = combinedMovementVector()
        let movement = smoothMovement(toward: targetMovement, deltaTime: deltaTime)
        let directionMultiplier = directionalFootworkMultiplier(for: movement)
        let movementMultiplier = phaseMultiplier * directionMultiplier
        let playerIsMoving = movementMultiplier > 0 && hypot(movement.dx, movement.dy) > 0.02

        if playerIsMoving {
            playerArenaPosition.x += movement.dx * CombatTuning.playerMoveSpeed * movementMultiplier * deltaTime
            playerArenaPosition.y += movement.dy * CombatTuning.playerDepthMoveSpeed * movementMultiplier * deltaTime
        }

        let cpuCanMove = engine.state(for: .cpu).phase == .idle
        var cpuMovement = CGVector.zero
        if cpuCanMove {
            cpuMovement = cpuController.movement(
                at: gameTime,
                playerPosition: playerArenaPosition,
                cpuPosition: cpuArenaPosition
            )
            cpuArenaPosition.x += cpuMovement.dx * CombatTuning.cpuMoveSpeed * deltaTime
            cpuArenaPosition.y += cpuMovement.dy * CombatTuning.cpuMoveSpeed * deltaTime
        }

        separateFighters()
        clampAndRenderFighters()
        player.updateLocomotion(
            movement: CGVector(dx: movement.dx * movementMultiplier, dy: movement.dy * movementMultiplier),
            deltaTime: deltaTime
        )
        cpu.updateLocomotion(movement: cpuMovement, deltaTime: deltaTime)
    }

    private func combinedMovementVector() -> CGVector {
        let sum = movementTouches.values.reduce(CGVector.zero) { partial, vector in
            CGVector(dx: partial.dx + vector.dx, dy: partial.dy + vector.dy)
        }
        let length = hypot(sum.dx, sum.dy)
        guard length > 0 else { return .zero }
        guard length > 1 else { return sum }
        return CGVector(dx: sum.dx / length, dy: sum.dy / length)
    }

    private func smoothMovement(toward target: CGVector, deltaTime: TimeInterval) -> CGVector {
        let current = smoothedPlayerMovement
        let targetIsIdle = hypot(target.dx, target.dy) < 0.001
        let dot = current.dx * target.dx + current.dy * target.dy
        let response: CGFloat
        if targetIsIdle {
            response = CombatTuning.movementDeceleration
        } else if dot < -0.15 {
            response = CombatTuning.movementTurnAcceleration
        } else {
            response = CombatTuning.movementAcceleration
        }

        let blend = 1 - CGFloat(exp(-Double(response) * deltaTime))
        smoothedPlayerMovement = CGVector(
            dx: current.dx + (target.dx - current.dx) * blend,
            dy: current.dy + (target.dy - current.dy) * blend
        )
        if targetIsIdle, hypot(smoothedPlayerMovement.dx, smoothedPlayerMovement.dy) < 0.015 {
            smoothedPlayerMovement = .zero
        }
        return smoothedPlayerMovement
    }

    private func playerFootworkMultiplier() -> CGFloat {
        switch engine.state(for: .player).phase {
        case .idle:
            return 1
        case .punchStartup:
            return CombatTuning.punchStartupFootworkMultiplier
        case .punchActive:
            return CombatTuning.punchActiveFootworkMultiplier
        case .punchRecovery:
            return CombatTuning.punchRecoveryFootworkMultiplier
        case .swaying:
            return CombatTuning.swayFootworkMultiplier
        case .hit, .knockedOut:
            return 0
        }
    }

    private func directionalFootworkMultiplier(for movement: CGVector) -> CGFloat {
        let movementLength = hypot(movement.dx, movement.dy)
        guard movementLength > 0.001 else { return 1 }

        let towardOpponent = CGVector(
            dx: cpuArenaPosition.x - playerArenaPosition.x,
            dy: cpuArenaPosition.y - playerArenaPosition.y
        )
        let opponentDistance = hypot(towardOpponent.dx, towardOpponent.dy)
        guard opponentDistance > 0.001 else { return 1 }

        let forwardDot = (
            movement.dx / movementLength * towardOpponent.dx / opponentDistance
            + movement.dy / movementLength * towardOpponent.dy / opponentDistance
        )
        if forwardDot >= 0 {
            return CombatTuning.lateralSpeedMultiplier
                + (1 - CombatTuning.lateralSpeedMultiplier) * forwardDot
        }
        return CombatTuning.lateralSpeedMultiplier
            + (CombatTuning.retreatSpeedMultiplier - CombatTuning.lateralSpeedMultiplier) * -forwardDot
    }

    private func separateFighters() {
        let delta = CGVector(
            dx: cpuArenaPosition.x - playerArenaPosition.x,
            dy: cpuArenaPosition.y - playerArenaPosition.y
        )
        let distance = hypot(delta.dx, delta.dy)
        guard distance < CombatTuning.minimumFighterSeparation else { return }

        let direction: CGVector
        if distance > 0.001 {
            direction = CGVector(dx: delta.dx / distance, dy: delta.dy / distance)
        } else {
            direction = CGVector(dx: 1, dy: 0)
        }
        let correction = CombatTuning.minimumFighterSeparation - distance
        playerArenaPosition.x -= direction.dx * correction * 0.5
        playerArenaPosition.y -= direction.dy * correction * 0.5
        cpuArenaPosition.x += direction.dx * correction * 0.5
        cpuArenaPosition.y += direction.dy * correction * 0.5
    }

    private func clampAndRenderFighters() {
        playerArenaPosition = clampedToRing(playerArenaPosition)
        cpuArenaPosition = clampedToRing(cpuArenaPosition)

        player.position = playerArenaPosition
        cpu.position = cpuArenaPosition
        player.orient(toward: CGVector(
            dx: cpuArenaPosition.x - playerArenaPosition.x,
            dy: cpuArenaPosition.y - playerArenaPosition.y
        ))
        cpu.orient(toward: CGVector(
            dx: playerArenaPosition.x - cpuArenaPosition.x,
            dy: playerArenaPosition.y - cpuArenaPosition.y
        ))

        applyPerspective(to: player, shadow: playerShadow, at: playerArenaPosition)
        applyPerspective(to: cpu, shadow: cpuShadow, at: cpuArenaPosition)
    }

    private func clampedToRing(_ position: CGPoint) -> CGPoint {
        let nearY = max(safeInsets.bottom + 70, size.height * CombatTuning.ringNearYRatio)
        let farY = size.height * CombatTuning.ringFarYRatio
        let y = min(max(position.y, nearY), farY)
        let progress = (y - nearY) / max(farY - nearY, 1)
        let nearLeft = safeInsets.left + CombatTuning.ringNearInset
        let nearRight = size.width - safeInsets.right - CombatTuning.ringNearInset
        let farLeft = safeInsets.left + size.width * CombatTuning.ringFarInsetRatio
        let farRight = size.width - safeInsets.right - size.width * CombatTuning.ringFarInsetRatio
        let left = nearLeft + (farLeft - nearLeft) * progress + 22
        let right = nearRight + (farRight - nearRight) * progress - 22
        return CGPoint(x: min(max(position.x, left), right), y: y)
    }

    private func applyPerspective(to fighter: FighterNode, shadow: SKShapeNode, at position: CGPoint) {
        let nearY = max(safeInsets.bottom + 70, size.height * CombatTuning.ringNearYRatio)
        let farY = size.height * CombatTuning.ringFarYRatio
        let progress = min(max((position.y - nearY) / max(farY - nearY, 1), 0), 1)
        let scale = perspectiveScale(at: position)
        fighter.setScale(scale)
        fighter.zPosition = 12 + (1 - progress) * 8

        shadow.position = CGPoint(x: position.x, y: position.y - 2)
        shadow.xScale = scale
        shadow.yScale = scale
        shadow.zPosition = fighter.zPosition - 1
    }

    private func isWithinPunchRange() -> Bool {
        let deltaX = playerArenaPosition.x - cpuArenaPosition.x
        let deltaY = (playerArenaPosition.y - cpuArenaPosition.y) * 1.35
        let averageScale = (perspectiveScale(at: playerArenaPosition) + perspectiveScale(at: cpuArenaPosition)) / 2
        let visibleReach = CombatTuning.punchReachAtUnitScale * averageScale
        return hypot(deltaX, deltaY) <= visibleReach
    }

    private func perspectiveScale(at position: CGPoint) -> CGFloat {
        let nearY = max(safeInsets.bottom + 70, size.height * CombatTuning.ringNearYRatio)
        let farY = size.height * CombatTuning.ringFarYRatio
        let progress = min(max((position.y - nearY) / max(farY - nearY, 1), 0), 1)
        return CombatTuning.nearPerspectiveScale
            + (CombatTuning.farPerspectiveScale - CombatTuning.nearPerspectiveScale) * progress
    }

    private func selectedSwayDirection() -> SwayDirection {
        let movement = combinedMovementVector()
        if movement.dx < -0.25 { return .left }
        if movement.dx > 0.25 { return .right }
        return .back
    }

    private func playerPunchIntent() -> PunchIntent {
        let rawMovement = combinedMovementVector()
        let effectiveMovement = CGVector(
            dx: smoothedPlayerMovement.dx * 0.70 + rawMovement.dx * 0.30,
            dy: smoothedPlayerMovement.dy * 0.70 + rawMovement.dy * 0.30
        )
        let opponentVector = CGVector(
            dx: cpuArenaPosition.x - playerArenaPosition.x,
            dy: cpuArenaPosition.y - playerArenaPosition.y
        )
        let opponentDistance = hypot(opponentVector.dx, opponentVector.dy)
        guard opponentDistance > 0.001 else { return .neutral }

        let forwardX = opponentVector.dx / opponentDistance
        let forwardY = opponentVector.dy / opponentDistance
        let forwardDrive = effectiveMovement.dx * forwardX + effectiveMovement.dy * forwardY
        let lateralDrive = effectiveMovement.dx * -forwardY + effectiveMovement.dy * forwardX
        return PunchIntent(
            forwardDrive: Double(forwardDrive),
            lateralDrive: Double(lateralDrive),
            movementIntensity: Double(min(hypot(effectiveMovement.dx, effectiveMovement.dy), 1))
        )
    }

    private func processBufferedPunch(at time: TimeInterval) {
        guard let intent = bufferedPlayerPunch else { return }
        guard time <= bufferedPunchExpiresAt else {
            bufferedPlayerPunch = nil
            return
        }
        guard engine.state(for: .player).phase == .idle else { return }

        bufferedPlayerPunch = nil
        handle(engine.request(.punch(intent), by: .player, at: time))
    }

    private func refreshMovementIndicator() {
        let movement = combinedMovementVector()
        controls.showMovement(movement == .zero ? nil : movement)
    }

    private func endMovementTouches(_ touches: Set<UITouch>) {
        touches.forEach { movementTouches.removeValue(forKey: ObjectIdentifier($0)) }
        refreshMovementIndicator()
    }

    private func handle(_ events: [CombatEvent]) {
        for event in events {
            switch event {
            case let .phaseChanged(fighter, phase):
                node(for: fighter).show(phase: phase)
            case let .punchStarted(fighter, hand, profile):
                node(for: fighter).preparePunch(hand, profile: profile)
            case let .swayStarted(fighter, direction):
                node(for: fighter).prepareSway(direction)
            case let .hit(_, defender, kind, _):
                node(for: defender).playHit(kind)
                showImpact(kind)
                haptics.playHit(kind)
                if kind == .counter { playCounterFeedback() }
            case .swayed(let defender):
                if defender == .player {
                    statusLabel.text = "COUNTER READY"
                    statusLabel.fontColor = .systemYellow
                    statusLabel.run(.sequence([
                        .fadeAlpha(to: 1, duration: 0.05),
                        .wait(forDuration: CombatTuning.counterReadyDuration),
                        .fadeOut(withDuration: CombatTuning.statusFadeDuration)
                    ]))
                    haptics.playSway()
                }
            case let .healthChanged(fighter, health):
                updateHealth(fighter, health: health)
            case let .roundEnded(winner):
                statusLabel.removeAllActions()
                statusLabel.alpha = 1
                statusLabel.fontColor = .white
                statusLabel.text = winner == .player ? "KO!" : "DOWN!"
                statusLabel.zPosition = 161
                roundEndOverlay.isHidden = false
                restartButton.isHidden = false
                controls.alpha = 0.35
                movementTouches.removeAll()
                smoothedPlayerMovement = .zero
                controls.showMovement(nil)
                layoutScene()
            }
        }
    }

    private func node(for fighter: FighterID) -> FighterNode {
        fighter == .player ? player : cpu
    }

    private func updateHealth(_ fighter: FighterID, health: Int) {
        let fraction = CGFloat(health) / CGFloat(CombatTuning.maximumHealth)
        let bar = fighter == .player ? playerHealthBar : cpuHealthBar
        let action = SKAction.scaleX(to: fraction, duration: CombatTuning.healthBarAnimationDuration)
        action.timingMode = .easeOut
        bar.run(action)
    }

    private func showImpact(_ kind: HitKind) {
        let radius: CGFloat = kind == .counter ? 42 : 24
        let impact = SKShapeNode(circleOfRadius: radius)
        impact.position = CGPoint(x: size.width / 2, y: size.height * 0.52)
        impact.strokeColor = kind == .counter ? .systemYellow : .white
        impact.lineWidth = kind == .counter ? 8 : 4
        impact.zPosition = 30
        impact.setScale(0.25)
        addChild(impact)
        impact.run(.sequence([
            .group([
                .scale(to: 1.45, duration: CombatTuning.impactAnimationDuration),
                .fadeOut(withDuration: CombatTuning.impactAnimationDuration)
            ]),
            .removeFromParent()
        ]))
    }

    private func playCounterFeedback() {
        statusLabel.removeAllActions()
        statusLabel.alpha = 1
        statusLabel.fontColor = .systemYellow
        statusLabel.text = "HARD COUNTER"
        statusLabel.setScale(1.35)
        statusLabel.run(.sequence([
            .scale(to: 1, duration: CombatTuning.counterTitleInDuration),
            .wait(forDuration: CombatTuning.counterTitleHoldDuration),
            .fadeOut(withDuration: CombatTuning.counterTitleOutDuration)
        ]))

        arenaNode.speed = 0
        run(.sequence([
            .wait(forDuration: CombatTuning.counterHitStop),
            .run { [weak self] in self?.arenaNode.speed = 1 }
        ]), withKey: "hitStop")

        let distance = CombatTuning.cameraShakeDistance
        arenaNode.run(.sequence([
            .moveBy(x: distance, y: 2, duration: CombatTuning.cameraShakeDuration * 0.175),
            .moveBy(x: -distance * 2, y: -4, duration: CombatTuning.cameraShakeDuration * 0.25),
            .moveBy(x: distance * 1.5, y: 3, duration: CombatTuning.cameraShakeDuration * 0.225),
            .move(to: .zero, duration: CombatTuning.cameraShakeDuration * 0.35)
        ]), withKey: "shake")
    }

    private func resetRound() {
        removeAction(forKey: "hitStop")
        arenaNode.speed = 1
        arenaNode.position = .zero
        player.resetPose()
        cpu.resetPose()
        playerArenaPosition = .zero
        cpuArenaPosition = .zero
        movementTouches.removeAll()
        smoothedPlayerMovement = .zero
        bufferedPlayerPunch = nil
        bufferedPunchExpiresAt = 0
        pendingPlayerSway = false
        controls.showMovement(nil)
        handle(engine.reset())
        cpuController.reset(at: gameTime)
        statusLabel.removeAllActions()
        statusLabel.text = nil
        statusLabel.alpha = 1
        statusLabel.zPosition = 20
        roundEndOverlay.isHidden = true
        restartButton.isHidden = true
        controls.alpha = 1
        playerHealthBar.xScale = 1
        cpuHealthBar.xScale = 1
        layoutScene()
        haptics.prepare()
    }
}

struct EdgeInsetsSnapshot: Equatable {
    let top: CGFloat
    let leading: CGFloat
    let bottom: CGFloat
    let trailing: CGFloat
}
