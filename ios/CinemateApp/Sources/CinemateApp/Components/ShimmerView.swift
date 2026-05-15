import SwiftUI

struct ShimmerView: View {
    @State private var phase: CGFloat = -1.0

    var body: some View {
        Rectangle()
            .fill(Theme.cardSurface)
            .overlay {
                GeometryReader { geometry in
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Color.white.opacity(0.05),
                                    Color.white.opacity(0.1),
                                    Color.white.opacity(0.05),
                                    Color.clear,
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * 0.6)
                        .offset(x: geometry.size.width * phase)
                }
                .clipped()
            }
            .onAppear {
                withAnimation(
                    .linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1.5
                }
            }
    }
}

struct ShimmerCard: View {
    var width: CGFloat = 160
    var height: CGFloat = 90

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ShimmerView()
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall))

            ShimmerView()
                .frame(width: width * 0.7, height: 12)
                .clipShape(RoundedRectangle(cornerRadius: 4))

            ShimmerView()
                .frame(width: width * 0.4, height: 10)
                .clipShape(RoundedRectangle(cornerRadius: 4))
        }
    }
}

struct ShimmerRow: View {
    var body: some View {
        HStack(spacing: 12) {
            ShimmerView()
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall))

            VStack(alignment: .leading, spacing: 6) {
                ShimmerView()
                    .frame(width: 140, height: 14)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                ShimmerView()
                    .frame(width: 90, height: 10)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }

            Spacer()
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack(spacing: 24) {
            ShimmerCard()
            ShimmerCard(width: 200, height: 120)
            ShimmerRow()
                .padding(.horizontal)
            ShimmerRow()
                .padding(.horizontal)
        }
    }
}
