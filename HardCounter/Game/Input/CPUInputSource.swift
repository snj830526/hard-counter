import Foundation

struct CPUInputSource: FighterInputSource {
    let fighter: FighterID = .cpu
    private var controller = CPUController()

    mutating func reset(at time: TimeInterval) {
        controller.reset(at: time)
    }

    mutating func movementCommand(for perception: CPUPerception) -> FighterCommand {
        FighterCommand(
            fighter: fighter,
            payload: .movement(controller.movement(for: perception)),
            issuedAt: perception.time
        )
    }

    mutating func combatCommand(for perception: CPUPerception) -> FighterCommand? {
        guard let action = controller.combatAction(for: perception) else { return nil }
        return FighterCommand(
            fighter: fighter,
            payload: .action(action),
            issuedAt: perception.time
        )
    }
}
