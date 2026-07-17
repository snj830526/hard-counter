import SpriteKit
import UIKit

final class CombatScene: SKScene {
    private let fighterProfile: FighterProfile
    private let opponentProfile: FighterProfile?
    private let networkConfiguration: NearbyMatchConfiguration?
    private weak var nearbyService: NearbyLobbyService?
    private let cameraRig = SKNode()
    private let arenaNode = SKNode()
    private let ringNode = BoxingRingNode()
    private lazy var player = FighterNode(
        facingRight: true,
        appearance: fighterProfile.appearance
    )
    private lazy var cpu = FighterNode(
        facingRight: false,
        appearance: opponentProfile?.appearance ?? .cpuRival
    )
    private let playerShadow = SKShapeNode(ellipseOf: CGSize(width: 84, height: 18))
    private let cpuShadow = SKShapeNode(ellipseOf: CGSize(width: 84, height: 18))
    private lazy var playerHealthBar = SKSpriteNode(color: fighterProfile.color, size: CGSize(width: 220, height: 14))
    private lazy var cpuHealthBar = SKSpriteNode(
        color: opponentProfile?.color ?? .systemOrange,
        size: CGSize(width: 220, height: 14)
    )
    private let playerStaminaBar = SKSpriteNode(color: .systemGreen, size: CGSize(width: 220, height: 6))
    private let cpuStaminaBar = SKSpriteNode(color: .systemGreen, size: CGSize(width: 220, height: 6))
    private let statusLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let playerName = SKLabelNode(fontNamed: "Menlo-Bold")
    private let cpuName = SKLabelNode(fontNamed: "Menlo-Bold")
    private let roundLabel = SKLabelNode(fontNamed: "Menlo-Bold")
    private let roundEndOverlay = SKSpriteNode(color: SKColor.black.withAlphaComponent(0.58), size: .zero)
    private let restartButton = SKShapeNode(rectOf: CGSize(width: 190, height: 52), cornerRadius: 12)
    private let restartLabel = SKLabelNode(fontNamed: "AvenirNext-Heavy")
    private let controls = CombatControlsNode()
    private let haptics = HapticController()

    private lazy var engine = CombatEngine(
        playerStats: fighterProfile.stats,
        cpuStats: opponentProfile?.stats ?? .standard
    )
    private lazy var localInputSource = LocalInputSource(
        fighter: networkConfiguration?.localFighterID ?? .player
    )
    private var cpuInputSource = CPUInputSource()
    private var gameTime: TimeInterval = 0
    private var remoteMovement = CGVector.zero
    private var lastRemoteInputSequence: UInt64 = 0
    private var networkStateSequence: UInt64 = 0
    private var lastNetworkMovementSentAt: TimeInterval = -.infinity
    private var lastNetworkStateSentAt: TimeInterval = -.infinity
    private var countdownEndsAt: TimeInterval?
    private var hasCompletedCountdown = false
    private var localRematchAccepted = false
    private var remoteRematchAccepted = false
    private var safeInsets = UIEdgeInsets.zero
    private var ringProjection = QuarterViewProjection(
        size: CGSize(width: 844, height: 390),
        safeInsets: EdgeInsetsSnapshot(top: 0, leading: 0, bottom: 0, trailing: 0)
    )
    private var didSetUp = false
    private var lastUpdateTime: TimeInterval?
    private var playerArenaPosition = CGPoint.zero
    private var cpuArenaPosition = CGPoint.zero
    private var playerToCPUScreenDirection = CGVector(dx: 1, dy: 0)
    private var playerMovementSmoother = MovementSmoother(
        acceleration: CombatTuning.movementAcceleration,
        turnAcceleration: CombatTuning.movementTurnAcceleration,
        deceleration: CombatTuning.movementDeceleration,
        turnDotThreshold: -0.15,
        idleThreshold: 0.015
    )
    private var cpuMovementSmoother = MovementSmoother(
        acceleration: CombatTuning.cpuMovementAcceleration,
        turnAcceleration: CombatTuning.cpuMovementTurnAcceleration,
        deceleration: CombatTuning.cpuMovementDeceleration,
        turnDotThreshold: -0.12,
        idleThreshold: 0.012
    )
    private let arenaZoom: CGFloat = 2.20
#if DEBUG
    private let motionShowcaseEnabled = ProcessInfo.processInfo.arguments.contains("--motion-showcase")
    private let swayShowcaseEnabled = ProcessInfo.processInfo.arguments.contains("--sway-showcase")
    private let impactShowcaseEnabled = ProcessInfo.processInfo.arguments.contains("--impact-showcase")
    private var motionShowcaseController = MotionShowcaseController()
    private var swayShowcaseController = SwayShowcaseController()
#endif

