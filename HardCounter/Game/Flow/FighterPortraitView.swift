import SwiftUI
import UIKit

struct FighterPortraitView: View {
    let fighter: FighterProfile

    var body: some View {
        let appearance = fighter.appearance
        let shoulderScale = appearance.bodyBuild.shoulderScale
        let limbScale = appearance.bodyBuild.limbScale
        let armor = fighter.swiftUIColor
        let darkMetal = Color(red: 0.06, green: 0.08, blue: 0.11)

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
                        colors: [armor.opacity(0.95), armor.opacity(0.48)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(
                    width: fighter == .pressure ? 48 : 38 * shoulderScale,
                    height: fighter == .outBoxer ? 43 : 39
                )
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(darkMetal)
                        .frame(height: 9)
                }
                .overlay {
                    Circle()
                        .fill(armor)
                        .shadow(color: armor, radius: 3)
                        .frame(width: 7, height: 7)
                        .offset(y: 4)
                }
                .offset(y: 12)

            if fighter == .pressure {
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
            } else if fighter == .outBoxer {
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
                        .fill(armor)
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
                    width: fighter == .pressure ? 36 : (fighter == .outBoxer ? 23 : 29),
                    height: fighter == .pressure ? 29 : (fighter == .outBoxer ? 35 : 31)
                )
                .overlay {
                    Capsule()
                        .fill(armor)
                        .shadow(color: armor, radius: 2)
                        .frame(width: fighter == .pressure ? 24 : 20, height: 4)
                        .offset(y: -3)
                }
                .overlay(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(armor.opacity(0.72))
                        .frame(width: 18, height: 7)
                        .offset(y: -2)
                }
                .offset(y: -18)

            glove(color: appearance.kitColor, scale: fighter == .pressure ? 1.28 : (fighter == .outBoxer ? 0.82 : 1))
                .offset(x: -25 * shoulderScale, y: 0)
            glove(color: appearance.kitColor, scale: fighter == .pressure ? 1.28 : (fighter == .outBoxer ? 0.82 : 1))
                .offset(x: 25 * shoulderScale, y: 1)
        }
        .frame(width: 78, height: 78)
    }

    private var armorBlock: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(fighter.swiftUIColor)
            .frame(width: 17, height: 16)
            .overlay { RoundedRectangle(cornerRadius: 4).stroke(.black.opacity(0.48), lineWidth: 2) }
    }

    private var speedFin: some View {
        UnevenRoundedRectangle(
            topLeadingRadius: 1,
            bottomLeadingRadius: 5,
            bottomTrailingRadius: 1,
            topTrailingRadius: 5
        )
        .fill(fighter.swiftUIColor.opacity(0.92))
        .frame(width: 5, height: 31)
    }

    private func glove(color: UIColor, scale: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color(uiColor: color))
            .frame(width: 15 * scale, height: 13 * scale)
            .overlay { RoundedRectangle(cornerRadius: 5).stroke(.black.opacity(0.38)) }
    }

}
