import SwiftUI
import AVKit

struct MoviePlayerView: View {
    @EnvironmentObject var apiClient: APIClient
    let movie: MediaItem
    let account: Account

    @State private var player: AVPlayer?
    @State private var showControls = true
    @State private var controlsTimer: Timer?
    @State private var currentTime: TimeInterval = 0
    @State private var totalDuration: TimeInterval = 0
    @State private var isPlaying = false
    @State private var isFillMode = false
    @State private var playerError: String?
    @State private var statusObserver: NSKeyValueObservation?
    @State private var errorObserver: NSKeyValueObservation?
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // Video Player
            if let player = player {
                #if os(iOS)
                PlayerLayerView(
                    player: player,
                    videoGravity: isFillMode ? .resizeAspectFill : .resizeAspect
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        showControls.toggle()
                    }
                    resetControlsTimer()
                }
                #else
                VideoPlayer(player: player)
                    .ignoresSafeArea()
                #endif
            } else if let error = playerError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.error)
                    Text("Playback Error")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.white)
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                    Button("Dismiss") { dismiss() }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.primaryGold)
                        .padding(.top, 8)
                }
            } else {
                ProgressView()
                    .tint(Theme.primaryGold)
                    .scaleEffect(1.5)
            }

            // Custom overlay controls
            if showControls {
                controlsOverlay
                    .transition(.opacity)
            }
        }
        .onAppear {
            setupPlayer()
            forceLandscape()
        }
        .onDisappear {
            saveProgress()
            statusObserver?.invalidate()
            errorObserver?.invalidate()
            player?.pause()
            player = nil
            restorePortrait()
        }
        .persistentSystemOverlays(.hidden)
    }

    private var controlsOverlay: some View {
        ZStack {
            // Background dimming
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                // Top bar
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 8) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                            Text(movie.title)
                                .font(.system(size: 16, weight: .semibold))
                                .lineLimit(1)
                        }
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.ultraThinMaterial.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Spacer()

                    HStack(spacing: 10) {
                        // Aspect ratio toggle
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isFillMode.toggle()
                            }
                        }) {
                            Image(systemName: isFillMode ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                                .font(.system(size: 16))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.ultraThinMaterial.opacity(0.6))
                                .clipShape(Circle())
                        }

                        // PiP button
                        Button(action: {}) {
                            Image(systemName: "pip.enter")
                                .font(.system(size: 18))
                                .foregroundStyle(.white)
                                .padding(10)
                                .background(.ultraThinMaterial.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                }
                .padding()

                Spacer()

                // Center controls
                HStack(spacing: 48) {
                    Button(action: { seekBackward() }) {
                        Image(systemName: "gobackward.10")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                    }

                    Button(action: { togglePlayPause() }) {
                        Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.white)
                    }

                    Button(action: { seekForward() }) {
                        Image(systemName: "goforward.10")
                            .font(.system(size: 32))
                            .foregroundStyle(.white)
                    }
                }

                Spacer()

                // Bottom bar with seek
                VStack(spacing: 8) {
                    // Seek slider
                    Slider(
                        value: Binding(
                            get: { currentTime },
                            set: { newValue in
                                currentTime = newValue
                                let time = CMTime(seconds: newValue, preferredTimescale: 600)
                                player?.seek(to: time)
                            }
                        ),
                        in: 0...max(totalDuration, 1)
                    )
                    .tint(Theme.primaryGold)

                    HStack {
                        Text(formatTime(currentTime))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))

                        Spacer()

                        Text("-\(formatTime(totalDuration - currentTime))")
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 20)
            }
        }
    }

    private func setupPlayer() {
        guard let streamURLString = movie.streamURL else {
            playerError = "No stream URL available for this movie."
            return
        }

        let transcodeURLString = streamURLString.replacingOccurrences(
            of: "/api/stream/\(movie.id)",
            with: "/api/stream/\(movie.id)/transcode"
        )
        let finalURLString = transcodeURLString.contains("/transcode") ? transcodeURLString : streamURLString

        guard let url = URL(string: finalURLString) else {
            playerError = "Invalid stream URL."
            return
        }

        let avPlayer = AVPlayer(url: url)

        statusObserver = avPlayer.currentItem?.observe(\.status, options: [.new]) { item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .failed:
                    self.player = nil
                    self.playerError = item.error?.localizedDescription ?? "Playback failed"
                case .readyToPlay:
                    if self.movie.watchProgress > 0, let duration = self.movie.duration {
                        let seekTime = CMTime(seconds: duration * self.movie.watchProgress, preferredTimescale: 600)
                        avPlayer.seek(to: seekTime)
                    }
                default:
                    break
                }
            }
        }

        self.player = avPlayer

        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            self.currentTime = time.seconds.isNaN ? 0 : time.seconds
            if let item = avPlayer.currentItem {
                let dur = item.duration.seconds
                if !dur.isNaN {
                    self.totalDuration = dur
                }
            }
        }

        avPlayer.play()
        isPlaying = true
        resetControlsTimer()
    }

    private func togglePlayPause() {
        if isPlaying {
            player?.pause()
        } else {
            player?.play()
        }
        isPlaying.toggle()
    }

    private func seekBackward() {
        let newTime = max(currentTime - 10, 0)
        let cmTime = CMTime(seconds: newTime, preferredTimescale: 600)
        player?.seek(to: cmTime)
    }

    private func seekForward() {
        let newTime = min(currentTime + 10, totalDuration)
        let cmTime = CMTime(seconds: newTime, preferredTimescale: 600)
        player?.seek(to: cmTime)
    }

    private func saveProgress() {
        guard totalDuration > 0 else { return }
        Task {
            try? await apiClient.updateWatchProgress(
                accountId: Int(account.id) ?? 0,
                movieId: movie.id,
                position: currentTime,
                duration: totalDuration
            )
        }
    }

    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls = false
            }
        }
    }

    private func forceLandscape() {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first else { return }
            let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(
                interfaceOrientations: .landscape
            )
            windowScene.requestGeometryUpdate(geometryPreferences)
            windowScene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.landscapeRight.rawValue, forKey: "orientation")
            UINavigationController.attemptRotationToDeviceOrientation()
        }
        #endif
    }

    private func restorePortrait() {
        #if os(iOS)
        if #available(iOS 16.0, *) {
            guard let windowScene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene }).first else { return }
            let geometryPreferences = UIWindowScene.GeometryPreferences.iOS(
                interfaceOrientations: .portrait
            )
            windowScene.requestGeometryUpdate(geometryPreferences)
            windowScene.keyWindow?.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        } else {
            UIDevice.current.setValue(UIInterfaceOrientation.portrait.rawValue, forKey: "orientation")
            UINavigationController.attemptRotationToDeviceOrientation()
        }
        #endif
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(max(seconds, 0))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let secs = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}

#Preview {
    MoviePlayerView(movie: .preview, account: Account.previewAccounts[0])
        .environmentObject(APIClient())
}
