import SwiftUI

struct MusicCard: View {
    let title: String
    let subtitle: String?
    let artPath: String?
    let onTap: () -> Void
    let onPlay: () -> Void

    @State private var isHovered = false
    @State private var artImage: NSImage?

    private let goldAccent = Color(red: 0.85, green: 0.65, blue: 0.13)

    private var placeholderColors: [Color] {
        let hash = abs((title + (subtitle ?? "")).hashValue)
        let hue1 = Double(hash % 360) / 360.0
        let hue2 = Double((hash / 360) % 360) / 360.0
        return [
            Color(hue: hue1, saturation: 0.5, brightness: 0.3),
            Color(hue: hue2, saturation: 0.6, brightness: 0.15)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let image = artImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(1, contentMode: .fill)
                } else {
                    LinearGradient(
                        colors: placeholderColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .aspectRatio(1, contentMode: .fit)
                    .overlay {
                        VStack(spacing: 6) {
                            Image(systemName: "music.note")
                                .font(.system(size: 28, weight: .light))
                                .foregroundColor(.white.opacity(0.3))
                            if let sub = subtitle {
                                Text(sub.prefix(1).uppercased())
                                    .font(.system(size: 22, weight: .bold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.2))
                            }
                        }
                    }
                }

                if isHovered {
                    Color.black.opacity(0.45)
                        .transition(.opacity)

                    Button(action: onPlay) {
                        ZStack {
                            Circle()
                                .fill(goldAccent)
                                .frame(width: 44, height: 44)
                                .shadow(color: goldAccent.opacity(0.4), radius: 8)

                            Image(systemName: "play.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.black)
                                .offset(x: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(
                color: .black.opacity(isHovered ? 0.5 : 0.2),
                radius: isHovered ? 12 : 4,
                y: isHovered ? 6 : 2
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .scaleEffect(isHovered ? 1.04 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .task { loadArt() }
    }

    private func loadArt() {
        guard let path = artPath else { return }
        if let image = NSImage(contentsOfFile: path) {
            artImage = image
        }
    }
}

// MARK: - Album Card Variant

struct AlbumCard: View {
    let album: MusicAlbum
    let onTap: () -> Void
    let onPlay: () -> Void

    var body: some View {
        MusicCard(
            title: album.name,
            subtitle: album.artist,
            artPath: album.artPath,
            onTap: onTap,
            onPlay: onPlay
        )
    }
}

// MARK: - Playlist Card Variant

struct PlaylistCard: View {
    let playlist: Playlist
    let onTap: () -> Void
    let onPlay: () -> Void

    @State private var coverImage: NSImage?
    @State private var isHovered = false

    private let goldAccent = Color(red: 0.85, green: 0.65, blue: 0.13)

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack {
                if let image = coverImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .aspectRatio(1, contentMode: .fit)
                        .clipped()
                } else {
                    PlaylistCoverCollage(tracks: playlist.tracks)
                        .aspectRatio(1, contentMode: .fit)
                }

                if isHovered {
                    Color.black.opacity(0.45)
                        .transition(.opacity)

                    Button(action: onPlay) {
                        ZStack {
                            Circle()
                                .fill(goldAccent)
                                .frame(width: 44, height: 44)
                                .shadow(color: goldAccent.opacity(0.4), radius: 8)

                            Image(systemName: "play.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.black)
                                .offset(x: 1)
                        }
                    }
                    .buttonStyle(.plain)
                    .transition(.scale.combined(with: .opacity))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .shadow(
                color: .black.opacity(isHovered ? 0.5 : 0.2),
                radius: isHovered ? 12 : 4,
                y: isHovered ? 6 : 2
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)

            Text(playlist.name)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(1)

            Text("\(playlist.trackCount) tracks")
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .lineLimit(1)
        }
        .scaleEffect(isHovered ? 1.04 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovered = hovering
            }
        }
        .task { loadCoverImage() }
    }

    private func loadCoverImage() {
        guard let path = playlist.coverImagePath,
              FileManager.default.fileExists(atPath: path),
              let image = NSImage(contentsOfFile: path) else {
            coverImage = nil
            return
        }
        coverImage = image
    }
}

// MARK: - Playlist Cover Collage

struct PlaylistCoverCollage: View {
    let tracks: [MusicTrack]

    var body: some View {
        let artPaths = uniqueArtPaths()

        GeometryReader { geo in
            let half = geo.size.width / 2

            ZStack {
                Color(white: 0.15)

                if artPaths.isEmpty {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 28))
                        .foregroundColor(.gray.opacity(0.4))
                } else {
                    VStack(spacing: 1) {
                        HStack(spacing: 1) {
                            artTile(path: artPaths[safe: 0], size: half)
                            artTile(path: artPaths[safe: 1], size: half)
                        }
                        HStack(spacing: 1) {
                            artTile(path: artPaths[safe: 2], size: half)
                            artTile(path: artPaths[safe: 3], size: half)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func artTile(path: String?, size: CGFloat) -> some View {
        if let path = path, let image = NSImage(contentsOfFile: path) {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: size, height: size)
                .clipped()
        } else {
            Color(white: 0.18)
                .frame(width: size, height: size)
                .overlay {
                    Image(systemName: "music.note")
                        .font(.system(size: 14))
                        .foregroundColor(.gray.opacity(0.3))
                }
        }
    }

    private func uniqueArtPaths() -> [String] {
        var seen = Set<String>()
        var paths: [String] = []
        for track in tracks {
            guard let path = track.albumArtPath, !seen.contains(path) else { continue }
            seen.insert(path)
            paths.append(path)
            if paths.count >= 4 { break }
        }
        return paths
    }
}

private extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
