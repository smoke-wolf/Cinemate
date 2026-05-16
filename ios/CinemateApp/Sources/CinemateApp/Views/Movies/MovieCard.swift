import SwiftUI

struct MovieCard: View {
    let movie: MediaItem
    var showProgress: Bool = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Thumbnail
                ZStack(alignment: .bottomLeading) {
                    CachedAsyncImage(url: URL(string: movie.thumbnailURL ?? "")) {
                        MediaPlaceholder(icon: "film")
                    }
                    .frame(width: 160, height: 90)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall))

                    // Quality badge
                    if let quality = movie.quality {
                        QualityBadge(quality: quality)
                            .padding(6)
                    }

                    // Progress bar overlay
                    if showProgress && movie.watchProgress > 0 {
                        VStack {
                            Spacer()
                            GoldProgressBar(progress: movie.watchProgress, height: 3)
                        }
                    }

                    // Play icon overlay on hover
                    if showProgress {
                        ZStack {
                            Circle()
                                .fill(Color.black.opacity(0.5))
                                .frame(width: 36, height: 36)
                            Image(systemName: "play.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(movie.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 6) {
                        if let year = movie.year {
                            Text(String(year))
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                        }

                        if let rating = movie.rating {
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 9))
                                    .foregroundStyle(Theme.warmAmber)
                                Text(String(format: "%.1f", rating))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Theme.warmAmber)
                            }
                        }
                    }
                }
            }
            .frame(width: 160)
        }
        .buttonStyle(PressableButtonStyle())
    }
}

struct WideMovieCard: View {
    let movie: MediaItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                CachedAsyncImage(url: URL(string: movie.thumbnailURL ?? "")) {
                    MediaPlaceholder(icon: "film")
                }
                .frame(width: 120, height: 68)
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall))
                .overlay(alignment: .bottomLeading) {
                    if let quality = movie.quality {
                        QualityBadge(quality: quality)
                            .padding(4)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(movie.title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        if let year = movie.year {
                            Text(String(year))
                                .font(.system(size: 12))
                                .foregroundStyle(Theme.textSecondary)
                        }

                        Text(movie.formattedDuration)
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    if movie.watchProgress > 0 && movie.watchProgress < 1 {
                        GoldProgressBar(progress: movie.watchProgress, height: 2)
                            .padding(.top, 2)
                    }
                }

                Spacer()

                if movie.isFavorite {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.error)
                }
            }
            .padding(12)
            .background(Theme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerMedium))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        VStack(spacing: 16) {
            HStack {
                MovieCard(movie: .preview, showProgress: true, onTap: {})
                MovieCard(movie: MediaItem.previewList[1], onTap: {})
            }
            WideMovieCard(movie: .preview, onTap: {})
                .padding(.horizontal)
        }
    }
}
