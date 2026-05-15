import SwiftUI

struct AlbumView: View {
    @EnvironmentObject var apiClient: APIClient
    @EnvironmentObject var audioPlayer: AudioPlayer
    let album: MusicAlbum

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Album Art
                    CachedAsyncImage(url: nil) {
                        AlbumArtPlaceholder(size: 240)
                    }
                    .frame(width: 240, height: 240)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerMedium))
                    .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)
                    .padding(.top, 20)

                    // Info
                    VStack(spacing: 6) {
                        Text(album.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)
                            .multilineTextAlignment(.center)

                        Text(album.artist)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(Theme.primaryGold)

                        HStack(spacing: 8) {
                            if let genre = album.genre {
                                Text(genre)
                            }
                            if let year = album.year {
                                Text("\u{2022} \(year)")
                            }
                            Text("\u{2022} \(album.trackCountDisplay)")
                            Text("\u{2022} \(album.formattedDuration)")
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                    }

                    // Action buttons
                    HStack(spacing: 16) {
                        GoldButton(title: "Play All", icon: "play.fill", action: {
                            if let first = album.tracks.first {
                                audioPlayer.playTrack(first, from: apiClient.baseURL, queue: album.tracks)
                            }
                        })

                        SecondaryButton(title: "Shuffle", icon: "shuffle") {
                            let shuffled = album.tracks.shuffled()
                            if let first = shuffled.first {
                                audioPlayer.playTrack(first, from: apiClient.baseURL, queue: shuffled)
                            }
                        }
                    }

                    // Track list
                    VStack(spacing: 0) {
                        ForEach(album.tracks) { track in
                            TrackRow(track: track) {
                                audioPlayer.playTrack(track, from: apiClient.baseURL, queue: album.tracks)
                            }

                            if track.id != album.tracks.last?.id {
                                Divider()
                                    .background(Theme.elevatedSurface)
                                    .padding(.leading, 82)
                            }
                        }
                    }
                }
                .padding(.bottom, 140)
            }
        }
        .cinemateNavigationBarInline()
        .cinemateToolbarColorScheme(.dark)
    }
}

#Preview {
    NavigationStack {
        AlbumView(album: .preview)
            .environmentObject(APIClient())
            .environmentObject(AudioPlayer())
    }
    .preferredColorScheme(.dark)
}
