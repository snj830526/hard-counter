import SwiftUI

struct FlowBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(uiColor: ArenaVisualPalette.carbon),
                    Color(uiColor: ArenaVisualPalette.void),
                    Color(red: 0.035, green: 0.046, blue: 0.060)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Canvas { context, size in
                // Industrial wall panels share the same seams and signal rails
                // as the ring apron, so every flow screen reads as a league
                // terminal inside the same arena.
                let horizon = size.height * 0.63
                for index in 0...12 {
                    var path = Path()
                    let x = CGFloat(index) * size.width / 12
                    path.move(to: CGPoint(x: size.width * 0.5, y: horizon))
                    path.addLine(to: CGPoint(x: x, y: size.height + 20))
                    context.stroke(
                        path,
                        with: .color(.white.opacity(0.035)),
                        lineWidth: 1
                    )
                }

                for index in 0..<7 {
                    let y = horizon + CGFloat(index * index) * 5.2
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(.white.opacity(0.035)), lineWidth: 1)
                }

                for index in 0..<6 {
                    let panelWidth = size.width / 6
                    let rect = CGRect(
                        x: CGFloat(index) * panelWidth + 5,
                        y: 8,
                        width: panelWidth - 10,
                        height: horizon - 22
                    )
                    context.stroke(
                        Path(roundedRect: rect, cornerRadius: 3),
                        with: .color(.white.opacity(index.isMultiple(of: 2) ? 0.055 : 0.028)),
                        lineWidth: 1
                    )
                }

                var cyanRail = Path()
                cyanRail.move(to: CGPoint(x: 0, y: horizon - 7))
                cyanRail.addLine(to: CGPoint(x: size.width * 0.46, y: horizon + 4))
                context.stroke(
                    cyanRail,
                    with: .color(Color(uiColor: ArenaVisualPalette.hudPlayerAccent).opacity(0.34)),
                    lineWidth: 2
                )

                var amberRail = Path()
                amberRail.move(to: CGPoint(x: size.width * 0.54, y: horizon + 4))
                amberRail.addLine(to: CGPoint(x: size.width, y: horizon - 7))
                context.stroke(
                    amberRail,
                    with: .color(Color(uiColor: ArenaVisualPalette.hudOpponentAccent).opacity(0.32)),
                    lineWidth: 2
                )
            }

            RadialGradient(
                colors: [Color(uiColor: ArenaVisualPalette.hudPlayerAccent).opacity(0.09), .clear],
                center: .topLeading,
                startRadius: 10,
                endRadius: 390
            )

            RadialGradient(
                colors: [Color(uiColor: ArenaVisualPalette.hudOpponentAccent).opacity(0.07), .clear],
                center: .bottomTrailing,
                startRadius: 10,
                endRadius: 360
            )

            VStack {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(uiColor: ArenaVisualPalette.hudPlayerAccent).opacity(0.76),
                                .white.opacity(0.18),
                                Color(uiColor: ArenaVisualPalette.hudOpponentAccent).opacity(0.74)
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 2)
                Spacer()
                Rectangle()
                    .fill(.black.opacity(0.45))
                    .frame(height: 8)
            }
        }
        .ignoresSafeArea()
    }
}
