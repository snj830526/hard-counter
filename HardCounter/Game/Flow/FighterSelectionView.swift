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
                HStack(spacing: 14) {
                    ForEach(FighterProfile.allCases) { fighter in
                        fighterCard(fighter)
                    }
                }
                .frame(maxHeight: .infinity)
                footer
            }
            .padding(.horizontal, 38)
            .padding(.vertical, 20)
        }
    }

    private var header: some View {
        HStack {
            Button(action: onBack) {
                Label("모드 선택", systemImage: "chevron.left")
                    .font(.system(size: 12, weight: .bold))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.72))

            Spacer()
            VStack(spacing: 2) {
                Text("SELECT FIGHTER")
                    .font(.system(size: 21, weight: .black, design: .rounded))
                Text("솔로 대전에 출전할 선수를 선택하세요")
                    .font(.system(size: 10, weight: .medium))
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
                FighterPortraitView(fighter: fighter)

                VStack(spacing: 1) {
                    Text(fighter.name)
                        .font(.system(size: 19, weight: .black, design: .rounded))
                    Text(fighter.title)
                        .font(.system(size: 8, weight: .black, design: .monospaced))
                        .tracking(1.2)
                        .foregroundStyle(fighter.swiftUIColor)
                }

                Text(fighter.styleName)
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.08), in: Capsule())

                Text(fighter.combatTraitName)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(fighter.swiftUIColor.opacity(0.86))
                    .lineLimit(1)

                VStack(spacing: 5) {
                    statRow(
                        "체력",
                        value: fighter.healthPreview,
                        valueText: "\(fighter.stats.maximumHealth)",
                        color: .red
                    )
                    statRow(
                        "스태미너",
                        value: fighter.staminaPreview,
                        valueText: "\(Int(fighter.stats.maximumStamina))",
                        color: .green
                    )
                    statRow(
                        "스피드",
                        value: fighter.speedPreview,
                        valueText: "\(Int((fighter.stats.movementSpeedMultiplier * 100).rounded()))",
                        color: .cyan
                    )
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .foregroundStyle(.white)
            .background(
                isSelected ? fighter.swiftUIColor.opacity(0.13) : .white.opacity(0.045),
                in: RoundedRectangle(cornerRadius: 16)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .stroke(
                        isSelected ? fighter.swiftUIColor : .white.opacity(0.10),
                        lineWidth: isSelected ? 2.5 : 1
                    )
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
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.white.opacity(0.58))
                .frame(width: 42, alignment: .leading)
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.09))
                    Capsule().fill(color).frame(width: proxy.size.width * value)
                }
            }
            .frame(height: 5)
            Text(valueText)
                .font(.system(size: 8, weight: .black, design: .monospaced))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 22, alignment: .trailing)
        }
    }

    private var footer: some View {
        HStack {
            Text("선택한 선수의 능력치와 기술 특성이 실제 경기에 적용됩니다")
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.42))
            Spacer()
            Button {
                onStart(selected)
            } label: {
                HStack(spacing: 10) {
                    Text("FIGHT")
                    Image(systemName: "arrow.right")
                }
                .font(.system(size: 15, weight: .black, design: .rounded))
                .foregroundStyle(.black)
                .padding(.horizontal, 28)
                .frame(height: 42)
                .background(selected.swiftUIColor, in: RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }
}
