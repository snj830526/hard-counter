import SwiftUI

struct FlowBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.025, green: 0.032, blue: 0.055),
                    Color(red: 0.055, green: 0.067, blue: 0.10),
                    Color(red: 0.018, green: 0.024, blue: 0.043)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Canvas { context, size in
                let center = CGPoint(x: size.width * 0.56, y: size.height * 0.55)
                for index in 0..<5 {
                    var path = Path()
                    let offset = CGFloat(index) * 48
                    path.move(to: CGPoint(x: -80, y: center.y + offset - 96))
                    path.addLine(to: CGPoint(x: center.x, y: center.y + offset))
                    path.addLine(to: CGPoint(x: size.width + 80, y: center.y + offset - 86))
                    context.stroke(
                        path,
                        with: .color(index.isMultiple(of: 2) ? .cyan.opacity(0.16) : .red.opacity(0.13)),
                        lineWidth: 2
                    )
                }
            }

            RadialGradient(
                colors: [.white.opacity(0.08), .clear],
                center: .topTrailing,
                startRadius: 10,
                endRadius: 420
            )
        }
        .ignoresSafeArea()
    }
}
