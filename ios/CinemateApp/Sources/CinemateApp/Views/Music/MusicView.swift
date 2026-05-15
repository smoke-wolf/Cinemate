import SwiftUI

struct MusicView: View {
    @EnvironmentObject var apiClient: APIClient
    @EnvironmentObject var audioPlayer: AudioPlayer

    @State private var selectedTab: MusicTab = .recents
    @State private var albums: [MusicAlbum] = MusicAlbum.previewList
    @State private var artists: [MusicArtist] = MusicArtist.previewList
    @State private var recentTracks: [MusicTrack] = MusicTrack.previewList
    @State private var playlists: [Playlist] = []

    enum MusicTab: String, CaseIterable {
        case recents = "Recents"
        case artists = "Artists"
        case albums = "Albums"
        case playlists = "Playlists"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Sub-tabs
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(MusicTab.allCases, id: \.self) { tab in
                                Button(action: {
                                    withAnimation(Theme.quickSpring) {
                                        selectedTab = tab
                                    }
                                }) {
                                    Text(tab.rawValue)
                                        .font(.system(size: 14, weight: selectedTab == tab ? .bold : .medium))
                                        .foregroundStyle(selectedTab == tab ? .black : Theme.textSecondary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 8)
                                        .background(
                                            selectedTab == tab
                                            ? AnyShapeStyle(Theme.goldGradient)
                                            : AnyShapeStyle(Theme.cardSurface)
                                        )
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 12)
                    }

                    // Content
                    ScrollView(.vertical, showsIndicators: false) {
                        switch selectedTab {
                        case .recents:
                            recentsContent
                        case .artists:
                            artistsContent
                        case .albums:
                            albumsContent
                        case .playlists:
                            playlistsContent
                        }
                    }
                }
            }
            .navigationTitle("Music")
            .cinemateToolbarBackground(Theme.background)
            .cinemateToolbarColorScheme(.dark)
        }
        .task {
            await loadData()
        }
    }

    private var recentsContent: some View {
        LazyVStack(spacing: 2) {
            ForEach(recentTracks) { track in
                TrackRow(track: track) {
                    audioPlayer.playTrack(track, from: apiClient.baseURL, queue: recentTracks)
                }
            }
        }
        .padding(.bottom, 140)
    }

    private var artistsContent: some View {
        LazyVStack(spacing: 8) {
            ForEach(artists) { artist in
                NavigationLink(destination: ArtistView(artist: artist)) {
                    HStack(spacing: 14) {
                        // Artist avatar
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Theme.cardSurface, Theme.elevatedSurface],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 52, height: 52)
                            .overlay {
                                Image(systemName: "music.mic")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Theme.textTertiary)
                            }

                        VStack(alignment: .leading, spacing: 3) {
                            Text(artist.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text("\(artist.albums.count) albums \u{2022} \(artist.trackCount) tracks")
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 6)
                }
            }
        }
        .padding(.bottom, 140)
    }

    private var albumsContent: some View {
        let columns = [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
        ]

        return LazyVGrid(columns: columns, spacing: 18) {
            ForEach(albums) { album in
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
                            Text(album.artist)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                }
                .buttonStyle(PressableButtonStyle())
            }
        }
        .padding(.horizontal)
        .padding(.bottom, 140)
    }

    private var playlistsContent: some View {
        VStack(spacing: 16) {
            if playlists.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.textTertiary)
                    Text("No Playlists")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                    Text("Your playlists will appear here")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 60)
            } else {
                ForEach(playlists) { playlist in
                    HStack(spacing: 14) {
                        AlbumArtPlaceholder(size: 52)

                        VStack(alignment: .leading, spacing: 3) {
                            Text(playlist.name)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                            Text(playlist.trackCountDisplay)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textTertiary)
                    }
                    .padding(.horizontal)
                }
            }
        }
        .padding(.bottom, 140)
    }

    private func loadData() async {
        do {
            albums = try await apiClient.getAlbums()
            artists = try await apiClient.getArtists()
            recentTracks = try await apiClient.getRecentTracks()
            playlists = try await apiClient.getPlaylists()
        } catch {
            // Keep preview data
        }
    }
}

#Preview {
    MusicView()
        .environmentObject(APIClient())
        .environmentObject(AudioPlayer())
        .preferredColorScheme(.dark)
}
