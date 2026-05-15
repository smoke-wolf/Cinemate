import SwiftUI
import UniformTypeIdentifiers

struct PlaylistView: View {
    @Binding var playlist: Playlist
    @ObservedObject var viewModel: MusicViewModel

    @State private var isEditingName = false
    @State private var editedName: String = ""
    @State private var isEditingDescription = false
    @State private var editedDescription: String = ""
    @State private var showAddTracksSheet = false
    @State private var showDeleteConfirmation = false
    @State private var addTrackSearchQuery = ""
    @State private var isCoverHovered = false
    @State private var coverImage: NSImage?

    private let goldAccent = Color(red: 0.85, green: 0.65, blue: 0.13)

    private static let coverDirectory: String = {
        let path = NSString(string: "~/.cinemate/playlist_covers").expandingTildeInPath
        try? FileManager.default.createDirectory(atPath: path, withIntermediateDirectories: true)
        return path
    }()

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Playlist header
                    headerSection

                    // Action buttons
                    actionButtons

                    Divider()
                        .background(Color.gray.opacity(0.2))
                        .padding(.horizontal, 24)

                    // Track list
                    trackListSection
                }
            }
        }
        .background(Color(white: 0.1))
        .sheet(isPresented: $showAddTracksSheet) {
            addTracksSheet
        }
        .alert("Delete Playlist", isPresented: $showDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                viewModel.deletePlaylist(playlist.id)
            }
        } message: {
            Text("Are you sure you want to delete \"\(playlist.name)\"? This cannot be undone.")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(alignment: .bottom, spacing: 24) {
            // Playlist cover — custom image or auto collage
            ZStack(alignment: .topTrailing) {
                Group {
                    if let image = coverImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 200, height: 200)
                            .clipped()
                    } else {
                        PlaylistCoverCollage(tracks: playlist.tracks)
                            .frame(width: 200, height: 200)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay {
                    if isCoverHovered {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.5))
                            .overlay {
                                Image(systemName: coverImage != nil ? "pencil" : "camera.fill")
                                    .font(.system(size: 24, weight: .medium))
                                    .foregroundColor(goldAccent)
                            }
                            .transition(.opacity)
                    }
                }
                .onTapGesture { pickCoverImage() }
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isCoverHovered = hovering
                    }
                }

                // Remove cover button
                if coverImage != nil && isCoverHovered {
                    Button(action: { removeCoverImage() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .symbolRenderingMode(.palette)
                            .foregroundStyle(.white, Color(white: 0.2))
                    }
                    .buttonStyle(.plain)
                    .offset(x: 6, y: -6)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .shadow(color: .black.opacity(0.4), radius: 16, y: 4)
            .task { loadCoverImage() }

            VStack(alignment: .leading, spacing: 8) {
                Text("Playlist")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .textCase(.uppercase)

                // Editable name
                if isEditingName {
                    TextField("Playlist name", text: $editedName, onCommit: {
                        playlist.name = editedName
                        isEditingName = false
                        viewModel.savePlaylistEdits()
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 28, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                } else {
                    Text(playlist.name)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.white)
                        .onTapGesture {
                            editedName = playlist.name
                            isEditingName = true
                        }
                }

                // Editable description
                if isEditingDescription {
                    TextField("Add a description...", text: $editedDescription, onCommit: {
                        let trimmed = editedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
                        playlist.description = trimmed.isEmpty ? nil : trimmed
                        isEditingDescription = false
                        viewModel.savePlaylistEdits()
                    })
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                } else if let description = playlist.description, !description.isEmpty {
                    Text(description)
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                        .lineLimit(2)
                        .onTapGesture {
                            editedDescription = description
                            isEditingDescription = true
                        }
                } else {
                    Text("Add description...")
                        .font(.system(size: 13))
                        .foregroundColor(.gray.opacity(0.5))
                        .italic()
                        .onTapGesture {
                            editedDescription = ""
                            isEditingDescription = true
                        }
                }

                HStack(spacing: 12) {
                    Text("\(playlist.trackCount) track\(playlist.trackCount == 1 ? "" : "s")")
                        .foregroundColor(.gray)

                    Text(playlist.durationFormatted)
                        .foregroundColor(.gray)

                    Text("Created \(playlist.createdAt.formatted(date: .abbreviated, time: .omitted))")
                        .foregroundColor(.gray.opacity(0.6))
                }
                .font(.system(size: 13))
            }

            Spacer()
        }
        .padding(24)
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button(action: { viewModel.playTracks(playlist.tracks) }) {
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

            Button(action: {
                var tracks = playlist.tracks
                tracks.shuffle()
                viewModel.playTracks(tracks)
            }) {
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

            Button(action: { showAddTracksSheet = true }) {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 13))
                    Text("Add Tracks")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white.opacity(0.7))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08))
                .cornerRadius(20)
            }
            .buttonStyle(.plain)

            Spacer()

            Button(action: { showDeleteConfirmation = true }) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundColor(.red.opacity(0.7))
                    .padding(10)
                    .background(Color.red.opacity(0.06))
                    .cornerRadius(8)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 20)
    }

    // MARK: - Track List

    private var trackListSection: some View {
        VStack(spacing: 0) {
            if playlist.tracks.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "music.note")
                        .font(.system(size: 40))
                        .foregroundColor(.gray.opacity(0.3))
                    Text("This playlist is empty")
                        .font(.system(size: 15))
                        .foregroundColor(.gray)
                    Button(action: { showAddTracksSheet = true }) {
                        Text("Add Tracks")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(goldAccent)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 60)
            } else {
                TrackListHeader()
                    .padding(.horizontal, 12)
                    .padding(.top, 16)

                ForEach(Array(playlist.tracks.enumerated()), id: \.element.id) { index, track in
                    HStack(spacing: 0) {
                        TrackRow(
                            track: track,
                            index: index + 1,
                            isCurrentlyPlaying: viewModel.nowPlaying.currentTrack?.id == track.id,
                            onPlay: { viewModel.playTracks(playlist.tracks, startingAt: index) },
                            onAddToQueue: { viewModel.addToQueue(track) },
                            onToggleFavorite: { viewModel.toggleFavorite(track) },
                            onGoToArtist: {
                                if let artist = viewModel.artists.first(where: { $0.name == track.artist }) {
                                    viewModel.selectedPlaylist = nil
                                    viewModel.selectedAlbum = nil
                                    viewModel.selectedArtist = artist
                                }
                            },
                            onGoToAlbum: {
                                let key = "\(track.artist):::\(track.album)"
                                if let album = viewModel.albums.first(where: { $0.id == key }) {
                                    viewModel.selectedPlaylist = nil
                                    viewModel.selectedArtist = nil
                                    viewModel.selectedAlbum = album
                                }
                            },
                            playlists: viewModel.playlists,
                            onAddToPlaylist: { playlistId in viewModel.addToPlaylist(playlistId, track: track) }
                        )

                        // Remove from playlist button on hover
                        Button(action: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                viewModel.removeFromPlaylist(playlist.id, trackId: track.id)
                                playlist.tracks.removeAll { $0.id == track.id }
                                playlist.trackCount = playlist.tracks.count
                                playlist.totalDuration = playlist.tracks.reduce(0) { $0 + $1.duration }
                            }
                        }) {
                            Image(systemName: "minus.circle")
                                .font(.system(size: 12))
                                .foregroundColor(.red.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 12)
                    }
                    .padding(.horizontal, 12)
                }
                .padding(.bottom, 24)
            }
        }
    }

    // MARK: - Add Tracks Sheet

    private var addTracksSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Add Tracks")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)

                Spacer()

                Button(action: { showAddTracksSheet = false }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(.white)
                        .padding(8)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(20)

            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                TextField("Search tracks...", text: $addTrackSearchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)
            .padding(.horizontal, 20)

            Divider()
                .background(Color.gray.opacity(0.2))
                .padding(.top, 12)

            // Filtered tracks
            let filtered = addTrackSearchQuery.isEmpty
                ? viewModel.tracks
                : viewModel.tracks.filter {
                    $0.title.lowercased().contains(addTrackSearchQuery.lowercased()) ||
                    $0.artist.lowercased().contains(addTrackSearchQuery.lowercased())
                }

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filtered) { track in
                        let alreadyAdded = playlist.tracks.contains(where: { $0.id == track.id })

                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.white)
                                    .lineLimit(1)
                                Text("\(track.artist) - \(track.album)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.gray)
                                    .lineLimit(1)
                            }

                            Spacer()

                            Text(track.durationFormatted)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.gray)

                            Button(action: {
                                if !alreadyAdded {
                                    viewModel.addToPlaylist(playlist.id, track: track)
                                    playlist.tracks.append(track)
                                    playlist.trackCount = playlist.tracks.count
                                    playlist.totalDuration = playlist.tracks.reduce(0) { $0 + $1.duration }
                                }
                            }) {
                                Image(systemName: alreadyAdded ? "checkmark.circle.fill" : "plus.circle")
                                    .font(.system(size: 18))
                                    .foregroundColor(alreadyAdded ? .green : goldAccent)
                            }
                            .buttonStyle(.plain)
                            .disabled(alreadyAdded)
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                    }
                }
            }
        }
        .frame(width: 500, height: 600)
        .background(Color(white: 0.08))
    }

    // MARK: - Cover Image Helpers

    private func loadCoverImage() {
        guard let path = playlist.coverImagePath,
              FileManager.default.fileExists(atPath: path),
              let image = NSImage(contentsOfFile: path) else {
            coverImage = nil
            return
        }
        coverImage = image
    }

    private func pickCoverImage() {
        let panel = NSOpenPanel()
        panel.title = "Choose Cover Image"
        panel.allowedContentTypes = [.jpeg, .png]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let sourceURL = panel.url else { return }

        let fileExtension = sourceURL.pathExtension.lowercased()
        let destPath = "\(Self.coverDirectory)/\(playlist.id).\(fileExtension)"
        let destURL = URL(fileURLWithPath: destPath)

        // Remove any existing cover file with a different extension
        removeExistingCoverFiles()

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
            playlist.coverImagePath = destPath
            coverImage = NSImage(contentsOfFile: destPath)
            viewModel.savePlaylistEdits()
        } catch {
            print("Failed to copy cover image: \(error)")
        }
    }

    private func removeCoverImage() {
        removeExistingCoverFiles()
        playlist.coverImagePath = nil
        withAnimation(.easeInOut(duration: 0.2)) {
            coverImage = nil
        }
        viewModel.savePlaylistEdits()
    }

    private func removeExistingCoverFiles() {
        let fm = FileManager.default
        for ext in ["jpg", "jpeg", "png"] {
            let path = "\(Self.coverDirectory)/\(playlist.id).\(ext)"
            if fm.fileExists(atPath: path) {
                try? fm.removeItem(atPath: path)
            }
        }
    }
}
