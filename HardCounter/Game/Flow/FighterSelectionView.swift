import SwiftUI

struct FighterSelectionView: View {
    let onBack: () -> Void
    let onStart: (FighterProfile) -> Void
    @State private var selected: FighterProfile = .allRounder

    var body: some View {
        ZStack {
            FlowBackground()

            VStack(spacing: 14) {
                header
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 14) {
                        ForEach(FighterProfile.allCases) { fighter in
                            fighterCard(fighter)
                                .frame(width: 224)
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .scrollIndicators(.hidden)
                .frame(maxHeight: .infinity)
                footer
            }
            .padding(.horizontal, 38)
            .padding(.vertical, 20)
        }
    }

    private var header: some View {
        HStack {
            FlowBackButton(title: "SELECT MODE", action: onBack)

            Spacer()
            VStack(spacing: 2) {
                Text("CHOOSE YOUR FIGHTER")
                    .font(FlowTypography.display(21))
                Text("Select a contender for the next bout")
                    .font(FlowTypography.supporting(10))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .foregroundStyle(.white)
            Spacer()

            Color.clear.frame(width: 76, height: 1)
        }
    }

    private func fighterCard(_ fighter: FighterProfile) -> some View {
        let isSelected = selected == fighter
        return Button {
            selected = fighter
        } label: {
            VStack(spacing: 8) {
                HStack {
                    Text("CONTENDER  //  \(fighter.id.uppercased())")
                    Spacer()
                    Circle()
                        .fill(isSelected ? Color(uiColor: ArenaVisualPalette.hudStamina) : .white.opacity(0.18))
                        .frame(width: 5, height: 5)
                }
                .font(FlowTypography.display(7))
                .tracking(1)
                .foregroundStyle(.white.opacity(0.40))

                FighterPortraitView(fighter: fighter)

                VStack(spacing: 1) {
                    Text(fighter.name)
                        .font(FlowTypography.display(19))
                    Text(fighter.title)
                        .font(FlowTypography.display(8))
                        .tracking(1.2)
                        .foregroundStyle(fighter.swiftUIColor)
                }

                Text(fighter.styleName)
                    .font(FlowTypography.display(10))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.08), in: Capsule())

                Text(fighter.combatTraitName)
                    .font(FlowTypography.supporting(8))
                    .foregroundStyle(fighter.swiftUIColor.opacity(0.86))
                    .lineLimit(1)

                VStack(spacing: 5) {
                    statRow(
                        "ARMOR",
                        value: fighter.healthPreview,
                        valueText: "\(fighter.balance.health)",
                        color: Color(uiColor: ArenaVisualPalette.hudHealth)
                    )
                    statRow(
                        "ENERGY",
                        value: fighter.staminaPreview,
                        valueText: "\(fighter.balance.stamina)",
                        color: Color(uiColor: ArenaVisualPalette.hudStamina)
                    )
                    statRow(
                        "SPEED",
                        value: fighter.speedPreview,
                        valueText: "\(fighter.balance.speed)",
                        color: Color(uiColor: ArenaVisualPalette.hudPlayerAccent)
                    )
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.white)
            .background(
                LinearGradient(
                    colors: [
                        isSelected
                            ? fighter.swiftUIColor.opacity(0.23)
                            : Color(uiColor: ArenaVisualPalette.raisedMetal).opacity(0.50),
                        Color(uiColor: ArenaVisualPalette.carbon).opacity(0.96)
                    ],
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
            .overlay {
                UnevenRoundedRectangle(
                    topLeadingRadius: 4,
                    bottomLeadingRadius: 15,
                    bottomTrailingRadius: 4,
                    topTrailingRadius: 15
                )
                    .stroke(
                        isSelected ? fighter.swiftUIColor : .white.opacity(0.10),
                        lineWidth: isSelected ? 2.5 : 1
                    )
            }
            .overlay(alignment: .top) {
                Rectangle()
                    .fill(fighter.swiftUIColor.opacity(isSelected ? 0.90 : 0.40))
                    .frame(height: 2)
                    .padding(.horizontal, 15)
            }
            .scaleEffect(isSelected ? 1 : 0.97)
        }
        .buttonStyle(.plain)
        .animation(.spring(response: 0.25, dampingFraction: 0.78), value: isSelected)
    }

    private func statRow(
        _ title: String,
        value: Double,
        valueText: String,
        color: Color
    ) -> some View {
        HStack(spacing: 7) {
            Text(title)
                .font(FlowTypography.display(9))
                .foregroundStyle(.white.opacity(0.58))
                .frame(width: 42, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Rectangle().fill(Color(uiColor: ArenaVisualPalette.carbon))
                    Rectangle().fill(color).frame(width: proxy.size.width * value)
                    Rectangle().fill(.white.opacity(0.18)).frame(height: 1).offset(y: -2)
                }
            }
            .frame(height: 5)
            Text(valueText)
                .font(FlowTypography.display(8))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 22, alignment: .trailing)
        }
    }

    private var footer: some View {
        HStack {
            Text("Fighter attributes and techniques apply directly to combat")
                .font(FlowTypography.supporting(9))
                .foregroundStyle(.white.opacity(0.42))
            Spacer()
            Button {
                onStart(selected)
            } label: {
                HStack(spacing: 10) {
                    Text("FIGHT")
                    Image(systemName: "arrow.right")
                }
                .font(FlowTypography.display(15))
                .foregroundStyle(.black)
                .padding(.horizontal, 28)
                .frame(height: 42)
                .background(selected.swiftUIColor, in: UnevenRoundedRectangle(
                    topLeadingRadius: 3,
                    bottomLeadingRadius: 10,
                    bottomTrailingRadius: 3,
                    topTrailingRadius: 10
                ))
                .overlay { UnevenRoundedRectangle(
                    topLeadingRadius: 3,
                    bottomLeadingRadius: 10,
                    bottomTrailingRadius: 3,
                    topTrailingRadius: 10
                ).stroke(.white.opacity(0.34)) }
            }
            .buttonStyle(.plain)
        }
    }
}
