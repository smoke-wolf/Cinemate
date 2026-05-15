import SwiftUI

struct MovieRow: View {
    let title: String
    let movies: [Movie]
    let onTap: (Movie) -> Void
    let onPlay: (Movie) -> Void
    let onFavorite: (Movie) -> Void

    var body: some View {
        if !movies.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 16) {
                        ForEach(movies) { movie in
                            MovieCard(
                                movie: movie,
                                onTap: { onTap(movie) },
                                onPlay: { onPlay(movie) },
                                onFavorite: { onFavorite(movie) }
                            )
                            .frame(width: 280)
                        }
                    }
                    .padding(.horizontal, 24)
                }
                .frame(height: 230)
            }
        }
    }
}
