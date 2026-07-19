import Combine
import Foundation
import Network
import UIKit

final class NearbyLobbyService: ObservableObject {
    static let serviceType = "_hardcounter._tcp"

    @Published private(set) var phase: NearbyLobbyPhase = .idle
    @Published private(set) var rooms: [NearbyRoom] = []
    @Published private(set) var role: NearbyLobbyRole?
    @Published private(set) var localPlayerName = UIDevice.current.name
    @Published private(set) var remotePlayerName = "OPPONENT"
    @Published private(set) var remoteFighter: FighterProfile = .allRounder
    @Published private(set) var remoteIsReady = false
    @Published private(set) var matchConfiguration: NearbyMatchConfiguration?
    @Published private(set) var localRematchAccepted = false
    @Published private(set) var remoteRematchAccepted = false
    @Published var localFighter: FighterProfile = .allRounder {
        didSet {
            if localFighter != oldValue {
                localIsReady = false
                sendSnapshot()
            }
        }
    }
    @Published var localIsReady = false {
        didSet {
            if localIsReady != oldValue {
                sendSnapshot()
            }
        }
    }

    var isConnected: Bool { phase == .connected }
    var bothPlayersReady: Bool { isConnected && localIsReady && remoteIsReady }
    var onCombatInput: ((NearbyCombatInput) -> Void)?
    var onCombatState: ((NearbyCombatState) -> Void)?
    var onRestartRound: (() -> Void)?
    var onRematchStateChanged: ((Bool, Bool) -> Void)?

    private let networkQueue = DispatchQueue(label: "com.soonispapa.HardCounter.nearby")
    private var listener: NWListener?
    private var browser: NWBrowser?
    private var connection: NWConnection?
    private var receiveBuffer = Data()
    private var isStopping = false
    private var combatInputSequence: UInt64 = 0

    deinit {
        listener?.cancel()
        browser?.cancel()
        connection?.cancel()
    }

    func startHosting() {
        stop(resetPhase: false)
        role = .host
        phase = .hosting
        remoteIsReady = false
        remotePlayerName = "OPPONENT"

        do {
            let parameters = Self.networkParameters()
            let listener = try NWListener(using: parameters)
            listener.service = NWListener.Service(
                name: Self.sanitizedServiceName(localPlayerName),
                type: Self.serviceType
            )
            listener.stateUpdateHandler = { [weak self] state in
                Task { @MainActor in self?.handleListenerState(state) }
            }
            listener.newConnectionHandler = { [weak self] connection in
                Task { @MainActor in self?.accept(connection) }
            }
            self.listener = listener
            listener.start(queue: networkQueue)
        } catch {
            fail("Unable to create room: \(error.localizedDescription)")
        }
    }

