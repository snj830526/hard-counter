import SpriteKit
import UIKit

final class CombatScene: SKScene {
    private let cameraRig = SKNode()
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
    private var ringProjection = QuarterViewProjection(
        size: CGSize(width: 844, height: 390),
        safeInsets: EdgeInsetsSnapshot(top: 0, leading: 0, bottom: 0, trailing: 0)
    )
    private var didSetUp = false
    private var lastUpdateTime: TimeInterval?
    private var playerArenaPosition = CGPoint.zero
    private var cpuArenaPosition = CGPoint.zero
    private var movementTouchID: ObjectIdentifier?
    private var movementVector = CGVector.zero
    private var smoothedPlayerMovement = CGVector.zero
    private var bufferedPlayerPunch: PunchIntent?
    private var bufferedPunchExpiresAt: TimeInterval = 0
    private let arenaZoom: CGFloat = 2.20

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

        let playerCanHit = isWithinPunchRange(for: .player)
        let cpuCanHit = isWithinPunchRange(for: .cpu)
        handle(engine.update(at: currentTime, canHit: { fighter in
            fighter == .player ? playerCanHit : cpuCanHit
        }))
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
            let location = touch.location(in: self)
            let input = controls.input(at: location)
            switch input {
            case .movement:
                guard movementTouchID == nil else { continue }
                movementTouchID = ObjectIdentifier(touch)
                movementVector = controls.beginMovement(at: location)
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
                handle(engine.request(.sway(selectedSwayIntent()), by: .player, at: gameTime))
            case .none:
                break
            }
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let identifier = ObjectIdentifier(touch)
            guard movementTouchID == identifier else { continue }
            let latestTouch = event?.coalescedTouches(for: touch)?.last ?? touch
            movementVector = controls.continuedMovement(at: latestTouch.location(in: self))
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
        addChild(cameraRig)
        cameraRig.addChild(arenaNode)
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
        let insetSnapshot = EdgeInsetsSnapshot(
            top: safeInsets.top,
            leading: safeInsets.left,
            bottom: safeInsets.bottom,
            trailing: safeInsets.right
        )
        ringProjection = QuarterViewProjection(size: size, safeInsets: insetSnapshot)
        ringNode.rebuild(in: size, projection: ringProjection)

        if playerArenaPosition == .zero || cpuArenaPosition == .zero {
            playerArenaPosition = CGPoint(x: -210, y: -40)
            cpuArenaPosition = CGPoint(x: 210, y: 40)
        }
        clampAndRenderFighters()
        positionCameraImmediately()

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

