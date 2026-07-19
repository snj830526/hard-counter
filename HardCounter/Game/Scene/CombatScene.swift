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
        appearance: fighterProfile.appearance,
        motionStyle: fighterProfile.motionStyle
    )
    private lazy var cpu = FighterNode(
        facingRight: false,
        appearance: opponentProfile?.appearance ?? .cpuRival,
        motionStyle: cpuMotionStyle
    )
    private let playerShadow = FighterGroundShadowNode()
    private let cpuShadow = FighterGroundShadowNode()
    private lazy var hud = CombatHUDNode(
        playerName: fighterProfile.name,
        playerColor: fighterProfile.color,
        playerDetail: networkConfiguration.map { "HOST  ·  \($0.hostName)" },
        opponentName: opponentProfile?.name ?? "CPU RIVAL",
        opponentColor: opponentProfile?.color ?? .systemOrange,
        opponentDetail: networkConfiguration.map { "GUEST  ·  \($0.guestName)" }
    )
    private var playerHealthBar: SKSpriteNode { hud.playerHealthBar }
    private var cpuHealthBar: SKSpriteNode { hud.cpuHealthBar }
    private var playerStaminaBar: SKSpriteNode { hud.playerStaminaBar }
    private var cpuStaminaBar: SKSpriteNode { hud.cpuStaminaBar }
    private var statusLabel: SKLabelNode { hud.statusLabel }
    private var roundEndOverlay: SKSpriteNode { hud.roundEndOverlay }
    private var restartButton: SKShapeNode { hud.restartButton }
    private var restartLabel: SKLabelNode { hud.restartLabel }
    private let controls = CombatControlsNode()
    private let haptics = HapticController()

    private lazy var engine = CombatEngine(
        playerStats: fighterProfile.stats,
        cpuStats: opponentProfile?.stats ?? .standard,
        playerStyle: fighterProfile.combatStyle,
        cpuStyle: cpuCombatStyle
    )
    private lazy var localInputSource = LocalInputSource(
        fighter: networkConfiguration?.localFighterID ?? .player
    )
    private var cpuInputSource = CPUInputSource()
    private var gameTime: TimeInterval = 0
    private var nextCPUAttackDeadline: TimeInterval = 0
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
    private var pendingPunchContactPoints: [FighterID: CGPoint] = [:]
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
    private lazy var playerBodyMotion = FighterFullBodyMotionController(
        cadence: fighterProfile.motionStyle.profile.strideCadence
    )
    private lazy var cpuBodyMotion = FighterFullBodyMotionController(
        cadence: cpuMotionStyle.profile.strideCadence
    )
    private var arenaZoom = ArenaViewTuning.baseZoom
    private var combatArena3DRenderer: CombatArena3DRenderer?

    private var cpuMotionStyle: Fighter3DMotionStyle {
#if DEBUG
        if fighterStyleShowcaseEnabled {
            return fighterProfile.motionStyle
        }
#endif
        return opponentProfile?.motionStyle ?? .rival
    }

    private var cpuCombatStyle: FighterCombatStyle {
#if DEBUG
        if fighterStyleShowcaseEnabled {
            return fighterProfile.combatStyle
        }
#endif
        return opponentProfile?.combatStyle ?? .rival
    }
    private let combatThreeDArenaEnabled = !ProcessInfo.processInfo.arguments.contains("--legacy-2d-arena")
#if DEBUG
    private let fighterStyleShowcaseEnabled = ProcessInfo.processInfo.arguments.contains("--fighter-style-showcase")
    private let motionShowcaseEnabled = ProcessInfo.processInfo.arguments.contains("--motion-showcase")
    private let uppercutShowcaseEnabled = ProcessInfo.processInfo.arguments.contains("--uppercut-showcase")
    private let swayShowcaseEnabled = ProcessInfo.processInfo.arguments.contains("--sway-showcase")
    private let impactShowcaseEnabled = ProcessInfo.processInfo.arguments.contains("--impact-showcase")
    private let knockoutShowcaseEnabled = ProcessInfo.processInfo.arguments.contains("--knockout-showcase")
    private let motionClipShowcaseEnabled = ProcessInfo.processInfo.arguments.contains("--motion-clip-showcase")
    private let footworkShowcaseEnabled = ProcessInfo.processInfo.arguments.contains("--footwork-showcase")
    private let cameraShowcaseEnabled = ProcessInfo.processInfo.arguments.contains("--camera-showcase")
    private let fatigueShowcaseEnabled = ProcessInfo.processInfo.arguments.contains("--fatigue-showcase")
    private let guardCloseupEnabled = ProcessInfo.processInfo.arguments.contains("--guard-closeup")
    private let damageShowcaseEnabled = ProcessInfo.processInfo.arguments.contains("--damage-showcase")
    private var motionShowcaseController = MotionShowcaseController(
        uppercutOnly: ProcessInfo.processInfo.arguments.contains("--uppercut-showcase")
    )
    private var swayShowcaseController = SwayShowcaseController()
    private var motionClipShowcaseController = MotionClipShowcaseController()
    private var footworkShowcaseController = FootworkShowcaseController()
