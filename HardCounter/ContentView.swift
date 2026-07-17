import SwiftUI

struct ContentView: View {
    @State private var destination: GameDestination = .modeSelection

    var body: some View {
        ZStack {
            switch destination {
            case .modeSelection:
                ModeSelectionView {
                    destination = .fighterSelection
                }
                .transition(.opacity.combined(with: .scale(scale: 0.98)))
            case .fighterSelection:
                FighterSelectionView(
                    onBack: { destination = .modeSelection },
                    onStart: { fighter in destination = .combat(fighter) }
                )
                .transition(.opacity.combined(with: .move(edge: .trailing)))
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
    case combat(FighterProfile)
}

#Preview {
    ContentView()
}
