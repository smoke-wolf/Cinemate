import SwiftUI

struct MusicView: View {
    @ObservedObject var viewModel: MusicViewModel
    @FocusState private var isSearchFocused: Bool

    private let goldAccent = Color(red: 0.85, green: 0.65, blue: 0.13)

    private let cardColumns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Sub-navigation bar
            subNavBar

            Divider().background(Color.gray.opacity(0.2))

            // Content area
            ZStack {
                if let artist = viewModel.selectedArtist {
                    VStack(spacing: 0) {
                        detailBackBar(title: artist.name) {
                            viewModel.selectedArtist = nil
                        }
                        ArtistView(artist: artist, viewModel: viewModel)
                    }
                } else if let album = viewModel.selectedAlbum {
                    VStack(spacing: 0) {
                        detailBackBar(title: album.name) {
                            viewModel.selectedAlbum = nil
                        }
                        AlbumView(album: album, viewModel: viewModel)
                    }
                } else if let playlistIndex = viewModel.playlists.firstIndex(where: { $0.id == viewModel.selectedPlaylist?.id }) {
                    VStack(spacing: 0) {
                        detailBackBar(title: viewModel.playlists[playlistIndex].name) {
                            viewModel.selectedPlaylist = nil
                        }
                        PlaylistView(playlist: $viewModel.playlists[playlistIndex], viewModel: viewModel)
                    }
                } else if viewModel.isLoading && viewModel.tracks.isEmpty {
                    VStack(spacing: 16) {
                        ProgressView()
                            .controlSize(.large)
                            .tint(goldAccent)
                        Text(viewModel.scanProgress.isEmpty ? "Loading music..." : viewModel.scanProgress)
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                    }
                } else if viewModel.tracks.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "music.note.house")
                            .font(.system(size: 56))
                            .foregroundColor(.gray.opacity(0.3))
                        Text("No music found")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.7))
                        Text("Add a folder to start listening")
                            .font(.system(size: 14))
                            .foregroundColor(.gray)
                        Button(action: pickMusicFolder) {
                            HStack(spacing: 8) {
                                Image(systemName: "folder.badge.plus")
                                Text("Choose Folder")
                            }
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 10)
                            .background(goldAccent)
                            .cornerRadius(20)
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    switch viewModel.currentSubTab {
                    case .browse:
                        browseContent
                    case .artists:
                        artistsGrid
                    case .albums:
                        albumsGrid
                    case .playlists:
                        playlistsGrid
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Now playing bar
            NowPlayingBar(viewModel: viewModel)
                .animation(.easeInOut(duration: 0.3), value: viewModel.nowPlaying.currentTrack != nil)
        }
        .background(Color(white: 0.1))
        .onAppear {
            viewModel.loadLibrary()
            installKeyboardMonitor()
        }
        .onDisappear {
            removeKeyboardMonitor()
        }
    }

    // MARK: - Keyboard Shortcuts

    @State private var keyMonitor: Any?

    private func installKeyboardMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [self] event in
            // Don't intercept when the search field is focused (let it handle text input)
            if isSearchFocused {
                // Only intercept Escape to defocus search
                if event.keyCode == 53 { // Escape
                    isSearchFocused = false
                    return nil
                }
                return event
            }

            let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Cmd+F — focus search
            if flags == .command && event.charactersIgnoringModifiers == "f" {
                isSearchFocused = true
                return nil
            }

            // Cmd+Up — volume up
            if flags == .command && event.keyCode == 126 { // up arrow
                viewModel.volumeUp()
                return nil
            }

            // Cmd+Down — volume down
            if flags == .command && event.keyCode == 125 { // down arrow
                viewModel.volumeDown()
                return nil
            }

            // No modifiers required for the following
            guard flags.isEmpty || flags == .function else { return event }

            switch event.keyCode {
            case 49: // Space — toggle play/pause
                viewModel.togglePlayPause()
                return nil
            case 124: // Right arrow — next track
                viewModel.next()
                return nil
            case 123: // Left arrow — previous track
                viewModel.previous()
                return nil
            case 53: // Escape — go back from detail view
                if viewModel.isInDetailView {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.navigateBack()
                    }
                    return nil
                }
                return event
            default:
                return event
            }
        }
    }

    private func removeKeyboardMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    private func pickMusicFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose your music folder"
        panel.prompt = "Scan"
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.scanMusicDirectory(url.path)
        }
    }

    // MARK: - Sub-Navigation Bar

    private var subNavBar: some View {
        HStack(spacing: 0) {
            ForEach(MusicSubTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.currentSubTab = tab
                    }
                }) {
                    Text(tab.rawValue)
                        .font(.system(size: 13, weight: viewModel.currentSubTab == tab ? .semibold : .regular))
                        .foregroundColor(viewModel.currentSubTab == tab ? .white : .gray)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            viewModel.currentSubTab == tab
                                ? Color.white.opacity(0.1)
                                : Color.clear
                        )
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
            }

            Spacer()

            if viewModel.isScanning {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text(viewModel.scanProgress)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .padding(.trailing, 8)
            }

            Button(action: pickMusicFolder) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .help("Add music folder")
            .padding(.trailing, 8)

            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

                TextField("Search music...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .frame(width: 180)
                    .focused($isSearchFocused)

                if !viewModel.searchQuery.isEmpty {
                    Button(action: { viewModel.searchQuery = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(Color(white: 0.08))
    }

    // MARK: - Browse Content

    private var browseContent: some View {
        Group {
            if !viewModel.searchQuery.isEmpty {
                // Search results as a track list
                searchResultsView
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Library stats header
                        libraryStatsHeader

                        // Recently Played row
                        if !viewModel.recentlyPlayed.isEmpty {
                            musicRow(
                                title: "Recently Played",
                                albums: albumsFromTracks(viewModel.recentlyPlayed)
                            )
                        }

                        // Favorites row
                        if !viewModel.favoriteTracks.isEmpty {
                            musicRow(
                                title: "Favorites",
                                albums: albumsFromTracks(viewModel.favoriteTracks)
                            )
                        }

                        // Recently Added row
                        if !viewModel.recentlyAddedTracks.isEmpty {
                            recentlyAddedSection
                        }

                        // Genre rows
                        ForEach(viewModel.genreAlbums, id: \.genre) { row in
                            musicRow(title: row.genre, albums: row.albums)
                        }

                        // Albums (skip if only "Unknown Album")
                        let realAlbums = viewModel.albums.filter { $0.name != "Unknown Album" }
                        if !realAlbums.isEmpty {
                            musicRow(title: "Albums", albums: realAlbums)
                        }

                        // All Tracks list
                        allTracksSection
                    }
                    .padding(.vertical, 24)
                }
            }
        }
    }

    private var searchResultsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text("Results for \"\(viewModel.searchQuery)\"")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 12)

                TrackListHeader()
                    .padding(.horizontal, 12)

                ForEach(Array(viewModel.filteredTracks.enumerated()), id: \.element.id) { index, track in
                    TrackRow(
                        track: track,
                        index: index + 1,
                        isCurrentlyPlaying: viewModel.nowPlaying.currentTrack?.id == track.id,
                        onPlay: { viewModel.playTracks(viewModel.filteredTracks, startingAt: index) },
                        onAddToQueue: { viewModel.addToQueue(track) },
                        onToggleFavorite: { viewModel.toggleFavorite(track) },
                        onGoToArtist: {
                            if let artist = viewModel.artists.first(where: { $0.name == track.artist }) {
                                viewModel.selectedAlbum = nil
                                viewModel.selectedArtist = artist
                            }
                        },
                        onGoToAlbum: {
                            let key = "\(track.artist):::\(track.album)"
                            if let album = viewModel.albums.first(where: { $0.id == key }) {
                                viewModel.selectedArtist = nil
                                viewModel.selectedAlbum = album
                            }
                        },
                        playlists: viewModel.playlists,
                        onAddToPlaylist: { playlistId in viewModel.addToPlaylist(playlistId, track: track) }
                    )
                    .padding(.horizontal, 12)
                }
            }
            .padding(.bottom, 24)
        }
    }

    // MARK: - All Tracks Section

    private var allTracksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("All Tracks")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)

            // Sort pill bar
            trackSortBar
                .padding(.horizontal, 24)

            TrackListHeader()
                .padding(.horizontal, 12)

            let sorted = viewModel.sortedTracks

            ForEach(Array(sorted.enumerated()), id: \.element.id) { index, track in
                TrackRow(
                    track: track,
                    index: index + 1,
                    isCurrentlyPlaying: viewModel.nowPlaying.currentTrack?.id == track.id,
                    onPlay: { viewModel.playTracks(sorted, startingAt: index) },
                    onAddToQueue: { viewModel.addToQueue(track) },
                    onToggleFavorite: { viewModel.toggleFavorite(track) },
                    onGoToArtist: {
                        if let artist = viewModel.artists.first(where: { $0.name == track.artist }) {
                            viewModel.selectedAlbum = nil
                            viewModel.selectedArtist = artist
                        }
                    },
                    onGoToAlbum: {
                        let key = "\(track.artist):::\(track.album)"
                        if let album = viewModel.albums.first(where: { $0.id == key }) {
                            viewModel.selectedArtist = nil
                            viewModel.selectedAlbum = album
                        }
                    },
                    playlists: viewModel.playlists,
                    onAddToPlaylist: { playlistId in viewModel.addToPlaylist(playlistId, track: track) }
                )
                .padding(.horizontal, 12)
            }
        }
    }

    // MARK: - Sort Pill Bars

    private var trackSortBar: some View {
        HStack(spacing: 8) {
            ForEach(TrackSortOption.allCases, id: \.self) { option in
                Button(action: {
                    if viewModel.trackSortOption == option {
                        viewModel.trackSortAscending.toggle()
                    } else {
                        viewModel.trackSortOption = option
                        viewModel.trackSortAscending = true
                    }
                }) {
                    Text(option.rawValue)
                        .font(.system(size: 11, weight: viewModel.trackSortOption == option ? .semibold : .regular))
                        .foregroundColor(viewModel.trackSortOption == option ? .black : .gray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            viewModel.trackSortOption == option
                                ? goldAccent
                                : Color.white.opacity(0.08)
                        )
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }

            Button(action: {
                viewModel.trackSortAscending.toggle()
            }) {
                Image(systemName: viewModel.trackSortAscending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .help(viewModel.trackSortAscending ? "Sort descending" : "Sort ascending")

            Spacer()
        }
    }

    private var artistSortBar: some View {
        HStack(spacing: 8) {
            ForEach(ArtistSortOption.allCases, id: \.self) { option in
                Button(action: {
                    if viewModel.artistSortOption == option {
                        viewModel.artistSortAscending.toggle()
                    } else {
                        viewModel.artistSortOption = option
                        viewModel.artistSortAscending = true
                    }
                }) {
                    Text(option.rawValue)
                        .font(.system(size: 11, weight: viewModel.artistSortOption == option ? .semibold : .regular))
                        .foregroundColor(viewModel.artistSortOption == option ? .black : .gray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            viewModel.artistSortOption == option
                                ? goldAccent
                                : Color.white.opacity(0.08)
                        )
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }

            Button(action: {
                viewModel.artistSortAscending.toggle()
            }) {
                Image(systemName: viewModel.artistSortAscending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .help(viewModel.artistSortAscending ? "Sort descending" : "Sort ascending")

            Spacer()
        }
    }

    private var albumSortBar: some View {
        HStack(spacing: 8) {
            ForEach(AlbumSortOption.allCases, id: \.self) { option in
                Button(action: {
                    if viewModel.albumSortOption == option {
                        viewModel.albumSortAscending.toggle()
                    } else {
                        viewModel.albumSortOption = option
                        viewModel.albumSortAscending = true
                    }
                }) {
                    Text(option.rawValue)
                        .font(.system(size: 11, weight: viewModel.albumSortOption == option ? .semibold : .regular))
                        .foregroundColor(viewModel.albumSortOption == option ? .black : .gray)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            viewModel.albumSortOption == option
                                ? goldAccent
                                : Color.white.opacity(0.08)
                        )
                        .cornerRadius(12)
                }
                .buttonStyle(.plain)
            }

            Button(action: {
                viewModel.albumSortAscending.toggle()
            }) {
                Image(systemName: viewModel.albumSortAscending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                    .frame(width: 24, height: 24)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .help(viewModel.albumSortAscending ? "Sort descending" : "Sort ascending")

            Spacer()
        }
    }

    // MARK: - Recently Added Section

    private var recentlyAddedSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Added")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(albumsFromTracks(viewModel.recentlyAddedTracks)) { album in
                        AlbumCard(
                            album: album,
                            onTap: { viewModel.selectedAlbum = album },
                            onPlay: { viewModel.playAlbum(album) }
                        )
                        .frame(width: 160)
                    }
                }
                .padding(.horizontal, 24)
            }
            .frame(height: 220)
        }
    }

    // MARK: - Library Stats Header

    private var libraryStatsHeader: some View {
        HStack(spacing: 32) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Your Library")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)

                let totalDuration = viewModel.tracks.reduce(0) { $0 + $1.duration }
                let hours = Int(totalDuration) / 3600
                let minutes = (Int(totalDuration) % 3600) / 60

                Text("\(viewModel.tracks.count) tracks \u{2022} \(viewModel.albums.count) albums \u{2022} \(viewModel.artists.count) artists \u{2022} \(hours)h \(minutes)m")
                    .font(.system(size: 14))
                    .foregroundColor(.gray)
            }

            Spacer()

            Button(action: {
                viewModel.playTracks(viewModel.tracks.shuffled())
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 13))
                    Text("Shuffle All")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(goldAccent)
                .cornerRadius(20)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
    }

    // MARK: - Music Row (horizontal scroll of cards)

    private func musicRow(title: String, albums: [MusicAlbum]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(albums) { album in
                        AlbumCard(
                            album: album,
                            onTap: { viewModel.selectedAlbum = album },
                            onPlay: { viewModel.playAlbum(album) }
                        )
                        .frame(width: 160)
                    }
                }
                .padding(.horizontal, 24)
            }
            .frame(height: 220)
        }
    }

    // MARK: - Artists Grid

    private var artistsGrid: some View {
        Group {
            if viewModel.artists.isEmpty {
                emptyState(icon: "music.mic", message: "No artists found")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        artistSortBar
                            .padding(.horizontal, 24)
                            .padding(.top, 24)

                        LazyVGrid(columns: cardColumns, spacing: 24) {
                            ForEach(viewModel.sortedArtists) { artist in
                                artistGridItem(artist)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
    }

    private func artistGridItem(_ artist: MusicArtist) -> some View {
        VStack(spacing: 10) {
            // Artist circle avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.2), Color(white: 0.13)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .aspectRatio(1, contentMode: .fit)

                // If first album has art, show it in circle
                if let artPath = artist.albums.first?.artPath,
                   let image = NSImage(contentsOfFile: artPath) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "music.mic")
                        .font(.system(size: 28))
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            .clipShape(Circle())

            Text(artist.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)

            Text("\(artist.albumCount) album\(artist.albumCount == 1 ? "" : "s")")
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
        .contentShape(Rectangle())
        .onTapGesture { viewModel.selectedArtist = artist }
    }

    // MARK: - Albums Grid

    private var albumsGrid: some View {
        Group {
            if viewModel.albums.isEmpty {
                emptyState(icon: "square.stack", message: "No albums found")
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        albumSortBar
                            .padding(.horizontal, 24)
                            .padding(.top, 24)

                        LazyVGrid(columns: cardColumns, spacing: 24) {
                            ForEach(viewModel.sortedAlbums) { album in
                                AlbumCard(
                                    album: album,
                                    onTap: { viewModel.selectedAlbum = album },
                                    onPlay: { viewModel.playAlbum(album) }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
    }

    // MARK: - Playlists Grid

    private var playlistsGrid: some View {
        Group {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("Playlists")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: {
                        viewModel.createPlaylist(name: "New Playlist")
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 12))
                            Text("New Playlist")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 24)
                .padding(.top, 24)
                .padding(.bottom, 16)

                if viewModel.playlists.isEmpty {
                    emptyState(icon: "music.note.list", message: "No playlists yet")
                } else {
                    ScrollView {
                        LazyVGrid(columns: cardColumns, spacing: 24) {
                            ForEach(viewModel.playlists) { playlist in
                                PlaylistCard(
                                    playlist: playlist,
                                    onTap: { viewModel.selectedPlaylist = playlist },
                                    onPlay: { viewModel.playTracks(playlist.tracks) }
                                )
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
    }

    // MARK: - Empty State

    private func emptyState(icon: String, message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.gray.opacity(0.4))
            Text(message)
                .font(.system(size: 16))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Detail Navigation

    private func detailBackBar(title: String, onBack: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { onBack() } }) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(goldAccent)
            }
            .buttonStyle(.plain)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray)
                .lineLimit(1)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(Color(white: 0.08))
    }

    // MARK: - Helpers

    private func albumsFromTracks(_ tracks: [MusicTrack]) -> [MusicAlbum] {
        var seen = Set<String>()
        var result: [MusicAlbum] = []
        for track in tracks {
            let key = "\(track.artist):::\(track.album)"
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            if let album = viewModel.albums.first(where: { $0.id == key }) {
                result.append(album)
            }
        }
        return result
    }
}
