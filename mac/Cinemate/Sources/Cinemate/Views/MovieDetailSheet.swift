import SwiftUI
import AVKit

struct MovieDetailSheet: View {
    let movie: MediaItem
    let onPlay: () -> Void
    let onFavorite: () -> Void
    let onToggleWatched: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var previewPlayer: AVPlayer?
    @State private var isMuted = true

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                // Fixed video preview at top
                ZStack(alignment: .bottomLeading) {
                    if let player = previewPlayer {
                        AVPlayerViewLite(player: player)
                    } else {
                        Color(white: 0.08)
                            .overlay {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                    }

                    LinearGradient(
                        colors: [.clear, Color(white: 0.06)],
                        startPoint: .center,
                        endPoint: .bottom
                    )
                    .frame(height: 100)

                    VStack(alignment: .leading, spacing: 4) {
                        if movie.mediaType == .tvEpisode {
                            Text(movie.showName ?? "")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.orange)
                        }
                        Text(movie.mediaType == .tvEpisode ? movie.episodeLabel : movie.title)
                            .font(.system(size: 28, weight: .bold))
                            .foregroundColor(.white)
                            .shadow(color: .black.opacity(0.8), radius: 4)
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)

                    HStack {
                        Spacer()
                        Button(action: {
                            isMuted.toggle()
                            previewPlayer?.isMuted = isMuted
                        }) {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .padding(7)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                        .padding(.trailing, 16)
                        .padding(.bottom, 12)
                    }
                }
                .frame(height: 380)
                .clipped()

                // Scrollable info section below
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 14) {
                        HStack(spacing: 10) {
                            if let year = movie.year {
                                Text(String(year))
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            if let genre = movie.genre, !genre.isEmpty {
                                Text(genre)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.1))
                                    .cornerRadius(4)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            if let rating = movie.rating {
                                HStack(spacing: 3) {
                                    Text("🍅")
                                        .font(.system(size: 12))
                                    Text("\(rating)%")
                                        .foregroundColor(rating >= 60 ? .green : .gray)
                                        .fontWeight(.bold)
                                }
                            }
                            if !movie.durationFormatted.isEmpty {
                                Text(movie.durationFormatted)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            if let q = movie.quality {
                                Text(q)
                                    .font(.system(size: 11, weight: .medium))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 3)
                                            .stroke(Color.white.opacity(0.3), lineWidth: 1)
                                    )
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .font(.system(size: 13))

                        if movie.watched {
                            HStack(spacing: 4) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("Watched")
                                    .foregroundColor(.green)
                            }
                            .font(.system(size: 12, weight: .medium))
                        } else if movie.watchProgress > 0 && movie.duration > 0 {
                            VStack(alignment: .leading, spacing: 4) {
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.white.opacity(0.15))
                                            .frame(height: 4)
                                        RoundedRectangle(cornerRadius: 2)
                                            .fill(Color.red)
                                            .frame(width: geo.size.width * CGFloat(movie.watchProgress / movie.duration), height: 4)
                                    }
                                }
                                .frame(height: 4)
                                Text("\(movie.progressPercent)% watched")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                        }

                        HStack(spacing: 10) {
                            Button(action: {
                                onPlay()
                                dismiss()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "play.fill")
                                    Text(movie.watchProgress > 0 && !movie.watched ? "Resume" : "Play")
                                }
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white)
                                .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            Button(action: onToggleWatched) {
                                Image(systemName: movie.watched ? "eye.fill" : "eye")
                                    .font(.system(size: 16))
                                    .foregroundColor(movie.watched ? .green : .white)
                                    .frame(width: 44, height: 40)
                                    .background(Color.white.opacity(0.12))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)

                            Button(action: onFavorite) {
                                Image(systemName: movie.favorite ? "heart.fill" : "heart")
                                    .font(.system(size: 16))
                                    .foregroundColor(movie.favorite ? .red : .white)
                                    .frame(width: 44, height: 40)
                                    .background(Color.white.opacity(0.12))
                                    .cornerRadius(6)
                            }
                            .buttonStyle(.plain)
                        }

                        if let desc = movie.description_ {
                            Text(desc)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.8))
                                .lineSpacing(4)
                        }

                        Divider().background(Color.gray.opacity(0.2))

                        VStack(alignment: .leading, spacing: 6) {
                            DetailInfoRow(label: "Format", value: "\(movie.fileExtension) · \(movie.fileSizeFormatted)")
                            if movie.playCount > 0 {
                                DetailInfoRow(label: "Plays", value: "\(movie.playCount)")
                            }
                            if let lastPlayed = movie.lastPlayed {
                                DetailInfoRow(label: "Last Played", value: lastPlayed.formatted(date: .abbreviated, time: .shortened))
                            }
                            DetailInfoRow(label: "Added", value: movie.dateAdded.formatted(date: .abbreviated, time: .omitted))
                            if !movie.totalWatchTimeFormatted.isEmpty {
                                DetailInfoRow(label: "Watch Time", value: movie.totalWatchTimeFormatted)
                            }
                        }
                    }
                    .padding(24)
                }
            }

            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .frame(width: 860, height: 720)
        .background(Color(white: 0.06))
        .onAppear { startPreview() }
        .onDisappear {
            previewPlayer?.pause()
            previewPlayer = nil
        }
    }

    private func startPreview() {
        let player = AVPlayer(url: URL(fileURLWithPath: movie.filePath))
        player.isMuted = true
        let startTime: Double
        if movie.watchProgress > 0 && !movie.watched {
            startTime = max(0, movie.watchProgress - 5)
        } else {
            startTime = max(movie.duration * 0.1, 30)
        }
        player.seek(to: CMTime(seconds: startTime, preferredTimescale: 600))
        player.play()

        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { _ in
            player.seek(to: CMTime(seconds: startTime, preferredTimescale: 600))
            player.play()
        }

        self.previewPlayer = player
    }
}

struct AVPlayerViewLite: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = player
        view.controlsStyle = .none
        view.videoGravity = .resizeAspectFill
        return view
    }

    func updateNSView(_ nsView: AVPlayerView, context: Context) {}
}

struct DetailInfoRow: View {
    let label: String
    let value: String
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.gray)
                .frame(width: 90, alignment: .leading)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.9))
        }
    }
}
