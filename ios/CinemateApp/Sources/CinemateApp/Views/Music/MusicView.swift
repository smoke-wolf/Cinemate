import SwiftUI

struct MusicView: View {
    @EnvironmentObject var apiClient: APIClient
    @EnvironmentObject var audioPlayer: AudioPlayer
    let account: Account

    @State private var selectedTab: MusicTab = .recents
    @State private var albums: [MusicAlbum] = []
    @State private var artists: [MusicArtist] = []
    @State private var recentTracks: [MusicTrack] = []
    @State private var playlists: [Playlist] = []
    @State private var isLoading = false
    @State private var isLoadingMoreAlbums = false
    @State private var isLoadingMoreArtists = false
    @State private var hasMoreAlbums = true
    @State private var hasMoreArtists = true
    private let pageSize = 40

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
                    if isLoading && albums.isEmpty && artists.isEmpty && recentTracks.isEmpty {
                        musicSkeletonView
                    } else {
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
                .onChange(of: selectedTab) { _, newTab in
                    if newTab == .playlists {
                        Task {
                            let accountId = Int(account.id) ?? 0
                            playlists = (try? await apiClient.getPlaylists(accountId: accountId)) ?? []
                        }
                    }
                }
            }
            .navigationTitle("Music")
            .cinemateToolbarBackground(Theme.background)
            .cinemateToolbarColorScheme(.dark)
        }
        .task {
            let accountId = Int(account.id) ?? 0
            audioPlayer.onTrackPlayed = { track in
                Task {
                    try? await apiClient.logPlay(accountId: accountId, trackId: track.id, duration: track.duration)
                }
            }
            await loadData()
        }
    }

    private var recentsContent: some View {
        Group {
            if !isLoading && recentTracks.isEmpty {
                musicEmptyState
            } else {
                LazyVStack(spacing: 2) {
                    ForEach(recentTracks) { track in
                        TrackRow(track: track, showTrackNumber: false, onTap: {
                            audioPlayer.playTrack(track, from: apiClient.baseURL, queue: recentTracks)
                        })
                    }
                }
                .padding(.bottom, 140)
            }
        }
    }

    private var artistsContent: some View {
        Group {
            if !isLoading && artists.isEmpty {
                musicEmptyState
            } else {
                artistsList
            }
        }
    }

    private var artistsList: some View {
        VStack(spacing: 0) {
            LazyVStack(spacing: 8) {
                ForEach(artists) { artist in
                    NavigationLink(destination: ArtistView(artist: artist)) {
                        HStack(spacing: 14) {
                            CachedAsyncImage(url: apiClient.artistImageURL(name: artist.name)) {
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
                            }
                            .frame(width: 52, height: 52)
                            .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 3) {
                                Text(artist.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(Theme.textPrimary)
                                Text("\(artist.albumCount) albums \u{2022} \(artist.trackCount) tracks")
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
                    .onAppear {
                        if artist.id == artists.last?.id && hasMoreArtists && !isLoadingMoreArtists {
                            Task { await loadMoreArtists() }
                        }
                    }
                }
            }

            if isLoadingMoreArtists {
                ProgressView()
                    .tint(Theme.primaryGold)
                    .padding(.vertical, 20)
            }

            Spacer().frame(height: 140)
        }
    }

    private var albumsContent: some View {
        let columns = [
            GridItem(.flexible(), spacing: 14),
            GridItem(.flexible(), spacing: 14),
        ]

        return Group {
            if !isLoading && albums.isEmpty {
                musicEmptyState
            } else {
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
                                    Text(album.artist)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(1)
                                }
                            }
                        }
                        .buttonStyle(PressableButtonStyle())
                        .onAppear {
                            if album.id == albums.last?.id && hasMoreAlbums && !isLoadingMoreAlbums {
                                Task { await loadMoreAlbums() }
                            }
                        }
                    }
                }
                .padding(.horizontal)

                if isLoadingMoreAlbums {
                    ProgressView()
                        .tint(Theme.primaryGold)
                        .padding(.vertical, 20)
                }

                Spacer().frame(height: 140)
            }
        }
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
                    NavigationLink(destination: PlaylistDetailView(playlist: playlist, account: account)) {
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
        }
        .padding(.bottom, 140)
    }

    private var musicEmptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note")
                .font(.system(size: 40))
                .foregroundStyle(Theme.textTertiary)
            Text("No music yet")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.textSecondary)
            Text("Your music library will appear here")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var musicSkeletonView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 4) {
                ForEach(0..<8, id: \.self) { _ in
                    ShimmerRow()
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                }
            }
        }
    }

    private func loadData() async {
        isLoading = true
        defer { isLoading = false }
        let accountId = Int(account.id) ?? 0
        async let a = apiClient.getAlbums(limit: pageSize, offset: 0)
        async let b = apiClient.getArtists(limit: pageSize, offset: 0)
        async let c = try? apiClient.getRecentTracks(accountId: accountId)
        async let d = try? apiClient.getPlaylists(accountId: accountId)
        do {
            let albumResponse = try await a
            albums = albumResponse.items
            hasMoreAlbums = albums.count < albumResponse.total
        } catch {}
        do {
            let artistResponse = try await b
            artists = artistResponse.items
            hasMoreArtists = artists.count < artistResponse.total
        } catch {}
        recentTracks = await c ?? []
        playlists = await d ?? []
    }

    private func loadMoreAlbums() async {
        guard hasMoreAlbums, !isLoadingMoreAlbums else { return }
        isLoadingMoreAlbums = true
        defer { isLoadingMoreAlbums = false }
        do {
            let response = try await apiClient.getAlbums(limit: pageSize, offset: albums.count)
            albums.append(contentsOf: response.items)
            hasMoreAlbums = albums.count < response.total
        } catch {}
    }

    private func loadMoreArtists() async {
        guard hasMoreArtists, !isLoadingMoreArtists else { return }
        isLoadingMoreArtists = true
        defer { isLoadingMoreArtists = false }
        do {
            let response = try await apiClient.getArtists(limit: pageSize, offset: artists.count)
            artists.append(contentsOf: response.items)
            hasMoreArtists = artists.count < response.total
        } catch {}
    }
}

#Preview {
    MusicView(account: Account.previewAccounts[0])
        .environmentObject(APIClient())
        .environmentObject(AudioPlayer())
        .preferredColorScheme(.dark)
}
