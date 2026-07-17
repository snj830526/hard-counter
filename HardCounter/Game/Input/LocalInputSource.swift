import CoreGraphics
import Foundation

final class LocalInputSource: FighterInputSource {
    let fighter: FighterID

    private var movementTouchID: ObjectIdentifier?
    private var movementVector = CGVector.zero
    private var rememberedSwayMovement = CGVector.zero
    private var rememberedSwayMovementAt: TimeInterval = -.infinity
    private var bufferedPunch: PunchIntent?
    private var bufferedPunchExpiresAt: TimeInterval = 0

    init(fighter: FighterID = .player) {
        self.fighter = fighter
    }

    func reset(at time: TimeInterval) {
        movementTouchID = nil
        movementVector = .zero
        rememberedSwayMovement = .zero
        rememberedSwayMovementAt = -.infinity
        clearBufferedPunch()
    }

    func beginMovement(touchID: ObjectIdentifier) -> Bool {
        guard movementTouchID == nil else { return false }
        movementTouchID = touchID
        movementVector = .zero
        return true
    }

    @discardableResult
    func updateMovement(
        touchID: ObjectIdentifier,
        vector: CGVector,
        at time: TimeInterval
    ) -> Bool {
        guard movementTouchID == touchID else { return false }
        movementVector = vector
        if hypot(vector.dx, vector.dy) > 0.18 {
            rememberedSwayMovement = vector
            rememberedSwayMovementAt = time
        }
        return true
    }

    func endMovement(touchIDs: Set<ObjectIdentifier>) -> Bool {
        guard let movementTouchID, touchIDs.contains(movementTouchID) else { return false }
        self.movementTouchID = nil
        movementVector = .zero
        return true
    }

    func movementCommand(at time: TimeInterval) -> FighterCommand {
        FighterCommand(
            fighter: fighter,
            payload: .movement(movementVector),
            issuedAt: time
        )
    }

    func actionCommand(_ action: CombatAction, at time: TimeInterval) -> FighterCommand {
        FighterCommand(fighter: fighter, payload: .action(action), issuedAt: time)
    }

    func swayIntent(
        at time: TimeInterval,
        towardOpponent: CGVector
    ) -> SwayIntent {
        let useRememberedDirection = hypot(movementVector.dx, movementVector.dy) <= 0.18
            && time - rememberedSwayMovementAt <= CombatTuning.swayDirectionInputGrace
        return SwayInputResolver.resolve(
            movement: useRememberedDirection ? rememberedSwayMovement : movementVector,
            towardOpponent: towardOpponent
        )
    }

    func recordPunchResult(
        intent: PunchIntent,
        events: [CombatEvent],
        stateBeforeRequest: FighterCombatState,
        at time: TimeInterval
    ) {
        guard events.isEmpty else {
            clearBufferedPunch()
            return
        }
        bufferedPunch = intent
        let normalExpiry = time + CombatTuning.punchInputBuffer
        if stateBeforeRequest.phase == .swaying {
            bufferedPunchExpiresAt = max(
                normalExpiry,
                stateBeforeRequest.swayStartedAt
                    + CombatTuning.swayPunchCancelDelay
                    + CombatTuning.swayPunchBufferGrace
            )
        } else {
            bufferedPunchExpiresAt = normalExpiry
        }
    }

    func bufferedPunchCommand(
        at time: TimeInterval,
        state: FighterCombatState
    ) -> FighterCommand? {
        guard let bufferedPunch else { return nil }
        guard time <= bufferedPunchExpiresAt else {
            clearBufferedPunch()
            return nil
        }
        let canTransitionFromSway = state.phase == .swaying
            && (state.swayWasSuccessful
                || time >= state.swayStartedAt + CombatTuning.swayPunchCancelDelay)
        guard state.phase == .idle || canTransitionFromSway else { return nil }

        clearBufferedPunch()
        return actionCommand(.punch(bufferedPunch), at: time)
    }

    func extendBufferedPunch(until time: TimeInterval) {
        guard bufferedPunch != nil else { return }
        bufferedPunchExpiresAt = max(bufferedPunchExpiresAt, time)
    }

    func clearBufferedPunch() {
        bufferedPunch = nil
        bufferedPunchExpiresAt = 0
    }
}
