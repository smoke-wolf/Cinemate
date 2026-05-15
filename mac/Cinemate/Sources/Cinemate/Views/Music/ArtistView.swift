import SwiftUI

struct ArtistView: View {
    let artist: MusicArtist
    @ObservedObject var viewModel: MusicViewModel

    @State private var showAllTracks = false

    private let goldAccent = Color(red: 0.85, green: 0.65, blue: 0.13)

    private let albumColumns = [
        GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 20)
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Artist header
                headerSection

                // Stats bar
                statsSection

                Divider()
                    .background(Color.gray.opacity(0.2))
                    .padding(.horizontal, 24)

                // Discography (albums sorted by year)
                discographySection

                // All Tracks expandable
                allTracksSection
            }
        }
        .background(Color(white: 0.1))
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 20) {
            // Artist avatar
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color(white: 0.2), Color(white: 0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 120, height: 120)

                if let artPath = artist.albums.first?.artPath,
                   let image = NSImage(contentsOfFile: artPath) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    Image(systemName: "music.mic")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            .shadow(color: .black.opacity(0.3), radius: 12)

            VStack(alignment: .leading, spacing: 8) {
                Text("Artist")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .textCase(.uppercase)

                Text(artist.name)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                HStack(spacing: 16) {
                    Button(action: { playAllTracks() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12))
                            Text("Play All")
                                .font(.system(size: 13, weight: .semibold))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.white)
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)

                    Button(action: { shuffleAllTracks() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "shuffle")
                                .font(.system(size: 12))
                            Text("Shuffle")
                                .font(.system(size: 13, weight: .medium))
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(20)
                    }
                    .buttonStyle(.plain)
                }
            }

            Spacer()
        }
        .padding(24)
    }

    // MARK: - Stats

    private var statsSection: some View {
        HStack(spacing: 32) {
            statItem(value: "\(artist.trackCount)", label: "Tracks")
            statItem(value: "\(artist.albumCount)", label: "Albums")
            statItem(value: artist.durationFormatted, label: "Total Duration")
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    private func statItem(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.gray)
        }
    }

    // MARK: - Discography

    private var discographySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Discography")
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.top, 24)

            let sortedAlbums = artist.albums.sorted { ($0.year ?? 0) > ($1.year ?? 0) }

            LazyVGrid(columns: albumColumns, spacing: 20) {
                ForEach(sortedAlbums) { album in
                    VStack(alignment: .leading, spacing: 8) {
                        AlbumCard(
                            album: album,
                            onTap: {
                                viewModel.selectedArtist = nil
                                viewModel.selectedAlbum = album
                            },
                            onPlay: { viewModel.playAlbum(album) }
                        )

                        if let year = album.year {
                            Text(String(year))
                                .font(.system(size: 11))
                                .foregroundColor(.gray.opacity(0.6))
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - All Tracks

    private var allTracksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showAllTracks.toggle()
                }
            }) {
                HStack {
                    Text("All Tracks")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)

                    Text("(\(artist.trackCount))")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)

                    Spacer()

                    Image(systemName: showAllTracks ? "chevron.up" : "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showAllTracks {
                VStack(spacing: 0) {
                    TrackListHeader(showAlbum: true)
                        .padding(.horizontal, 12)

                    let allTracks = artist.albums
                        .flatMap(\.tracks)
                        .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }

                    ForEach(Array(allTracks.enumerated()), id: \.element.id) { index, track in
                        TrackRow(
                            track: track,
                            index: index + 1,
                            isCurrentlyPlaying: viewModel.nowPlaying.currentTrack?.id == track.id,
                            showAlbum: true,
                            onPlay: { viewModel.playTracks(allTracks, startingAt: index) },
                            onAddToQueue: { viewModel.addToQueue(track) },
                            onToggleFavorite: { viewModel.toggleFavorite(track) },
                            onGoToArtist: {},
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
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Actions

    private func playAllTracks() {
        let allTracks = artist.albums.flatMap(\.tracks)
        viewModel.playTracks(allTracks)
    }

    private func shuffleAllTracks() {
        var allTracks = artist.albums.flatMap(\.tracks)
        allTracks.shuffle()
        viewModel.playTracks(allTracks)
    }
}
