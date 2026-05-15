import SwiftUI

struct BookCard: View {
    let book: Book
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                // Cover
                ZStack(alignment: .bottomTrailing) {
                    CachedAsyncImage(url: nil) {
                        BookCoverPlaceholder()
                    }
                    .aspectRatio(2.0/3.0, contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall))
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 2, y: 4)

                    // Format badge
                    FormatBadge(format: book.format)
                        .padding(6)

                    // Finished overlay
                    if book.finished {
                        VStack {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Theme.success)
                                    .background(Circle().fill(.black.opacity(0.5)))
                                Spacer()
                            }
                            .padding(6)
                            Spacer()
                        }
                    }
                }

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(book.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(2)

                    Text(book.author ?? "Unknown")
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                // Progress bar
                if book.progress > 0 && !book.finished {
                    VStack(alignment: .leading, spacing: 3) {
                        GoldProgressBar(progress: book.progress, height: 2)
                        Text("\(Int(book.progress * 100))%")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
            }
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        HStack {
            BookCard(book: .preview, onTap: {})
                .frame(width: 120)
            BookCard(book: Book.previewList[1], onTap: {})
                .frame(width: 120)
        }
    }
}
