import SwiftUI

struct MovieDetailView: View {
    @EnvironmentObject var apiClient: APIClient
    let movie: MediaItem
    let account: Account

    @State private var isFavorite: Bool
    @State private var isWatched: Bool
    @State private var showPlayer = false
    @State private var descriptionExpanded = false
    @State private var scrollOffset: CGFloat = 0

    init(movie: MediaItem, account: Account) {
        self.movie = movie
        self.account = account
        _isFavorite = State(initialValue: movie.isFavorite)
        _isWatched = State(initialValue: movie.isWatched)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(alignment: .leading, spacing: 0) {
                    // Hero Thumbnail with parallax
                    GeometryReader { geometry in
                        let offset = geometry.frame(in: .global).minY
                        let heroHeight: CGFloat = 280

                        ZStack(alignment: .bottom) {
                            CachedAsyncImage(url: URL(string: movie.thumbnailURL ?? "")) {
                                MediaPlaceholder(icon: "film")
                            }
                            .frame(
                                width: geometry.size.width,
                                height: heroHeight + (offset > 0 ? offset : 0)
                            )
                            .clipped()
                            .offset(y: offset > 0 ? -offset : 0)

                            // Gradient overlay
                            LinearGradient(
                                colors: [
                                    Color.clear,
                                    Theme.background.opacity(0.6),
                                    Theme.background,
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                            .frame(height: 140)
                        }
                        .frame(height: heroHeight)
                    }
                    .frame(height: 280)

                    // Content
                    VStack(alignment: .leading, spacing: 20) {
                        // Title + Meta
                        VStack(alignment: .leading, spacing: 8) {
                            Text(movie.cleanTitle)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)

                            HStack(spacing: 12) {
                                if let year = movie.year {
                                    Text(String(year))
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.textSecondary)
                                }

                                if !movie.genre.isEmpty {
                                    Text(movie.genreDisplay)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.textSecondary)
                                        .lineLimit(1)
                                }
                            }

                            HStack(spacing: 16) {
                                RatingDisplay(rating: movie.rating)

                                if let quality = movie.quality {
                                    QualityBadge(quality: quality)
                                }

                                if !movie.formattedDuration.isEmpty {
                                    HStack(spacing: 4) {
                                        Image(systemName: "clock")
                                            .font(.system(size: 12))
                                        Text(movie.formattedDuration)
                                            .font(.system(size: 13))
                                    }
                                    .foregroundStyle(Theme.textSecondary)
                                }

                                if !movie.formattedFileSize.isEmpty {
                                    Text(movie.formattedFileSize)
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.textTertiary)
                                }
                            }
                        }
                        .padding(.horizontal)

                        // Progress bar
                        if movie.watchProgress > 0 && movie.watchProgress < 1 {
                            VStack(alignment: .leading, spacing: 6) {
                                GoldProgressBar(progress: movie.watchProgress, height: 4)
                                Text("\(Int(movie.watchProgress * 100))% watched")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            .padding(.horizontal)
                        }

                        // Play Button
                        HStack(spacing: 12) {
                            GoldButton(
                                title: movie.watchProgress > 0 ? "Resume" : "Play",
                                icon: "play.fill",
                                action: { showPlayer = true },
                                isFullWidth: false,
                                size: .large
                            )

                            // Favorite
                            Button(action: {
                                isFavorite.toggle()
                                hapticImpact(.medium)
                                Task {
                                    try? await apiClient.toggleFavorite(
                                        accountId: Int(account.id) ?? 0,
                                        movieId: movie.id
                                    )
                                }
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                                        .font(.system(size: 22))
                                        .foregroundStyle(isFavorite ? Theme.error : Theme.textSecondary)
                                    Text("Favorite")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .frame(width: 60)
                            }

                            // Watched
                            Button(action: {
                                isWatched.toggle()
                                hapticImpact(.medium)
                            }) {
                                VStack(spacing: 4) {
                                    Image(systemName: isWatched ? "checkmark.circle.fill" : "checkmark.circle")
                                        .font(.system(size: 22))
                                        .foregroundStyle(isWatched ? Theme.success : Theme.textSecondary)
                                    Text("Watched")
                                        .font(.system(size: 11))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .frame(width: 60)
                            }
                        }
                        .padding(.horizontal)

                        // Description
                        if let description = movie.description, !description.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Synopsis")
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(Theme.textPrimary)

                                Text(description)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.textSecondary)
                                    .lineLimit(descriptionExpanded ? nil : 3)
                                    .animation(.easeInOut, value: descriptionExpanded)

                                if description.count > 150 {
                                    Button(action: {
                                        descriptionExpanded.toggle()
                                    }) {
                                        Text(descriptionExpanded ? "Show Less" : "Read More")
                                            .font(.system(size: 13, weight: .semibold))
                                            .foregroundStyle(Theme.primaryGold)
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                    }
                    .padding(.bottom, 100)
                }
            }
        }
        .cinemateNavigationBarInline()
        .cinemateToolbarHidden()
        .cinemateToolbarColorScheme(.dark)
        #if os(iOS)
        .fullScreenCover(isPresented: $showPlayer) {
            MoviePlayerView(movie: movie, account: account)
                .environmentObject(apiClient)
        }
        #else
        .sheet(isPresented: $showPlayer) {
            MoviePlayerView(movie: movie, account: account)
                .environmentObject(apiClient)
        }
        #endif
    }
}

#Preview {
    NavigationStack {
        MovieDetailView(movie: .preview, account: Account.previewAccounts[0])
            .environmentObject(APIClient())
    }
    .preferredColorScheme(.dark)
}
