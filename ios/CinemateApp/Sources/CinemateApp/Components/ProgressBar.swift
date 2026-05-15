import SwiftUI

struct CinemateProgressBar: View {
    let progress: Double
    var height: CGFloat = 3
    var backgroundColor: Color = Theme.elevatedSurface
    var foregroundColor: Color = Theme.primaryGold
    var animated: Bool = false

    @State private var animatedProgress: Double = 0

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(backgroundColor)
                    .frame(height: height)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(foregroundColor)
                    .frame(
                        width: geometry.size.width * CGFloat(animated ? animatedProgress : progress),
                        height: height
                    )
            }
        }
        .frame(height: height)
        .onAppear {
            if animated {
                withAnimation(.easeInOut(duration: 2.5)) {
                    animatedProgress = progress
                }
            }
        }
    }
}

struct GoldProgressBar: View {
    let progress: Double
    var height: CGFloat = 3

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Theme.elevatedSurface)
                    .frame(height: height)

                RoundedRectangle(cornerRadius: height / 2)
                    .fill(Theme.goldGradient)
                    .frame(
                        width: geometry.size.width * CGFloat(min(max(progress, 0), 1)),
                        height: height
                    )
            }
        }
        .frame(height: height)
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack(spacing: 20) {
            CinemateProgressBar(progress: 0.35)
            CinemateProgressBar(progress: 0.7, height: 5, foregroundColor: Theme.warmAmber)
            GoldProgressBar(progress: 0.5)
            GoldProgressBar(progress: 0.85, height: 4)
        }
        .padding()
    }
}
