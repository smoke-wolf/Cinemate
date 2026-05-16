import SwiftUI

struct NowPlayingBar: View {
    @EnvironmentObject var audioPlayer: AudioPlayer
    let onTap: () -> Void

    var body: some View {
        if let track = audioPlayer.currentTrack {
            Button(action: onTap) {
                VStack(spacing: 0) {
                    // Progress line
                    if audioPlayer.duration > 0 {
                        GeometryReader { geometry in
                            Rectangle()
                                .fill(Theme.primaryGold)
                                .frame(
                                    width: geometry.size.width * CGFloat(audioPlayer.currentTime / audioPlayer.duration),
                                    height: 2
                                )
                        }
                        .frame(height: 2)
                    }

                    HStack(spacing: 12) {
                        // Album art
                        CachedAsyncImage(url: audioPlayer.albumArtURL) {
                            AlbumArtPlaceholder(size: 40)
                        }
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        // Track info
                        VStack(alignment: .leading, spacing: 2) {
                            Text(track.title)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Theme.textPrimary)
                                .lineLimit(1)

                            Text(track.artist)
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        // Controls
                        HStack(spacing: 20) {
                            Button(action: {
                                audioPlayer.togglePlayPause()
                            }) {
                                Image(systemName: audioPlayer.isPlaying ? "pause.fill" : "play.fill")
                                    .font(.system(size: 20))
                                    .foregroundStyle(Theme.textPrimary)
                            }

                            Button(action: {
                                audioPlayer.next()
                            }) {
                                Image(systemName: "forward.fill")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
                .background(
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .colorScheme(.dark)
                )
            }
            .buttonStyle(.plain)
            .transition(.asymmetric(
                insertion: .move(edge: .bottom).combined(with: .opacity),
                removal: .move(edge: .bottom).combined(with: .opacity)
            ))
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack {
            Spacer()
            NowPlayingBar(onTap: {})
        }
    }
    .environmentObject(AudioPlayer())
}
