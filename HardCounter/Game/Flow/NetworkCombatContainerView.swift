import SpriteKit
import SwiftUI

struct NetworkCombatContainerView: View {
    let configuration: NearbyMatchConfiguration
    let service: NearbyLobbyService
    let onExit: () -> Void
    @State private var combatScene: CombatScene

    init(
        configuration: NearbyMatchConfiguration,
        service: NearbyLobbyService,
        onExit: @escaping () -> Void
    ) {
        self.configuration = configuration
        self.service = service
        self.onExit = onExit
        _combatScene = State(initialValue: CombatScene(
            networkConfiguration: configuration,
            service: service
        ))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                SpriteView(scene: combatScene, options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()
                    .onAppear { updateSafeArea(from: proxy) }
                    .onChange(of: proxy.safeAreaInsets) { _, _ in updateSafeArea(from: proxy) }

                Button(action: onExit) {
                    Label("대전 종료", systemImage: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(.black.opacity(0.42), in: Capsule())
                        .overlay { Capsule().stroke(.white.opacity(0.14)) }
                }
                .buttonStyle(.plain)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 6))
            }
        }
        .onDisappear { service.detachCombatHandlers() }
    }

    private func updateSafeArea(from proxy: GeometryProxy) {
        let insets = proxy.safeAreaInsets
        combatScene.updateSafeAreaInsets(EdgeInsetsSnapshot(
            top: insets.top,
            leading: insets.leading,
            bottom: insets.bottom,
            trailing: insets.trailing
        ))
    }
}