        controls.layout(in: size, safeInsets: insetSnapshot)
    }

    private func updateMovement(deltaTime: TimeInterval) {
        guard engine.winner == nil, deltaTime > 0 else {
            player.updateLocomotion(movement: .zero, deltaTime: deltaTime)
            cpu.updateLocomotion(movement: .zero, deltaTime: deltaTime)
            return
        }

        let phaseMultiplier = playerFootworkMultiplier()
        let targetMovement = combinedMovementVector()
        let screenMovement = smoothMovement(toward: targetMovement, deltaTime: deltaTime)
        let worldMovement = ringProjection.worldDirection(forScreenVector: screenMovement)
        let directionMultiplier = directionalFootworkMultiplier(for: worldMovement)
        let movementMultiplier = phaseMultiplier * directionMultiplier
        let playerIsMoving = movementMultiplier > 0 && hypot(worldMovement.dx, worldMovement.dy) > 0.02

        if playerIsMoving {
            playerArenaPosition.x += worldMovement.dx * CombatTuning.playerMoveSpeed * movementMultiplier * deltaTime
            playerArenaPosition.y += worldMovement.dy * CombatTuning.playerDepthMoveSpeed * movementMultiplier * deltaTime
        }

        let cpuCanMove = engine.state(for: .cpu).phase == .idle
        var cpuMovement = CGVector.zero
        if cpuCanMove {
            cpuMovement = cpuController.movement(
                at: gameTime,
                playerPosition: playerArenaPosition,
                cpuPosition: cpuArenaPosition,
                visibleDistance: visibleFighterDistance(),
                preferredPunchRange: baseVisiblePunchReach(for: .cpu)
            )
            cpuArenaPosition.x += cpuMovement.dx * CombatTuning.cpuMoveSpeed * deltaTime
            cpuArenaPosition.y += cpuMovement.dy * CombatTuning.cpuMoveSpeed * deltaTime
        }

        clampAndRenderFighters()
        updateCamera(deltaTime: deltaTime)
        player.updateLocomotion(
            movement: CGVector(dx: screenMovement.dx * movementMultiplier, dy: screenMovement.dy * movementMultiplier),
            deltaTime: deltaTime
        )
        cpu.updateLocomotion(movement: ringProjection.screenVector(forWorldVector: cpuMovement), deltaTime: deltaTime)
    }

    private func combinedMovementVector() -> CGVector {
        movementVector
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
        let projectedDelta = ringProjection.screenVector(forWorldVector: delta)
        let screenDistance = hypot(projectedDelta.dx, projectedDelta.dy) * arenaZoom
        guard screenDistance < CombatTuning.minimumFighterScreenSeparation else { return }

        let direction: CGVector
        if distance > 0.001 {
            direction = CGVector(dx: delta.dx / distance, dy: delta.dy / distance)
        } else {
            direction = CGVector(dx: 1, dy: 0)
        }
        let projectedUnit = ringProjection.screenVector(forWorldVector: direction)
        let screenPointsPerWorldPoint = hypot(projectedUnit.dx, projectedUnit.dy) * arenaZoom
        guard screenPointsPerWorldPoint > 0.001 else { return }
        let targetWorldDistance = CombatTuning.minimumFighterScreenSeparation / screenPointsPerWorldPoint
        let correction = max(targetWorldDistance - distance, 0)
        playerArenaPosition = clampedToRing(CGPoint(
            x: playerArenaPosition.x - direction.dx * correction * 0.5,
            y: playerArenaPosition.y - direction.dy * correction * 0.5
        ))
        cpuArenaPosition = clampedToRing(CGPoint(
            x: cpuArenaPosition.x + direction.dx * correction * 0.5,
            y: cpuArenaPosition.y + direction.dy * correction * 0.5
        ))

        let correctedDelta = CGVector(
            dx: cpuArenaPosition.x - playerArenaPosition.x,
            dy: cpuArenaPosition.y - playerArenaPosition.y
        )
        let correctedScreenDelta = ringProjection.screenVector(forWorldVector: correctedDelta)
        let correctedScreenDistance = hypot(correctedScreenDelta.dx, correctedScreenDelta.dy) * arenaZoom
        let remaining = max(
            (CombatTuning.minimumFighterScreenSeparation - correctedScreenDistance) / screenPointsPerWorldPoint,
            0
        )
        guard remaining > 0.001 else { return }

        playerArenaPosition = clampedToRing(CGPoint(
            x: playerArenaPosition.x - direction.dx * remaining,
            y: playerArenaPosition.y - direction.dy * remaining
        ))
        let finalDelta = CGVector(
            dx: cpuArenaPosition.x - playerArenaPosition.x,
            dy: cpuArenaPosition.y - playerArenaPosition.y
        )
        let finalScreenDelta = ringProjection.screenVector(forWorldVector: finalDelta)
        let finalScreenDistance = hypot(finalScreenDelta.dx, finalScreenDelta.dy) * arenaZoom
        let finalRemaining = max(
            (CombatTuning.minimumFighterScreenSeparation - finalScreenDistance) / screenPointsPerWorldPoint,
            0
        )
        if finalRemaining > 0.001 {
            cpuArenaPosition = clampedToRing(CGPoint(
                x: cpuArenaPosition.x + direction.dx * finalRemaining,
                y: cpuArenaPosition.y + direction.dy * finalRemaining
            ))
        }
    }

    private func clampAndRenderFighters() {
        playerArenaPosition = clampedToRing(playerArenaPosition)
        cpuArenaPosition = clampedToRing(cpuArenaPosition)
        separateFighters()

        let playerScreenPosition = ringProjection.project(playerArenaPosition)
        let cpuScreenPosition = ringProjection.project(cpuArenaPosition)
        let playerToCPU = ringProjection.screenVector(forWorldVector: CGVector(
            dx: cpuArenaPosition.x - playerArenaPosition.x,
            dy: cpuArenaPosition.y - playerArenaPosition.y
        ))

        player.position = playerScreenPosition
        cpu.position = cpuScreenPosition
        player.orient(toward: playerToCPU)
        cpu.orient(toward: CGVector(dx: -playerToCPU.dx, dy: -playerToCPU.dy))

        applyPerspective(to: player, shadow: playerShadow, worldPosition: playerArenaPosition, screenPosition: playerScreenPosition)
        applyPerspective(to: cpu, shadow: cpuShadow, worldPosition: cpuArenaPosition, screenPosition: cpuScreenPosition)
    }

    private func clampedToRing(_ position: CGPoint) -> CGPoint {
        ringProjection.clamped(position)
    }

    private func cameraFocusPoint() -> CGPoint {
        CGPoint(
            x: player.position.x * 0.65 + cpu.position.x * 0.35,
            y: player.position.y * 0.65 + cpu.position.y * 0.35
        )
    }

    private func positionCameraImmediately() {
        cameraRig.setScale(arenaZoom)
        let focus = cameraFocusPoint()
        let target = CGPoint(x: size.width * 0.5, y: size.height * 0.43)
        cameraRig.position = clampedCameraPosition(CGPoint(
            x: target.x - focus.x * arenaZoom,
            y: target.y - focus.y * arenaZoom
        ))
    }

    private func updateCamera(deltaTime: TimeInterval) {
        guard deltaTime > 0 else { return }
        let focus = cameraFocusPoint()
        let focusOnScreen = CGPoint(
            x: focus.x * arenaZoom + cameraRig.position.x,
            y: focus.y * arenaZoom + cameraRig.position.y
        )
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.43)
        let deadZone = CGSize(width: size.width * 0.15, height: size.height * 0.13)
        var correction = CGVector.zero
        if focusOnScreen.x < center.x - deadZone.width { correction.dx = center.x - deadZone.width - focusOnScreen.x }
        if focusOnScreen.x > center.x + deadZone.width { correction.dx = center.x + deadZone.width - focusOnScreen.x }
        if focusOnScreen.y < center.y - deadZone.height { correction.dy = center.y - deadZone.height - focusOnScreen.y }
        if focusOnScreen.y > center.y + deadZone.height { correction.dy = center.y + deadZone.height - focusOnScreen.y }
        guard correction != .zero else { return }

        let target = clampedCameraPosition(CGPoint(
            x: cameraRig.position.x + correction.dx,
            y: cameraRig.position.y + correction.dy
        ))
        let blend = 1 - CGFloat(exp(-5.5 * deltaTime))
        cameraRig.position = CGPoint(
            x: cameraRig.position.x + (target.x - cameraRig.position.x) * blend,
            y: cameraRig.position.y + (target.y - cameraRig.position.y) * blend
        )
    }

    private func clampedCameraPosition(_ position: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(position.x, -size.width * 0.74), size.width * 0.68),
            y: min(max(position.y, -size.height * 0.68), size.height * 0.58)
        )
    }

    private func applyPerspective(
        to fighter: FighterNode,
        shadow: SKShapeNode,
        worldPosition: CGPoint,
        screenPosition: CGPoint
    ) {
        let progress = ringProjection.depthProgress(at: worldPosition)
        let scale = perspectiveScale(at: worldPosition) / arenaZoom
        fighter.setScale(scale)
        fighter.zPosition = 12 + (1 - progress) * 16

        shadow.position = CGPoint(x: screenPosition.x, y: screenPosition.y - 2)
        shadow.xScale = scale
        shadow.yScale = scale
        shadow.zPosition = fighter.zPosition - 1
    }

    private func isWithinPunchRange(for attacker: FighterID) -> Bool {
        let profile = engine.state(for: attacker).activePunchProfile
        let motionReachScale: CGFloat
        switch profile.motion {
        case .quick:
            motionReachScale = 1
        case .retreating:
            motionReachScale = CombatTuning.retreatingPunchReachScale
        case .driving:
            motionReachScale = CombatTuning.drivingPunchReachScale
        case .counter:
            motionReachScale = CombatTuning.counterPunchReachScale
        }
        return visibleFighterDistance() <= baseVisiblePunchReach(for: attacker) * motionReachScale
    }

    private func visibleFighterDistance() -> CGFloat {
        let delta = CGVector(
            dx: cpuArenaPosition.x - playerArenaPosition.x,
            dy: cpuArenaPosition.y - playerArenaPosition.y
        )
        let projectedDelta = ringProjection.screenVector(forWorldVector: delta)
        return hypot(projectedDelta.dx, projectedDelta.dy) * arenaZoom
    }

    private func baseVisiblePunchReach(for attacker: FighterID) -> CGFloat {
        let attackerPosition = attacker == .player ? playerArenaPosition : cpuArenaPosition
        let defenderPosition = attacker == .player ? cpuArenaPosition : playerArenaPosition
        let attackerScale = perspectiveScale(at: attackerPosition)
        let defenderScale = perspectiveScale(at: defenderPosition)
        let averageScale = attackerScale * 0.72 + defenderScale * 0.28
        return CombatTuning.punchReachAtUnitScale * averageScale
    }

    private func perspectiveScale(at position: CGPoint) -> CGFloat {
        let progress = ringProjection.depthProgress(at: position)
        return CombatTuning.nearPerspectiveScale
            + (CombatTuning.farPerspectiveScale - CombatTuning.nearPerspectiveScale) * progress
    }

    private func selectedSwayIntent() -> SwayIntent {
        SwayInputResolver.resolve(
            movement: combinedMovementVector(),
            towardOpponent: ringProjection.screenVector(forWorldVector: CGVector(
                dx: cpuArenaPosition.x - playerArenaPosition.x,
                dy: cpuArenaPosition.y - playerArenaPosition.y
            ))
        )
    }

    private func playerPunchIntent() -> PunchIntent {
        let rawMovement = combinedMovementVector()
        let effectiveMovement = CGVector(
            dx: smoothedPlayerMovement.dx * 0.70 + rawMovement.dx * 0.30,
            dy: smoothedPlayerMovement.dy * 0.70 + rawMovement.dy * 0.30
        )
        let worldMovement = ringProjection.worldDirection(forScreenVector: effectiveMovement)
        let opponentVector = CGVector(
            dx: cpuArenaPosition.x - playerArenaPosition.x,
            dy: cpuArenaPosition.y - playerArenaPosition.y
        )
        let opponentDistance = hypot(opponentVector.dx, opponentVector.dy)
        guard opponentDistance > 0.001 else { return .neutral }

        let forwardX = opponentVector.dx / opponentDistance
        let forwardY = opponentVector.dy / opponentDistance
        let forwardDrive = worldMovement.dx * forwardX + worldMovement.dy * forwardY
        let lateralDrive = worldMovement.dx * -forwardY + worldMovement.dy * forwardX
        return PunchIntent(
            forwardDrive: Double(forwardDrive),
            lateralDrive: Double(lateralDrive),
            movementIntensity: Double(min(hypot(worldMovement.dx, worldMovement.dy), 1))
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
        guard touches.contains(where: { ObjectIdentifier($0) == movementTouchID }) else { return }
        movementTouchID = nil
        movementVector = .zero
        controls.endMovement()
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
                movementTouchID = nil
                movementVector = .zero
                controls.endMovement()
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
        let averageScale = (player.xScale + cpu.xScale) / 2
        impact.position = CGPoint(
            x: (player.position.x + cpu.position.x) / 2,
            y: (player.position.y + cpu.position.y) / 2 + 66 * averageScale
        )
        impact.strokeColor = kind == .counter ? .systemYellow : .white
        impact.lineWidth = kind == .counter ? 8 : 4
        impact.zPosition = 30
        impact.setScale(0.25 / arenaZoom)
        arenaNode.addChild(impact)
        impact.run(.sequence([
            .group([
                .scale(to: 1.45 / arenaZoom, duration: CombatTuning.impactAnimationDuration),
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

        let distance = CombatTuning.cameraShakeDistance / arenaZoom
        let verticalDistance: CGFloat = 2 / arenaZoom
        arenaNode.run(.sequence([
            .moveBy(x: distance, y: verticalDistance, duration: CombatTuning.cameraShakeDuration * 0.175),
            .moveBy(x: -distance * 2, y: -verticalDistance * 2, duration: CombatTuning.cameraShakeDuration * 0.25),
            .moveBy(x: distance * 1.5, y: verticalDistance * 1.5, duration: CombatTuning.cameraShakeDuration * 0.225),
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
        movementTouchID = nil
        movementVector = .zero
        controls.endMovement()
        smoothedPlayerMovement = .zero
        bufferedPlayerPunch = nil
        bufferedPunchExpiresAt = 0
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
