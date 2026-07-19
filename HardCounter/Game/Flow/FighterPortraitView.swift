import SwiftUI
import UIKit

struct FighterPortraitView: View {
    let fighter: FighterProfile

    var body: some View {
        let appearance = fighter.appearance
        let shoulderScale = appearance.bodyBuild.shoulderScale
        let limbScale = appearance.bodyBuild.limbScale
        let armor = fighter.swiftUIColor
        let accent = Color(uiColor: appearance.accentColor)
        let secondaryArmor = Color(uiColor: appearance.machineColors.secondaryArmor)
        let signal = Color(uiColor: appearance.machineColors.signal)
        let darkMetal = Color(uiColor: appearance.machineColors.frame)
        let isPressureKit = appearance.kitStyle == .pressure
        let isSpeedKit = appearance.kitStyle == .speed

        ZStack {
            Circle()
                .fill(fighter.swiftUIColor.opacity(0.13))

            Capsule()
                .fill(darkMetal)
                .frame(width: 9 * limbScale, height: 36)
                .rotationEffect(.degrees(-34))
                .offset(x: -19 * shoulderScale, y: 12)

            Capsule()
                .fill(darkMetal)
                .frame(width: 8 * limbScale, height: 34)
                .rotationEffect(.degrees(34))
                .offset(x: 18 * shoulderScale, y: 13)

            RoundedRectangle(cornerRadius: 9)
                .fill(
                    LinearGradient(
                        colors: [armor.opacity(0.96), secondaryArmor.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(
                    width: isPressureKit ? 48 : 38 * shoulderScale,
                    height: isSpeedKit ? 43 : 39
                )
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(darkMetal)
                        .frame(height: 9)
                }
                .overlay {
                    Circle()
                        .fill(signal)
                        .shadow(color: signal, radius: 3)
                        .frame(width: 7, height: 7)
                        .offset(y: 4)
                }
                .offset(y: 12)

            if isPressureKit {
                HStack(spacing: 29) {
                    armorBlock
                    armorBlock
                }
                .offset(y: 3)

                HStack(spacing: 37) {
                    Capsule().fill(darkMetal).frame(width: 6, height: 30)
                    Capsule().fill(darkMetal).frame(width: 6, height: 30)
                }
                .offset(y: 15)
            } else if isSpeedKit {
                HStack(spacing: 36) {
                    speedFin.rotationEffect(.degrees(-24))
                    speedFin.rotationEffect(.degrees(24))
                }
                .offset(y: 1)

                speedFin
                    .frame(height: 25)
                    .rotationEffect(.degrees(18))
                    .offset(x: 8, y: -38)
            }

            RoundedRectangle(cornerRadius: 3)
                .fill(darkMetal)
                .frame(width: 42 * appearance.bodyBuild.waistScale, height: 15)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(accent)
                        .frame(height: 4)
                }
                .offset(y: 29)

            UnevenRoundedRectangle(
                topLeadingRadius: 8,
                bottomLeadingRadius: 3,
                bottomTrailingRadius: 3,
                topTrailingRadius: 8
            )
                .fill(darkMetal)
                .frame(
                    width: isPressureKit ? 36 : (isSpeedKit ? 23 : 29),
                    height: isPressureKit ? 29 : (isSpeedKit ? 35 : 31)
                )
                .overlay {
                    Capsule()
                        .fill(signal)
                        .shadow(color: signal, radius: 2)
                        .frame(width: isPressureKit ? 24 : 20, height: 4)
                        .offset(y: -3)
                }
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(secondaryArmor.opacity(0.92))
                        .frame(width: 18, height: 7)
                        .offset(y: -2)
                }
                .offset(y: -18)

            glove(
                color: appearance.kitColor,
                accent: appearance.accentColor,
                scale: isPressureKit ? 1.28 : (isSpeedKit ? 0.82 : 1)
            )
                .offset(x: -25 * shoulderScale, y: 0)
            glove(
                color: appearance.kitColor,
                accent: appearance.accentColor,
                scale: isPressureKit ? 1.28 : (isSpeedKit ? 0.82 : 1)
            )
                .offset(x: 25 * shoulderScale, y: 1)
        }
        .frame(width: 78, height: 78)
    }

    private var armorBlock: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(Color(uiColor: fighter.appearance.machineColors.secondaryArmor))
            .frame(width: 17, height: 16)
            .overlay {
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Color(uiColor: fighter.appearance.accentColor), lineWidth: 2)
            }
    }

    private var speedFin: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 1,
            bottomLeadingRadius: 5,
            bottomTrailingRadius: 1,
            topTrailingRadius: 5
        )
        .fill(Color(uiColor: fighter.appearance.accentColor).opacity(0.94))
        .frame(width: 5, height: 31)
    }

    private func glove(color: UIColor, accent: UIColor, scale: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color(uiColor: color))
            .frame(width: 15 * scale, height: 13 * scale)
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(Color(uiColor: accent), lineWidth: 1.5)
            }
    }

}
