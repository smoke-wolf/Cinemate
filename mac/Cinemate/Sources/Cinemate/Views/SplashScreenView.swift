import SwiftUI

// MARK: - Splash Screen View

struct SplashScreenView: View {
    @State private var phase: SplashPhase = .dark

    // Animation states
    @State private var projectorBeamOpacity: Double = 0
    @State private var projectorBeamScale: CGFloat = 0.3
    @State private var logoOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.6
    @State private var logoBlur: CGFloat = 12
    @State private var letterOffsets: [CGFloat] = Array(repeating: 40, count: 8)
    @State private var letterOpacities: [Double] = Array(repeating: 0, count: 8)
    @State private var taglineOpacity: Double = 0
    @State private var taglineOffset: CGFloat = 10
    @State private var reelRotation: Double = 0
    @State private var particlePhase: CGFloat = 0
    @State private var progressWidth: CGFloat = 0
    @State private var progressOpacity: Double = 0
    @State private var vignetteOpacity: Double = 0
    @State private var filmStripOffset: CGFloat = 0
    @State private var glowPulse: Double = 0
    @State private var ambientParticlePhase: Double = 0

    private let appName = Array("CINEMATE")
    private let accentGold = Color(red: 0.85, green: 0.65, blue: 0.13)
    private let deepGold = Color(red: 0.72, green: 0.53, blue: 0.04)
    private let warmAmber = Color(red: 0.93, green: 0.76, blue: 0.20)
    private let richBlack = Color(red: 0.04, green: 0.04, blue: 0.06)

    enum SplashPhase {
        case dark, projectorOn, logoReveal, complete
    }

