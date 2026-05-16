import SwiftUI

struct ConnectingView: View {
    let serverURL: String
    let onCancel: () -> Void

    @State private var dotCount = 0
    @State private var pulseScale: CGFloat = 1.0
    @State private var showCancel = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .fill(Theme.primaryGold.opacity(0.1))
                        .frame(width: 120, height: 120)
                        .scaleEffect(pulseScale)

                    Circle()
                        .fill(Theme.primaryGold.opacity(0.05))
                        .frame(width: 160, height: 160)
                        .scaleEffect(pulseScale * 0.9)

                    Image(systemName: "antenna.radiowaves.left.and.right")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.goldGradient)
                }

                VStack(spacing: 10) {
                    Text("Connecting" + String(repeating: ".", count: dotCount))
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                        .frame(width: 200, alignment: .leading)

                    Text(serverURL)
                        .font(.system(size: 14, design: .monospaced))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if showCancel {
                    Button(action: onCancel) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 15))
                            Text("Cancel")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundStyle(Theme.textSecondary)
                        .padding(.horizontal, 28)
                        .padding(.vertical, 12)
                        .background(Theme.cardSurface)
                        .clipShape(Capsule())
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()
                    .frame(height: 60)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.15
            }

            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
                dotCount = (dotCount % 3) + 1
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    showCancel = true
                }
            }
        }
    }
}

#Preview {
    ConnectingView(serverURL: "http://192.168.1.186:9876", onCancel: {})
}
