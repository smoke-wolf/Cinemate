import SwiftUI
import AVKit

struct TVShowDetailView: View {
    @EnvironmentObject var apiClient: APIClient
    let show: TVShow

    @State private var selectedSeason: Int = 0
    @State private var isFavorite: Bool
    @State private var showPlayer = false
    @State private var playingEpisode: Episode?

    init(show: TVShow) {
        self.show = show
        _isFavorite = State(initialValue: show.isFavorite)
    }

    var currentSeason: Season? {
        guard selectedSeason < show.seasons.count else { return nil }
        return show.seasons[selectedSeason]
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero
                    ZStack(alignment: .bottom) {
                        CachedAsyncImage(url: URL(string: show.thumbnailURL ?? "")) {
                            MediaPlaceholder(icon: "tv")
                        }
                        .frame(height: 220)

                        LinearGradient(
                            colors: [.clear, Theme.background],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                        .frame(height: 120)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        // Title + Meta
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(show.title)
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(Theme.textPrimary)

                                Spacer()

                                Button(action: {
                                    isFavorite.toggle()
                                    hapticImpact(.medium)
                                }) {
                                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                                        .font(.system(size: 20))
                                        .foregroundStyle(isFavorite ? Theme.error : Theme.textSecondary)
                                }
                            }

                            HStack(spacing: 12) {
                                if let year = show.year {
                                    Text("\(year)")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.textSecondary)
                                }

                                Text(show.genre.joined(separator: " \u{2022} "))
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(1)
                            }

                            HStack(spacing: 12) {
                                RatingDisplay(rating: show.rating)

                                Text(show.seasonCount)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textSecondary)

                                Text("\(show.totalEpisodes) episodes")
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                        .padding(.horizontal)

                        // Description
                        if let description = show.description {
                            Text(description)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(3)
                                .padding(.horizontal)
                        }

                        // Season Picker
                        if show.seasons.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(Array(show.seasons.enumerated()), id: \.element.id) { index, season in
                                        Button(action: {
                                            withAnimation(Theme.quickSpring) {
                                                selectedSeason = index
                                            }
                                        }) {
                                            Text(season.displayTitle)
                                                .font(.system(size: 14, weight: selectedSeason == index ? .bold : .medium))
                                                .foregroundStyle(selectedSeason == index ? .black : Theme.textSecondary)
                                                .padding(.horizontal, 16)
                                                .padding(.vertical, 8)
                                                .background(
                                                    selectedSeason == index
                                                    ? AnyShapeStyle(Theme.goldGradient)
                                                    : AnyShapeStyle(Theme.cardSurface)
                                                )
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                                .padding(.horizontal)
                            }
                        }

                        // Episode List
                        if let season = currentSeason {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Episodes")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundStyle(Theme.textPrimary)
                                    .padding(.horizontal)
                                    .padding(.bottom, 4)

                                ForEach(season.episodes) { episode in
                                    EpisodeRow(episode: episode) {
                                        playingEpisode = episode
                                        showPlayer = true
                                    }
                                }
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .cinemateNavigationBarInline()
        .cinemateToolbarHidden()
        .cinemateToolbarColorScheme(.dark)
        #if os(iOS)
        .fullScreenCover(isPresented: $showPlayer) {
            if let episode = playingEpisode {
                EpisodePlayerView(show: show, episode: episode)
                    .environmentObject(apiClient)
            }
        }
        #else
        .sheet(isPresented: $showPlayer) {
            if let episode = playingEpisode {
                EpisodePlayerView(show: show, episode: episode)
                    .environmentObject(apiClient)
            }
        }
        #endif
    }
}

struct EpisodeRow: View {
    let episode: Episode
    let onPlay: () -> Void

    var body: some View {
        Button(action: onPlay) {
            HStack(spacing: 14) {
                // Thumbnail
                ZStack {
                    CachedAsyncImage(url: URL(string: episode.thumbnailURL ?? "")) {
                        MediaPlaceholder(icon: "play.rectangle")
                    }
                    .frame(width: 120, height: 68)
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                    // Play icon
                    Circle()
                        .fill(.black.opacity(0.4))
                        .frame(width: 32, height: 32)
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12))
                                .foregroundStyle(.white)
                        }

                    // Progress
                    if episode.watchProgress > 0 && episode.watchProgress < 1 {
                        VStack {
                            Spacer()
                            GoldProgressBar(progress: episode.watchProgress, height: 2)
                        }
                        .frame(width: 120, height: 68)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(episode.episodeLabel)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(Theme.primaryGold)

                        if episode.isWatched {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.success)
                        }
                    }

                    Text(episode.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if !episode.formattedDuration.isEmpty {
                            Text(episode.formattedDuration)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }

                    if let desc = episode.description {
                        Text(desc)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                            .lineLimit(2)
                    }
                }

                Spacer()
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .buttonStyle(.plain)
    }
}

struct EpisodePlayerView: View {
    @EnvironmentObject var apiClient: APIClient
    let show: TVShow
    let episode: Episode

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
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            VStack {
                HStack {
                    Button(action: { dismiss() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "chevron.left")
                            VStack(alignment: .leading, spacing: 2) {
                                Text(show.title)
                                    .font(.system(size: 14, weight: .semibold))
                                Text("\(episode.episodeLabel) - \(episode.title)")
                                    .font(.system(size: 12))
                                    .opacity(0.8)
                            }
                        }
                        .foregroundStyle(.white)
                        .padding(12)
                        .background(.ultraThinMaterial.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Spacer()

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
                }
                .padding()

                Spacer()

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

                VStack(spacing: 8) {
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
        guard let streamURLString = episode.streamURL else {
            playerError = "No stream URL available for this episode."
            return
        }

        let transcodeURLString = streamURLString.contains("/api/stream/")
            ? streamURLString + "/transcode" : streamURLString

        guard let url = URL(string: transcodeURLString) else {
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
        player?.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
    }

    private func seekForward() {
        let newTime = min(currentTime + 10, totalDuration)
        player?.seek(to: CMTime(seconds: newTime, preferredTimescale: 600))
    }

    private func resetControlsTimer() {
        controlsTimer?.invalidate()
        controlsTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            withAnimation(.easeInOut(duration: 0.3)) {
                showControls = false
            }
        }
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
}

#Preview {
    NavigationStack {
        TVShowDetailView(show: .preview)
            .environmentObject(APIClient())
    }
    .preferredColorScheme(.dark)
}
