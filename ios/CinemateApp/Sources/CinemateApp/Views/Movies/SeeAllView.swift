import SwiftUI

struct SeeAllView: View {
    let title: String
    let items: [MediaItem]
    let account: Account

    @State private var selectedMovie: MediaItem?

    private let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14)
    ]

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            if items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "film.stack")
                        .font(.system(size: 40))
                        .foregroundStyle(Theme.textTertiary)
                    Text("No movies here")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(items) { movie in
                            Button {
                                selectedMovie = movie
                            } label: {
                                SeeAllMovieCard(movie: movie)
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.large)
        .cinemateToolbarBackground(Theme.background)
        .cinemateToolbarColorScheme(.dark)
        .navigationDestination(item: $selectedMovie) { movie in
            MovieDetailView(movie: movie, account: account)
        }
    }
}

private struct SeeAllMovieCard: View {
    let movie: MediaItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomLeading) {
                CachedAsyncImage(url: URL(string: movie.thumbnailURL ?? "")) {
                    MediaPlaceholder(icon: "film")
                }
                .aspectRatio(16 / 9, contentMode: .fill)
                .clipped()
                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall))

                if let quality = movie.quality {
                    QualityBadge(quality: quality)
                        .padding(6)
                }

                if movie.watchProgress > 0 && movie.watchProgress < 1 {
                    VStack {
                        Spacer()
                        GoldProgressBar(progress: movie.watchProgress, height: 3)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(movie.title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 6) {
                    if let year = movie.year {
                        Text("\(year)")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    if let rating = movie.rating {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Theme.warmAmber)
                            Text(String(format: "%.1f", rating))
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(Theme.warmAmber)
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        SeeAllView(
            title: "Action",
            items: MediaItem.previewList,
            account: Account.previewAccounts[0]
        )
    }
    .environmentObject(APIClient())
    .preferredColorScheme(.dark)
}
