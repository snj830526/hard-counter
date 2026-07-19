import SwiftUI

struct ContentView: View {
    @State private var destination: GameDestination
    @StateObject private var nearbyService = NearbyLobbyService()

    init() {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("--fighter-selection-showcase") {
            _destination = State(initialValue: .fighterSelection)
            return
        }
        if arguments.contains("--nearby-lobby-showcase") {
            _destination = State(initialValue: .nearbyLobby)
            return
        }
        if arguments.contains("--pressure-showcase") {
            _destination = State(initialValue: .combat(.pressure))
            return
        }
        if arguments.contains("--outboxer-showcase") {
            _destination = State(initialValue: .combat(.outBoxer))
            return
        }
        let shouldLaunchMotionShowcase = [
            "--footwork-showcase",
            "--motion-showcase",
            "--motion-clip-showcase",
            "--sway-showcase",
            "--impact-showcase",
            "--fatigue-showcase",
            "--guard-closeup",
            "--fighter-style-showcase",
            "--damage-showcase"
        ].contains(where: arguments.contains)
        if shouldLaunchMotionShowcase {
            _destination = State(initialValue: .combat(.allRounder))
            return
        }
#endif
        _destination = State(initialValue: .modeSelection)
    }

    var body: some View {
        ZStack {
            switch destination {
            case .modeSelection:
                ModeSelectionView(
                    onSelectSolo: { destination = .fighterSelection },
                    onSelectNearby: { destination = .nearbyLobby }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .fighterSelection:
                FighterSelectionView(
                    onBack: { destination = .modeSelection },
                    onStart: { fighter in destination = .combat(fighter) }
                )
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            case .nearbyLobby:
                NearbyLobbyView(
                    onBack: { destination = .modeSelection },
                    onStart: { configuration in destination = .nearbyCombat(configuration) },
                    service: nearbyService
                )
                .transition(.opacity.combined(with: .move(edge: .trailing)))
            case let .nearbyCombat(configuration):
                NetworkCombatContainerView(configuration: configuration, service: nearbyService) {
                    nearbyService.stop()
                    destination = .modeSelection
                }
                .transition(.opacity)
            case let .combat(fighter):
                CombatContainerView(fighter: fighter) {
                    destination = .modeSelection
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.24), value: destination)
        .background(Color(red: 0.025, green: 0.032, blue: 0.055))
        .ignoresSafeArea()
        .persistentSystemOverlays(.hidden)
        .onAppear(perform: requestLandscapeOrientation)
    }

    private func requestLandscapeOrientation() {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first else { return }

        windowScene.requestGeometryUpdate(.iOS(interfaceOrientations: .landscape))
        windowScene.windows.first(where: \.isKeyWindow)?
            .rootViewController?
            .setNeedsUpdateOfSupportedInterfaceOrientations()
    }
}

private enum GameDestination: Equatable {
    case modeSelection
    case fighterSelection
    case nearbyLobby
    case nearbyCombat(NearbyMatchConfiguration)
    case combat(FighterProfile)
}

#Preview {
    ContentView()
}
