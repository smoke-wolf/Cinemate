import SwiftUI

struct MovieGrid: View {
    let movies: [Movie]
    let onTap: (Movie) -> Void
    let onPlay: (Movie) -> Void
    let onFavorite: (Movie) -> Void

    private let columns = [
        GridItem(.adaptive(minimum: 240, maximum: 320), spacing: 20)
    ]

    var body: some View {
        if movies.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "film.stack")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                Text("No movies found")
                    .font(.title3)
                    .foregroundColor(.gray)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(movies) { movie in
                        MovieCard(
                            movie: movie,
                            onTap: { onTap(movie) },
                            onPlay: { onPlay(movie) },
                            onFavorite: { onFavorite(movie) }
                        )
                    }
                }
                .padding(24)
            }
        }
    }
}
