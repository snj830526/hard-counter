import CoreGraphics
import Foundation

enum FighterCommandPayload {
    case movement(CGVector)
    case action(CombatAction)
}

struct FighterCommand {
    let fighter: FighterID
    let payload: FighterCommandPayload
    let issuedAt: TimeInterval
}

protocol FighterInputSource {
    var fighter: FighterID { get }
    mutating func reset(at time: TimeInterval)
}

extension FighterCommand {
    var movementVector: CGVector? {
        guard case let .movement(vector) = payload else { return nil }
        return vector
    }
}
