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
            Button {
                service.stop()
                onBack()
            } label: {
                Label("모드 선택", systemImage: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.72))

            Spacer()
            VStack(spacing: 2) {
                Text("NEARBY MATCH")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                Text("가까운 iPhone과 로비를 만들고 선수를 준비하세요")
                    .font(.system(size: 10, weight: .medium))
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
            progressPanel(title: "연결 중", detail: "\(name) 로비에 입장하고 있습니다")
        case .connected:
            connectedLobby
        case let .failed(message):
            failurePanel(message)
        }
    }

    private var entryPanel: some View {
        HStack(spacing: 20) {
            entryButton(
                title: "방 만들기",
                subtitle: "내 iPhone을 호스트로 열고 상대를 기다립니다",
                symbol: "plus.circle.fill",
                tint: .cyan,
                action: service.startHosting
            )
            entryButton(
                title: "주변 방 찾기",
                subtitle: "같은 공간에 열린 HARD COUNTER 로비를 찾습니다",
                symbol: "antenna.radiowaves.left.and.right",
                tint: .orange,
                action: service.startBrowsing
            )
        }
        .frame(maxWidth: 820, maxHeight: .infinity)
    }

    private var waitingPanel: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().stroke(.cyan.opacity(0.16), lineWidth: 3).frame(width: 100, height: 100)
                Circle().trim(from: 0.1, to: 0.8)
                    .stroke(.cyan, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 100, height: 100)
                    .rotationEffect(.degrees(-90))
                Image(systemName: "iphone.radiowaves.left.and.right")
                    .font(.system(size: 31, weight: .bold))
                    .foregroundStyle(.cyan)
            }
            Text("상대를 기다리는 중")
                .font(.system(size: 24, weight: .black, design: .rounded))
            Text("다른 iPhone에서 주변 방 찾기를 누르고 ‘\(service.localPlayerName)’ 방을 선택하세요")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.58))
                .multilineTextAlignment(.center)
            secondaryButton("방 닫기", action: service.stop)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var browserPanel: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("주변 로비")
                        .font(.system(size: 22, weight: .black, design: .rounded))
                    Text("방이 보이지 않으면 호스트의 로컬 네트워크 권한과 Wi-Fi를 확인하세요")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                }
                Spacer()
                ProgressView().tint(.orange)
                secondaryButton("검색 취소", action: service.stop)
            }

            if service.rooms.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 34, weight: .medium))
                        .foregroundStyle(.orange.opacity(0.8))
                    Text("열린 방을 찾고 있습니다…")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white.opacity(0.58))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
            } else {
                ScrollView {
                    LazyVStack(spacing: 9) {
                        ForEach(service.rooms) { room in
                            Button { service.join(room) } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: "iphone")
                                        .font(.system(size: 20, weight: .bold))
                                        .foregroundStyle(.orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(room.name)
                                            .font(.system(size: 15, weight: .black, design: .rounded))
                                        Text("HARD COUNTER 로비")
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.46))
                                    }
                                    Spacer()
                                    Text("입장")
                                        .font(.system(size: 11, weight: .black))
                                    Image(systemName: "chevron.right")
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 18)
                                .frame(height: 62)
                                .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
                                .overlay { RoundedRectangle(cornerRadius: 12).stroke(.orange.opacity(0.34)) }
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
                    .font(.system(size: 24, weight: .black, design: .rounded))
                    .foregroundStyle(.orange)
                playerPanel(
                    label: service.role == .host ? "GUEST" : "HOST",
                    name: service.remotePlayerName,
                    fighter: service.remoteFighter,
                    isReady: service.remoteIsReady,
                    isLocal: false
                )
            }

            HStack {
                Text(service.bothPlayersReady ? "양쪽 선수 준비 완료 · 경기를 시작합니다" : "선수를 선택한 뒤 준비 버튼을 누르세요")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(service.bothPlayersReady ? .green : .white.opacity(0.48))
                Spacer()
                secondaryButton("나가기", action: service.stop)
                Button(action: service.toggleReady) {
                    Text(service.localIsReady ? "준비 취소" : "READY")
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .foregroundStyle(service.localIsReady ? .white : .black)
                        .padding(.horizontal, 26)
                        .frame(height: 40)
                        .background(service.localIsReady ? Color.white.opacity(0.12) : Color.green, in: RoundedRectangle(cornerRadius: 10))
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
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(fighter.swiftUIColor)
                    Text(name)
                        .font(.system(size: 13, weight: .black, design: .rounded))
                        .lineLimit(1)
                }
                Spacer()
                Label(isReady ? "READY" : "SELECTING", systemImage: isReady ? "checkmark.circle.fill" : "ellipsis.circle")
                    .font(.system(size: 9, weight: .black, design: .monospaced))
                    .foregroundStyle(isReady ? .green : .white.opacity(0.42))
            }

            HStack(spacing: 12) {
                FighterPortraitView(fighter: fighter)
                    .frame(width: 108)
                VStack(alignment: .leading, spacing: 4) {
                    Text(fighter.name)
                        .font(.system(size: 25, weight: .black, design: .rounded))
                    Text(fighter.styleName)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white.opacity(0.58))
                    Text("HP \(fighter.stats.maximumHealth)  ·  ST \(Int(fighter.stats.maximumStamina))  ·  SP \(Int((fighter.stats.movementSpeedMultiplier * 100).rounded()))")
                        .font(.system(size: 8, weight: .black, design: .monospaced))
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
                                .font(.system(size: 9, weight: .black, design: .rounded))
                                .frame(maxWidth: .infinity)
                                .frame(height: 29)
                                .foregroundStyle(service.localFighter == option ? .black : .white.opacity(0.7))
                                .background(service.localFighter == option ? option.swiftUIColor : .white.opacity(0.06), in: RoundedRectangle(cornerRadius: 7))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .disabled(isReady)
            } else {
                Text("상대의 선수 선택이 실시간으로 표시됩니다")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.4))
                    .frame(maxWidth: .infinity, minHeight: 29)
            }
        }
        .padding(14)
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(fighter.swiftUIColor.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
        .overlay { RoundedRectangle(cornerRadius: 16).stroke(fighter.swiftUIColor.opacity(0.48), lineWidth: 1.5) }
    }

    private func progressPanel(title: String, detail: String) -> some View {
        VStack(spacing: 14) {
            ProgressView().controlSize(.large).tint(.orange)
            Text(title).font(.system(size: 23, weight: .black, design: .rounded))
            Text(detail).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.52))
            secondaryButton("취소", action: service.stop)
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func failurePanel(_ message: String) -> some View {
        VStack(spacing: 13) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 38, weight: .bold))
                .foregroundStyle(.orange)
            Text("연결할 수 없습니다")
                .font(.system(size: 23, weight: .black, design: .rounded))
            Text(message)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.56))
                .multilineTextAlignment(.center)
            HStack {
                secondaryButton("처음으로", action: service.stop)
                Button("다시 시도", action: service.retry)
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
            }
        }
        .foregroundStyle(.white)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var connectionBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(service.isConnected ? Color.green : Color.white.opacity(0.26))
                .frame(width: 6, height: 6)
            Text(service.isConnected ? "CONNECTED" : "OFFLINE")
        }
        .font(.system(size: 8, weight: .black, design: .monospaced))
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
                Text(title).font(.system(size: 22, weight: .black, design: .rounded))
                Text(subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.52))
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(.white)
            .padding(24)
            .frame(maxWidth: .infinity, maxHeight: 230)
            .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 18))
            .overlay { RoundedRectangle(cornerRadius: 18).stroke(tint.opacity(0.42), lineWidth: 1.5) }
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 10, weight: .bold))
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.66))
            .padding(.horizontal, 13)
            .frame(height: 34)
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }
}
