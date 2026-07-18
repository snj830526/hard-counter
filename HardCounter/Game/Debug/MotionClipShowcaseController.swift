#if DEBUG
import Foundation

struct MotionClipShowcaseController {
    private var nextPunchAt: TimeInterval?
    private var usesLegacyLead = true

    mutating func reset(at time: TimeInterval) {
        nextPunchAt = time + 0.8
        usesLegacyLead = true
    }

    mutating func command(
        at time: TimeInterval,
        state: FighterCombatState
    ) -> String? {
        if nextPunchAt == nil { reset(at: time) }
        guard let nextPunchAt, time >= nextPunchAt, state.phase == .idle else {
            return nil
        }
        let label = usesLegacyLead
            ? "LEGACY LEAD STRAIGHT"
            : "CLIP REAR STRAIGHT"
        usesLegacyLead.toggle()
        self.nextPunchAt = time + 1.25
        return label
    }
}
#endif
