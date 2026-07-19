import SwiftUI

struct NearbyLobbyView: View {
    let onBack: () -> Void
    let onStart: (NearbyMatchConfiguration) -> Void
    @ObservedObject var service: NearbyLobbyService

    var body: some View {
        ZStack {
            FlowBackground()

            VStack(spacing: 18) {
                header
                content
            }
            .padding(.horizontal, 38)
            .padding(.vertical, 20)
        }
        .onChange(of: service.matchConfiguration) { _, configuration in
            if let configuration { onStart(configuration) }
        }
    }

    private var header: some View {
        HStack {
            FlowBackButton(title: "SELECT MODE") {
                service.stop()
                onBack()
            }

            Spacer()
            VStack(spacing: 2) {
                Text("NEARBY MATCH")
                    .font(FlowTypography.display(21))
                Text("Create a nearby lobby and ready your fighter")
                    .font(FlowTypography.supporting(10))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .foregroundStyle(.white)
            Spacer()

            connectionBadge
                .frame(width: 92, alignment: .trailing)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch service.phase {
        case .idle:
            entryPanel
        case .hosting:
            waitingPanel
        case .browsing:
            browserPanel
        case let .connecting(name):
            progressPanel(title: "CONNECTING", detail: "Entering \(name)'s lobby")
        case .connected:
            connectedLobby
        case let .failed(message):
            failurePanel(message)
        }
    }

    private var entryPanel: some View {
        HStack(spacing: 20) {
            entryButton(
                title: "CREATE ROOM",
                subtitle: "Host on this iPhone and wait for an opponent",
                symbol: "plus.circle.fill",
                tint: Color(uiColor: ArenaVisualPalette.hudPlayerAccent),
                action: service.startHosting
            )
            entryButton(
                title: "FIND NEARBY ROOM",
                subtitle: "Find an open HARD COUNTER lobby nearby",
                symbol: "antenna.radiowaves.left.and.right",
                tint: Color(uiColor: ArenaVisualPalette.hudOpponentAccent),
                action: service.startBrowsing
            )
        }
        .frame(maxWidth: 820, maxHeight: .infinity)
    }

    private var waitingPanel: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().stroke(Color(uiColor: ArenaVisualPalette.gunmetal), lineWidth: 3).frame(width: 100, height: 100)
                Circle().trim(from: 0.1, to: 0.8)
                    .stroke(
                        Color(uiColor: ArenaVisualPalette.hudPlayerAccent),
                        style: StrokeStyle(lineWidth: 5, lineCap: .round)
                    )
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(Color(uiColor: ArenaVisualPalette.hudPlayerAccent))
            }
            Text("WAITING FOR OPPONENT")
                .font(FlowTypography.display(24))
            Text("On the other iPhone, choose Find Nearby Room and select ‘\(service.localPlayerName)’")
                .font(FlowTypography.supporting(12))
                .foregroundStyle(.white.opacity(0.58))
                .multilineTextAlignment(.center)
            secondaryButton("CLOSE ROOM", action: service.stop)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var browserPanel: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("NEARBY LOBBIES")
                        .font(FlowTypography.display(22))
                    Text("If no room appears, check the host's Local Network permission and Wi-Fi")
                        .font(FlowTypography.supporting(10))
                        .foregroundStyle(.white.opacity(0.48))
                }
                Spacer()
                ProgressView().tint(Color(uiColor: ArenaVisualPalette.hudOpponentAccent))
                secondaryButton("CANCEL SEARCH", action: service.stop)
            }

            if service.rooms.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(FlowTypography.supporting(34))
                        .foregroundStyle(Color(uiColor: ArenaVisualPalette.hudOpponentAccent).opacity(0.8))
                    Text("Searching for open rooms…")
                        .font(FlowTypography.display(13))
                        .foregroundStyle(.white.opacity(0.58))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(uiColor: ArenaVisualPalette.carbon).opacity(0.88), in: RoundedRectangle(cornerRadius: 5))
                .overlay {
                    RoundedRectangle(cornerRadius: 5)
                        .stroke(Color(uiColor: ArenaVisualPalette.hudOpponentAccent).opacity(0.20))
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 9) {
                        ForEach(service.rooms) { room in
                            Button { service.join(room) } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "iphone")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(Color(uiColor: ArenaVisualPalette.hudOpponentAccent))
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(room.name)
                                            .font(FlowTypography.display(15))
                                        Text("HARD COUNTER LOBBY")
                                            .font(FlowTypography.supporting(9))
                                            .foregroundStyle(.white.opacity(0.46))
                                    }
                                    Spacer()
                                    Text("JOIN")
                                        .font(FlowTypography.display(11))
                                    Image(systemName: "chevron.right")
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .frame(height: 62)
                                .background(Color(uiColor: ArenaVisualPalette.carbon).opacity(0.92), in: UnevenRoundedRectangle(
                                    topLeadingRadius: 3,
                                    bottomLeadingRadius: 11,
                                    bottomTrailingRadius: 3,
                                    topTrailingRadius: 11
                                ))
                                .overlay { UnevenRoundedRectangle(
                                    topLeadingRadius: 3,
                                    bottomLeadingRadius: 11,
                                    bottomTrailingRadius: 3,
                                    topTrailingRadius: 11
                                ).stroke(Color(uiColor: ArenaVisualPalette.hudOpponentAccent).opacity(0.42)) }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: 820, maxHeight: .infinity)
    }

    private var connectedLobby: some View {
        VStack(spacing: 12) {
            HStack(spacing: 18) {
                playerPanel(
                    label: service.role == .host ? "HOST · YOU" : "GUEST · YOU",
                    name: service.localPlayerName,
                    fighter: service.localFighter,
                    isReady: service.localIsReady,
                    isLocal: true
                )
                Text("VS")
                    .font(FlowTypography.display(24))
                    .foregroundStyle(Color(uiColor: ArenaVisualPalette.hudOpponentAccent))
                playerPanel(
                    label: service.role == .host ? "GUEST" : "HOST",
                    name: service.remotePlayerName,
                    fighter: service.remoteFighter,
                    isReady: service.remoteIsReady,
                    isLocal: false
                )
            }

            HStack {
                Text(service.bothPlayersReady ? "BOTH FIGHTERS READY · STARTING MATCH" : "SELECT A FIGHTER, THEN PRESS READY")
                    .font(FlowTypography.display(10))
                    .foregroundStyle(service.bothPlayersReady ? Color(uiColor: ArenaVisualPalette.hudStamina) : .white.opacity(0.48))
                Spacer()
                secondaryButton("LEAVE", action: service.stop)
                Button(action: service.toggleReady) {
                    Text(service.localIsReady ? "CANCEL READY" : "READY")
                        .font(FlowTypography.display(13))
                        .foregroundStyle(service.localIsReady ? .white : .black)
                        .padding(.horizontal, 26)
                        .frame(height: 40)
                        .background(
                            service.localIsReady
                                ? Color(uiColor: ArenaVisualPalette.gunmetal)
                                : Color(uiColor: ArenaVisualPalette.hudStamina),
                            in: RoundedRectangle(cornerRadius: 5)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: 920, maxHeight: .infinity)
    }

    private func playerPanel(
        label: String,
        name: String,
        fighter: FighterProfile,
        isReady: Bool,
        isLocal: Bool
    ) -> some View {
        VStack(spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(label)
                        .font(FlowTypography.display(8))
                        .tracking(1.2)
                        .foregroundStyle(fighter.swiftUIColor)
                    Text(name)
                        .font(FlowTypography.display(13))
                        .lineLimit(1)
                }
                Spacer()
                Label(isReady ? "READY" : "SELECTING", systemImage: isReady ? "checkmark.circle.fill" : "ellipsis.circle")
                    .font(FlowTypography.display(9))
                    .foregroundStyle(isReady ? Color(uiColor: ArenaVisualPalette.hudStamina) : .white.opacity(0.42))
            }

            HStack(spacing: 12) {
                FighterPortraitView(fighter: fighter)
                    .frame(width: 108)
                VStack(alignment: .leading, spacing: 4) {
                    Text(fighter.name)
                        .font(FlowTypography.display(25))
                    Text(fighter.styleName)
                        .font(FlowTypography.display(10))
                        .foregroundStyle(.white.opacity(0.58))
                    Text(fighter.combatTraitName)
                        .font(FlowTypography.supporting(8))
                        .foregroundStyle(fighter.swiftUIColor.opacity(0.86))
                    Text("HP \(fighter.stats.maximumHealth)  ·  ST \(Int(fighter.stats.maximumStamina))  ·  SP \(Int((fighter.stats.movementSpeedMultiplier * 100).rounded()))")
                        .font(FlowTypography.display(8))
                        .foregroundStyle(fighter.swiftUIColor)
                }
                Spacer()
            }

            if isLocal {
                HStack(spacing: 7) {
                    ForEach(FighterProfile.allCases) { option in
                        Button {
                            service.localFighter = option
                        } label: {
                            Text(option.name)
                                .font(FlowTypography.display(9))
                                .frame(maxWidth: .infinity)
                                .frame(height: 29)
                                .foregroundStyle(service.localFighter == option ? .black : .white.opacity(0.7))
                                .background(
                                    service.localFighter == option
                                        ? option.swiftUIColor
                                        : Color(uiColor: ArenaVisualPalette.carbon),
                                    in: RoundedRectangle(cornerRadius: 4)
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .disabled(isReady)
            } else {
                Text("Your opponent's fighter selection updates in real time")
                    .font(FlowTypography.supporting(9))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, minHeight: 29)
            }
        }
        .padding(14)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [fighter.swiftUIColor.opacity(0.18), Color(uiColor: ArenaVisualPalette.carbon).opacity(0.96)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: UnevenRoundedRectangle(
                topLeadingRadius: 4,
                bottomLeadingRadius: 15,
                bottomTrailingRadius: 4,
                topTrailingRadius: 15
            )
        )
        .overlay { UnevenRoundedRectangle(
            topLeadingRadius: 4,
            bottomLeadingRadius: 15,
            bottomTrailingRadius: 4,
            topTrailingRadius: 15
        ).stroke(fighter.swiftUIColor.opacity(0.58), lineWidth: 1.5) }
    }

    private func progressPanel(title: String, detail: String) -> some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large).tint(Color(uiColor: ArenaVisualPalette.hudOpponentAccent))
            Text(title).font(FlowTypography.display(23))
            Text(detail).font(FlowTypography.supporting(11)).foregroundStyle(.white.opacity(0.52))
            secondaryButton("CANCEL", action: service.stop)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failurePanel(_ message: String) -> some View {
        VStack(spacing: 13) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(Color(uiColor: ArenaVisualPalette.hudOpponentAccent))
            Text("CONNECTION FAILED")
                .font(FlowTypography.display(23))
            Text(message)
                .font(FlowTypography.supporting(11))
                .foregroundStyle(.white.opacity(0.56))
                .multilineTextAlignment(.center)
            HStack {
                secondaryButton("BACK TO START", action: service.stop)
                Button("TRY AGAIN", action: service.retry)
                    .buttonStyle(.borderedProminent)
                    .tint(Color(uiColor: ArenaVisualPalette.hudOpponentAccent))
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var connectionBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(service.isConnected ? Color(uiColor: ArenaVisualPalette.hudStamina) : Color.white.opacity(0.26))
                .frame(width: 6, height: 6)
            Text(service.isConnected ? "CONNECTED" : "OFFLINE")
        }
        .font(FlowTypography.display(8))
        .foregroundStyle(.white.opacity(0.66))
    }

    private func entryButton(
        title: String,
        subtitle: String,
        symbol: String,
        tint: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 13) {
                Image(systemName: symbol)
                    .font(.system(size: 35, weight: .bold))
                    .foregroundStyle(tint)
                Text(title).font(FlowTypography.display(22))
                Text(subtitle)
                    .font(FlowTypography.supporting(10))
                    .foregroundStyle(.white.opacity(0.52))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: 230)
            .background(
                LinearGradient(
                    colors: [Color(uiColor: ArenaVisualPalette.raisedMetal).opacity(0.65), Color(uiColor: ArenaVisualPalette.carbon).opacity(0.96)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: UnevenRoundedRectangle(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: 18,
                    bottomTrailingRadius: 4,
                    topTrailingRadius: 18
                )
            )
            .overlay { UnevenRoundedRectangle(
                topLeadingRadius: 4,
                bottomLeadingRadius: 18,
                bottomTrailingRadius: 4,
                topTrailingRadius: 18
            ).stroke(tint.opacity(0.52), lineWidth: 1.5) }
            .overlay(alignment: .top) {
                Rectangle().fill(tint.opacity(0.72)).frame(height: 2).padding(.horizontal, 18)
            }
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(FlowTypography.display(10))
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.66))
            .padding(.horizontal, 13)
            .frame(height: 34)
            .background(Color(uiColor: ArenaVisualPalette.carbon).opacity(0.92), in: RoundedRectangle(cornerRadius: 4))
            .overlay { RoundedRectangle(cornerRadius: 4).stroke(.white.opacity(0.12)) }
    }
}
