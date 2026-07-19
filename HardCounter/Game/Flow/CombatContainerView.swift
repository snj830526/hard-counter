import SpriteKit
import SwiftUI

struct CombatContainerView: View {
    let fighter: FighterProfile
    let onExit: () -> Void
    @State private var combatScene: CombatScene

    init(fighter: FighterProfile, onExit: @escaping () -> Void) {
        self.fighter = fighter
        self.onExit = onExit
        _combatScene = State(initialValue: CombatScene(fighter: fighter))
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .bottom) {
                SpriteView(scene: combatScene, options: [.ignoresSiblingOrder])
                    .ignoresSafeArea()
                    .onAppear { updateSafeArea(from: proxy) }
                    .onChange(of: proxy.safeAreaInsets) { _, _ in updateSafeArea(from: proxy) }

                CombatMenuButton(title: "MENU", action: onExit)
                .padding(.bottom, max(proxy.safeAreaInsets.bottom, 6))
            }
        }
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