    var body: some View {
        ZStack {
            // Layer 0: Deep black base
            richBlack.ignoresSafeArea()

            // Layer 1: Subtle radial gradient background
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.10, green: 0.08, blue: 0.04).opacity(vignetteOpacity),
                    richBlack
                ]),
                center: .center,
                startRadius: 50,
                endRadius: 500
            )
            .ignoresSafeArea()

            // Layer 2: Animated film grain texture
            FilmGrainView()
                .opacity(0.03)
                .ignoresSafeArea()

            // Layer 3: Film strip borders (top and bottom)
            VStack {
                FilmStripEdge()
                    .offset(x: filmStripOffset)
                Spacer()
                FilmStripEdge()
                    .offset(x: -filmStripOffset)
            }
            .opacity(vignetteOpacity * 0.15)
            .ignoresSafeArea()

            // Layer 4: Projector beam cone
            ProjectorBeamView(opacity: projectorBeamOpacity, scale: projectorBeamScale)

            // Layer 5: Floating dust particles in the beam
            DustParticlesView(phase: particlePhase)
                .opacity(projectorBeamOpacity * 0.6)

            // Layer 6: Main content
            VStack(spacing: 0) {
                Spacer()

                // Film reel icon above the title
                ZStack {
                    // Outer reel
                    Image(systemName: "film.circle")
                        .font(.system(size: 52, weight: .ultraLight))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [warmAmber, accentGold, deepGold],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(reelRotation))
                        .opacity(logoOpacity)
                        .shadow(color: accentGold.opacity(0.4 + glowPulse * 0.3), radius: 20)

                    // Inner glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [warmAmber.opacity(0.3 + glowPulse * 0.2), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 35
                            )
                        )
                        .frame(width: 70, height: 70)
                        .opacity(logoOpacity)
                }
                .padding(.bottom, 24)

                // Kinetic typography: "CINEMATE"
                HStack(spacing: 3) {
                    ForEach(0..<appName.count, id: \.self) { index in
                        Text(String(appName[index]))
                            .font(.system(size: 56, weight: .bold, design: .default))
                            .tracking(2)
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [warmAmber, accentGold, deepGold],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .shadow(color: accentGold.opacity(0.6), radius: 8, x: 0, y: 0)
                            .shadow(color: accentGold.opacity(0.2), radius: 24, x: 0, y: 0)
                            .offset(y: letterOffsets[index])
                            .opacity(letterOpacities[index])
                    }
                }
                .blur(radius: logoBlur)
                .scaleEffect(logoScale)

                // Separator line
                CinematicDivider(accentGold: accentGold, warmAmber: warmAmber)
                    .opacity(taglineOpacity)
                    .padding(.top, 16)
                    .padding(.bottom, 12)

                // Tagline
                Text("Your Private Cinema")
                    .font(.system(size: 14, weight: .medium, design: .default))
                    .tracking(6)
                    .foregroundColor(accentGold.opacity(0.7))
                    .opacity(taglineOpacity)
                    .offset(y: taglineOffset)

                Spacer()

                // Loading progress bar
                VStack(spacing: 12) {
                    // Minimal progress track
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 1)
                            .fill(Color.white.opacity(0.06))
                            .frame(width: 200, height: 2)

                        RoundedRectangle(cornerRadius: 1)
                            .fill(
                                LinearGradient(
                                    colors: [deepGold, accentGold, warmAmber],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: progressWidth, height: 2)
                            .shadow(color: accentGold.opacity(0.5), radius: 6)
                    }

                    Text("Loading")
                        .font(.system(size: 10, weight: .regular))
                        .tracking(3)
                        .foregroundColor(Color.white.opacity(0.3))
                }
                .opacity(progressOpacity)
                .padding(.bottom, 60)
            }

            // Layer 7: Vignette overlay
            RadialGradient(
                gradient: Gradient(colors: [
                    .clear,
                    .clear,
                    richBlack.opacity(0.5),
                    richBlack.opacity(0.9)
                ]),
                center: .center,
                startRadius: 150,
                endRadius: 600
            )
            .ignoresSafeArea()
            .opacity(vignetteOpacity)
            .allowsHitTesting(false)
        }
        .onAppear {
            startAnimationSequence()
        }
    }

    // MARK: - Animation Sequence

    private func startAnimationSequence() {
        // Continuous animations
        withAnimation(.linear(duration: 20).repeatForever(autoreverses: false)) {
            reelRotation = 360
        }
        withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
            glowPulse = 1.0
        }
        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
            particlePhase = 1.0
        }
        withAnimation(.linear(duration: 15).repeatForever(autoreverses: false)) {
            filmStripOffset = -200
        }
        withAnimation(.linear(duration: 3.0).repeatForever(autoreverses: false)) {
            ambientParticlePhase = 1.0
        }

        // Phase 1: Projector beam appears (0.2s delay)
        withAnimation(.easeOut(duration: 0.8).delay(0.2)) {
            projectorBeamOpacity = 1.0
            projectorBeamScale = 1.0
            vignetteOpacity = 1.0
            phase = .projectorOn
        }

        // Phase 2: Logo materializes (0.6s delay)
        withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.6)) {
            logoScale = 1.0
            logoBlur = 0
            logoOpacity = 1.0
        }

        // Phase 3: Kinetic letters cascade in (0.8s delay, staggered)
        for i in 0..<appName.count {
            let stagger = Double(i) * 0.06
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.8 + stagger)) {
                letterOffsets[i] = 0
                letterOpacities[i] = 1.0
            }
        }

        // Phase 4: Tagline and progress (1.5s delay)
        withAnimation(.easeOut(duration: 0.6).delay(1.5)) {
            taglineOpacity = 1.0
            taglineOffset = 0
            progressOpacity = 1.0
        }

        // Phase 5: Progress bar fills (1.6s delay)
        withAnimation(.easeInOut(duration: 1.5).delay(1.6)) {
            progressWidth = 200
        }
    }
}

// MARK: - Projector Beam

