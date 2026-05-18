import SwiftUI
import AVKit

struct NowPlayingView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var apiClient: APIClient
    let account: Account
    @State private var showQueue = false
    @State private var showLyrics = false
    @State private var artworkScale: CGFloat = 1.0
    @Environment(\.dismiss) var dismiss

    @State private var showToast = false
    @State private var toastIcon = ""
    @State private var toastMessage = ""

    var body: some View {
        ZStack {
            // Gradient background
            LinearGradient(
                colors: [
                    Color(hex: "#1A1208"),
                    Theme.background,
                    Color(hex: "#0D0D14"),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag indicator
                Capsule()
                    .fill(Theme.textTertiary.opacity(0.4))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)

                Spacer()

                if let track = audioPlayer.currentTrack {
                    // Album Art / Lyrics toggle
                    ZStack {
                        if showLyrics && audioPlayer.hasLyrics {
                            NowPlayingLyricsPanel(audioPlayer: audioPlayer) {
                                audioPlayer.seek(to: $0)
                            }
                        } else {
                            CachedAsyncImage(url: audioPlayer.albumArtURL) {
                                RoundedRectangle(cornerRadius: Theme.cornerLarge)
                                    .fill(
                                        LinearGradient(
                                            colors: [Theme.cardSurface, Theme.elevatedSurface],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .overlay {
                                        Image(systemName: "music.note")
                                            .font(.system(size: 60))
                                            .foregroundStyle(Theme.textTertiary)
                                    }
                            }
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerLarge))
                            .shadow(color: .black.opacity(0.5), radius: 30, x: 0, y: 15)
                            .scaleEffect(audioPlayer.isPlaying ? 1.0 : 0.88)
                            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: audioPlayer.isPlaying)
                        }
                    }
                    .frame(width: 300, height: 300)
                    .onTapGesture {
                        if audioPlayer.hasLyrics {
                            withAnimation(.easeInOut(duration: 0.3)) {
                                showLyrics.toggle()
                            }
                        }
                    }
                    .padding(.bottom, 32)

                    // Track Info
                    VStack(spacing: 6) {
                        Text(track.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)

                        Text(track.artist)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.primaryGold)

                        if let album = track.albumTitle {
                            Text(album)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 24)

                    // Seek Slider
                    VStack(spacing: 4) {
                        Slider(
                            value: Binding(
                                get: { audioPlayer.currentTime },
                                set: { audioPlayer.seek(to: $0) }
                            ),
                            in: 0...max(audioPlayer.duration, 1)
                        )
                        .tint(Theme.primaryGold)

                        HStack {
                            Text(formatTime(audioPlayer.currentTime))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(Theme.textTertiary)
                            Spacer()
                            Text("-\(formatTime(audioPlayer.duration - audioPlayer.currentTime))")
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundStyle(Theme.textTertiary)
                        }
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 20)

                    // Main Controls
                    HStack(spacing: 0) {
                        // Shuffle
                        Button(action: {
                            hapticImpact(.light)
                            audioPlayer.toggleShuffle()
                            showFeedback(icon: "shuffle", message: audioPlayer.isShuffled ? "Shuffle On" : "Shuffle Off")
                        }) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 18))
                                .foregroundStyle(audioPlayer.isShuffled ? Theme.primaryGold : Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)

                        // Previous
                        Button(action: {
                            hapticImpact(.medium)
                            audioPlayer.previous()
                        }) {
                            Image(systemName: "backward.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)

                        // Play/Pause
                        Button(action: {
                            hapticImpact(.medium)
                            audioPlayer.togglePlayPause()
                        }) {
                            ZStack {
                                Circle()
                                    .fill(Theme.goldGradient)
                                    .frame(width: 64, height: 64)
                                    .shadow(color: Theme.goldGlow, radius: 12, x: 0, y: 4)

                                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 24))
                                    .foregroundStyle(.black)
                                    .offset(x: audioPlayer.isPlaying ? 0 : 2)
                            }
                        }
                        .frame(maxWidth: .infinity)

                        // Next
                        Button(action: {
                            hapticImpact(.medium)
                            audioPlayer.next()
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.system(size: 28))
                                .foregroundStyle(Theme.textPrimary)
                        }
                        .frame(maxWidth: .infinity)

                        // Repeat
                        Button(action: {
                            hapticImpact(.light)
                            audioPlayer.toggleRepeat()
                            let msg: String
                            switch audioPlayer.repeatMode {
                            case .off: msg = "Repeat Off"
                            case .all: msg = "Repeat All"
                            case .one: msg = "Repeat One"
                            }
                            showFeedback(icon: audioPlayer.repeatMode.icon, message: msg)
                        }) {
                            Image(systemName: audioPlayer.repeatMode.icon)
                                .font(.system(size: 18))
                                .foregroundStyle(audioPlayer.repeatMode.isActive ? Theme.primaryGold : Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 28)

                    // Volume Slider
                    HStack(spacing: 12) {
                        Image(systemName: "speaker.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)

                        Slider(
                            value: Binding(
                                get: { audioPlayer.volume },
                                set: { audioPlayer.volume = $0 }
                            ),
                            in: 0...1
                        )
                        .tint(Theme.textSecondary)

                        Image(systemName: "speaker.wave.3.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.horizontal, 32)
                    .padding(.bottom, 16)

                    // Bottom actions
                    HStack(spacing: 0) {
                        // Favorite
                        Button(action: {
                            hapticImpact(.light)
                            let wasFavorite = track.isFavorite
                            Task {
                                try? await apiClient.toggleMusicFavorite(accountId: Int(account.id) ?? 0, trackId: track.id)
                                audioPlayer.currentTrack?.isFavorite.toggle()
                                showFeedback(
                                    icon: wasFavorite ? "heart" : "heart.fill",
                                    message: wasFavorite ? "Removed from Favorites" : "Added to Favorites"
                                )
                            }
                        }) {
                            Image(systemName: track.isFavorite ? "heart.fill" : "heart")
                                .font(.system(size: 20))
                                .foregroundStyle(track.isFavorite ? Theme.primaryGold : Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)

                        // Lyrics
                        Button(action: {
                            hapticImpact(.light)
                            if audioPlayer.hasLyrics {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    showLyrics.toggle()
                                }
                            } else {
                                showFeedback(icon: "quote.bubble", message: "No lyrics available")
                            }
                        }) {
                            Image(systemName: "quote.bubble")
                                .font(.system(size: 20))
                                .foregroundStyle(
                                    showLyrics ? Theme.primaryGold :
                                    audioPlayer.hasLyrics ? Theme.textSecondary :
                                    Theme.textTertiary.opacity(0.4)
                                )
                        }
                        .frame(maxWidth: .infinity)

                        // AirPlay
                        CrossPlatformAirPlayButton()
                            .frame(width: 24, height: 24)
                            .frame(maxWidth: .infinity)

                        // Queue
                        Button(action: {
                            hapticImpact(.light)
                            showQueue.toggle()
                        }) {
                            Image(systemName: "list.bullet")
                                .font(.system(size: 20))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 32)

                } else {
                    Text("Nothing Playing")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()
            }
        }
        .sheet(isPresented: $showQueue) {
            QueueView()
        }
        .toast(isPresented: $showToast, icon: toastIcon, message: toastMessage, edge: .top)
    }

    private func showFeedback(icon: String, message: String) {
        toastIcon = icon
        toastMessage = message
        withAnimation { showToast = true }
    }

    private func formatTime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(max(seconds, 0))
        let minutes = totalSeconds / 60
        let secs = totalSeconds % 60
        return "\(minutes):\(String(format: "%02d", secs))"
    }
}

struct QueueView: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                HStack {
                    Text("Up Next")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Button("Done") { dismiss() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Theme.primaryGold)
                }
                .padding()

                if audioPlayer.queue.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 36))
                            .foregroundStyle(Theme.textTertiary)
                        Text("Queue is empty")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .frame(maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 2) {
                            ForEach(audioPlayer.queue) { track in
                                TrackRow(track: track) {
                                    audioPlayer.playTrack(track, from: "", queue: audioPlayer.queue)
                                }
                            }
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Lyrics Panel (inline in Now Playing)

struct NowPlayingLyricsPanel: View {
    @ObservedObject var audioPlayer: AudioPlayer
    var onSeek: (TimeInterval) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: 2) {
                    Spacer().frame(height: 100)

                    ForEach(audioPlayer.lyricLines) { line in
                        let isActive = line.id == audioPlayer.currentLyricIndex
                        let isPast = line.id < audioPlayer.currentLyricIndex

                        Text(line.text)
                            .font(.system(size: isActive ? 17 : 14, weight: isActive ? .bold : .medium))
                            .foregroundStyle(
                                isActive ? Color.white :
                                isPast ? Color.white.opacity(0.2) :
                                Color.white.opacity(0.4)
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 4)
                            .id(line.id)
                            .onTapGesture {
                                onSeek(line.time)
                            }
                    }

                    Spacer().frame(height: 120)
                }
            }
            .onChange(of: audioPlayer.currentLyricIndex) { _, newIndex in
                guard newIndex >= 0 else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.black.opacity(0.6))
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

#Preview {
    NowPlayingView(account: Account.previewAccounts[0])
        .environmentObject(AudioPlayer())
        .environmentObject(APIClient())
}
