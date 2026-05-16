import SwiftUI

struct BookCard: View {
    @EnvironmentObject var apiClient: APIClient
    let book: Book
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topLeading) {
                    CachedAsyncImage(url: apiClient.bookCoverURL(bookId: book.id)) {
                        BookCoverPlaceholder()
                    }
                    .aspectRatio(2.0/3.0, contentMode: .fit)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .shadow(color: .black.opacity(0.4), radius: 8, x: 2, y: 4)

                    if book.finished {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.success)
                            .background(Circle().fill(.black.opacity(0.5)))
                            .padding(8)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)

                    Text(book.author ?? "Unknown")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                if book.progress > 0 && !book.finished {
                    GoldProgressBar(progress: book.progress, height: 3)
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        HStack(spacing: 16) {
            BookCard(book: .preview, onTap: {})
                .frame(width: 160)
            BookCard(book: Book.previewList[1], onTap: {})
                .frame(width: 160)
        }
    }
}
