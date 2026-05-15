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
                        CachedAsyncImage(url: nil) {
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
            }
        }
        #else
        .sheet(isPresented: $showPlayer) {
            if let episode = playingEpisode {
                EpisodePlayerView(show: show, episode: episode)
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
                    CachedAsyncImage(url: nil) {
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
    @Environment(\.dismiss) var dismiss

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = player {
                VideoPlayer(player: player)
                    .ignoresSafeArea()
            } else {
                ProgressView()
                    .tint(Theme.primaryGold)
            }

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
                        .background(.ultraThinMaterial.opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    Spacer()
                }
                .padding()
                Spacer()
            }
        }
        .onAppear {
            if let streamURL = episode.streamURL,
               let url = apiClient.streamURL(for: streamURL) {
                let avPlayer = AVPlayer(url: url)
                self.player = avPlayer
                avPlayer.play()
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .persistentSystemOverlays(.hidden)
    }
}

#Preview {
    NavigationStack {
        TVShowDetailView(show: .preview)
            .environmentObject(APIClient())
    }
    .preferredColorScheme(.dark)
}
