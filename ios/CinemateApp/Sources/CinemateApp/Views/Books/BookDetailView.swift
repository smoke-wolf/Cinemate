import SwiftUI

struct BookDetailView: View {
    @EnvironmentObject var apiClient: APIClient
    let book: Book
    let account: Account

    @ObservedObject var downloadManager = DownloadManager.shared
    @State private var isFavorite: Bool
    @State private var showReader = false
    @State private var descriptionExpanded = false

    init(book: Book, account: Account) {
        self.book = book
        self.account = account
        _isFavorite = State(initialValue: book.favorite)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 24) {
                    // Cover + Info Header
                    HStack(alignment: .top, spacing: 20) {
                        // Cover
                        CachedAsyncImage(url: apiClient.bookCoverURL(bookId: book.id)) {
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

                            Text(book.author ?? "Unknown Author")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Theme.primaryGold)

                            if let genre = book.genre {
                                Text(genre)
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.textSecondary)
                            }

                            HStack(spacing: 12) {
                                FormatBadge(format: book.format)

                                if book.pageCount > 0 {
                                    Text("\(book.pageCount) pages")
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
                    if book.progress > 0 && !book.finished {
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
                            Task {
                                try? await apiClient.toggleBookFavorite(
                                    accountId: Int(account.id) ?? 0,
                                    bookId: book.id
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

                        Button(action: downloadBook) {
                            VStack(spacing: 4) {
                                ZStack {
                                    switch bookDownloadStatus {
                                    case .completed:
                                        Image(systemName: "checkmark.circle.fill")
                                            .font(.system(size: 22))
                                            .foregroundStyle(Theme.success)
                                    case .downloading, .queued, .paused:
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(Theme.primaryGold)
                                    case .failed:
                                        Image(systemName: "arrow.clockwise")
                                            .font(.system(size: 22))
                                            .foregroundStyle(Theme.error)
                                    default:
                                        Image(systemName: "arrow.down.circle")
                                            .font(.system(size: 22))
                                            .foregroundStyle(Theme.textSecondary)
                                    }
                                }
                                .frame(height: 24)
                                Text(bookDownloadLabel)
                                    .font(.system(size: 11))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                            .frame(width: 60)
                        }
                        .disabled(bookDownloadStatus == .completed || bookDownloadStatus == .downloading || bookDownloadStatus == .queued)
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

                }
                .padding(.bottom, 100)
            }
        }
        .cinemateNavigationBarInline()
        .cinemateToolbarColorScheme(.dark)
        #if os(iOS)
        .fullScreenCover(isPresented: $showReader) {
            BookReaderView(book: book, account: account)
        }
        #else
        .sheet(isPresented: $showReader) {
            BookReaderView(book: book, account: account)
        }
        #endif
    }

    private var bookDownloadStatus: DownloadStatus? {
        downloadManager.downloadState(contentType: .book, contentId: book.id)
    }

    private var bookDownloadLabel: String {
        switch bookDownloadStatus {
        case .completed: return "Saved"
        case .downloading, .queued, .paused: return "Saving..."
        case .failed: return "Retry"
        default: return "Download"
        }
    }

    private func downloadBook() {
        guard bookDownloadStatus == nil || bookDownloadStatus == .failed || bookDownloadStatus == .cancelled else { return }
        hapticImpact(.medium)
        downloadManager.enqueueDownload(
            contentType: .book,
            contentId: book.id,
            title: book.title,
            subtitle: book.author,
            thumbnailPath: "/api/books/cover/\(book.id)",
            fileSize: book.fileSize,
            downloadPath: "/api/books/read/\(book.id)"
        )
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
        BookDetailView(book: .preview, account: Account.previewAccounts[0])
            .environmentObject(APIClient())
    }
    .preferredColorScheme(.dark)
}
