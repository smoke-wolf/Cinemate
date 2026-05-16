import SwiftUI

struct PlaylistDetailView: View {
    @EnvironmentObject var apiClient: APIClient
    @EnvironmentObject var audioPlayer: AudioPlayer
    let playlist: Playlist
    let account: Account

    @State private var tracks: [MusicTrack] = []
    @State private var isLoading = true

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

                        Text(playlist.name)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)

                        if let desc = playlist.description, !desc.isEmpty {
                            Text(desc)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textSecondary)
                        }

                        Text("\(tracks.count) tracks")
                            .font(.system(size: 13))
                            .foregroundStyle(Theme.textTertiary)
                    }

                    // Play All button
                    if !tracks.isEmpty {
                        Button(action: {
                            audioPlayer.playTrack(tracks[0], from: apiClient.baseURL, queue: tracks)
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 14))
                                Text("Play All")
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 12)
                            .background(Theme.goldGradient)
                            .clipShape(Capsule())
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
                            }
                        }
                    }
                }
                .padding(.bottom, 140)
            }
        }
        .navigationTitle(playlist.name)
        .task {
            await loadTracks()
        }
    }

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
}