#endif

    init(size: CGSize, fighter: FighterProfile) {
        fighterProfile = fighter
        opponentProfile = FighterProfile.allCases
            .filter { $0 != fighter }
            .randomElement() ?? .pressure
        networkConfiguration = nil
        nearbyService = nil
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = ArenaVisualPalette.void
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
        backgroundColor = ArenaVisualPalette.void
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
        nextCPUAttackDeadline = gameTime + CombatTuning.cpuInitialDelay
#if DEBUG
        motionShowcaseController.reset(at: gameTime)
        swayShowcaseController.reset(at: gameTime)
        motionClipShowcaseController.reset(at: gameTime)
        footworkShowcaseController.reset(at: gameTime)
#endif
        haptics.prepare()
        layoutScene()
#if DEBUG
        if damageShowcaseEnabled {
            player.updateDamage(fraction: 0.14)
            cpu.updateDamage(fraction: 0.31)
        }
#endif
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
            nextCPUAttackDeadline = currentTime + CombatTuning.cpuInitialDelay
#if DEBUG
            motionShowcaseController.reset(at: currentTime)
            swayShowcaseController.reset(at: currentTime)
            motionClipShowcaseController.reset(at: currentTime)
            footworkShowcaseController.reset(at: currentTime)
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
                statusLabel.fontColor = ArenaVisualPalette.amberSignal
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
        } else if motionClipShowcaseEnabled {
            updateMotionClipShowcase(at: currentTime)
        } else if footworkShowcaseEnabled || cameraShowcaseEnabled {
            updateFootworkShowcase(at: currentTime)
        } else if fatigueShowcaseEnabled {
            updateFatigueShowcase()
        } else if knockoutShowcaseEnabled {
            updateKnockoutShowcase()
        } else if guardCloseupEnabled {
            updateGuardCloseup()
        } else if damageShowcaseEnabled {
            updateDamageShowcase()
        } else if swayShowcaseEnabled {
            updateSwayShowcase(at: currentTime)
        } else if motionShowcaseEnabled || uppercutShowcaseEnabled || impactShowcaseEnabled {
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

        // A second finger can press SWAY before UIKit delivers the pending
        // touchesMoved callback for the stick finger. Re-sample the active
        // stick from this event so the committed sway uses what the player is
        // actually holding on this exact frame, not the previous frame.
        refreshActiveMovement(from: event)

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

    private func refreshActiveMovement(from event: UIEvent?) {
        guard let activeTouches = event?.allTouches else { return }
        for touch in activeTouches where touch.phase != .ended && touch.phase != .cancelled {
            let latestTouch = event?.coalescedTouches(for: touch)?.last ?? touch
            if localInputSource.updateMovement(
                touchID: ObjectIdentifier(touch),
                vector: controls.continuedMovement(at: latestTouch.location(in: self)),
                at: gameTime
            ) {
                refreshMovementIndicator()
                return
            }
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
        arenaNode.addChild(playerShadow)
        arenaNode.addChild(cpuShadow)
        player.zPosition = 10
        cpu.zPosition = 10
        arenaNode.addChild(player)
        arenaNode.addChild(cpu)

        if combatThreeDArenaEnabled {
            let renderer = CombatArena3DRenderer(
                size: size,
                player: player,
                opponent: cpu
            )
            combatArena3DRenderer = renderer
            addChild(renderer.viewport)
            player.attachDamageEffects(to: self)
            cpu.attachDamageEffects(to: self)
            ringNode.isHidden = true
            playerShadow.isHidden = true
            cpuShadow.isHidden = true
        }

        addChild(hud)
        addChild(controls)
    }

    private func layoutScene() {
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
            if guardCloseupEnabled || damageShowcaseEnabled {
                playerArenaPosition = CGPoint(x: -82, y: 0)
                cpuArenaPosition = CGPoint(x: 82, y: 0)
            } else if footworkShowcaseEnabled || cameraShowcaseEnabled || fatigueShowcaseEnabled
                || fighterStyleShowcaseEnabled {
                playerArenaPosition = CGPoint(x: -92, y: 0)
                cpuArenaPosition = CGPoint(x: 92, y: 0)
            } else if impactShowcaseEnabled || motionShowcaseEnabled || uppercutShowcaseEnabled
                || motionClipShowcaseEnabled || swayShowcaseEnabled {
                playerArenaPosition = CGPoint(x: -16, y: 0)
                cpuArenaPosition = CGPoint(x: 16, y: 0)
            } else {
                playerArenaPosition = CGPoint(
                    x: -ArenaViewTuning.startingHorizontalOffset,
                    y: -ArenaViewTuning.startingDepthOffset
                )
                cpuArenaPosition = CGPoint(
                    x: ArenaViewTuning.startingHorizontalOffset,
                    y: ArenaViewTuning.startingDepthOffset
                )
            }
#else
            playerArenaPosition = CGPoint(
                x: -ArenaViewTuning.startingHorizontalOffset,
                y: -ArenaViewTuning.startingDepthOffset
            )
            cpuArenaPosition = CGPoint(
                x: ArenaViewTuning.startingHorizontalOffset,
                y: ArenaViewTuning.startingDepthOffset
            )
#endif
        }
        clampAndRenderFighters(deltaTime: 0)
        updateFighterMotion(
            playerMovement: .zero,
            cpuMovement: .zero,
            playerBodyMotion: .neutral,
            cpuBodyMotion: .neutral,
            previousPlayerPosition: player.position,
            previousCPUPosition: cpu.position,
            deltaTime: 0
        )
        positionCameraImmediately()

        combatArena3DRenderer?.layout(size: size)

        hud.layout(in: size, safeInsets: safeInsets, roundEnded: engine.winner != nil)
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
#if DEBUG
        if cameraShowcaseEnabled {
            targetMovement = footworkShowcaseController.frame(at: gameTime).screenMovement
        } else if let networkConfiguration {
            targetMovement = networkConfiguration.localFighterID == .player ? localMovement : remoteMovement
        } else {
            targetMovement = localMovement
        }
#else
        if let networkConfiguration {
            targetMovement = networkConfiguration.localFighterID == .player ? localMovement : remoteMovement
        } else {
            targetMovement = localMovement
        }
#endif
        let phaseMultiplier = footworkMultiplier(for: .player)
        let playerBodyFrame = playerBodyMotion.update(
            movementIntent: targetMovement,
            towardOpponent: playerToCPUScreenDirection,
            phase: engine.state(for: .player).phase,
            deltaTime: deltaTime
        )
        let screenMovement = playerMovementSmoother.update(
            toward: playerBodyFrame.resolvedMovement,
            deltaTime: deltaTime
        )
        let worldMovement = presentationWorldDirection(forScreenVector: screenMovement)
        let directionMultiplier = directionalFootworkMultiplier(for: worldMovement)
        let movementMultiplier = phaseMultiplier * directionMultiplier
            * staminaFootworkMultiplier(for: .player)
            * fighterProfile.stats.movementSpeedMultiplier
        let playerVelocity = screenNormalizedWorldVelocity(
            for: worldMovement,
            screenSpeed: CombatTuning.playerScreenMoveSpeed
        )
        let playerIsMoving = movementMultiplier > 0
            && hypot(playerVelocity.dx, playerVelocity.dy) > 0.02

        if playerIsMoving {
            playerArenaPosition.x += playerVelocity.dx * movementMultiplier * deltaTime
            playerArenaPosition.y += playerVelocity.dy * movementMultiplier * deltaTime
        }

        let cpuCanMove = networkConfiguration != nil
            ? footworkMultiplier(for: .cpu) > 0
            : engine.state(for: .cpu).phase == .idle && !isMotionShowcaseEnabled
        var cpuTargetMovement = CGVector.zero
        if let networkConfiguration {
            cpuTargetMovement = networkConfiguration.localFighterID == .cpu ? localMovement : remoteMovement
        } else if let showcaseMovement = footworkShowcaseMovement(at: gameTime) {
            cpuTargetMovement = presentationWorldDirection(
                forScreenVector: cameraShowcaseOpponentMovement(showcaseMovement)
            )
        } else if cpuCanMove {
            cpuTargetMovement = cpuInputSource
                .movementCommand(for: cpuPerception(at: gameTime))
                .movementVector ?? .zero
        }
        let cpuTowardOpponent: CGVector
        if networkConfiguration != nil {
            cpuTowardOpponent = CGVector(
                dx: -playerToCPUScreenDirection.dx,
                dy: -playerToCPUScreenDirection.dy
            )
        } else {
            cpuTowardOpponent = CGVector(
                dx: playerArenaPosition.x - cpuArenaPosition.x,
                dy: playerArenaPosition.y - cpuArenaPosition.y
            )
        }
        let cpuBodyFrame = cpuBodyMotion.update(
            movementIntent: cpuTargetMovement,
            towardOpponent: cpuTowardOpponent,
            phase: engine.state(for: .cpu).phase,
            deltaTime: deltaTime
        )
        let cpuMovement = cpuMovementSmoother.update(
            toward: cpuBodyFrame.resolvedMovement,
            deltaTime: deltaTime
        )
        if cpuCanMove {
            let staminaMultiplier = staminaFootworkMultiplier(for: .cpu)
            if networkConfiguration != nil {
                let cpuWorldMovement = presentationWorldDirection(forScreenVector: cpuMovement)
                let multiplier = footworkMultiplier(for: .cpu)
                    * directionalFootworkMultiplier(for: cpuWorldMovement, fighter: .cpu)
                    * staminaMultiplier
                    * (opponentProfile?.stats.movementSpeedMultiplier ?? 1)
                let cpuVelocity = screenNormalizedWorldVelocity(
                    for: cpuWorldMovement,
                    screenSpeed: CombatTuning.playerScreenMoveSpeed
                )
                cpuArenaPosition.x += cpuVelocity.dx * multiplier * deltaTime
                cpuArenaPosition.y += cpuVelocity.dy * multiplier * deltaTime
            } else {
                let cpuVelocity = screenNormalizedWorldVelocity(
                    for: cpuMovement,
                    screenSpeed: CombatTuning.cpuScreenMoveSpeed
                )
                cpuArenaPosition.x += cpuVelocity.dx * staminaMultiplier * deltaTime
                cpuArenaPosition.y += cpuVelocity.dy * staminaMultiplier * deltaTime
            }
        }

        clampAndRenderFighters(deltaTime: deltaTime)
        updateCamera(deltaTime: deltaTime)
        updateFighterMotion(
            playerMovement: CGVector(
                dx: screenMovement.dx * movementMultiplier,
                dy: screenMovement.dy * movementMultiplier
            ),
            cpuMovement: cpuCanMove
                ? (networkConfiguration == nil
                    ? presentationScreenDirection(forWorldVector: cpuMovement)
                    : cpuMovement) : .zero,
            playerBodyMotion: playerBodyFrame,
            cpuBodyMotion: cpuBodyFrame,
            previousPlayerPosition: previousPlayerScreenPosition,
            previousCPUPosition: previousCPUScreenPosition,
            deltaTime: deltaTime
        )
    }

    private func updateFighterMotion(
        playerMovement: CGVector,
        cpuMovement: CGVector,
        playerBodyMotion: FighterBodyMotionFrame,
        cpuBodyMotion: FighterBodyMotionFrame,
        previousPlayerPosition: CGPoint,
        previousCPUPosition: CGPoint,
        deltaTime: TimeInterval
    ) {
        // Hit stop freezes the presentation timeline only. The combat engine
        // continues to advance so solo and nearby matches keep identical rules.
        let motionDeltaTime = arenaNode.speed == 0 ? 0 : deltaTime
        player.updateMotion(
            FighterMovementState(
                screenMovement: playerMovement,
                screenDisplacement: CGVector(
                    dx: player.position.x - previousPlayerPosition.x,
                    dy: player.position.y - previousPlayerPosition.y
                ),
                towardOpponent: playerToCPUScreenDirection,
                bodyMotion: playerBodyMotion
            ),
            deltaTime: motionDeltaTime
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
                ),
                bodyMotion: cpuBodyMotion
            ),
            deltaTime: motionDeltaTime
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

    /// Converts a world direction into velocity whose projected length is
    /// constant on screen. Quarter-view axes are skewed and have different
    /// scales, so multiplying world X/Y independently makes diagonals uneven.
    private func screenNormalizedWorldVelocity(
        for movement: CGVector,
        screenSpeed: CGFloat
    ) -> CGVector {
        let inputAmount = min(hypot(movement.dx, movement.dy), 1)
        guard inputAmount > 0.001 else { return .zero }

        let worldUnit = CGVector(
            dx: movement.dx / inputAmount,
            dy: movement.dy / inputAmount
        )
        let screenPointsPerWorldPoint = presentationGeometry
            .screenPointsPerWorldPoint(for: worldUnit)
        guard screenPointsPerWorldPoint > 0.001 else { return .zero }

        let worldSpeed = screenSpeed * inputAmount / screenPointsPerWorldPoint
        return CGVector(dx: worldUnit.dx * worldSpeed, dy: worldUnit.dy * worldSpeed)
    }

    private func separateFighters() {
        let delta = CGVector(
            dx: cpuArenaPosition.x - playerArenaPosition.x,
            dy: cpuArenaPosition.y - playerArenaPosition.y
        )
        let distance = hypot(delta.dx, delta.dy)
        let direction: CGVector
        if distance > 0.001 {
            direction = CGVector(dx: delta.dx / distance, dy: delta.dy / distance)
        } else {
            direction = CGVector(dx: 1, dy: 0)
        }
        if let minimumWorldSeparation = presentationGeometry
            .threeDMinimumWorldSeparation(along: direction) {
            separateThreeDArenaFighters(
                direction: direction,
                currentDistance: distance,
                minimumDistance: minimumWorldSeparation
            )
            return
        }

        let projectedDelta = presentationScreenVector(forWorldVector: delta)
        let screenDistance = hypot(projectedDelta.dx, projectedDelta.dy)
        let averagePerspectiveScale = (
            fighterScreenScale(at: playerArenaPosition)
                + fighterScreenScale(at: cpuArenaPosition)
        ) * 0.5
        let minimumScreenSeparation = CombatTuning.minimumFighterSeparationAtUnitScale
            * averagePerspectiveScale
            * presentationGeometry.fighterSeparationScale
        guard screenDistance < minimumScreenSeparation else { return }

        let projectedUnit = presentationScreenVector(forWorldVector: direction)
        let screenPointsPerWorldPoint = hypot(projectedUnit.dx, projectedUnit.dy)
        guard screenPointsPerWorldPoint > 0.001 else { return }
        let targetWorldDistance = minimumScreenSeparation / screenPointsPerWorldPoint
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
        let correctedScreenDelta = presentationScreenVector(forWorldVector: correctedDelta)
        let correctedScreenDistance = hypot(correctedScreenDelta.dx, correctedScreenDelta.dy)
        let remaining = max(
            (minimumScreenSeparation - correctedScreenDistance) / screenPointsPerWorldPoint,
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
        let finalScreenDelta = presentationScreenVector(forWorldVector: finalDelta)
        let finalScreenDistance = hypot(finalScreenDelta.dx, finalScreenDelta.dy)
        let finalRemaining = max(
            (minimumScreenSeparation - finalScreenDistance) / screenPointsPerWorldPoint,
            0
        )
        if finalRemaining > 0.001 {
            cpuArenaPosition = clampedToRing(CGPoint(
                x: cpuArenaPosition.x + direction.dx * finalRemaining,
                y: cpuArenaPosition.y + direction.dy * finalRemaining
            ))
        }
    }

    private func separateThreeDArenaFighters(
        direction: CGVector,
        currentDistance: CGFloat,
        minimumDistance: CGFloat
    ) {
        let correction = max(minimumDistance - currentDistance, 0)
        guard correction > 0.001 else { return }
        playerArenaPosition = clampedToRing(CGPoint(
            x: playerArenaPosition.x - direction.dx * correction * 0.5,
            y: playerArenaPosition.y - direction.dy * correction * 0.5
        ))
        cpuArenaPosition = clampedToRing(CGPoint(
            x: cpuArenaPosition.x + direction.dx * correction * 0.5,
            y: cpuArenaPosition.y + direction.dy * correction * 0.5
        ))

        let correctedDistance = hypot(
            cpuArenaPosition.x - playerArenaPosition.x,
            cpuArenaPosition.y - playerArenaPosition.y
        )
        let remaining = max(minimumDistance - correctedDistance, 0)
        guard remaining > 0.001 else { return }
        playerArenaPosition = clampedToRing(CGPoint(
            x: playerArenaPosition.x - direction.dx * remaining,
            y: playerArenaPosition.y - direction.dy * remaining
        ))
        let finalDistance = hypot(
            cpuArenaPosition.x - playerArenaPosition.x,
            cpuArenaPosition.y - playerArenaPosition.y
        )
        let finalRemaining = max(minimumDistance - finalDistance, 0)
        if finalRemaining > 0.001 {
            cpuArenaPosition = clampedToRing(CGPoint(
                x: cpuArenaPosition.x + direction.dx * finalRemaining,
                y: cpuArenaPosition.y + direction.dy * finalRemaining
            ))
        }
    }

    private func clampAndRenderFighters(deltaTime: TimeInterval) {
        playerArenaPosition = clampedToRing(playerArenaPosition)
        cpuArenaPosition = clampedToRing(cpuArenaPosition)
        separateFighters()

        combatArena3DRenderer?.update(
            player: player,
            opponent: cpu,
            playerWorldPosition: playerArenaPosition,
            opponentWorldPosition: cpuArenaPosition,
            deltaTime: deltaTime
        )

        let playerScreenPosition = presentationGeometry.screenPoint(
            forWorldPosition: playerArenaPosition
        )
        let cpuScreenPosition = presentationGeometry.screenPoint(
            forWorldPosition: cpuArenaPosition
        )
        playerToCPUScreenDirection = presentationScreenDirection(forWorldVector: CGVector(
            dx: cpuArenaPosition.x - playerArenaPosition.x,
            dy: cpuArenaPosition.y - playerArenaPosition.y
        ))

        player.position = playerScreenPosition
        cpu.position = cpuScreenPosition

        applyPerspective(to: player, shadow: playerShadow, worldPosition: playerArenaPosition, screenPosition: playerScreenPosition)
        applyPerspective(to: cpu, shadow: cpuShadow, worldPosition: cpuArenaPosition, screenPosition: cpuScreenPosition)
        if let combatArena3DRenderer {
            player.updateDamageEffectAnchor(
                combatArena3DRenderer.damageEffectPoint(for: player)
            )
            cpu.updateDamageEffectAnchor(
                combatArena3DRenderer.damageEffectPoint(for: cpu)
            )
        } else {
            player.updateDamageEffectScreenPosition(
                playerScreenPosition,
                fighterScale: player.xScale
            )
            cpu.updateDamageEffectScreenPosition(
                cpuScreenPosition,
                fighterScale: cpu.xScale
            )
        }
    }

    private func clampedToRing(_ position: CGPoint) -> CGPoint {
        ringProjection.clamped(position)
    }

    private func presentationWorldDirection(forScreenVector vector: CGVector) -> CGVector {
        presentationGeometry.worldDirection(forScreenVector: vector)
    }

    private func presentationScreenDirection(forWorldVector vector: CGVector) -> CGVector {
        presentationGeometry.screenDirection(forWorldVector: vector)
    }

    private func presentationScreenVector(forWorldVector vector: CGVector) -> CGVector {
        presentationGeometry.screenVector(forWorldVector: vector)
    }

    private var presentationGeometry: ArenaPresentationGeometry {
        ArenaPresentationGeometry(
            quarterProjection: ringProjection,
            arenaZoom: arenaZoom,
            combatArena: combatArena3DRenderer
        )
    }

    private func cameraFocusPoint() -> CGPoint {
        let playerWeight = ArenaViewTuning.playerFocusWeight
        return CGPoint(
            x: player.position.x * playerWeight + cpu.position.x * (1 - playerWeight),
            y: player.position.y * playerWeight + cpu.position.y * (1 - playerWeight)
        )
    }

    private func positionCameraImmediately() {
        arenaZoom = desiredArenaZoom()
        cameraRig.setScale(arenaZoom)
        let focus = cameraFocusPoint()
        let target = CGPoint(x: size.width * 0.5, y: size.height * 0.43)
        cameraRig.position = cameraPositionKeepingFightersVisible(
            clampedCameraPosition(CGPoint(
                x: target.x - focus.x * arenaZoom,
                y: target.y - focus.y * arenaZoom
            )),
            zoom: arenaZoom
        )
    }

    private func updateCamera(deltaTime: TimeInterval) {
        guard deltaTime > 0 else { return }
        let focus = cameraFocusPoint()
        let previousZoom = arenaZoom
        let desiredZoom = desiredArenaZoom()
        // Zoom out aggressively when either fighter approaches an edge. A
        // slower zoom-in keeps close exchanges from breathing on every network
        // correction while an urgent zoom-out prevents one-frame escapes.
        let zoomResponse = desiredZoom < arenaZoom
            ? ArenaViewTuning.zoomResponse * 2.4
            : ArenaViewTuning.zoomResponse
        let zoomBlend = 1 - CGFloat(exp(-zoomResponse * deltaTime))
        arenaZoom += (desiredZoom - arenaZoom) * zoomBlend
        // Network authority can move an anchor farther than interpolation did
        // on the previous frame. Never let smoothing keep a zoom that is too
        // tight for the current pair of complete silhouettes.
        arenaZoom = min(arenaZoom, maximumFighterContainmentZoom())
        cameraRig.position = CGPoint(
            x: cameraRig.position.x + focus.x * (previousZoom - arenaZoom),
            y: cameraRig.position.y + focus.y * (previousZoom - arenaZoom)
        )
        cameraRig.setScale(arenaZoom)

        let focusOnScreen = CGPoint(
            x: focus.x * arenaZoom + cameraRig.position.x,
            y: focus.y * arenaZoom + cameraRig.position.y
        )
        let center = CGPoint(x: size.width * 0.5, y: size.height * 0.43)
        let deadZone = CGSize(
            width: size.width * ArenaViewTuning.cameraDeadZoneWidthFraction,
            height: size.height * ArenaViewTuning.cameraDeadZoneHeightFraction
        )
        var correction = CGVector.zero
        if focusOnScreen.x < center.x - deadZone.width { correction.dx = center.x - deadZone.width - focusOnScreen.x }
        if focusOnScreen.x > center.x + deadZone.width { correction.dx = center.x + deadZone.width - focusOnScreen.x }
        if focusOnScreen.y < center.y - deadZone.height { correction.dy = center.y - deadZone.height - focusOnScreen.y }
        if focusOnScreen.y > center.y + deadZone.height { correction.dy = center.y + deadZone.height - focusOnScreen.y }
        let target = correction == .zero
            ? cameraRig.position
            : clampedCameraPosition(CGPoint(
                x: cameraRig.position.x + correction.dx,
                y: cameraRig.position.y + correction.dy
            ))
        let blend = 1 - CGFloat(exp(-ArenaViewTuning.cameraFollowResponse * deltaTime))
        let smoothedPosition = CGPoint(
            x: cameraRig.position.x + (target.x - cameraRig.position.x) * blend,
            y: cameraRig.position.y + (target.y - cameraRig.position.y) * blend
        )
        // Focus following is aesthetic; containment is a gameplay guarantee.
        // Clamp after smoothing so authoritative network corrections cannot
        // leave either complete silhouette outside the device safe area.
        cameraRig.position = cameraPositionKeepingFightersVisible(
            smoothedPosition,
            zoom: arenaZoom
        )
    }

    private func desiredArenaZoom() -> CGFloat {
        let delta = ringProjection.screenVector(forWorldVector: CGVector(
            dx: cpuArenaPosition.x - playerArenaPosition.x,
            dy: cpuArenaPosition.y - playerArenaPosition.y
        ))
        let separation = hypot(delta.dx, delta.dy)
        let range = max(
            ArenaViewTuning.farSeparation - ArenaViewTuning.closeSeparation,
            1
        )
        let distanceProgress = min(max(
            (separation - ArenaViewTuning.closeSeparation) / range,
            0
        ), 1)
        let combatZoom = ArenaViewTuning.closeZoom
            + (ArenaViewTuning.farZoom - ArenaViewTuning.closeZoom) * distanceProgress

        let containmentZoom = maximumFighterContainmentZoom()
        return min(
            max(
                min(combatZoom, containmentZoom),
                ArenaViewTuning.containmentMinimumZoom
            ),
            ArenaViewTuning.closeZoom
        )
    }

    private func maximumFighterContainmentZoom() -> CGFloat {
        let presentationBounds = fighterPresentationBounds()
        let safeFrame = fighterCameraSafeFrame()
        let horizontalFit = presentationBounds.width > 1
            ? safeFrame.width / presentationBounds.width
            : ArenaViewTuning.closeZoom
        let verticalFit = presentationBounds.height > 1
            ? safeFrame.height / presentationBounds.height
            : ArenaViewTuning.closeZoom
        return min(horizontalFit, verticalFit, ArenaViewTuning.closeZoom)
    }

    private func fighterPresentationBounds() -> CGRect {
        fighterPresentationFrame(
            at: player.position,
            worldPosition: playerArenaPosition
        ).union(fighterPresentationFrame(
            at: cpu.position,
            worldPosition: cpuArenaPosition
        ))
    }

    private func fighterPresentationFrame(
        at position: CGPoint,
        worldPosition: CGPoint
    ) -> CGRect {
        let scale = perspectiveScale(at: worldPosition)
            / ArenaViewTuning.baseZoom
            * ArenaViewTuning.fighterScaleBoost
        let halfWidth = ArenaViewTuning.fighterVisibleHalfWidth * scale
        let bottom = ArenaViewTuning.fighterVisibleBottom * scale
        let top = ArenaViewTuning.fighterVisibleTop * scale
        return CGRect(
            x: position.x - halfWidth,
            y: position.y - bottom,
            width: halfWidth * 2,
            height: bottom + top
        )
    }

    private func fighterCameraSafeFrame() -> CGRect {
        let left = safeInsets.left + ArenaViewTuning.cameraHorizontalSafetyMargin
        let right = size.width - safeInsets.right
            - ArenaViewTuning.cameraHorizontalSafetyMargin
        let bottom = safeInsets.bottom + ArenaViewTuning.cameraBottomSafetyMargin
        let top = size.height - safeInsets.top
            - ArenaViewTuning.cameraTopSafetyMargin
        return CGRect(
            x: left,
            y: bottom,
            width: max(right - left, 1),
            height: max(top - bottom, 1)
        )
    }

    private func cameraPositionKeepingFightersVisible(
        _ proposed: CGPoint,
        zoom: CGFloat
    ) -> CGPoint {
        let bounds = fighterPresentationBounds()
        let safeFrame = fighterCameraSafeFrame()

        func fittedAxis(
            proposed: CGFloat,
            contentMinimum: CGFloat,
            contentMaximum: CGFloat,
            safeMinimum: CGFloat,
            safeMaximum: CGFloat
        ) -> CGFloat {
            let minimumPosition = safeMinimum - contentMinimum * zoom
            let maximumPosition = safeMaximum - contentMaximum * zoom
            guard minimumPosition <= maximumPosition else {
                let contentCenter = (contentMinimum + contentMaximum) * 0.5
                let safeCenter = (safeMinimum + safeMaximum) * 0.5
                return safeCenter - contentCenter * zoom
            }
            return min(max(proposed, minimumPosition), maximumPosition)
        }

        let broadlyClamped = clampedCameraPosition(proposed)
        return CGPoint(
            x: fittedAxis(
                proposed: broadlyClamped.x,
                contentMinimum: bounds.minX,
                contentMaximum: bounds.maxX,
                safeMinimum: safeFrame.minX,
                safeMaximum: safeFrame.maxX
            ),
            y: fittedAxis(
                proposed: broadlyClamped.y,
                contentMinimum: bounds.minY,
                contentMaximum: bounds.maxY,
                safeMinimum: safeFrame.minY,
                safeMaximum: safeFrame.maxY
            )
        )
    }

    private func clampedCameraPosition(_ position: CGPoint) -> CGPoint {
        CGPoint(
            x: min(max(position.x, -size.width * 1.35), size.width * 1.25),
            y: min(max(position.y, -size.height * 1.20), size.height * 1.08)
        )
    }

    private func applyPerspective(
        to fighter: FighterNode,
        shadow: FighterGroundShadowNode,
        worldPosition: CGPoint,
        screenPosition: CGPoint
    ) {
        let progress = ringProjection.depthProgress(at: worldPosition)
        let closeupScale: CGFloat
#if DEBUG
        closeupScale = guardCloseupEnabled ? 2.15 : 1
#else
        closeupScale = 1
#endif
        let scale = perspectiveScale(at: worldPosition)
            / ArenaViewTuning.baseZoom
            * ArenaViewTuning.fighterScaleBoost
            * closeupScale
        fighter.setScale(scale)
        // Each fighter is rendered into its own transparent SK3DNode texture,
        // so SpriteKit can only order complete fighters. Use the projected
        // screen depth instead of the approximate world diagonal; otherwise a
        // visually rear fighter can be composited over the nearer silhouette
        // at certain quarter-view angles and look as if it shows through.
        let screenDepth = min(max(screenPosition.y / max(size.height, 1), 0), 1)
        let tieBreaker: CGFloat = fighter === player ? 0.001 : 0
        fighter.zPosition = 12 + (1 - screenDepth) * 16 + tieBreaker

        shadow.position = CGPoint(x: screenPosition.x, y: screenPosition.y - 1)
        shadow.applyPerspective(scale: scale, depthProgress: progress)
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
        if let combatArena3DRenderer {
            let attackerWorld = attacker == .player
                ? playerArenaPosition : cpuArenaPosition
            let defenderWorld = attacker == .player
                ? cpuArenaPosition : playerArenaPosition
            let attackerNode = attacker == .player ? player : cpu
            let defenderNode = attacker == .player ? cpu : player
            let contactPoint = combatArena3DRenderer.punchContactPoint(
                attackerWorldPosition: attackerWorld,
                defenderWorldPosition: defenderWorld,
                committedScreenAim: attackerNode.committedPunchAimDirection,
                attacker: attackerNode,
                defender: defenderNode,
                profile: profile,
                reachScale: motionReachScale
                    * techniqueReachScale
                    * CGFloat(profile.reachScale)
            )
            pendingPunchContactPoints[attacker] = contactPoint
            return contactPoint != nil
        }
        let attackerNode = attacker == .player ? player : cpu
        let defenderNode = attacker == .player ? cpu : player
        // Visual framing may enlarge the fighters for readability. Contact
        // distance must stay at the calibrated boxing scale instead of growing
        // with that presentation-only boost.
        let contactScaleNormalization = ArenaViewTuning.fighterScaleBoost
        let contactPoint = PunchContactGeometry.contactPointOnFighter(
            attackerPosition: attackerNode.position,
            attackerScale: attackerNode.xScale / contactScaleNormalization,
            aimDirection: attackerNode.committedPunchAimDirection,
            defenderPosition: defenderNode.position,
            defenderScale: defenderNode.xScale / contactScaleNormalization,
            profile: profile,
            reachScale: motionReachScale
                * techniqueReachScale
                * CGFloat(profile.reachScale)
        )
        pendingPunchContactPoints[attacker] = contactPoint
        return contactPoint != nil
    }

    private func visibleFighterDistance() -> CGFloat {
        let delta = CGVector(
            dx: cpuArenaPosition.x - playerArenaPosition.x,
            dy: cpuArenaPosition.y - playerArenaPosition.y
        )
        let projectedDelta = presentationScreenVector(forWorldVector: delta)
        return hypot(projectedDelta.dx, projectedDelta.dy)
    }

    private func maximumVisiblePunchDistance(
        for attacker: FighterID,
        armReachScale: CGFloat
    ) -> CGFloat {
        let attackerPosition = attacker == .player ? playerArenaPosition : cpuArenaPosition
        let defenderPosition = attacker == .player ? cpuArenaPosition : playerArenaPosition
        let armReach = CombatTuning.punchArmReachAtUnitScale
            * fighterCombatScale(at: attackerPosition)
            * armReachScale
        let targetRadius = CombatTuning.punchTargetRadiusAtUnitScale
            * fighterCombatScale(at: defenderPosition)
        return armReach + targetRadius
    }

    private func fighterScreenScale(at position: CGPoint) -> CGFloat {
        fighterCombatScale(at: position) * ArenaViewTuning.fighterScaleBoost
    }

    private func fighterCombatScale(at position: CGPoint) -> CGFloat {
        perspectiveScale(at: position) * arenaZoom / ArenaViewTuning.baseZoom
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
            towardOpponent: presentationScreenDirection(forWorldVector: towardOpponent)
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
        let worldMovement = presentationWorldDirection(forScreenVector: effectiveMovement)
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
        motionShowcaseEnabled || uppercutShowcaseEnabled || swayShowcaseEnabled || impactShowcaseEnabled
            || motionClipShowcaseEnabled || fatigueShowcaseEnabled || guardCloseupEnabled
            || damageShowcaseEnabled || cameraShowcaseEnabled || knockoutShowcaseEnabled
#else
        false
#endif
    }

    private func footworkShowcaseMovement(at time: TimeInterval) -> CGVector? {
#if DEBUG
        guard footworkShowcaseEnabled || cameraShowcaseEnabled else { return nil }
        return footworkShowcaseController.frame(at: time).screenMovement
#else
        return nil
#endif
    }

    private func cameraShowcaseOpponentMovement(_ movement: CGVector) -> CGVector {
#if DEBUG
        guard cameraShowcaseEnabled else { return movement }
        return CGVector(dx: -movement.dx, dy: -movement.dy)
#else
        return movement
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
            preferredPunchRange: maximumVisiblePunchDistance(
                for: .cpu,
                armReachScale: CGFloat(cpuCombatStyle.modifier(
                    for: .straight,
                    motion: .quick
                ).reach)
            )
        )
    }

    private func updateCPUCombat(at time: TimeInterval) {
        let perception = cpuPerception(at: time)
        if let command = cpuInputSource.combatCommand(for: perception) {
            execute(command)
            if engine.state(for: .cpu).phase == .punchStartup {
                nextCPUAttackDeadline = time + 1.05
            }
            return
        }

        // A scene-level watchdog guarantees offensive output even if a
        // tactical decision keeps being invalidated at the edge of range.
        // It still waits until the fighters are plausibly close, so this does
        // not turn into repeated full-ring whiffs.
        guard time >= nextCPUAttackDeadline,
              perception.selfState.phase == .idle,
              perception.selfState.stamina >= CombatTuning.straightStaminaCost,
              perception.visibleDistance <= perception.preferredPunchRange * 2.0 else { return }
        execute(FighterCommand(
            fighter: .cpu,
            payload: .action(.punch(PunchIntent(
                forwardDrive: 0.68,
                lateralDrive: 0,
                movementIntensity: 0.80
            ))),
            issuedAt: time
        ))
        nextCPUAttackDeadline = time + 1.05
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
                y: Double(intent.screenDirection.dy)
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
            let screenDirection = CGVector(dx: input.x, dy: input.y)
            let intent = resolvedSwayIntent(
                for: remoteFighter,
                screenDirection: screenDirection
            )
            execute(FighterCommand(
                fighter: remoteFighter,
                payload: .action(.sway(intent)),
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

    private func resolvedSwayIntent(
        for fighter: FighterID,
        screenDirection: CGVector
    ) -> SwayIntent {
        let towardOpponent = fighter == .player
            ? CGVector(
                dx: cpuArenaPosition.x - playerArenaPosition.x,
                dy: cpuArenaPosition.y - playerArenaPosition.y
            )
            : CGVector(
                dx: playerArenaPosition.x - cpuArenaPosition.x,
                dy: playerArenaPosition.y - cpuArenaPosition.y
            )
        return SwayInputResolver.resolve(
            movement: screenDirection,
            towardOpponent: presentationScreenDirection(forWorldVector: towardOpponent)
        )
    }

#if DEBUG
    private func updateGuardCloseup() {
        cpu.isHidden = true
        cpuShadow.isHidden = true
        guard statusLabel.text != "GUARD CLOSEUP" else { return }
        statusLabel.removeAllActions()
        statusLabel.alpha = 1
        statusLabel.fontColor = .systemCyan
        statusLabel.text = "GUARD CLOSEUP"
    }

    private func updateDamageShowcase() {
        playerHealthBar.xScale = 0.14
        cpuHealthBar.xScale = 0.31
        guard statusLabel.text != "DAMAGE SYSTEM" else { return }
        statusLabel.removeAllActions()
        statusLabel.alpha = 1
        statusLabel.fontColor = ArenaVisualPalette.dangerSignal
        statusLabel.text = "DAMAGE SYSTEM"
    }

    private func updateKnockoutShowcase() {
        guard statusLabel.text != "KNOCKOUT GROUNDING" else { return }
        statusLabel.removeAllActions()
        statusLabel.alpha = 1
        statusLabel.fontColor = ArenaVisualPalette.dangerSignal
        statusLabel.text = "KNOCKOUT GROUNDING"
        cpu.show(phase: .knockedOut)
    }

    private func updateFatigueShowcase() {
        updateStamina(.cpu, stamina: 0)
        guard statusLabel.text != "CPU EXHAUSTED" else { return }
        statusLabel.removeAllActions()
        statusLabel.alpha = 1
        statusLabel.fontColor = .systemRed
        statusLabel.text = "CPU EXHAUSTED"
    }

    private func updateFootworkShowcase(at time: TimeInterval) {
        let frame = footworkShowcaseController.frame(at: time)
        let towardPlayer = CGVector(
            dx: -playerToCPUScreenDirection.dx,
            dy: -playerToCPUScreenDirection.dy
        )
        if let transition = footworkShowcaseController.transition(
            at: time,
            state: engine.state(for: .cpu),
            towardOpponent: towardPlayer
        ) {
            statusLabel.removeAllActions()
            statusLabel.alpha = 1
            statusLabel.fontColor = .systemCyan
            statusLabel.text = transition.label
            execute(FighterCommand(
                fighter: .cpu,
                payload: .action(transition.action),
                issuedAt: time
            ))
        } else if engine.state(for: .cpu).phase == .idle,
                  statusLabel.text != frame.label {
            statusLabel.removeAllActions()
            statusLabel.alpha = 1
            statusLabel.fontColor = frame.screenMovement == .zero ? .systemGreen : .systemYellow
            statusLabel.text = frame.label
        }
    }

    private func updateMotionClipShowcase(at time: TimeInterval) {
        guard let label = motionClipShowcaseController.command(
            at: time,
            state: engine.state(for: .cpu)
        ) else { return }
        statusLabel.removeAllActions()
        statusLabel.alpha = 1
        statusLabel.fontColor = label.hasPrefix("CLIP") ? .systemCyan : .systemYellow
        statusLabel.text = label
        execute(FighterCommand(
            fighter: .cpu,
            payload: .action(.punch(.neutral)),
            issuedAt: time
        ))
    }

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
        statusLabel.fontColor = intent.isTowardOpponent ? .systemRed : .systemYellow
        statusLabel.text = demo.label
        let playerIntent = SwayInputResolver.resolve(
            movement: demo.screenDirection,
            towardOpponent: playerToCPUScreenDirection
        )
        execute(FighterCommand(
            fighter: .player,
            payload: .action(.sway(playerIntent)),
            issuedAt: time
        ))
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
#if DEBUG
                if fighterStyleShowcaseEnabled, fighter == .cpu {
                    statusLabel.text = String(
                        format: "PWR %.2f  SPD %.2f  RNG %.2f",
                        profile.powerScale,
                        1 / profile.startupScale,
                        profile.reachScale
                    )
                }
#endif
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
                restartLabel.text = networkConfiguration == nil ? "PLAY AGAIN" : "REQUEST REMATCH"
                controls.alpha = 0.35
                localInputSource.reset(at: gameTime)
                controls.endMovement()
                playerMovementSmoother.reset()
                cpuMovementSmoother.reset()
                playerBodyMotion.reset()
                cpuBodyMotion.reset()
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
        node(for: fighter).updateDamage(fraction: fraction)
        let action = SKAction.scaleX(to: fraction, duration: CombatTuning.healthBarAnimationDuration)
        action.timingMode = .easeOut
        bar.run(action)
    }

    private func updateStamina(_ fighter: FighterID, stamina: Double) {
        let state = engine.state(for: fighter)
        let fraction = CGFloat(stamina / state.stats.maximumStamina)
        node(for: fighter).updateStamina(fraction: fraction)
        let bar = fighter == .player ? playerStaminaBar : cpuStaminaBar
        bar.xScale = fraction
        if stamina <= state.stats.lowStaminaThreshold {
            bar.color = ArenaVisualPalette.hudStaminaLow
        } else if stamina <= state.stats.maximumStamina * 0.50 {
            bar.color = ArenaVisualPalette.hudStamina.withAlphaComponent(0.78)
        } else {
            bar.color = ArenaVisualPalette.hudStamina
        }
    }

    private func showImpact(
        _ kind: HitKind,
        profile: PunchProfile,
        attacker: FighterID,
        defender: FighterID
    ) {
        let attackerNode = node(for: attacker)
        let defenderNode = node(for: defender)
        let averageScale = (attackerNode.xScale + defenderNode.xScale) / 2
        let fallback = CGPoint(
            x: attackerNode.position.x * 0.28 + defenderNode.position.x * 0.72,
            y: attackerNode.position.y * 0.22 + defenderNode.position.y * 0.78
                + 70 * averageScale
        )
        let projectedContact = pendingPunchContactPoints.removeValue(forKey: attacker)
        let contactPoint = projectedContact.map {
            frame.insetBy(dx: -24, dy: -24).contains($0) ? $0 : fallback
        } ?? fallback
        let color: SKColor
        switch (kind, profile.technique) {
        case (.counter, _): color = .systemYellow
        case (_, .straight): color = .white
        case (_, .smash): color = .systemOrange
        case (_, .uppercut): color = .systemCyan
        }

        combatArena3DRenderer?.showImpact(
            on: defenderNode,
            technique: profile.technique,
            color: color,
            isCounter: kind == .counter
        )

        let root = SKNode()
        root.position = contactPoint
        root.zPosition = 130
        root.setScale(0.72 * impactPresentationScale)

        let radius: CGFloat
        switch (kind, profile.technique) {
        case (.counter, _): radius = 42
        case (_, .straight): radius = 22
        case (_, .smash): radius = 31
        case (_, .uppercut): radius = 28
        }
        let burst = SKShapeNode(path: impactBurstPath(radius: radius))
        burst.fillColor = color.withAlphaComponent(kind == .counter ? 0.42 : 0.30)
        burst.strokeColor = color.withAlphaComponent(0.96)
        burst.lineWidth = kind == .counter ? 5.2 : 3.4
        burst.glowWidth = kind == .counter ? 7 : 4
        root.addChild(burst)

        let core = SKShapeNode(path: impactDiamondPath(radius: radius * 0.30))
        core.fillColor = color.withAlphaComponent(0.96)
        core.strokeColor = .clear
        core.glowWidth = 5
        core.zPosition = 2
        root.addChild(core)

        let shockRing = SKShapeNode(circleOfRadius: radius * 0.64)
        shockRing.fillColor = .clear
        shockRing.strokeColor = color.withAlphaComponent(0.72)
        shockRing.lineWidth = kind == .counter ? 4 : 2.4
        shockRing.glowWidth = 4
        shockRing.zPosition = 1
        root.addChild(shockRing)

        let direction = CGVector(
            dx: defenderNode.position.x - attackerNode.position.x,
            dy: defenderNode.position.y - attackerNode.position.y
        )
        addImpactSparks(
            to: root,
            color: color,
            direction: direction,
            technique: profile.technique,
            isCounter: kind == .counter
        )
        showMechanicalFragments(
            at: contactPoint,
            color: color,
            direction: direction,
            isCounter: kind == .counter,
            power: CGFloat(profile.powerScale)
        )

        impactPresentationLayer.addChild(root)
        root.run(.sequence([
            .wait(forDuration: 0.035),
            .group([
                .scale(
                    to: 1.42 * impactPresentationScale,
                    duration: CombatTuning.impactAnimationDuration
                ),
                .fadeOut(withDuration: CombatTuning.impactAnimationDuration)
            ]),
            .removeFromParent()
        ]))
    }

    private func impactDiamondPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: 0, y: radius))
        path.addLine(to: CGPoint(x: radius * 0.72, y: 0))
        path.addLine(to: CGPoint(x: 0, y: -radius))
        path.addLine(to: CGPoint(x: -radius * 0.72, y: 0))
        path.closeSubpath()
        return path
    }

    private func impactBurstPath(radius: CGFloat) -> CGPath {
        let path = CGMutablePath()
        let pointCount = 16
        for index in 0..<pointCount {
            let angle = -CGFloat.pi / 2
                + CGFloat(index) * (2 * CGFloat.pi / CGFloat(pointCount))
            let pointRadius = index.isMultiple(of: 2) ? radius : radius * 0.56
            let point = CGPoint(
                x: cos(angle) * pointRadius,
                y: sin(angle) * pointRadius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }

    private func addImpactSparks(
        to root: SKNode,
        color: SKColor,
        direction: CGVector,
        technique: PunchTechnique,
        isCounter: Bool
    ) {
        let directionAngle = atan2(direction.dy, direction.dx)
        let count = isCounter ? 11 : 7
        for index in 0..<count {
            let centered = CGFloat(index) - CGFloat(count - 1) * 0.5
            var angle = directionAngle + centered * (isCounter ? 0.24 : 0.30)
            switch technique {
            case .straight: break
            case .smash: angle -= 0.22
            case .uppercut: angle += 0.34
            }
            let length = CGFloat(18 + (index * 11) % 24) * (isCounter ? 1.35 : 1)
            let path = CGMutablePath()
            path.move(to: .zero)
            path.addLine(to: CGPoint(
                x: cos(angle) * length,
                y: sin(angle) * length
            ))
            let spark = SKShapeNode(path: path)
            spark.strokeColor = index.isMultiple(of: 3)
                ? SKColor.white.withAlphaComponent(0.92)
                : color.withAlphaComponent(0.86)
            spark.lineWidth = isCounter ? 3.2 : 2.2
            spark.lineCap = .round
            spark.glowWidth = isCounter ? 4 : 2
            spark.zPosition = 1
            root.addChild(spark)
        }
    }

    private func showMechanicalFragments(
        at contactPoint: CGPoint,
        color: SKColor,
        direction: CGVector,
        isCounter: Bool,
        power: CGFloat
    ) {
        let root = SKNode()
        root.position = contactPoint
        root.zPosition = 132
        root.setScale(impactPresentationScale)
        impactPresentationLayer.addChild(root)

        let baseAngle = atan2(direction.dy, direction.dx)
        let count = isCounter ? 14 : 9
        let clampedPower = min(max(power, 0.7), 1.35)
        for index in 0..<count {
            let spread = (CGFloat(index) / CGFloat(max(count - 1, 1)) - 0.5)
                * (isCounter ? 2.2 : 1.72)
            let angle = baseAngle + spread + CGFloat((index * 17) % 9 - 4) * 0.035
            let distance = CGFloat(30 + (index * 13) % 31)
                * clampedPower * (isCounter ? 1.22 : 1)
            let fragment = SKShapeNode(rectOf: CGSize(
                width: index.isMultiple(of: 3) ? 8 : 5,
                height: index.isMultiple(of: 2) ? 1.8 : 1.2
            ), cornerRadius: 0.6)
            fragment.fillColor = index.isMultiple(of: 4)
                ? ArenaVisualPalette.whiteMark
                : (index.isMultiple(of: 3) ? color : ArenaVisualPalette.amberSignal)
            fragment.strokeColor = .clear
            fragment.glowWidth = isCounter ? 4 : 2.5
            fragment.zRotation = angle
            root.addChild(fragment)

            let firstLeg = SKAction.group([
                .moveBy(
                    x: cos(angle) * distance * 0.68,
                    y: sin(angle) * distance * 0.68 + 8,
                    duration: 0.11
                ),
                .rotate(byAngle: spread * 1.8, duration: 0.11),
                .scale(to: 0.72, duration: 0.11)
            ])
            firstLeg.timingMode = .easeOut
            let fall = SKAction.group([
                .moveBy(
                    x: cos(angle) * distance * 0.32,
                    y: sin(angle) * distance * 0.18 - 20,
                    duration: 0.18
                ),
                .rotate(byAngle: spread * 1.4, duration: 0.18),
                .fadeOut(withDuration: 0.18)
            ])
            fall.timingMode = .easeIn
            fragment.run(.sequence([firstLeg, fall, .removeFromParent()]))
        }
        root.run(.sequence([.wait(forDuration: 0.32), .removeFromParent()]))
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
        let shakeNode = combatArena3DRenderer?.viewport ?? arenaNode
        let restingPosition = shakeNode.position
        shakeNode.removeAction(forKey: "shake")
        shakeNode.run(.sequence([
            .moveBy(x: dx, y: dy, duration: CombatTuning.cameraShakeDuration * 0.16),
            .moveBy(x: -dx * 1.75, y: -dy * 1.75, duration: CombatTuning.cameraShakeDuration * 0.23),
            .moveBy(x: dx * 1.20, y: dy * 1.20, duration: CombatTuning.cameraShakeDuration * 0.21),
            .move(to: restingPosition, duration: CombatTuning.cameraShakeDuration * 0.40)
        ]), withKey: "shake")
    }

    private var impactPresentationLayer: SKNode {
        combatArena3DRenderer == nil ? arenaNode : self
    }

    private var impactPresentationScale: CGFloat {
        combatArena3DRenderer == nil ? 1 / arenaZoom : 1
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
            restartLabel.text = "CANCEL REQUEST"
            statusLabel.text = "WAITING FOR REMATCH RESPONSE"
            statusLabel.fontColor = .systemYellow
        } else if remote {
            restartLabel.text = "ACCEPT REMATCH"
            statusLabel.text = "OPPONENT REQUESTED A REMATCH"
            statusLabel.fontColor = .systemGreen
        } else {
            restartLabel.text = "REQUEST REMATCH"
            statusLabel.text = "REQUEST A REMATCH OR LEAVE THE MATCH"
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
        playerBodyMotion.reset()
        cpuBodyMotion.reset()
        controls.showMovement(nil)
        localRematchAccepted = false
        remoteRematchAccepted = false
        handle(engine.reset())
        cpuInputSource.reset(at: gameTime)
        nextCPUAttackDeadline = gameTime + CombatTuning.cpuInitialDelay
#if DEBUG
        motionShowcaseController.reset(at: gameTime)
        swayShowcaseController.reset(at: gameTime)
        motionClipShowcaseController.reset(at: gameTime)
        footworkShowcaseController.reset(at: gameTime)
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
