import SwiftUI

struct TrackRow: View {
    let track: MusicTrack
    let index: Int?
    let isCurrentlyPlaying: Bool
    let showAlbum: Bool
    let onPlay: () -> Void
    let onAddToQueue: () -> Void
    let onToggleFavorite: () -> Void
    let onGoToArtist: () -> Void
    let onGoToAlbum: () -> Void
    let playlists: [Playlist]
    let onAddToPlaylist: (String) -> Void

    @State private var isHovered = false
    @State private var artistHovered = false
    @State private var albumHovered = false

    private let goldAccent = Color(red: 0.85, green: 0.65, blue: 0.13)

    init(
        track: MusicTrack,
        index: Int? = nil,
        isCurrentlyPlaying: Bool = false,
        showAlbum: Bool = true,
        onPlay: @escaping () -> Void,
        onAddToQueue: @escaping () -> Void = {},
        onToggleFavorite: @escaping () -> Void = {},
        onGoToArtist: @escaping () -> Void = {},
        onGoToAlbum: @escaping () -> Void = {},
        playlists: [Playlist] = [],
        onAddToPlaylist: @escaping (String) -> Void = { _ in }
    ) {
        self.track = track
        self.index = index
        self.isCurrentlyPlaying = isCurrentlyPlaying
        self.showAlbum = showAlbum
        self.onPlay = onPlay
        self.onAddToQueue = onAddToQueue
        self.onToggleFavorite = onToggleFavorite
        self.onGoToArtist = onGoToArtist
        self.onGoToAlbum = onGoToAlbum
        self.playlists = playlists
        self.onAddToPlaylist = onAddToPlaylist
    }

    var body: some View {
        HStack(spacing: 0) {
            // Track number / play button / now playing indicator
            ZStack {
                if isCurrentlyPlaying {
                    NowPlayingBars()
                        .frame(width: 14, height: 14)
                } else if isHovered {
                    Button(action: onPlay) {
                        Image(systemName: "play.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.white)
                    }
                    .buttonStyle(.plain)
                } else if let index = index {
                    Text("\(index)")
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(isCurrentlyPlaying ? goldAccent : .gray)
                }
            }
            .frame(width: 36, alignment: .center)

            // Title + explicit badge
            HStack(spacing: 6) {
                Text(track.title)
                    .font(.system(size: 14, weight: isCurrentlyPlaying ? .semibold : .regular))
                    .foregroundColor(isCurrentlyPlaying ? goldAccent : .white)
                    .lineLimit(1)

                if track.isExplicit {
                    Text("E")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(Color.gray.opacity(0.25))
                        .cornerRadius(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Artist (clickable)
            Button(action: onGoToArtist) {
                Text(track.artist)
                    .font(.system(size: 13))
                    .foregroundColor(artistHovered ? .white : .gray)
                    .underline(artistHovered)
                    .lineLimit(1)
            }
            .buttonStyle(.plain)
            .onHover { hovering in artistHovered = hovering }
            .frame(width: 160, alignment: .leading)

            // Album (optional, clickable)
            if showAlbum {
                Button(action: onGoToAlbum) {
                    Text(track.album)
                        .font(.system(size: 13))
                        .foregroundColor(albumHovered ? .white : .gray.opacity(0.7))
                        .underline(albumHovered)
                        .lineLimit(1)
                }
                .buttonStyle(.plain)
                .onHover { hovering in albumHovered = hovering }
                .frame(width: 160, alignment: .leading)
            }

            // Hover actions
            if isHovered {
                HStack(spacing: 8) {
                    Button(action: onToggleFavorite) {
                        Image(systemName: track.favorite ? "heart.fill" : "heart")
                            .font(.system(size: 12))
                            .foregroundColor(track.favorite ? .red : .gray)
                    }
                    .buttonStyle(.plain)

                    Button(action: onAddToQueue) {
                        Image(systemName: "text.badge.plus")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: 56, alignment: .trailing)
            } else {
                // Favorite indicator (always visible when favorited, not hovered)
                if track.favorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.red.opacity(0.6))
                        .frame(width: 56, alignment: .trailing)
                } else {
                    Spacer()
                        .frame(width: 56)
                }
            }

            // Duration
            Text(track.durationFormatted)
                .font(.system(size: 13, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 50, alignment: .trailing)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.white.opacity(0.06) : Color.clear)
        )
        .contentShape(Rectangle())
        .onTapGesture(count: 2) { onPlay() }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.1)) { isHovered = hovering }
        }
        .contextMenu {
            Button(action: onPlay) {
                Label("Play", systemImage: "play.fill")
            }

            Button(action: onAddToQueue) {
                Label("Add to Queue", systemImage: "text.badge.plus")
            }

            Divider()

            Button(action: onGoToArtist) {
                Label("Go to Artist", systemImage: "music.mic")
            }

            Button(action: onGoToAlbum) {
                Label("Go to Album", systemImage: "square.stack")
            }

            Divider()

            if !playlists.isEmpty {
                Menu {
                    ForEach(playlists) { playlist in
                        Button(action: { onAddToPlaylist(playlist.id) }) {
                            Text(playlist.name)
                        }
                    }
                } label: {
                    Label("Add to Playlist", systemImage: "music.note.list")
                }

                Divider()
            }

            Button(action: onToggleFavorite) {
                Label(
                    track.favorite ? "Remove from Favorites" : "Add to Favorites",
                    systemImage: track.favorite ? "heart.slash" : "heart"
                )
            }
        }
    }
}

// MARK: - Now Playing Animated Bars

struct NowPlayingBars: View {
    @State private var animating = false

    private let goldAccent = Color(red: 0.85, green: 0.65, blue: 0.13)

    var body: some View {
        HStack(spacing: 2) {
            bar(delay: 0.0)
            bar(delay: 0.15)
            bar(delay: 0.3)
        }
        .onAppear { animating = true }
    }

    private func bar(delay: Double) -> some View {
        RoundedRectangle(cornerRadius: 1)
            .fill(goldAccent)
            .frame(width: 3)
            .scaleEffect(y: animating ? 1.0 : 0.3, anchor: .bottom)
            .animation(
                .easeInOut(duration: 0.5)
                    .repeatForever(autoreverses: true)
                    .delay(delay),
                value: animating
            )
    }
}

// MARK: - Track List Header

struct TrackListHeader: View {
    let showAlbum: Bool

    init(showAlbum: Bool = true) {
        self.showAlbum = showAlbum
    }

    var body: some View {
        HStack(spacing: 0) {
            Text("#")
                .frame(width: 36, alignment: .center)

            Text("Title")
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("Artist")
                .frame(width: 160, alignment: .leading)

            if showAlbum {
                Text("Album")
                    .frame(width: 160, alignment: .leading)
            }

            Spacer()
                .frame(width: 56)

            Image(systemName: "clock")
                .frame(width: 50, alignment: .trailing)
        }
        .font(.system(size: 11, weight: .semibold))
        .foregroundColor(.gray.opacity(0.6))
        .textCase(.uppercase)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .padding(.bottom, 4)

        Divider()
            .background(Color.gray.opacity(0.2))
            .padding(.horizontal, 12)
    }
}
