import SwiftUI

struct AlbumView: View {
    let album: MusicAlbum
    @ObservedObject var viewModel: MusicViewModel

    @State private var artImage: NSImage?
    @State private var dominantColor: Color = Color(white: 0.15)

    private let goldAccent = Color(red: 0.85, green: 0.65, blue: 0.13)

    var body: some View {
        ZStack(alignment: .top) {
            // Gradient background derived from album art
            VStack(spacing: 0) {
                LinearGradient(
                    colors: [dominantColor.opacity(0.6), Color(white: 0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 320)

                Color(white: 0.1)
            }
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Album header
                    headerSection

                    // Action buttons
                    actionButtons

                    // Track list
                    trackListSection
                }
            }
        }
        .task { loadAlbumArt() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .bottom, spacing: 24) {
            // Album art
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(white: 0.15))
                    .frame(width: 240, height: 240)

                if let image = artImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 240, height: 240)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "music.note")
                            .font(.system(size: 48))
                            .foregroundColor(.gray.opacity(0.4))
                    }
                }
            }
            .shadow(color: .black.opacity(0.5), radius: 24, y: 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("Album")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .textCase(.uppercase)

                Text(album.name)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .lineLimit(2)

                // Artist name (tappable)
                Button(action: {
                    if let artist = viewModel.artists.first(where: { $0.name == album.artist }) {
                        viewModel.selectedAlbum = nil
                        viewModel.selectedArtist = artist
                    }
                }) {
                    Text(album.artist)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)

                // Metadata row
                HStack(spacing: 12) {
                    if let year = album.year {
                        Text(String(year))
                            .foregroundColor(.gray)
                    }

                    if let genre = album.genre {
                        Text(genre)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 2)
                            .background(Color.white.opacity(0.1))
                            .cornerRadius(4)
                            .foregroundColor(.white.opacity(0.7))
                    }

                    Text("\(album.trackCount) track\(album.trackCount == 1 ? "" : "s")")
                        .foregroundColor(.gray)

                    Text(album.durationFormatted)
                        .foregroundColor(.gray)
                }
                .font(.system(size: 13))
            }

            Spacer()
        }
        .padding(24)
        .padding(.top, 8)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.playAlbum(album) }) {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill")
                        .font(.system(size: 13))
                    Text("Play All")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.white)
                .cornerRadius(20)
            }
            .buttonStyle(.plain)

            Button(action: { shuffleAlbum() }) {
                HStack(spacing: 6) {
                    Image(systemName: "shuffle")
                        .font(.system(size: 13))
                    Text("Shuffle")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.8))
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.1))
                .cornerRadius(20)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    // MARK: - Track List

    private var trackListSection: some View {
        VStack(spacing: 0) {
            TrackListHeader(showAlbum: false)
                .padding(.horizontal, 12)

            let sortedTracks = album.tracks.sorted {
                if $0.discNumber != $1.discNumber {
                    return $0.discNumber < $1.discNumber
                }
                return $0.trackNumber < $1.trackNumber
            }

            // Group by disc if multi-disc
            let discs = Set(sortedTracks.map(\.discNumber))

            if discs.count > 1 {
                ForEach(discs.sorted(), id: \.self) { disc in
                    Text("Disc \(disc)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.gray)
                        .textCase(.uppercase)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                        .padding(.bottom, 4)

                    let discTracks = sortedTracks.filter { $0.discNumber == disc }
                    ForEach(Array(discTracks.enumerated()), id: \.element.id) { index, track in
                        TrackRow(
                            track: track,
                            index: track.trackNumber > 0 ? track.trackNumber : index + 1,
                            isCurrentlyPlaying: viewModel.nowPlaying.currentTrack?.id == track.id,
                            showAlbum: false,
                            onPlay: { viewModel.playAlbum(album, startingAt: album.tracks.firstIndex(where: { $0.id == track.id }) ?? 0) },
                            onAddToQueue: { viewModel.addToQueue(track) },
                            onToggleFavorite: { viewModel.toggleFavorite(track) },
                            onGoToArtist: {
                                if let artist = viewModel.artists.first(where: { $0.name == track.artist }) {
                                    viewModel.selectedAlbum = nil
                                    viewModel.selectedArtist = artist
                                }
                            },
                            onGoToAlbum: {},
                            playlists: viewModel.playlists,
                            onAddToPlaylist: { playlistId in viewModel.addToPlaylist(playlistId, track: track) }
                        )
                        .padding(.horizontal, 12)
                    }
                }
            } else {
                ForEach(Array(sortedTracks.enumerated()), id: \.element.id) { index, track in
                    TrackRow(
                        track: track,
                        index: track.trackNumber > 0 ? track.trackNumber : index + 1,
                        isCurrentlyPlaying: viewModel.nowPlaying.currentTrack?.id == track.id,
                        showAlbum: false,
                        onPlay: { viewModel.playAlbum(album, startingAt: index) },
                        onAddToQueue: { viewModel.addToQueue(track) },
                        onToggleFavorite: { viewModel.toggleFavorite(track) },
                        onGoToArtist: {
                            if let artist = viewModel.artists.first(where: { $0.name == track.artist }) {
                                viewModel.selectedAlbum = nil
                                viewModel.selectedArtist = artist
                            }
                        },
                        onGoToAlbum: {},
                        playlists: viewModel.playlists,
                        onAddToPlaylist: { playlistId in viewModel.addToPlaylist(playlistId, track: track) }
                    )
                    .padding(.horizontal, 12)
                }
            }
        }
        .padding(.bottom, 32)
    }

    // MARK: - Helpers

    private func loadAlbumArt() {
        guard let path = album.artPath else { return }
        guard let image = NSImage(contentsOfFile: path) else { return }
        artImage = image
        dominantColor = extractDominantColor(from: image)
    }

    private func extractDominantColor(from image: NSImage) -> Color {
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return Color(white: 0.15)
        }

        // Sample center pixel area for a rough dominant color
        let sampleX = bitmap.pixelsWide / 2
        let sampleY = bitmap.pixelsHigh / 3
        guard let color = bitmap.colorAt(x: sampleX, y: sampleY) else {
            return Color(white: 0.15)
        }

        return Color(nsColor: color)
    }

    private func shuffleAlbum() {
        var tracks = album.tracks
        tracks.shuffle()
        viewModel.playTracks(tracks)
    }
}
