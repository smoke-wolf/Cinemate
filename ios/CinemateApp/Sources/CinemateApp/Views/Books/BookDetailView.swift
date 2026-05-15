import SwiftUI

struct BookDetailView: View {
    @EnvironmentObject var apiClient: APIClient
    let book: Book

    @State private var isFavorite: Bool
    @State private var showReader = false
    @State private var descriptionExpanded = false

    init(book: Book) {
        self.book = book
        _isFavorite = State(initialValue: book.isFavorite)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Cover + Info Header
                    HStack(alignment: .top, spacing: 20) {
                        // Cover
                        CachedAsyncImage(url: nil) {
                            BookCoverPlaceholder()
                        }
                        .frame(width: 140, height: 210)
                        .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall))
                        .shadow(color: .black.opacity(0.4), radius: 12, x: 4, y: 8)

                        // Meta
                        VStack(alignment: .leading, spacing: 8) {
                            Text(book.title)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)

                            Text(book.author)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Theme.primaryGold)

                            if let genre = book.genre {
                                Text(genre)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.textSecondary)
                            }

                            HStack(spacing: 12) {
                                FormatBadge(format: book.format.rawValue)

                                if let pages = book.pageCount {
                                    Text("\(pages) pages")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }

                            // Status
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(statusColor)
                                    .frame(width: 8, height: 8)
                                Text(book.readingStatus.rawValue)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top, 16)

                    // Progress
                    if book.progress > 0 && !book.isFinished {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Reading Progress")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(Theme.textSecondary)
                                Spacer()
                                Text(book.progressDisplay)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            GoldProgressBar(progress: book.progress, height: 5)
                        }
                        .padding(.horizontal)
                    }

                    // Action Buttons
                    HStack(spacing: 12) {
                        GoldButton(
                            title: book.currentPage > 0 ? "Continue Reading" : "Start Reading",
                            icon: "book.fill",
                            action: { showReader = true },
                            size: .large
                        )

                        Button(action: {
                            isFavorite.toggle()
                            hapticImpact(.medium)
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
                    }
                    .padding(.horizontal)

                    // Description
                    if let description = book.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)

                            Text(description)
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(descriptionExpanded ? nil : 4)
                                .animation(.easeInOut, value: descriptionExpanded)

                            if description.count > 200 {
                                Button(action: { descriptionExpanded.toggle() }) {
                                    Text(descriptionExpanded ? "Show Less" : "Read More")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(Theme.primaryGold)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Bookmarks
                    if !book.bookmarks.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Bookmarks")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)

                            ForEach(book.bookmarks) { bookmark in
                                HStack(spacing: 12) {
                                    Image(systemName: "bookmark.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.primaryGold)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(bookmark.title ?? "Page \(bookmark.page)")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(Theme.textPrimary)
                                        Text("Page \(bookmark.page)")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Theme.textTertiary)
                                    }

                                    Spacer()

                                    Button(action: {
                                        // Jump to page
                                        showReader = true
                                    }) {
                                        Image(systemName: "arrow.right.circle")
                                            .font(.system(size: 16))
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                }
                                .padding(12)
                                .background(Theme.cardSurface)
                                .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall))
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 100)
            }
        }
        .cinemateNavigationBarInline()
        .cinemateToolbarColorScheme(.dark)
        #if os(iOS)
        .fullScreenCover(isPresented: $showReader) {
            BookReaderView(book: book)
        }
        #else
        .sheet(isPresented: $showReader) {
            BookReaderView(book: book)
        }
        #endif
    }

    private var statusColor: Color {
        switch book.readingStatus {
        case .unread: return Theme.textTertiary
        case .reading: return Theme.primaryGold
        case .finished: return Theme.success
        }
    }
}

#Preview {
    NavigationStack {
        BookDetailView(book: .preview)
            .environmentObject(APIClient())
    }
    .preferredColorScheme(.dark)
}
