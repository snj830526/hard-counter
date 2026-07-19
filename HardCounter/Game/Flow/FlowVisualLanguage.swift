import SwiftUI

enum FlowTypography {
    static func display(_ size: CGFloat) -> Font {
        .custom(CombatTypography.display, size: size)
    }

    static func supporting(_ size: CGFloat) -> Font {
        .custom(CombatTypography.supporting, size: size)
    }
}

struct FlowBackButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: "chevron.left")
                .font(FlowTypography.display(11))
                .tracking(0.8)
                .foregroundStyle(.white.opacity(0.78))
                .padding(.horizontal, 13)
                .frame(height: 34)
                .background(Color(uiColor: ArenaVisualPalette.carbon).opacity(0.92), in: chamfer)
                .overlay { chamfer.stroke(.white.opacity(0.16), lineWidth: 1) }
        }
        .buttonStyle(.plain)
    }

    private var chamfer: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 3,
            bottomLeadingRadius: 9,
            bottomTrailingRadius: 3,
            topTrailingRadius: 9
        )
    }
}

struct CombatMenuButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "rectangle.portrait.and.arrow.right")
                    .font(.system(size: 11, weight: .bold))
                Text(title)
                    .font(FlowTypography.display(11))
                    .tracking(1)
            }
            .foregroundStyle(.white.opacity(0.82))
            .padding(.horizontal, 16)
            .frame(height: 34)
            .background(Color(uiColor: ArenaVisualPalette.void).opacity(0.80), in: chamfer)
            .overlay { chamfer.stroke(Color(uiColor: ArenaVisualPalette.hudStamina).opacity(0.45)) }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(Color(uiColor: ArenaVisualPalette.hudStamina).opacity(0.78))
                    .frame(width: 42, height: 2)
            }
        }
        .buttonStyle(.plain)
    }

    private var chamfer: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            topLeadingRadius: 3,
            bottomLeadingRadius: 10,
            bottomTrailingRadius: 3,
            topTrailingRadius: 10
        )
    }
}
