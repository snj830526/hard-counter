import SwiftUI

struct ModeSelectionView: View {
    let onSelectSolo: () -> Void
    let onSelectNearby: () -> Void

    var body: some View {
        ZStack {
            FlowBackground()

            HStack(spacing: 38) {
                titlePanel
                modePanel
            }
            .padding(.horizontal, 54)
            .padding(.vertical, 32)
        }
    }

    private var titlePanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("HCML // TERMINAL 01")
                .font(.system(size: 9, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(Color(uiColor: ArenaVisualPalette.greenSignal))
                .padding(.horizontal, 8)
                .frame(height: 22)
                .background(Color(uiColor: ArenaVisualPalette.carbon), in: RoundedRectangle(cornerRadius: 3))
                .overlay { RoundedRectangle(cornerRadius: 3).stroke(.white.opacity(0.12)) }
            Text("HARD")
                .foregroundStyle(.white)
            Text("COUNTER")
                .foregroundStyle(Color.cyan)
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.cyan, .white.opacity(0.55), .orange],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 74, height: 5)
                .padding(.vertical, 4)
            Text("QUARTER-VIEW MECHA BOXING")
                .font(.system(size: 13, weight: .bold, design: .monospaced))
                .tracking(2.4)
                .foregroundStyle(.white.opacity(0.54))
            Text("Control distance and rhythm behind a steel guard")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))
                .padding(.top, 10)
        }
        .font(.system(size: 48, weight: .black, design: .rounded))
        .lineSpacing(-8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var modePanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SELECT MODE")
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .tracking(2)
                .foregroundStyle(.white.opacity(0.58))

            modeButton(
                title: "SOLO",
                subtitle: "1-on-1 against a CPU rival",
                symbol: "figure.boxing",
                tint: .cyan,
                action: onSelectSolo
            )
            modeButton(
                title: "NEARBY",
                subtitle: "1-on-1 with a nearby iPhone",
                symbol: "antenna.radiowaves.left.and.right",
                tint: .orange,
                badge: "LOBBY",
                action: onSelectNearby
            )
        }
        .frame(maxWidth: 430)
    }

    private func modeButton(
        title: String,
        subtitle: String,
        symbol: String,
        tint: Color,
        badge: String? = nil,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 18) {
                Image(systemName: symbol)
                    .font(.system(size: 25, weight: .bold))
                    .frame(width: 46, height: 46)
                    .background(Color(uiColor: ArenaVisualPalette.carbon), in: RoundedRectangle(cornerRadius: 5))
                    .overlay { RoundedRectangle(cornerRadius: 5).stroke(tint.opacity(0.48)) }
                    .foregroundStyle(tint)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(title)
                            .font(.system(size: 21, weight: .black, design: .rounded))
                        if let badge {
                            Text(badge)
                                .font(.system(size: 8, weight: .black, design: .monospaced))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(tint.opacity(0.22), in: Capsule())
                                .foregroundStyle(tint)
                        }
                    }
                    Text(subtitle)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .black))
                    .foregroundStyle(tint)
            }
            .padding(.horizontal, 18)
            .frame(height: 82)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [
                        Color(uiColor: ArenaVisualPalette.raisedMetal).opacity(0.72),
                        Color(uiColor: ArenaVisualPalette.carbon).opacity(0.96)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: UnevenRoundedRectangle(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: 14,
                    bottomTrailingRadius: 4,
                    topTrailingRadius: 14
                )
            )
            .overlay {
                UnevenRoundedRectangle(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: 14,
                    bottomTrailingRadius: 4,
                    topTrailingRadius: 14
                )
                    .stroke(tint.opacity(0.42), lineWidth: 1.5)
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(tint.opacity(0.75))
                    .frame(height: 2)
                    .padding(.horizontal, 18)
            }
        }
        .buttonStyle(.plain)
    }
}
