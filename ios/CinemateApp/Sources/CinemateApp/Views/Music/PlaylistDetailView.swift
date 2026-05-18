import SwiftUI

struct PlaylistDetailView: View {
    @EnvironmentObject var apiClient: APIClient
    @EnvironmentObject var audioPlayer: AudioPlayer
    @ObservedObject var downloadManager = DownloadManager.shared
    let playlist: Playlist
    let account: Account

    @State private var tracks: [MusicTrack] = []
    @State private var isLoading = true
    @State private var playlistName: String = ""
    @State private var playlistDescription: String = ""
    @State private var showEditSheet = false

    // Toast
    @State private var showToast = false
    @State private var toastIcon = ""
    @State private var toastMessage = ""

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 20) {
                    // Playlist header
                    VStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(
                                    LinearGradient(
                                        colors: [Theme.primaryGold.opacity(0.3), Theme.cardSurface],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 180, height: 180)

                            Image(systemName: "music.note.list")
                                .font(.system(size: 56))
                                .foregroundStyle(Theme.primaryGold.opacity(0.6))
                        }
                        .padding(.top, 20)

                        Text(playlistName)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)

                        if !playlistDescription.isEmpty {
                            Text(playlistDescription)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textSecondary)
                        }

                        Text("\(tracks.count) tracks")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textTertiary)
                    }

                    // Action buttons
                    if !tracks.isEmpty {
                        HStack(spacing: 12) {
                            // Play All
                            Button(action: {
                                hapticImpact(.medium)
                                audioPlayer.playTrack(tracks[0], from: apiClient.baseURL, queue: tracks)
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "play.fill")
                                        .font(.system(size: 14))
                                    Text("Play All")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundStyle(.black)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Theme.goldGradient)
                                .clipShape(Capsule())
                            }

                            // Download All
                            Button(action: {
                                hapticImpact(.medium)
                                downloadAllTracks()
                            }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 14))
                                    Text("Download All")
                                        .font(.system(size: 15, weight: .semibold))
                                }
                                .foregroundStyle(Theme.textPrimary)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 12)
                                .background(Theme.elevatedSurface)
                                .clipShape(Capsule())
                            }
                        }
                    }

                    // Track list
                    if isLoading {
                        ProgressView()
                            .tint(Theme.primaryGold)
                            .padding(.top, 20)
                    } else if tracks.isEmpty {
                        VStack(spacing: 8) {
                            Text("No tracks in this playlist")
                                .font(.system(size: 15))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        .padding(.top, 20)
                    } else {
                        LazyVStack(spacing: 2) {
                            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                                TrackRow(track: track) {
                                    audioPlayer.playTrack(track, from: apiClient.baseURL, queue: tracks)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                    Button(role: .destructive) {
                                        removeTrack(track)
                                    } label: {
                                        Label("Remove", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.bottom, 140)
            }
        }
        .navigationTitle(playlistName)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    hapticImpact(.medium)
                    showEditSheet = true
                } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(Theme.primaryGold)
                }
            }
        }
        .sheet(isPresented: $showEditSheet) {
            EditPlaylistSheet(
                name: playlistName,
                description: playlistDescription,
                onSave: { newName, newDescription in
                    Task { await savePlaylist(name: newName, description: newDescription) }
                }
            )
        }
        .toast(isPresented: $showToast, icon: toastIcon, message: toastMessage, edge: .top)
        .task {
            playlistName = playlist.name
            playlistDescription = playlist.description ?? ""
            await loadTracks()
        }
    }

    // MARK: - Actions

    private func loadTracks() async {
        isLoading = true
        defer { isLoading = false }
        let accountId = Int(account.id) ?? 0
        do {
            let detail = try await apiClient.getPlaylistDetail(accountId: accountId, playlistId: playlist.id)
            tracks = detail.tracks
        } catch {
            tracks = []
        }
    }

    private func savePlaylist(name: String, description: String) async {
        let accountId = Int(account.id) ?? 0
        let desc = description.isEmpty ? nil : description
        do {
            let updated = try await apiClient.updatePlaylist(
                accountId: accountId,
                playlistId: playlist.id,
                name: name,
                description: desc
            )
            playlistName = updated.name
            playlistDescription = updated.description ?? ""
            showFeedback(icon: "checkmark.circle", message: "Playlist updated")
        } catch {
            showFeedback(icon: "exclamationmark.triangle", message: "Failed to update playlist")
        }
    }

    private func downloadAllTracks() {
        for track in tracks {
            downloadManager.enqueueDownload(
                contentType: .musicTrack,
                contentId: track.id,
                title: track.title,
                subtitle: track.artist,
                thumbnailPath: track.albumId.map { "/api/music/art/\($0)" },
                fileSize: 0,
                downloadPath: "/api/music/stream/\(track.id)"
            )
        }
        showFeedback(icon: "arrow.down.circle", message: "Downloading \(tracks.count) tracks")
    }

    private func removeTrack(_ track: MusicTrack) {
        hapticImpact(.medium)
        let accountId = Int(account.id) ?? 0
        Task {
            do {
                try await apiClient.removeTrackFromPlaylist(
                    accountId: accountId,
                    playlistId: playlist.id,
                    trackId: track.id
                )
                withAnimation {
                    tracks.removeAll { $0.id == track.id }
                }
                showFeedback(icon: "trash", message: "Removed \(track.title)")
            } catch {
                showFeedback(icon: "exclamationmark.triangle", message: "Failed to remove track")
            }
        }
    }

    private func showFeedback(icon: String, message: String) {
        toastIcon = icon
        toastMessage = message
        withAnimation { showToast = true }
    }
}

// MARK: - Edit Playlist Sheet

private struct EditPlaylistSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var name: String
    @State var description: String
    let onSave: (String, String) -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Name")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                        TextField("Playlist name", text: $name)
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.textPrimary)
                            .padding(12)
                            .background(Theme.cardSurface)
                            .cornerRadius(10)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.textSecondary)
                        TextField("Optional description", text: $description, axis: .vertical)
                            .font(.system(size: 16))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(3...6)
                            .padding(12)
                            .background(Theme.cardSurface)
                            .cornerRadius(10)
                    }

                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("Edit Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundStyle(Theme.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        hapticImpact(.medium)
                        onSave(name, description)
                        dismiss()
                    }
                    .foregroundStyle(Theme.primaryGold)
                    .fontWeight(.semibold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}
