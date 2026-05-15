import SwiftUI

struct SplashScreen: View {
    @State private var letterAnimations: [Bool]
    @State private var showIcon = false
    @State private var iconRotation: Double = 0
    @State private var showTagline = false
    @State private var showBeam = false
    @State private var progress: Double = 0
    @State private var glowPulse = false
    @State private var particles: [Particle] = []
    @State private var isComplete = false

    let onComplete: () -> Void

    private let title = "CINEMATE"
    private let letterDelay: Double = 0.06

    init(onComplete: @escaping () -> Void) {
        self.onComplete = onComplete
        _letterAnimations = State(initialValue: Array(repeating: false, count: "CINEMATE".count))
    }

    var body: some View {
        ZStack {
            // Background
            Theme.background
                .ignoresSafeArea()

            // Projector beam effect
            if showBeam {
                RadialGradient(
                    colors: [
                        Theme.primaryGold.opacity(0.08),
                        Theme.primaryGold.opacity(0.03),
                        Color.clear,
                    ],
                    center: .center,
                    startRadius: 20,
                    endRadius: 300
                )
                .ignoresSafeArea()
                .transition(.opacity)
            }

            // Floating particles
            ForEach(particles) { particle in
                Circle()
                    .fill(Theme.primaryGold.opacity(particle.opacity))
                    .frame(width: particle.size, height: particle.size)
                    .position(particle.position)
                    .blur(radius: particle.size * 0.3)
            }

            VStack(spacing: 32) {
                Spacer()

                // Film reel icon
                ZStack {
                    // Glow behind
                    if showIcon {
                        Circle()
                            .fill(Theme.primaryGold.opacity(glowPulse ? 0.2 : 0.08))
                            .frame(width: 120, height: 120)
                            .blur(radius: 30)
                    }

                    Image(systemName: "film.circle")
                        .font(.system(size: 64))
                        .foregroundStyle(Theme.goldGradient)
                        .rotationEffect(.degrees(iconRotation))
                        .opacity(showIcon ? 1 : 0)
                        .scaleEffect(showIcon ? 1 : 0.3)
                }
                .frame(height: 80)

                // Title - letter by letter
                HStack(spacing: 4) {
                    ForEach(Array(title.enumerated()), id: \.offset) { index, letter in
                        Text(String(letter))
                            .font(.system(size: 38, weight: .black, design: .default))
                            .tracking(6)
                            .foregroundStyle(Theme.goldGradient)
                            .opacity(letterAnimations[index] ? 1 : 0)
                            .offset(y: letterAnimations[index] ? 0 : -20)
                    }
                }

                // Tagline
                Text("Your Private Cinema")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Theme.textSecondary)
                    .opacity(showTagline ? 1 : 0)
                    .offset(y: showTagline ? 0 : 10)

                Spacer()

                // Progress bar
                VStack(spacing: 12) {
                    GoldProgressBar(progress: progress, height: 3)
                        .frame(width: 200)

                    Text("Loading...")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.textTertiary)
                        .opacity(progress > 0 ? 1 : 0)
                }
                .padding(.bottom, 60)
            }
        }
        .opacity(isComplete ? 0 : 1)
        .onAppear {
            startAnimationSequence()
        }
    }

    private func startAnimationSequence() {
        // Generate particles
        generateParticles()

        // Show beam
        withAnimation(.easeIn(duration: 0.8)) {
            showBeam = true
        }

        // Animate icon
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            withAnimation(Theme.springAnimation) {
                showIcon = true
            }
            // Rotate icon continuously
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                iconRotation = 360
            }
            // Pulse glow
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                glowPulse = true
            }
        }

        // Letter cascade
        for i in 0..<title.count {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6 + Double(i) * letterDelay) {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    letterAnimations[i] = true
                }
            }
        }

        // Tagline
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeOut(duration: 0.6)) {
                showTagline = true
            }
        }

        // Progress bar
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 2.5)) {
                progress = 1.0
            }
        }

        // Complete
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            withAnimation(.easeInOut(duration: 0.4)) {
                isComplete = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onComplete()
            }
        }
    }

    private func generateParticles() {
        let screenWidth = ScreenInfo.width
        let screenHeight = ScreenInfo.height

        for _ in 0..<20 {
            let particle = Particle(
                position: CGPoint(
                    x: CGFloat.random(in: 0...screenWidth),
                    y: CGFloat.random(in: 0...screenHeight)
                ),
                size: CGFloat.random(in: 2...6),
                opacity: Double.random(in: 0.1...0.4),
                speed: Double.random(in: 1...3)
            )
            particles.append(particle)
        }

        // Animate particles floating
        withAnimation(
            .easeInOut(duration: 3)
            .repeatForever(autoreverses: true)
        ) {
            for i in 0..<particles.count {
                particles[i].position.y -= CGFloat.random(in: 20...60)
                particles[i].opacity = Double.random(in: 0.05...0.3)
            }
        }
    }
}

struct Particle: Identifiable {
    let id = UUID()
    var position: CGPoint
    var size: CGFloat
    var opacity: Double
    var speed: Double
}

#Preview {
    SplashScreen(onComplete: {})
}
