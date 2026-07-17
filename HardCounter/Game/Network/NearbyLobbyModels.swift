import Foundation
import Network

enum NearbyLobbyRole: Equatable {
    case host
    case guest
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
    }

    static let protocolVersion = 1

    let version: Int
    let kind: Kind
    let playerName: String
    let fighterID: String
    let isReady: Bool

    init(playerName: String, fighter: FighterProfile, isReady: Bool) {
        version = Self.protocolVersion
        kind = .snapshot
        self.playerName = playerName
        fighterID = fighter.rawValue
        self.isReady = isReady
    }
}
