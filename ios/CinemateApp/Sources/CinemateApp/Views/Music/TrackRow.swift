import SwiftUI

struct TrackRow: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var apiClient: APIClient
    @Environment(\.accountId) private var accountId
    let track: MusicTrack
    let onTap: () -> Void
    var onGoToArtist: ((String) -> Void)? = nil
    var onGoToAlbum: ((Int) -> Void)? = nil

    @State private var isFavorite: Bool = false
    @State private var showPlaylistPicker = false
    @State private var showDownloadStarted = false

    private var isCurrentTrack: Bool {
        audioPlayer.currentTrack?.id == track.id
    }

    var body: some View {
        Button(action: {
            hapticImpact(.light)
            onTap()
        }) {
            HStack(spacing: 14) {
                ZStack {
                    if isCurrentTrack {
                        NowPlayingIndicator(isAnimating: audioPlayer.isPlaying)
                            .frame(width: 24, height: 16)
                    } else if let num = track.trackNumber {
                        Text("\(num)")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(width: 24)

                CachedAsyncImage(url: track.albumId.flatMap { apiClient.albumArtURL(albumId: $0) }) {
                    AlbumArtPlaceholder(size: 44)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                VStack(alignment: .leading, spacing: 3) {
                    Text(track.title)
                        .font(.system(size: 15, weight: isCurrentTrack ? .bold : .medium))
                        .foregroundStyle(isCurrentTrack ? Theme.primaryGold : Theme.textPrimary)
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(track.formattedDuration)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)

                if isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.primaryGold)
                }

                Menu {
                    Button(action: {
                        isFavorite.toggle()
                        hapticImpact(.medium)
                        Task {
                            try? await apiClient.toggleMusicFavorite(accountId: accountId, trackId: track.id)
                        }
                    }) {
                        Label(isFavorite ? "Unfavorite" : "Favorite",
                              systemImage: isFavorite ? "heart.slash" : "heart")
                    }

                    Button(action: { showPlaylistPicker = true }) {
                        Label("Add to Playlist", systemImage: "text.badge.plus")
                    }

                    Button(action: downloadTrack) {
                        Label("Download", systemImage: "arrow.down.circle")
                    }

                    Divider()

                    if let onGoToArtist {
                        Button(action: { onGoToArtist(track.artist) }) {
                            Label("Go to Artist", systemImage: "music.mic")
                        }
                    }

                    if let albumId = track.albumId, let onGoToAlbum {
                        Button(action: { onGoToAlbum(albumId) }) {
                            Label("Go to Album", systemImage: "square.stack")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textTertiary)
                        .frame(width: 24, height: 24)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(isCurrentTrack ? Theme.primaryGold.opacity(0.06) : Color.clear)
        }
        .buttonStyle(.plain)
        .onAppear { isFavorite = track.isFavorite }
        .sheet(isPresented: $showPlaylistPicker) {
            PlaylistPickerSheet(trackId: track.id)
        }
        .overlay(alignment: .top) {
            if showDownloadStarted {
                Text("Download started")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Theme.primaryGold.opacity(0.9))
                    .clipShape(Capsule())
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .offset(y: -4)
            }
        }
    }

    private func downloadTrack() {
        hapticImpact(.medium)
        DownloadManager.shared.enqueueDownload(
            contentType: .musicTrack,
            contentId: track.id,
            title: track.title,
            subtitle: track.artist,
            thumbnailPath: track.artworkURL,
            fileSize: 0,
            downloadPath: "/api/music/stream/\(track.id)"
        )
        withAnimation { showDownloadStarted = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation { showDownloadStarted = false }
        }
    }
}

struct PlaylistPickerSheet: View {
    @EnvironmentObject var apiClient: APIClient
    @Environment(\.dismiss) var dismiss
    @Environment(\.accountId) private var accountId
    let trackId: Int

    @State private var playlists: [Playlist] = []
    @State private var isLoading = true
    @State private var showNewPlaylist = false
    @State private var newName = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                if isLoading {
                    ProgressView()
                        .tint(Theme.primaryGold)
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            // Create new row
                            Button(action: { showNewPlaylist = true }) {
                                HStack(spacing: 14) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Theme.primaryGold.opacity(0.15))
                                            .frame(width: 48, height: 48)
                                        Image(systemName: "plus")
                                            .font(.system(size: 20, weight: .semibold))
                                            .foregroundStyle(Theme.primaryGold)
                                    }
                                    Text("New Playlist")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(Theme.primaryGold)
                                    Spacer()
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 10)
                            }

                            if playlists.isEmpty {
                                VStack(spacing: 8) {
                                    Text("No playlists yet")
                                        .font(.system(size: 15, weight: .medium))
                                        .foregroundStyle(Theme.textSecondary)
                                    Text("Create one to get started")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.textTertiary)
                                }
                                .padding(.top, 32)
                            } else {
                                ForEach(playlists) { playlist in
                                    Button(action: { addToPlaylist(playlist.id) }) {
                                        HStack(spacing: 14) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8)
                                                    .fill(Theme.cardSurface)
                                                    .frame(width: 48, height: 48)
                                                Image(systemName: "music.note.list")
                                                    .font(.system(size: 18))
                                                    .foregroundStyle(Theme.textTertiary)
                                            }
                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(playlist.name)
                                                    .font(.system(size: 15, weight: .medium))
                                                    .foregroundStyle(Theme.textPrimary)
                                                Text(playlist.trackCountDisplay)
                                                    .font(.system(size: 12))
                                                    .foregroundStyle(Theme.textSecondary)
                                            }
                                            Spacer()
                                            Image(systemName: "plus.circle")
                                                .font(.system(size: 18))
                                                .foregroundStyle(Theme.textTertiary)
                                        }
                                        .padding(.horizontal)
                                        .padding(.vertical, 10)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Add to Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Theme.textSecondary)
                }
            }
            .alert("New Playlist", isPresented: $showNewPlaylist) {
                TextField("Playlist name", text: $newName)
                Button("Cancel", role: .cancel) { newName = "" }
                Button("Create") { createAndAdd() }
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
            } message: {
                Text("Enter a name for your new playlist.")
            }
        }
        .presentationDetents([.medium])
        .task { await loadPlaylists() }
    }

    private func loadPlaylists() async {
        isLoading = true
        defer { isLoading = false }
        playlists = (try? await apiClient.getPlaylists(accountId: accountId)) ?? []
    }

    private func addToPlaylist(_ playlistId: Int) {
        Task {
            try? await apiClient.addTrackToPlaylist(accountId: accountId, playlistId: playlistId, trackId: trackId)
            hapticImpact(.medium)
            dismiss()
        }
    }

    private func createAndAdd() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        Task {
            do {
                let playlist = try await apiClient.createPlaylist(accountId: accountId, name: name)
                try await apiClient.addTrackToPlaylist(accountId: accountId, playlistId: playlist.id, trackId: trackId)
                hapticImpact(.medium)
                dismiss()
            } catch {
                await loadPlaylists()
            }
        }
        newName = ""
    }
}

struct NowPlayingIndicator: View {
    let isAnimating: Bool

    @State private var heights: [CGFloat] = [4, 8, 6]

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<3, id: \.self) { index in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Theme.primaryGold)
                    .frame(width: 3, height: heights[index])
            }
        }
        .onAppear {
            if isAnimating {
                startAnimating()
            }
        }
        .onChange(of: isAnimating) { _, newValue in
            if newValue {
                startAnimating()
            } else {
                heights = [4, 8, 6]
            }
        }
    }

    private func startAnimating() {
        withAnimation(
            .easeInOut(duration: 0.4)
            .repeatForever(autoreverses: true)
        ) {
            heights = [12, 6, 14]
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack(spacing: 0) {
            ForEach(MusicTrack.previewList) { track in
                TrackRow(track: track, onTap: {})
            }
        }
    }
    .environmentObject(AudioPlayer())
}
