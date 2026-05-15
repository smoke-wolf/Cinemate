import SwiftUI

struct TrackRow: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    let track: MusicTrack
    let onTap: () -> Void

    private var isCurrentTrack: Bool {
        audioPlayer.currentTrack?.id == track.id
    }

    var body: some View {
        Button(action: {
            hapticImpact(.light)
            onTap()
        }) {
            HStack(spacing: 14) {
                // Track number or playing indicator
                ZStack {
                    if isCurrentTrack {
                        // Animated bars
                        NowPlayingIndicator(isAnimating: audioPlayer.isPlaying)
                            .frame(width: 24, height: 16)
                    } else if let num = track.trackNumber {
                        Text("\(num)")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(width: 24)

                // Album art
                CachedAsyncImage(url: nil) {
                    AlbumArtPlaceholder(size: 44)
                }
                .frame(width: 44, height: 44)
                .clipShape(RoundedRectangle(cornerRadius: 6))

                // Info
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

                // Duration
                Text(track.formattedDuration)
                    .font(.system(size: 13, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)

                // Favorite indicator
                if track.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.primaryGold)
                }

                // Menu
                Button(action: {}) {
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
