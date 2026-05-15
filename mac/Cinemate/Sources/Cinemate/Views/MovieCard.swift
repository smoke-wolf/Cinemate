import SwiftUI
import AVKit

struct MovieCard: View {
    let movie: Movie
    let onTap: () -> Void
    let onPlay: () -> Void
    let onFavorite: () -> Void

    @State private var isHovered = false
    @State private var thumbnailImage: NSImage?
    @State private var previewPlayer: AVPlayer?
    @State private var showPreview = false
    @State private var hoverTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomLeading) {
                Color(white: 0.15)
                    .aspectRatio(16.0/9.0, contentMode: .fit)
                    .overlay {
                        if showPreview, let player = previewPlayer {
                            AVPlayerViewLite(player: player)
                                .transition(.opacity)
                        } else if let image = thumbnailImage {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .layoutPriority(-1)
                        } else {
                            VStack(spacing: 8) {
                                Image(systemName: "film")
                                    .font(.system(size: 28))
                                    .foregroundColor(.gray.opacity(0.5))
                                Text(movie.fileExtension)
                                    .font(.caption2)
                                    .foregroundColor(.gray.opacity(0.5))
                            }
                        }
                    }
                    .overlay {
                        if isHovered {
                            Color.black.opacity(0.45)
                            VStack(spacing: 10) {
                                Button(action: onPlay) {
                                    Image(systemName: "play.circle.fill")
                                        .font(.system(size: 40))
                                        .foregroundColor(.white)
                                }
                                .buttonStyle(.plain)

                                HStack(spacing: 14) {
                                    Button(action: onFavorite) {
                                        Image(systemName: movie.favorite ? "heart.fill" : "heart")
                                            .font(.system(size: 16))
                                            .foregroundColor(movie.favorite ? .red : .white)
                                    }
                                    .buttonStyle(.plain)

                                    if !movie.durationFormatted.isEmpty {
                                        Text(movie.durationFormatted)
                                            .font(.system(size: 11))
                                            .foregroundColor(.white.opacity(0.7))
                                    }
                                    if let q = movie.quality {
                                        Text(q)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                }
                            }
                        }
                    }
                    .overlay(alignment: .topTrailing) {
                        HStack(spacing: 4) {
                            if let rating = movie.rating {
                                HStack(spacing: 2) {
                                    Text("🍅")
                                        .font(.system(size: 10))
                                    Text("\(rating)%")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(rating >= 60 ? .red : .gray)
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(.black.opacity(0.7))
                                .cornerRadius(4)
                            }
                            if movie.watched {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundColor(.green)
                                    .shadow(radius: 2)
                            }
                        }
                        .padding(6)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                if movie.watchProgress > 0 && !movie.watched && movie.duration > 0 {
                    GeometryReader { geo in
                        VStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.orange)
                                .frame(width: geo.size.width * CGFloat(movie.watchProgress / movie.duration), height: 3)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
                if hovering {
                    hoverTask?.cancel()
                    hoverTask = Task {
                        try? await Task.sleep(nanoseconds: 1_500_000_000)
                        guard !Task.isCancelled else { return }
                        let url = URL(fileURLWithPath: movie.filePath)
                        let asset = AVURLAsset(url: url)
                        let totalSeconds: Double
                        if let dur = try? await asset.load(.duration) {
                            totalSeconds = CMTimeGetSeconds(dur)
                        } else {
                            totalSeconds = 0
                        }
                        let seekTime = totalSeconds > 0 ? totalSeconds * 0.1 : 30.0
                        guard !Task.isCancelled else { return }
                        let player = AVPlayer(playerItem: AVPlayerItem(asset: asset))
                        player.isMuted = true
                        await player.seek(to: CMTime(seconds: seekTime, preferredTimescale: 600))
                        guard !Task.isCancelled else { return }
                        player.play()
                        withAnimation(.easeIn(duration: 0.3)) { showPreview = true }
                        previewPlayer = player
                        // Auto-stop after 60 seconds
                        try? await Task.sleep(nanoseconds: 60_000_000_000)
                        guard !Task.isCancelled else { return }
                        player.pause()
                    }
                } else {
                    hoverTask?.cancel()
                    hoverTask = nil
                    withAnimation(.easeOut(duration: 0.2)) { showPreview = false }
                    previewPlayer?.pause()
                    previewPlayer = nil
                }
            }
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovered)

            Text(movie.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                if let year = movie.year {
                    Text(String(year))
                        .foregroundColor(.gray)
                }
                if let genre = movie.genre, !genre.isEmpty {
                    Text(genre)
                        .foregroundColor(.gray.opacity(0.7))
                }
                if !movie.durationFormatted.isEmpty {
                    Text(movie.durationFormatted)
                        .foregroundColor(.gray.opacity(0.7))
                }
                if let q = movie.quality {
                    Text(q)
                        .foregroundColor(.gray.opacity(0.5))
                }
            }
            .font(.system(size: 11))
        }
        .task { await loadThumbnail() }
    }

    private func loadThumbnail() async {
        if let path = movie.thumbnailPath, FileManager.default.fileExists(atPath: path) {
            thumbnailImage = NSImage(contentsOfFile: path)
            return
        }
        if let path = await ThumbnailGenerator.generate(for: movie) {
            thumbnailImage = NSImage(contentsOfFile: path)
        }
    }
}