    init(size: CGSize, fighter: FighterProfile) {
        fighterProfile = fighter
        opponentProfile = nil
        networkConfiguration = nil
        nearbyService = nil
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.035, green: 0.045, blue: 0.075, alpha: 1)
    }

    init(
        size: CGSize = CGSize(width: 844, height: 390),
        networkConfiguration: NearbyMatchConfiguration,
        service: NearbyLobbyService
    ) {
        fighterProfile = networkConfiguration.hostFighter
        opponentProfile = networkConfiguration.guestFighter
        self.networkConfiguration = networkConfiguration
        nearbyService = service
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = SKColor(red: 0.035, green: 0.045, blue: 0.075, alpha: 1)
    }

    override convenience init(size: CGSize) {
        self.init(size: size, fighter: .allRounder)
    }

    convenience init(fighter: FighterProfile) {
        self.init(size: CGSize(width: 844, height: 390), fighter: fighter)
    }

    override convenience init() {
        self.init(size: CGSize(width: 844, height: 390), fighter: .allRounder)
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) { nil }

    override func didMove(to view: SKView) {
        guard !didSetUp else { return }
        didSetUp = true
        view.isMultipleTouchEnabled = true
        buildScene()
        attachNetworkHandlers()
        cpuInputSource.reset(at: gameTime)
#if DEBUG
        motionShowcaseController.reset(at: gameTime)
        swayShowcaseController.reset(at: gameTime)
#endif
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
        if lastUpdateTime == nil {
            cpuInputSource.reset(at: currentTime)
#if DEBUG
            motionShowcaseController.reset(at: currentTime)
            swayShowcaseController.reset(at: currentTime)
#endif
        }
        let deltaTime = min(max(currentTime - (lastUpdateTime ?? currentTime), 0), 0.05)
        lastUpdateTime = currentTime
        gameTime = currentTime
        if networkConfiguration != nil {
            if !hasCompletedCountdown, countdownEndsAt == nil { countdownEndsAt = currentTime + 3 }
            if let countdownEndsAt, currentTime < countdownEndsAt {
                showCountdown(remaining: countdownEndsAt - currentTime)
                return
            }
            if countdownEndsAt != nil {
                self.countdownEndsAt = nil
                hasCompletedCountdown = true
                controls.alpha = 1
                statusLabel.text = "FIGHT!"
                statusLabel.fontColor = .systemYellow
                statusLabel.run(.sequence([.wait(forDuration: 0.45), .fadeOut(withDuration: 0.2)]))
            }
        }
        updateMovement(deltaTime: deltaTime)

        let canResolveDamage = networkConfiguration?.role != .guest
        let playerCanHit = canResolveDamage && isWithinPunchRange(for: .player)
        let cpuCanHit = canResolveDamage && isWithinPunchRange(for: .cpu)
        handle(engine.update(at: currentTime, canHit: { fighter in
            fighter == .player ? playerCanHit : cpuCanHit
        }))
        processBufferedPunch(at: currentTime)

#if DEBUG
        if networkConfiguration != nil {
            updateNetworkCombat(at: currentTime)
        } else if swayShowcaseEnabled {
            updateSwayShowcase(at: currentTime)
        } else if motionShowcaseEnabled || impactShowcaseEnabled {
            updateMotionShowcase(at: currentTime)
        } else {
            updateCPUCombat(at: currentTime)
        }
#else
        if networkConfiguration != nil {
            updateNetworkCombat(at: currentTime)
        } else {
            updateCPUCombat(at: currentTime)
        }
#endif
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        if engine.winner != nil {
            guard touches.contains(where: { restartButton.frame.contains($0.location(in: self)) }) else { return }
            if networkConfiguration != nil {
                nearbyService?.setRematchAccepted(!localRematchAccepted)
                return
            }
            restartButton.removeAction(forKey: "press")
            restartButton.run(.sequence([
                .scale(to: 0.94, duration: 0.045),
                .scale(to: 1, duration: 0.08),
                .run { [weak self] in
                    guard let self else { return }
                    self.resetRound()
                }
            ]), withKey: "press")
            return
        }
        guard countdownEndsAt == nil else { return }

        // UIKit delivers simultaneous touches as a Set. Resolve SWAY before
        // PUNCH so a near-simultaneous two-button chain is deterministic and
        // the punch enters the sway buffer instead of randomly starting first.
        let orderedTouches = touches.sorted {
            inputPriority(controls.input(at: $0.location(in: self)))
                < inputPriority(controls.input(at: $1.location(in: self)))
        }
        for touch in orderedTouches {
            let location = touch.location(in: self)
            let input = controls.input(at: location)
            switch input {
            case .movement:
                guard localInputSource.beginMovement(
                    touchID: ObjectIdentifier(touch)
                ) else { continue }
                let vector = controls.beginMovement(at: location)
                localInputSource.updateMovement(
                    touchID: ObjectIdentifier(touch),
                    vector: vector,
                    at: gameTime
                )
                refreshMovementIndicator()
            case .punch:
                controls.flash(input)
                executeLocal(localInputSource.actionCommand(
                    .punch(playerPunchIntent()),
                    at: gameTime
                ))
            case .sway:
                controls.flash(input)
                executeLocal(localInputSource.actionCommand(
                    .sway(selectedSwayIntent()),
                    at: gameTime
                ))
            case .none:
                break
            }
        }
    }

    private func inputPriority(_ input: CombatControlInput) -> Int {
        switch input {
        case .movement: return 0
        case .sway: return 1
        case .punch: return 2
        case .none: return 3
        }
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        for touch in touches {
            let identifier = ObjectIdentifier(touch)
            let latestTouch = event?.coalescedTouches(for: touch)?.last ?? touch
            localInputSource.updateMovement(
                touchID: identifier,
                vector: controls.continuedMovement(at: latestTouch.location(in: self)),
                at: gameTime
            )
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
        addStaminaBarBackground(for: playerStaminaBar, name: "playerStaminaBackground")
        addStaminaBarBackground(for: cpuStaminaBar, name: "cpuStaminaBackground")
        playerHealthBar.anchorPoint = CGPoint(x: 0, y: 0.5)
        cpuHealthBar.anchorPoint = CGPoint(x: 1, y: 0.5)
        playerStaminaBar.anchorPoint = CGPoint(x: 0, y: 0.5)
        cpuStaminaBar.anchorPoint = CGPoint(x: 1, y: 0.5)
        addChild(playerHealthBar)
        addChild(cpuHealthBar)
        addChild(playerStaminaBar)
        addChild(cpuStaminaBar)

        statusLabel.fontSize = 26
        statusLabel.fontColor = .white
        statusLabel.verticalAlignmentMode = .center
        statusLabel.zPosition = 20
        addChild(statusLabel)

        configureNameLabel(
            playerName,
            text: networkConfiguration?.hostName ?? fighterProfile.name,
            alignment: .left,
            color: fighterProfile.color
        )
        configureNameLabel(
            cpuName,
            text: networkConfiguration?.guestName ?? "CPU RIVAL",
            alignment: .right,
            color: opponentProfile?.color ?? .systemOrange
        )
        roundLabel.text = networkConfiguration == nil ? "ROUND 1" : "NEARBY · ROUND 1"
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

    private func addStaminaBarBackground(for bar: SKSpriteNode, name: String) {
        let background = SKSpriteNode(
            color: SKColor.white.withAlphaComponent(0.11),
            size: CGSize(width: 228, height: 10)
        )
        background.name = name
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
#if DEBUG
            if impactShowcaseEnabled {
                playerArenaPosition = CGPoint(x: -22, y: 0)
                cpuArenaPosition = CGPoint(x: 22, y: 0)
            } else {
                playerArenaPosition = CGPoint(x: -210, y: -40)
                cpuArenaPosition = CGPoint(x: 210, y: 40)
            }
#else
            playerArenaPosition = CGPoint(x: -210, y: -40)
            cpuArenaPosition = CGPoint(x: 210, y: 40)
#endif
        }
        clampAndRenderFighters()
        updateFighterMotion(
            playerMovement: .zero,
            cpuMovement: .zero,
            previousPlayerPosition: player.position,
            previousCPUPosition: cpu.position,
            deltaTime: 0
        )
        positionCameraImmediately()

        childNode(withName: "playerHealthBackground")?.position = CGPoint(x: left + 110, y: top)
        childNode(withName: "cpuHealthBackground")?.position = CGPoint(x: right - 110, y: top)
        childNode(withName: "playerStaminaBackground")?.position = CGPoint(x: left + 110, y: top - 18)
        childNode(withName: "cpuStaminaBackground")?.position = CGPoint(x: right - 110, y: top - 18)
        playerHealthBar.position = CGPoint(x: left, y: top)
        cpuHealthBar.position = CGPoint(x: right, y: top)
        playerStaminaBar.position = CGPoint(x: left, y: top - 18)
        cpuStaminaBar.position = CGPoint(x: right, y: top - 18)
        playerName.position = CGPoint(x: left, y: top - 34)
        cpuName.position = CGPoint(x: right, y: top - 34)
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
            player.updateMotion(
                .stationary(towardOpponent: playerToCPUScreenDirection),
                deltaTime: deltaTime
            )
            cpu.updateMotion(
                .stationary(towardOpponent: CGVector(
                    dx: -playerToCPUScreenDirection.dx,
                    dy: -playerToCPUScreenDirection.dy
                )),
                deltaTime: deltaTime
            )
            return
        }

        let previousPlayerScreenPosition = player.position
        let previousCPUScreenPosition = cpu.position

        let localMovement = localInputSource.movementCommand(at: gameTime).movementVector ?? .zero
        let targetMovement: CGVector
        if let networkConfiguration {
            targetMovement = networkConfiguration.localFighterID == .player ? localMovement : remoteMovement
        } else {
            targetMovement = localMovement
        }
        let phaseMultiplier = footworkMultiplier(for: .player)
        let screenMovement = playerMovementSmoother.update(
            toward: targetMovement,
            deltaTime: deltaTime
        )
        let worldMovement = ringProjection.worldDirection(forScreenVector: screenMovement)
        let directionMultiplier = directionalFootworkMultiplier(for: worldMovement)
        let movementMultiplier = phaseMultiplier * directionMultiplier
            * staminaFootworkMultiplier(for: .player)
            * fighterProfile.stats.movementSpeedMultiplier
        let playerIsMoving = movementMultiplier > 0 && hypot(worldMovement.dx, worldMovement.dy) > 0.02

        if playerIsMoving {
            playerArenaPosition.x += worldMovement.dx * CombatTuning.playerMoveSpeed * movementMultiplier * deltaTime
            playerArenaPosition.y += worldMovement.dy * CombatTuning.playerDepthMoveSpeed * movementMultiplier * deltaTime
        }

        let cpuCanMove = networkConfiguration != nil
            ? footworkMultiplier(for: .cpu) > 0
            : engine.state(for: .cpu).phase == .idle && !isMotionShowcaseEnabled
        var cpuTargetMovement = CGVector.zero
        if let networkConfiguration {
            cpuTargetMovement = networkConfiguration.localFighterID == .cpu ? localMovement : remoteMovement
        } else if cpuCanMove {
            cpuTargetMovement = cpuInputSource
                .movementCommand(for: cpuPerception(at: gameTime))
                .movementVector ?? .zero
        }
        let cpuMovement = cpuMovementSmoother.update(
            toward: cpuTargetMovement,
            deltaTime: deltaTime
        )
        if cpuCanMove {
            let staminaMultiplier = staminaFootworkMultiplier(for: .cpu)
            if networkConfiguration != nil {
                let cpuWorldMovement = ringProjection.worldDirection(forScreenVector: cpuMovement)
                let multiplier = footworkMultiplier(for: .cpu)
                    * directionalFootworkMultiplier(for: cpuWorldMovement, fighter: .cpu)
                    * staminaMultiplier
                    * (opponentProfile?.stats.movementSpeedMultiplier ?? 1)
                cpuArenaPosition.x += cpuWorldMovement.dx * CombatTuning.playerMoveSpeed * multiplier * deltaTime
                cpuArenaPosition.y += cpuWorldMovement.dy * CombatTuning.playerDepthMoveSpeed * multiplier * deltaTime
            } else {
                cpuArenaPosition.x += cpuMovement.dx * CombatTuning.cpuMoveSpeed
                    * staminaMultiplier * deltaTime
                cpuArenaPosition.y += cpuMovement.dy * CombatTuning.cpuMoveSpeed
                    * staminaMultiplier * deltaTime
            }
        }

        clampAndRenderFighters()
        updateCamera(deltaTime: deltaTime)
        updateFighterMotion(
            playerMovement: CGVector(
                dx: screenMovement.dx * movementMultiplier,
                dy: screenMovement.dy * movementMultiplier
            ),
            cpuMovement: cpuCanMove
                ? (networkConfiguration == nil
                    ? ringProjection.screenVector(forWorldVector: cpuMovement)
                    : cpuMovement) : .zero,
            previousPlayerPosition: previousPlayerScreenPosition,
            previousCPUPosition: previousCPUScreenPosition,
            deltaTime: deltaTime
        )
    }

    private func updateFighterMotion(
        playerMovement: CGVector,
        cpuMovement: CGVector,
        previousPlayerPosition: CGPoint,
        previousCPUPosition: CGPoint,
        deltaTime: TimeInterval
    ) {
        player.updateMotion(
            FighterMovementState(
                screenMovement: playerMovement,
                screenDisplacement: CGVector(
                    dx: player.position.x - previousPlayerPosition.x,
                    dy: player.position.y - previousPlayerPosition.y
                ),
                towardOpponent: playerToCPUScreenDirection
            ),
            deltaTime: deltaTime
        )
        cpu.updateMotion(
            FighterMovementState(
                screenMovement: cpuMovement,
                screenDisplacement: CGVector(
                    dx: cpu.position.x - previousCPUPosition.x,
                    dy: cpu.position.y - previousCPUPosition.y
                ),
                towardOpponent: CGVector(
                    dx: -playerToCPUScreenDirection.dx,
                    dy: -playerToCPUScreenDirection.dy
                )
            ),
            deltaTime: deltaTime
        )
    }

    private func footworkMultiplier(for fighter: FighterID) -> CGFloat {
        switch engine.state(for: fighter).phase {
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

    private func staminaFootworkMultiplier(for fighter: FighterID) -> CGFloat {
        let state = engine.state(for: fighter)
        guard state.stamina < state.stats.lowStaminaThreshold else { return 1 }
        let fraction = max(state.stamina / state.stats.lowStaminaThreshold, 0)
        let minimum = CombatTuning.minimumExhaustedFootwork
        return minimum + CGFloat(fraction) * (1 - minimum)
    }

    private func directionalFootworkMultiplier(
        for movement: CGVector,
        fighter: FighterID = .player
    ) -> CGFloat {
        let movementLength = hypot(movement.dx, movement.dy)
        guard movementLength > 0.001 else { return 1 }

        let towardOpponent = fighter == .player
            ? CGVector(dx: cpuArenaPosition.x - playerArenaPosition.x, dy: cpuArenaPosition.y - playerArenaPosition.y)
            : CGVector(dx: playerArenaPosition.x - cpuArenaPosition.x, dy: playerArenaPosition.y - cpuArenaPosition.y)
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
        playerToCPUScreenDirection = ringProjection.screenVector(forWorldVector: CGVector(
            dx: cpuArenaPosition.x - playerArenaPosition.x,
            dy: cpuArenaPosition.y - playerArenaPosition.y
        ))

        player.position = playerScreenPosition
        cpu.position = cpuScreenPosition

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
        let techniqueReachScale: CGFloat
        switch profile.technique {
        case .straight: techniqueReachScale = 1
        case .smash: techniqueReachScale = CombatTuning.smashReachScale
        case .uppercut: techniqueReachScale = CombatTuning.uppercutReachScale
        }
        return visibleFighterDistance()
            <= baseVisiblePunchReach(for: attacker) * motionReachScale * techniqueReachScale
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
        let localFighter = networkConfiguration?.localFighterID ?? .player
        let towardOpponent = localFighter == .player
            ? CGVector(dx: cpuArenaPosition.x - playerArenaPosition.x, dy: cpuArenaPosition.y - playerArenaPosition.y)
            : CGVector(dx: playerArenaPosition.x - cpuArenaPosition.x, dy: playerArenaPosition.y - cpuArenaPosition.y)
        return localInputSource.swayIntent(
            at: gameTime,
            towardOpponent: ringProjection.screenVector(forWorldVector: towardOpponent)
        )
    }

    private func playerPunchIntent() -> PunchIntent {
        let localFighter = networkConfiguration?.localFighterID ?? .player
        let rawMovement = localInputSource.movementCommand(at: gameTime)
            .movementVector ?? .zero
        let smoother = localFighter == .player ? playerMovementSmoother.value : cpuMovementSmoother.value
        let effectiveMovement = CGVector(
            dx: smoother.dx * 0.70 + rawMovement.dx * 0.30,
            dy: smoother.dy * 0.70 + rawMovement.dy * 0.30
        )
        let worldMovement = ringProjection.worldDirection(forScreenVector: effectiveMovement)
        let opponentVector = localFighter == .player
            ? CGVector(dx: cpuArenaPosition.x - playerArenaPosition.x, dy: cpuArenaPosition.y - playerArenaPosition.y)
            : CGVector(dx: playerArenaPosition.x - cpuArenaPosition.x, dy: playerArenaPosition.y - cpuArenaPosition.y)
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

    private var isMotionShowcaseEnabled: Bool {
#if DEBUG
        motionShowcaseEnabled || swayShowcaseEnabled || impactShowcaseEnabled
#else
        false
#endif
    }

    private func cpuPerception(at time: TimeInterval) -> CPUPerception {
        CPUPerception(
            time: time,
            selfState: engine.state(for: .cpu),
            opponentState: engine.state(for: .player),
            towardOpponent: CGVector(
                dx: playerArenaPosition.x - cpuArenaPosition.x,
                dy: playerArenaPosition.y - cpuArenaPosition.y
            ),
            screenTowardOpponent: CGVector(
                dx: -playerToCPUScreenDirection.dx,
                dy: -playerToCPUScreenDirection.dy
            ),
            visibleDistance: visibleFighterDistance(),
            preferredPunchRange: baseVisiblePunchReach(for: .cpu)
        )
    }

    private func updateCPUCombat(at time: TimeInterval) {
        guard let command = cpuInputSource.combatCommand(
            for: cpuPerception(at: time)
        ) else { return }
        execute(command)
    }

    private func attachNetworkHandlers() {
        guard networkConfiguration != nil, let nearbyService else { return }
        nearbyService.onCombatInput = { [weak self] input in self?.receive(input) }
        nearbyService.onCombatState = { [weak self] state in self?.apply(state) }
        nearbyService.onRestartRound = { [weak self] in self?.resetRound() }
        nearbyService.onRematchStateChanged = { [weak self] local, remote in
            self?.updateRematchUI(local: local, remote: remote)
        }
    }

    private func showCountdown(remaining: TimeInterval) {
        statusLabel.removeAllActions()
        statusLabel.alpha = 1
        statusLabel.fontColor = .white
        statusLabel.text = String(max(Int(ceil(remaining)), 1))
        controls.alpha = 0.35
    }

    private func updateNetworkCombat(at time: TimeInterval) {
        guard let configuration = networkConfiguration, let nearbyService else { return }
        if time - lastNetworkMovementSentAt >= 1.0 / 30.0 {
            lastNetworkMovementSentAt = time
            let movement = localInputSource.movementCommand(at: time).movementVector ?? .zero
            nearbyService.sendCombatInput(NearbyCombatInput(
                sequence: nearbyService.nextCombatInputSequence(),
                kind: .movement,
                x: Double(movement.dx),
                y: Double(movement.dy)
            ))
        }
        if configuration.role == .host, time - lastNetworkStateSentAt >= 1.0 / 15.0 {
            lastNetworkStateSentAt = time
            networkStateSequence &+= 1
            nearbyService.sendCombatState(NearbyCombatState(
                sequence: networkStateSequence,
                playerX: Double(playerArenaPosition.x),
                playerY: Double(playerArenaPosition.y),
                cpuX: Double(cpuArenaPosition.x),
                cpuY: Double(cpuArenaPosition.y),
                playerHealth: engine.state(for: .player).health,
                cpuHealth: engine.state(for: .cpu).health,
                playerStamina: engine.state(for: .player).stamina,
                cpuStamina: engine.state(for: .cpu).stamina,
                winner: engine.winner.map { $0 == .player ? "player" : "cpu" }
            ))
        }
    }

    private func networkInput(for action: CombatAction) -> NearbyCombatInput {
        let sequence = nearbyService?.nextCombatInputSequence() ?? 0
        switch action {
        case let .punch(intent):
            return NearbyCombatInput(
                sequence: sequence,
                kind: .punch,
                forwardDrive: intent.forwardDrive,
                lateralDrive: intent.lateralDrive,
                movementIntensity: intent.movementIntensity
            )
        case let .sway(intent):
            return NearbyCombatInput(
                sequence: sequence,
                kind: .sway,
                x: Double(intent.screenDirection.dx),
                y: Double(intent.screenDirection.dy),
                swayDirection: networkName(for: intent.direction),
                isTowardOpponent: intent.isTowardOpponent
            )
        }
    }

    private func receive(_ input: NearbyCombatInput) {
        guard input.sequence > lastRemoteInputSequence,
              let remoteFighter = networkConfiguration?.remoteFighterID else { return }
        lastRemoteInputSequence = input.sequence
        switch input.kind {
        case .movement:
            remoteMovement = CGVector(dx: input.x, dy: input.y)
        case .punch:
            execute(FighterCommand(
                fighter: remoteFighter,
                payload: .action(.punch(PunchIntent(
                    forwardDrive: input.forwardDrive,
                    lateralDrive: input.lateralDrive,
                    movementIntensity: input.movementIntensity
                ))),
                issuedAt: gameTime
            ))
        case .sway:
            guard let name = input.swayDirection, let direction = swayDirection(named: name) else { return }
            execute(FighterCommand(
                fighter: remoteFighter,
                payload: .action(.sway(SwayIntent(
                    direction: direction,
                    isTowardOpponent: input.isTowardOpponent,
                    screenDirection: CGVector(dx: input.x, dy: input.y)
                ))),
                issuedAt: gameTime
            ))
        }
    }

    private func apply(_ state: NearbyCombatState) {
        guard state.sequence > networkStateSequence else { return }
        networkStateSequence = state.sequence
        let previousPlayerHealth = engine.state(for: .player).health
        let previousCPUHealth = engine.state(for: .cpu).health
        let blend: CGFloat = 0.38
        playerArenaPosition.x += (CGFloat(state.playerX) - playerArenaPosition.x) * blend
        playerArenaPosition.y += (CGFloat(state.playerY) - playerArenaPosition.y) * blend
        cpuArenaPosition.x += (CGFloat(state.cpuX) - cpuArenaPosition.x) * blend
        cpuArenaPosition.y += (CGFloat(state.cpuY) - cpuArenaPosition.y) * blend
        let winner: FighterID? = state.winner == "player" ? .player : (state.winner == "cpu" ? .cpu : nil)
        handle(engine.applyAuthoritativeState(
            playerHealth: state.playerHealth,
            cpuHealth: state.cpuHealth,
            playerStamina: state.playerStamina,
            cpuStamina: state.cpuStamina,
            winner: winner
        ))
        let fallbackProfile = PunchProfile()
        if state.playerHealth < previousPlayerHealth {
            player.playHit(.normal, profile: fallbackProfile)
            showImpact(
                .normal,
                profile: fallbackProfile,
                attacker: .cpu,
                defender: .player
            )
            playImpactFeedback(
                .normal,
                profile: fallbackProfile,
                attacker: .cpu,
                defender: .player
            )
            if networkConfiguration?.localFighterID == .player {
                haptics.playHit(.normal)
            }
        }
        if state.cpuHealth < previousCPUHealth {
            cpu.playHit(.normal, profile: fallbackProfile)
            showImpact(
                .normal,
                profile: fallbackProfile,
                attacker: .player,
                defender: .cpu
            )
            playImpactFeedback(
                .normal,
                profile: fallbackProfile,
                attacker: .player,
                defender: .cpu
            )
            if networkConfiguration?.localFighterID == .cpu {
                haptics.playHit(.normal)
            }
        }
    }

    private func networkName(for direction: SwayDirection) -> String {
        switch direction {
        case .left: "left"
        case .right: "right"
        case .back: "back"
        case .forward: "forward"
        }
    }

    private func swayDirection(named name: String) -> SwayDirection? {
        switch name {
        case "left": .left
        case "right": .right
        case "back": .back
        case "forward": .forward
        default: nil
        }
    }

#if DEBUG
    private func updateSwayShowcase(at time: TimeInterval) {
        let towardPlayer = CGVector(
            dx: -playerToCPUScreenDirection.dx,
            dy: -playerToCPUScreenDirection.dy
        )
        guard let (demo, intent) = swayShowcaseController.command(
            at: time,
            state: engine.state(for: .cpu),
            towardOpponent: towardPlayer
        ) else { return }
        statusLabel.removeAllActions()
        statusLabel.alpha = 1
        statusLabel.fontColor = demo.direction == .forward ? .systemRed : .systemYellow
        statusLabel.text = demo.label
        execute(FighterCommand(
            fighter: .cpu,
            payload: .action(.sway(intent)),
            issuedAt: time
        ))
    }

    private func updateMotionShowcase(at time: TimeInterval) {
        let towardPlayer = CGVector(
            dx: -playerToCPUScreenDirection.dx,
            dy: -playerToCPUScreenDirection.dy
        )
        guard let command = motionShowcaseController.command(
            at: time,
            state: engine.state(for: .cpu),
            towardOpponent: towardPlayer
        ) else { return }

        switch command {
        case let .start(label, intent):
            statusLabel.removeAllActions()
            statusLabel.alpha = 1
            statusLabel.fontColor = .systemYellow
            statusLabel.text = label
            execute(FighterCommand(
                fighter: .cpu,
                payload: .action(.sway(intent)),
                issuedAt: time
            ))
        case .punch:
            execute(FighterCommand(
                fighter: .cpu,
                payload: .action(.punch(.neutral)),
                issuedAt: time
            ))
        }
    }
#endif

    private func processBufferedPunch(at time: TimeInterval) {
        guard let command = localInputSource.bufferedPunchCommand(
            at: time,
            state: engine.state(for: localInputSource.fighter)
        ) else { return }
        executeLocal(command)
    }

    private func refreshMovementIndicator() {
        let movement = localInputSource.movementCommand(at: gameTime)
            .movementVector ?? .zero
        controls.showMovement(movement == .zero ? nil : movement)
    }

    private func endMovementTouches(_ touches: Set<UITouch>) {
        let identifiers = Set(touches.map(ObjectIdentifier.init))
        guard localInputSource.endMovement(touchIDs: identifiers) else { return }
        controls.endMovement()
        refreshMovementIndicator()
    }

    private func execute(_ command: FighterCommand) {
        guard case let .action(action) = command.payload else { return }
        let stateBeforeRequest = engine.state(for: command.fighter)
        let events = engine.request(
            action,
            by: command.fighter,
            at: command.issuedAt
        )
        if command.fighter == localInputSource.fighter, case let .punch(intent) = action {
            localInputSource.recordPunchResult(
                intent: intent,
                events: events,
                stateBeforeRequest: stateBeforeRequest,
                at: command.issuedAt
            )
        }
        handle(events)
    }

    private func executeLocal(_ command: FighterCommand) {
        execute(command)
        guard networkConfiguration != nil, case let .action(action) = command.payload else { return }
        nearbyService?.sendCombatInput(networkInput(for: action))
    }

    private func handle(_ events: [CombatEvent]) {
        for event in events {
            switch event {
            case let .phaseChanged(fighter, phase):
                node(for: fighter).show(phase: phase)
            case let .punchStarted(fighter, hand, profile):
                node(for: fighter).preparePunch(hand, profile: profile)
            case let .punchMissed(fighter, profile):
                node(for: fighter).playWhiff(profile)
            case let .swayStarted(fighter, direction, screenDirection, performance):
                node(for: fighter).prepareSway(
                    direction,
                    screenDirection: screenDirection,
                    performance: performance
                )
            case let .hit(attacker, defender, kind, _, profile):
                if defender == localInputSource.fighter {
                    localInputSource.clearBufferedPunch()
                }
                node(for: attacker).playHitConfirm(profile)
                node(for: defender).playHit(kind, profile: profile)
                showImpact(
                    kind,
                    profile: profile,
                    attacker: attacker,
                    defender: defender
                )
                playImpactFeedback(
                    kind,
                    profile: profile,
                    attacker: attacker,
                    defender: defender
                )
                haptics.playHit(kind, technique: profile.technique)
            case .swayed(let defender):
                if defender == localInputSource.fighter {
                    // A late successful evade must not lose a follow-up that
                    // was pressed during the sway's loading motion.
                    localInputSource.extendBufferedPunch(
                        until: gameTime + CombatTuning.counterWindow
                    )
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
            case let .staminaChanged(fighter, stamina):
                updateStamina(fighter, stamina: stamina)
            case let .roundEnded(winner):
                statusLabel.removeAllActions()
                statusLabel.alpha = 1
                statusLabel.fontColor = .white
                let localFighter = networkConfiguration?.localFighterID ?? .player
                statusLabel.text = winner == localFighter ? "YOU WIN!" : "YOU LOSE"
                statusLabel.zPosition = 161
                roundEndOverlay.isHidden = false
                restartButton.isHidden = false
                restartLabel.text = networkConfiguration == nil ? "다시 하기" : "재대결 요청"
                controls.alpha = 0.35
                localInputSource.reset(at: gameTime)
                controls.endMovement()
                playerMovementSmoother.reset()
                cpuMovementSmoother.reset()
                controls.showMovement(nil)
                layoutScene()
                if networkConfiguration != nil, remoteRematchAccepted {
                    updateRematchUI(local: localRematchAccepted, remote: true)
                }
            }
        }
    }

    private func node(for fighter: FighterID) -> FighterNode {
        fighter == .player ? player : cpu
    }

    private func updateHealth(_ fighter: FighterID, health: Int) {
        let maximumHealth = engine.state(for: fighter).stats.maximumHealth
        let fraction = CGFloat(health) / CGFloat(maximumHealth)
        let bar = fighter == .player ? playerHealthBar : cpuHealthBar
        let action = SKAction.scaleX(to: fraction, duration: CombatTuning.healthBarAnimationDuration)
        action.timingMode = .easeOut
        bar.run(action)
    }

    private func updateStamina(_ fighter: FighterID, stamina: Double) {
        let state = engine.state(for: fighter)
        let fraction = CGFloat(stamina / state.stats.maximumStamina)
        let bar = fighter == .player ? playerStaminaBar : cpuStaminaBar
        bar.xScale = fraction
        if stamina <= state.stats.lowStaminaThreshold {
            bar.color = .systemRed
        } else if stamina <= state.stats.maximumStamina * 0.50 {
            bar.color = .systemYellow
        } else {
            bar.color = .systemGreen
        }
    }

    private func showImpact(
        _ kind: HitKind,
        profile: PunchProfile,
        attacker: FighterID,
        defender: FighterID
    ) {
        let techniqueRadius: CGFloat
        switch profile.technique {
        case .straight: techniqueRadius = 22
        case .smash: techniqueRadius = 29
        case .uppercut: techniqueRadius = 27
        }
        let radius: CGFloat = kind == .counter ? 42 : techniqueRadius
        let impact = SKShapeNode(circleOfRadius: radius)
        let attackerNode = node(for: attacker)
        let defenderNode = node(for: defender)
        let averageScale = (attackerNode.xScale + defenderNode.xScale) / 2
        impact.position = CGPoint(
            x: attackerNode.position.x * 0.28 + defenderNode.position.x * 0.72,
            y: attackerNode.position.y * 0.22 + defenderNode.position.y * 0.78
                + 70 * averageScale
        )
        switch (kind, profile.technique) {
        case (.counter, _): impact.strokeColor = .systemYellow
        case (_, .straight): impact.strokeColor = .white
        case (_, .smash): impact.strokeColor = .systemOrange
        case (_, .uppercut): impact.strokeColor = .systemCyan
        }
        impact.lineWidth = kind == .counter ? 8 : 4
        impact.zPosition = 30
        impact.setScale(0.25 / arenaZoom)
        let core = SKShapeNode(circleOfRadius: radius * 0.28)
        core.fillColor = impact.strokeColor.withAlphaComponent(0.88)
        core.strokeColor = .clear
        core.zPosition = 1
        impact.addChild(core)
        arenaNode.addChild(impact)
        impact.run(.sequence([
            .group([
                .scale(to: 1.45 / arenaZoom, duration: CombatTuning.impactAnimationDuration),
                .fadeOut(withDuration: CombatTuning.impactAnimationDuration)
            ]),
            .removeFromParent()
        ]))
    }

    private func playImpactFeedback(
        _ kind: HitKind,
        profile: PunchProfile,
        attacker: FighterID,
        defender: FighterID
    ) {
        if kind == .counter { showCounterTitle() }

        let hitStopDuration: TimeInterval
        if kind == .counter {
            hitStopDuration = CombatTuning.counterHitStop
        } else {
            switch profile.technique {
            case .straight: hitStopDuration = CombatTuning.normalHitStop
            case .smash, .uppercut: hitStopDuration = CombatTuning.heavyHitStop
            }
        }
        removeAction(forKey: "hitStop")
        arenaNode.speed = 0
        run(.sequence([
            .wait(forDuration: hitStopDuration),
            .run { [weak self] in self?.arenaNode.speed = 1 }
        ]), withKey: "hitStop")

        let attackerPosition = node(for: attacker).position
        let defenderPosition = node(for: defender).position
        let direction = CGVector(
            dx: defenderPosition.x - attackerPosition.x,
            dy: defenderPosition.y - attackerPosition.y
        )
        let length = max(hypot(direction.dx, direction.dy), 0.001)
        let baseDistance = kind == .counter
            ? CombatTuning.cameraShakeDistance
            : CombatTuning.normalCameraShakeDistance
        let techniqueScale: CGFloat
        switch profile.technique {
        case .straight: techniqueScale = 1
        case .smash: techniqueScale = 1.22
        case .uppercut: techniqueScale = 1.12
        }
        let distance = baseDistance * techniqueScale / arenaZoom
        let dx = direction.dx / length * distance
        let dy = direction.dy / length * distance + (profile.technique == .uppercut ? distance * 0.45 : 0)
        arenaNode.removeAction(forKey: "shake")
        arenaNode.run(.sequence([
            .moveBy(x: dx, y: dy, duration: CombatTuning.cameraShakeDuration * 0.16),
            .moveBy(x: -dx * 1.75, y: -dy * 1.75, duration: CombatTuning.cameraShakeDuration * 0.23),
            .moveBy(x: dx * 1.20, y: dy * 1.20, duration: CombatTuning.cameraShakeDuration * 0.21),
            .move(to: .zero, duration: CombatTuning.cameraShakeDuration * 0.40)
        ]), withKey: "shake")
    }

    private func showCounterTitle() {
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

    }

    private func updateRematchUI(local: Bool, remote: Bool) {
        localRematchAccepted = local
        remoteRematchAccepted = remote
        guard networkConfiguration != nil, engine.winner != nil else { return }

        statusLabel.removeAllActions()
        statusLabel.alpha = 1
        if local {
            restartLabel.text = "요청 취소"
            statusLabel.text = "상대의 재대결 수락을 기다리는 중"
            statusLabel.fontColor = .systemYellow
        } else if remote {
            restartLabel.text = "재대결 수락"
            statusLabel.text = "상대가 재대결을 요청했습니다"
            statusLabel.fontColor = .systemGreen
        } else {
            restartLabel.text = "재대결 요청"
            statusLabel.text = "재대결을 요청하거나 대전을 종료하세요"
            statusLabel.fontColor = .white
        }
    }

    private func resetRound() {
        removeAction(forKey: "hitStop")
        arenaNode.speed = 1
        arenaNode.position = .zero
        player.resetPose()
        cpu.resetPose()
        playerArenaPosition = .zero
        cpuArenaPosition = .zero
        localInputSource.reset(at: gameTime)
        controls.endMovement()
        playerMovementSmoother.reset()
        cpuMovementSmoother.reset()
        controls.showMovement(nil)
        localRematchAccepted = false
        remoteRematchAccepted = false
        handle(engine.reset())
        cpuInputSource.reset(at: gameTime)
#if DEBUG
        motionShowcaseController.reset(at: gameTime)
        swayShowcaseController.reset(at: gameTime)
#endif
        statusLabel.removeAllActions()
        statusLabel.text = nil
        statusLabel.alpha = 1
        statusLabel.zPosition = 20
        roundEndOverlay.isHidden = true
        restartButton.isHidden = true
        controls.alpha = 1
        if networkConfiguration != nil {
            hasCompletedCountdown = false
            countdownEndsAt = gameTime + 3
            controls.alpha = 0.35
        }
        playerHealthBar.xScale = 1
        cpuHealthBar.xScale = 1
        playerStaminaBar.xScale = 1
        cpuStaminaBar.xScale = 1
        playerStaminaBar.color = .systemGreen
        cpuStaminaBar.color = .systemGreen
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
