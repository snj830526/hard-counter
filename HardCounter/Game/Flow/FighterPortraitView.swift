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
                .frame(width: 38 * shoulderScale, height: 39)
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
                .frame(width: 29, height: 31)
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

            glove(color: appearance.kitColor)
                .offset(x: -25 * shoulderScale, y: 0)
            glove(color: appearance.kitColor)
                .offset(x: 25 * shoulderScale, y: 1)
        }
        .frame(width: 78, height: 78)
    }

    private func glove(color: UIColor) -> some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(Color(uiColor: color))
            .frame(width: 15, height: 13)
            .overlay { RoundedRectangle(cornerRadius: 5).stroke(.black.opacity(0.38)) }
    }

}
