import SwiftUI

struct ArtistView: View {
    @EnvironmentObject var apiClient: APIClient
    @EnvironmentObject var audioPlayer: AudioPlayer
    let artist: MusicArtist

    let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
    ]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Artist Header
                    VStack(spacing: 16) {
                        // Avatar
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.cardSurface, Theme.elevatedSurface, Theme.cardSurface],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 120, height: 120)
                            .overlay {
                                Image(systemName: "music.mic")
                                    .font(.system(size: 40))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)

                        Text(artist.name)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)

                        HStack(spacing: 12) {
                            Label("\(artist.albums.count) Albums", systemImage: "square.stack")
                            Text("\u{2022}")
                            Label("\(artist.trackCount) Tracks", systemImage: "music.note")
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.top, 20)

                    // Albums Grid
                    if !artist.albums.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Albums")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                                .padding(.horizontal)

                            LazyVGrid(columns: columns, spacing: 18) {
                                ForEach(artist.albums) { album in
                                    NavigationLink(destination: AlbumView(album: album)) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            CachedAsyncImage(url: nil) {
                                                AlbumArtPlaceholder(size: 170)
                                            }
                                            .aspectRatio(1, contentMode: .fill)
                                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall))

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(album.title)
                                                    .font(.system(size: 14, weight: .semibold))
                                                    .foregroundStyle(Theme.textPrimary)
                                                    .lineLimit(1)

                                                HStack(spacing: 4) {
                                                    if let year = album.year {
                                                        Text("\(year)")
                                                    }
                                                    Text("\u{2022} \(album.trackCountDisplay)")
                                                }
                                                .font(.system(size: 12))
                                                .foregroundStyle(Theme.textSecondary)
                                            }
                                        }
                                    }
                                    .buttonStyle(PressableButtonStyle())
                                }
                            }
                            .padding(.horizontal)
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
        ArtistView(artist: .preview)
            .environmentObject(APIClient())
            .environmentObject(AudioPlayer())
    }
    .preferredColorScheme(.dark)
}
