//
//  ContentView.swift
//  HardCounter
//
//  Created by john choi on 7/17/26.
//

import SwiftUI
import SpriteKit

struct ContentView: View {
    @State private var combatScene = CombatScene()

    var body: some View {
        GeometryReader { proxy in
            SpriteView(scene: combatScene, options: [.ignoresSiblingOrder])
                .ignoresSafeArea()
                .onAppear {
                    requestLandscapeOrientation()
                    updateSafeArea(from: proxy)
                }
                .onChange(of: proxy.safeAreaInsets) { _, _ in updateSafeArea(from: proxy) }
        }
        .background(Color.black)
        .persistentSystemOverlays(.hidden)
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

#Preview {
    ContentView()
}