    func startBrowsing() {
        stop(resetPhase: false)
        role = .guest
        phase = .browsing
        rooms = []
        remoteIsReady = false

        let browser = NWBrowser(
            for: .bonjour(type: Self.serviceType, domain: nil),
            using: Self.networkParameters()
        )
        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in self?.handleBrowserState(state) }
        }
        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.rooms = results.map(Self.room(from:)).sorted { $0.name < $1.name }
            }
        }
        self.browser = browser
        browser.start(queue: networkQueue)
    }

    func join(_ room: NearbyRoom) {
        guard role == .guest else { return }
        browser?.cancel()
        browser = nil
        rooms = []
        phase = .connecting(room.name)
        beginConnection(NWConnection(to: room.endpoint, using: Self.networkParameters()))
    }

    func toggleReady() {
        guard isConnected else { return }
        localIsReady.toggle()
        tryStartMatchIfHost()
    }

    func sendCombatInput(_ input: NearbyCombatInput) {
        guard let matchID = matchConfiguration?.id else { return }
        send(NearbyLobbyMessage(kind: .combatInput, matchID: matchID, input: input))
    }

    func nextCombatInputSequence() -> UInt64 {
        combatInputSequence &+= 1
        return combatInputSequence
    }

    func sendCombatState(_ state: NearbyCombatState) {
        guard role == .host, let matchID = matchConfiguration?.id else { return }
        send(NearbyLobbyMessage(kind: .combatState, matchID: matchID, state: state))
    }

    func setRematchAccepted(_ accepted: Bool) {
        guard let matchID = matchConfiguration?.id else { return }
        localRematchAccepted = accepted
        onRematchStateChanged?(localRematchAccepted, remoteRematchAccepted)
        send(NearbyLobbyMessage(matchID: matchID, rematchAccepted: accepted))
        beginRematchIfHostAndReady()
    }

    func detachCombatHandlers() {
        onCombatInput = nil
        onCombatState = nil
        onRestartRound = nil
        onRematchStateChanged = nil
    }

    func retry() {
        if role == .host {
            startHosting()
        } else {
            startBrowsing()
        }
    }

    func stop() {
        stop(resetPhase: true)
    }

    private func stop(resetPhase: Bool) {
        isStopping = true
        listener?.cancel()
        listener = nil
        browser?.cancel()
        browser = nil
        connection?.cancel()
        connection = nil
        receiveBuffer.removeAll(keepingCapacity: false)
        rooms = []
        remoteIsReady = false
        localIsReady = false
        matchConfiguration = nil
        resetRematchState(notify: false)
        detachCombatHandlers()
        if resetPhase {
            phase = .idle
            role = nil
        }
        isStopping = false
    }

    private func accept(_ newConnection: NWConnection) {
        guard connection == nil, role == .host else {
            newConnection.cancel()
            return
        }
        listener?.cancel()
        listener = nil
        phase = .connecting("OPPONENT")
        beginConnection(newConnection)
    }

    private func beginConnection(_ newConnection: NWConnection) {
        connection?.cancel()
        connection = newConnection
        receiveBuffer.removeAll(keepingCapacity: true)
        newConnection.stateUpdateHandler = { [weak self, weak newConnection] state in
            guard let newConnection else { return }
            Task { @MainActor in self?.handleConnectionState(state, connection: newConnection) }
        }
        newConnection.start(queue: networkQueue)
    }

    private func handleListenerState(_ state: NWListener.State) {
        switch state {
        case .ready:
            phase = .hosting
        case let .failed(error):
            fail("Unable to open room: \(error.localizedDescription)")
        case .cancelled:
            break
        default:
            break
        }
    }

    private func handleBrowserState(_ state: NWBrowser.State) {
        switch state {
        case .ready:
            phase = .browsing
        case .waiting:
            // This state may arrive while the initial Local Network permission response is pending.
            // Keeping the browser active allows discovery to continue after permission is granted.
            phase = .browsing
        case let .failed(error):
            fail("Unable to find nearby rooms: \(error.localizedDescription)")
        case .cancelled:
            break
        default:
            break
        }
    }

    private func handleConnectionState(_ state: NWConnection.State, connection: NWConnection) {
        guard self.connection === connection else { return }

        switch state {
        case .ready:
            phase = .connected
            sendSnapshot()
            receiveNext(on: connection)
        case let .waiting(error):
            phase = .connecting(error.localizedDescription)
        case let .failed(error):
            fail("Connection lost: \(error.localizedDescription)")
        case .cancelled:
            if !isStopping, phase == .connected {
                fail("The opponent ended the connection.")
            }
        default:
            break
        }
    }

    private func sendSnapshot() {
        let message = NearbyLobbyMessage(
            playerName: localPlayerName,
            fighter: localFighter,
            isReady: localIsReady
        )
        send(message)
    }

    private func send(_ message: NearbyLobbyMessage) {
        guard phase == .connected, let connection else { return }

        do {
            let payload = try JSONEncoder().encode(message)
            guard payload.count <= 65_536 else { return }

            var length = UInt32(payload.count).bigEndian
            var frame = Data(bytes: &length, count: MemoryLayout<UInt32>.size)
            frame.append(payload)
            connection.send(content: frame, completion: .contentProcessed { [weak self] error in
                guard let self, let error else { return }
                let message = "Unable to send lobby data: \(error.localizedDescription)"
                Task { @MainActor [self] in
                    self.fail(message)
                }
            })
        } catch {
            fail("Unable to create network data: \(error.localizedDescription)")
        }
    }

    private func receiveNext(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65_540) { [weak self, weak connection] data, _, isComplete, error in
            guard let self, let connection else { return }
            Task { @MainActor in
                guard self.connection === connection else { return }
                if let data, !data.isEmpty {
                    self.receiveBuffer.append(data)
                    self.processReceivedFrames()
                }
                if let error {
                    self.fail("Unable to receive lobby data: \(error.localizedDescription)")
                    return
                }
                if isComplete {
                    self.fail("The opponent left the lobby.")
                    return
                }
                self.receiveNext(on: connection)
            }
        }
    }

    private func processReceivedFrames() {
        while receiveBuffer.count >= MemoryLayout<UInt32>.size {
            let length = receiveBuffer.prefix(4).reduce(UInt32.zero) { ($0 << 8) | UInt32($1) }
            guard length <= 65_536 else {
                fail("Received incompatible lobby data.")
                return
            }
            let frameLength = 4 + Int(length)
            guard receiveBuffer.count >= frameLength else { return }
            let payload = receiveBuffer.subdata(in: 4..<frameLength)
            receiveBuffer.removeSubrange(0..<frameLength)

            do {
                let message = try JSONDecoder().decode(NearbyLobbyMessage.self, from: payload)
                guard message.version == NearbyLobbyMessage.protocolVersion else {
                    fail("Different game versions cannot connect.")
                    return
                }
                process(message)
            } catch {
                fail("Unable to read lobby data.")
                return
            }
        }
    }

    private func process(_ message: NearbyLobbyMessage) {
        switch message.kind {
        case .snapshot:
            guard let playerName = message.playerName,
                  let fighterID = message.fighterID,
                  let fighter = FighterProfile(rawValue: fighterID),
                  let isReady = message.isReady else {
                fail("Received incompatible lobby information.")
                return
            }
            remotePlayerName = playerName
            remoteFighter = fighter
            remoteIsReady = isReady
            tryStartMatchIfHost()
        case .startMatch:
            guard role == .guest, let matchID = message.matchID else { return }
            matchConfiguration = makeMatchConfiguration(id: matchID)
        case .combatInput:
            guard message.matchID == matchConfiguration?.id, let input = message.combatInput else { return }
            onCombatInput?(input)
        case .combatState:
            guard role == .guest,
                  message.matchID == matchConfiguration?.id,
                  let state = message.combatState else { return }
            onCombatState?(state)
        case .rematchVote:
            guard message.matchID == matchConfiguration?.id,
                  let accepted = message.rematchAccepted else { return }
            remoteRematchAccepted = accepted
            onRematchStateChanged?(localRematchAccepted, remoteRematchAccepted)
            beginRematchIfHostAndReady()
        case .restartRound:
            guard role == .guest, message.matchID == matchConfiguration?.id else { return }
            resetRematchState(notify: true)
            onRestartRound?()
        }
    }

    private func tryStartMatchIfHost() {
        guard role == .host, bothPlayersReady, matchConfiguration == nil else { return }
        let matchID = UUID()
        matchConfiguration = makeMatchConfiguration(id: matchID)
        send(NearbyLobbyMessage(kind: .startMatch, matchID: matchID))
    }

    private func beginRematchIfHostAndReady() {
        guard role == .host,
              localRematchAccepted,
              remoteRematchAccepted,
              let matchID = matchConfiguration?.id else { return }
        send(NearbyLobbyMessage(kind: .restartRound, matchID: matchID))
        resetRematchState(notify: true)
        onRestartRound?()
    }

    private func resetRematchState(notify: Bool) {
        localRematchAccepted = false
        remoteRematchAccepted = false
        if notify { onRematchStateChanged?(false, false) }
    }

    private func makeMatchConfiguration(id: UUID) -> NearbyMatchConfiguration {
        if role == .host {
            return NearbyMatchConfiguration(
                id: id,
                role: .host,
                hostName: localPlayerName,
                guestName: remotePlayerName,
                hostFighter: localFighter,
                guestFighter: remoteFighter
            )
        }
        return NearbyMatchConfiguration(
            id: id,
            role: .guest,
            hostName: remotePlayerName,
            guestName: localPlayerName,
            hostFighter: remoteFighter,
            guestFighter: localFighter
        )
    }

    private func fail(_ message: String) {
        connection?.cancel()
        connection = nil
        listener?.cancel()
        listener = nil
        browser?.cancel()
        browser = nil
        rooms = []
        remoteIsReady = false
        phase = .failed(message)
    }

    private static func networkParameters() -> NWParameters {
        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        return parameters
    }

    private static func room(from result: NWBrowser.Result) -> NearbyRoom {
        let name: String
        if case let .service(serviceName, _, _, _) = result.endpoint {
            name = serviceName
        } else {
            name = "HARD COUNTER ROOM"
        }
        return NearbyRoom(id: String(describing: result.endpoint), name: name, endpoint: result.endpoint)
    }

    private static func sanitizedServiceName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "HARD COUNTER" : String(trimmed.prefix(40))
    }
}
