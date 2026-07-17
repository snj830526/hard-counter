import SwiftUI
import UIKit

struct FighterPortraitView: View {
    let fighter: FighterProfile

    var body: some View {
        let appearance = fighter.appearance
        let shoulderScale = appearance.bodyBuild.shoulderScale
        let limbScale = appearance.bodyBuild.limbScale

        ZStack {
            Circle()
                .fill(fighter.swiftUIColor.opacity(0.13))

            Capsule()
                .fill(Color(uiColor: appearance.skinColor))
                .frame(width: 9 * limbScale, height: 36)
                .rotationEffect(.degrees(-34))
                .offset(x: -19 * shoulderScale, y: 12)

            Capsule()
                .fill(Color(uiColor: appearance.skinShadowColor))
                .frame(width: 8 * limbScale, height: 34)
                .rotationEffect(.degrees(34))
                .offset(x: 18 * shoulderScale, y: 13)

            RoundedRectangle(cornerRadius: 9)
                .fill(Color(uiColor: appearance.skinColor))
                .frame(width: 38 * shoulderScale, height: 39)
                .overlay(alignment: .bottom) {
                    Rectangle()
                        .fill(Color(uiColor: appearance.skinShadowColor).opacity(0.55))
                        .frame(height: 12)
                }
                .offset(y: 12)

            RoundedRectangle(cornerRadius: 3)
                .fill(Color(uiColor: appearance.kitColor))
                .frame(width: 42 * appearance.bodyBuild.waistScale, height: 15)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Color(uiColor: appearance.accentColor))
                        .frame(height: 4)
                }
                .offset(y: 29)

            Circle()
                .fill(Color(uiColor: appearance.skinColor))
                .frame(width: 29, height: 31)
                .overlay(alignment: .top) {
                    hairShape(appearance.hairStyle)
                        .fill(Color(uiColor: appearance.hairColor))
                        .frame(width: 27, height: hairHeight(appearance.hairStyle))
                        .offset(y: -2)
                }
                .overlay(alignment: .trailing) {
                    Circle()
                        .fill(.black.opacity(0.78))
                        .frame(width: 2.5, height: 2.5)
                        .offset(x: -6, y: -1)
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

    private func hairShape(_ style: FighterHairStyle) -> UnevenRoundedRectangle {
        switch style {
        case .cropped:
            UnevenRoundedRectangle(
                topLeadingRadius: 10,
                bottomLeadingRadius: 2,
                bottomTrailingRadius: 3,
                topTrailingRadius: 8
            )
        case .shaved:
            UnevenRoundedRectangle(
                topLeadingRadius: 8,
                bottomLeadingRadius: 5,
                bottomTrailingRadius: 5,
                topTrailingRadius: 8
            )
        case .swept:
            UnevenRoundedRectangle(
                topLeadingRadius: 4,
                bottomLeadingRadius: 2,
                bottomTrailingRadius: 8,
                topTrailingRadius: 13
            )
        }
    }

    private func hairHeight(_ style: FighterHairStyle) -> CGFloat {
        switch style {
        case .cropped: 11
        case .shaved: 7
        case .swept: 14
        }
    }
}