private struct ProjectorBeamView: View {
    let opacity: Double
    let scale: CGFloat

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            ZStack {
                // Primary beam cone from top
                EllipticalGradient(
                    gradient: Gradient(colors: [
                        Color(red: 0.93, green: 0.76, blue: 0.20).opacity(0.08),
                        Color(red: 0.85, green: 0.65, blue: 0.13).opacity(0.03),
                        .clear
                    ]),
                    center: .center,
                    startRadiusFraction: 0.0,
                    endRadiusFraction: 0.5
                )
                .frame(width: geo.size.width * 0.7, height: geo.size.height * 0.8)
                .position(center)

                // Secondary hotspot
                RadialGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(0.04),
                        Color(red: 0.85, green: 0.65, blue: 0.13).opacity(0.02),
                        .clear
                    ]),
                    center: .center,
                    startRadius: 0,
                    endRadius: 200
                )
                .frame(width: 400, height: 400)
                .position(center)
            }
        }
        .opacity(opacity)
        .scaleEffect(scale)
    }
}

// MARK: - Dust Particles

private struct DustParticlesView: View {
    let phase: CGFloat

    var body: some View {
        Canvas { context, size in
            let particles = generateParticles(count: 40, size: size, phase: phase)
            for p in particles {
                let rect = CGRect(
                    x: p.x - p.radius,
                    y: p.y - p.radius,
                    width: p.radius * 2,
                    height: p.radius * 2
                )
                context.opacity = p.opacity
                context.fill(
                    Circle().path(in: rect),
                    with: .color(Color(red: 0.93, green: 0.76, blue: 0.20))
                )
            }
        }
        .allowsHitTesting(false)
    }

    private func generateParticles(count: Int, size: CGSize, phase: CGFloat) -> [Particle] {
        (0..<count).map { i in
            let seed = Double(i)
            let t = (phase + seed / Double(count)).truncatingRemainder(dividingBy: 1.0)
            let x = size.width * 0.3 + (size.width * 0.4) * pseudoRandom(seed: seed)
            let y = size.height * t
            let radius = 0.5 + 1.5 * pseudoRandom(seed: seed + 100)
            let opacity = 0.1 + 0.3 * pseudoRandom(seed: seed + 200) * sin(.pi * t)
            return Particle(x: x, y: y, radius: radius, opacity: opacity)
        }
    }

    private func pseudoRandom(seed: Double) -> Double {
        let x = sin(seed * 12.9898 + 78.233) * 43758.5453
        return x - floor(x)
    }

    private struct Particle {
        let x: Double
        let y: Double
        let radius: Double
        let opacity: Double
    }
}

// MARK: - Film Grain

private struct FilmGrainView: View {
    var body: some View {
        Canvas { context, size in
            for _ in 0..<300 {
                let x = Double.random(in: 0..<size.width)
                let y = Double.random(in: 0..<size.height)
                let brightness = Double.random(in: 0.3...1.0)
                let rect = CGRect(x: x, y: y, width: 1, height: 1)
                context.opacity = brightness
                context.fill(
                    Rectangle().path(in: rect),
                    with: .color(.white)
                )
            }
        }
    }
}

// MARK: - Film Strip Edge

private struct FilmStripEdge: View {
    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<40, id: \.self) { _ in
                HStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 16, height: 12)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)

                    Rectangle()
                        .fill(Color.white.opacity(0.05))
                        .frame(width: 1, height: 20)
                }
            }
        }
        .frame(height: 20)
    }
}

// MARK: - Cinematic Divider

private struct CinematicDivider: View {
    let accentGold: Color
    let warmAmber: Color

    var body: some View {
        HStack(spacing: 8) {
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [.clear, accentGold.opacity(0.4)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 60, height: 0.5)

            Image(systemName: "sparkle")
                .font(.system(size: 6))
                .foregroundColor(warmAmber.opacity(0.6))

            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [accentGold.opacity(0.4), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: 60, height: 0.5)
        }
    }
}

// MARK: - Preview

#if DEBUG
#Preview("Cinemate Splash Screen") {
    SplashScreenView()
        .frame(width: 1280, height: 800)
        .preferredColorScheme(.dark)
}
#endif
