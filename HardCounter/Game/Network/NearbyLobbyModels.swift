import Foundation
import Network

enum NearbyLobbyRole: Equatable {
    case host
    case guest
}

struct NearbyMatchConfiguration: Equatable {
    let id: UUID
    let role: NearbyLobbyRole
    let hostName: String
    let guestName: String
    let hostFighter: FighterProfile
    let guestFighter: FighterProfile

    var localFighterID: FighterID { role == .host ? .player : .cpu }
    var remoteFighterID: FighterID { localFighterID.opponent }
}

enum NearbyLobbyPhase: Equatable {
    case idle
    case hosting
    case browsing
    case connecting(String)
    case connected
    case failed(String)
}

struct NearbyRoom: Identifiable {
    let id: String
    let name: String
    let endpoint: NWEndpoint
}

struct NearbyLobbyMessage: Codable {
    enum Kind: String, Codable {
        case snapshot
        case startMatch
        case combatInput
        case combatState
        case rematchVote
        case restartRound
    }

    static let protocolVersion = 3

    let version: Int
    let kind: Kind
    var playerName: String?
    var fighterID: String?
    var isReady: Bool?
    var matchID: UUID?
    var combatInput: NearbyCombatInput?
    var combatState: NearbyCombatState?
    var rematchAccepted: Bool?

    init(playerName: String, fighter: FighterProfile, isReady: Bool) {
        version = Self.protocolVersion
        kind = .snapshot
        self.playerName = playerName
        fighterID = fighter.rawValue
        self.isReady = isReady
    }

    init(kind: Kind, matchID: UUID, input: NearbyCombatInput? = nil, state: NearbyCombatState? = nil) {
        version = Self.protocolVersion
        self.kind = kind
        self.matchID = matchID
        combatInput = input
        combatState = state
    }

    init(matchID: UUID, rematchAccepted: Bool) {
        version = Self.protocolVersion
        kind = .rematchVote
        self.matchID = matchID
        self.rematchAccepted = rematchAccepted
    }
}

struct NearbyCombatInput: Codable {
    enum Kind: String, Codable { case movement, punch, sway }
    let sequence: UInt64
    let kind: Kind
    var x: Double = 0
    var y: Double = 0
    var forwardDrive: Double = 0
    var lateralDrive: Double = 0
    var movementIntensity: Double = 0
    var swayDirection: String?
    var isTowardOpponent = false
}

struct NearbyCombatState: Codable {
    let sequence: UInt64
    let playerX: Double
    let playerY: Double
    let cpuX: Double
    let cpuY: Double
    let playerHealth: Int
    let cpuHealth: Int
    let playerStamina: Double
    let cpuStamina: Double
    let winner: String?
}
