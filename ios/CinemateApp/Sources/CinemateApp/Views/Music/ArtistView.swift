import SwiftUI

struct ArtistView: View {
    @EnvironmentObject var apiClient: APIClient
    @EnvironmentObject var audioPlayer: AudioPlayer
    let artist: MusicArtist

    @State private var profile: ArtistProfile?
    @State private var albums: [MusicAlbum] = []
    @State private var bioExpanded = false

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
                        // Avatar — Spotify image, server artist image, or placeholder
                        CachedAsyncImage(url: artistImageURL) {
                            artistPlaceholder
                        }
                        .frame(width: 140, height: 140)
                        .clipShape(Circle())
                        .shadow(color: .black.opacity(0.5), radius: 20, x: 0, y: 10)

                        Text(artist.name)
                            .font(.system(size: 26, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)

                        // Stats row
                        HStack(spacing: 12) {
                            Label("\(profile?.albumCount ?? artist.albumCount) Albums", systemImage: "square.stack")
                            Text("\u{2022}")
                            Label("\(profile?.trackCount ?? artist.trackCount) Tracks", systemImage: "music.note")
                            if let followers = profile?.formattedFollowers {
                                Text("\u{2022}")
                                Label(followers, systemImage: "person.2")
                            }
                        }
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)

                        // Popularity bar
                        if let popularity = profile?.popularity, popularity > 0 {
                            VStack(spacing: 4) {
                                GoldProgressBar(progress: Double(popularity) / 100.0, height: 3)
                                Text("Popularity: \(popularity)/100")
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            .frame(maxWidth: 200)
                        }
                    }
                    .padding(.top, 20)

                    // Genre tags
                    if let genres = profile?.genres, !genres.isEmpty {
                        FlowLayout(spacing: 8) {
                            ForEach(genres, id: \.self) { genre in
                                Text(genre)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Theme.primaryGold)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Theme.primaryGold.opacity(0.12))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Bio
                    if let bio = profile?.bio, !bio.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)

                            Text(bio)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(bioExpanded ? nil : 4)
                                .animation(.easeInOut, value: bioExpanded)

                            if bio.count > 200 {
                                Button(action: { bioExpanded.toggle() }) {
                                    Text(bioExpanded ? "Show Less" : "Read More")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Theme.primaryGold)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Albums Grid
                    if !albums.isEmpty {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("Albums")
                                .font(.system(size: 20, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)
                                .padding(.horizontal)

                            LazyVGrid(columns: columns, spacing: 18) {
                                ForEach(albums) { album in
                                    NavigationLink(destination: AlbumView(album: album)) {
                                        VStack(alignment: .leading, spacing: 8) {
                                            CachedAsyncImage(url: apiClient.albumArtURL(albumId: album.id)) {
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
                                                        Text(String(year))
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
        .task {
            async let profileTask: () = loadProfile()
            async let albumsTask: () = loadAlbums()
            _ = await (profileTask, albumsTask)
        }
    }

    /// Best available artist image URL: prefer Spotify image_url from the
    /// enriched profile, fall back to the server's artist image endpoint which
    /// serves album art or a downloaded Spotify image.
    private var artistImageURL: URL? {
        if let imageURL = profile?.imageURL, let url = URL(string: imageURL) {
            return url
        }
        return apiClient.artistImageURL(name: artist.name)
    }

    private var artistPlaceholder: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: [Theme.cardSurface, Theme.elevatedSurface, Theme.cardSurface],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .frame(width: 140, height: 140)
            .overlay {
                Image(systemName: "music.mic")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.textTertiary)
            }
            .shadow(color: .black.opacity(0.4), radius: 16, x: 0, y: 8)
    }

    private func loadProfile() async {
        do {
            profile = try await apiClient.getArtistProfile(name: artist.name)
        } catch {}
    }

    private func loadAlbums() async {
        do {
            let allAlbums = try await apiClient.getAlbums()
            albums = allAlbums.filter { $0.artist.localizedCaseInsensitiveCompare(artist.name) == .orderedSame }
        } catch {}
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
