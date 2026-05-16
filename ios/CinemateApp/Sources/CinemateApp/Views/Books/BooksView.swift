import SwiftUI

struct BooksView: View {
    @EnvironmentObject var apiClient: APIClient
    let account: Account
    @State private var books: [Book] = []
    @State private var isLoading = false
    @State private var isLoadingMore = false
    @State private var hasMore = true
    @State private var totalBooks = 0
    @State private var selectedFilter: BookFilter = .all
    @State private var selectedBook: Book?
    @State private var sortOrder: SortOrder = .recent
    private let pageSize = 40

    enum BookFilter: String, CaseIterable {
        case all = "All"
        case reading = "Reading"
        case finished = "Finished"
    }

    enum SortOrder: String, CaseIterable {
        case recent = "Recent"
        case title = "Title"
        case author = "Author"
    }

    private var filteredBooks: [Book] {
        var filtered: [Book]
        switch selectedFilter {
        case .all: filtered = books
        case .reading: filtered = books.filter { $0.readingStatus == .reading }
        case .finished: filtered = books.filter { $0.readingStatus == .finished }
        }

        switch sortOrder {
        case .recent: return filtered.sorted { ($0.dateAdded ?? "") > ($1.dateAdded ?? "") }
        case .title: return filtered.sorted { $0.title < $1.title }
        case .author: return filtered.sorted { ($0.author ?? "") < ($1.author ?? "") }
        }
    }

    let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // Filters
                    HStack(spacing: 8) {
                        // Filter pills
                        ForEach(BookFilter.allCases, id: \.self) { filter in
                            Button(action: {
                                withAnimation(Theme.quickSpring) {
                                    selectedFilter = filter
                                }
                            }) {
                                Text(filter.rawValue)
                                    .font(.system(size: 13, weight: selectedFilter == filter ? .bold : .medium))
                                    .foregroundStyle(selectedFilter == filter ? .black : Theme.textSecondary)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 7)
                                    .background(
                                        selectedFilter == filter
                                        ? AnyShapeStyle(Theme.goldGradient)
                                        : AnyShapeStyle(Theme.cardSurface)
                                    )
                                    .clipShape(Capsule())
                            }
                        }

                        Spacer()

                        // Sort menu
                        Menu {
                            ForEach(SortOrder.allCases, id: \.self) { order in
                                Button(action: { sortOrder = order }) {
                                    HStack {
                                        Text(order.rawValue)
                                        if sortOrder == order {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            Image(systemName: "arrow.up.arrow.down")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textSecondary)
                                .padding(8)
                                .background(Theme.cardSurface)
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 12)

                    // Book Grid
                    if isLoading && books.isEmpty {
                        booksSkeletonView
                    } else if !isLoading && books.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "book.closed")
                                .font(.system(size: 40))
                                .foregroundStyle(Theme.textTertiary)
                            Text("No books yet")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Theme.textSecondary)
                            Text("Your book library will appear here")
                                .font(.system(size: 14))
                                .foregroundStyle(Theme.textTertiary)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.top, 60)
                    } else {
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVGrid(columns: columns, spacing: 24) {
                                ForEach(filteredBooks) { book in
                                    BookCard(book: book) {
                                        selectedBook = book
                                    }
                                    .onAppear {
                                        if book.id == filteredBooks.last?.id && hasMore && !isLoadingMore {
                                            Task { await loadMoreBooks() }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)

                            if isLoadingMore {
                                ProgressView()
                                    .tint(Theme.primaryGold)
                                    .padding(.vertical, 20)
                            }

                            Spacer().frame(height: 100)
                        }
                        .refreshable {
                            await loadBooks(reset: true)
                        }
                    }
                }
            }
            .navigationTitle("Books")
            .cinemateToolbarBackground(Theme.background)
            .cinemateToolbarColorScheme(.dark)
            .navigationDestination(item: $selectedBook) { book in
                BookDetailView(book: book, account: account)
            }
        }
        .task {
            await loadBooks()
        }
    }

    private var booksSkeletonView: some View {
        ScrollView(.vertical, showsIndicators: false) {
            LazyVGrid(columns: columns, spacing: 24) {
                ForEach(0..<6, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 8) {
                        ShimmerView()
                            .aspectRatio(2.0/3.0, contentMode: .fit)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerSmall))

                        ShimmerView()
                            .frame(height: 14)
                            .clipShape(RoundedRectangle(cornerRadius: 4))

                        ShimmerView()
                            .frame(width: 80, height: 10)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private func loadBooks(reset: Bool = false) async {
        if reset {
            books = []
            hasMore = true
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let accountId = Int(account.id) ?? 0
            let response = try await apiClient.getBooks(accountId: accountId, limit: pageSize, offset: 0)
            books = response.items
            totalBooks = response.total
            hasMore = books.count < totalBooks
        } catch {}
    }

    private func loadMoreBooks() async {
        guard hasMore, !isLoadingMore else { return }
        isLoadingMore = true
        defer { isLoadingMore = false }
        do {
            let accountId = Int(account.id) ?? 0
            let response = try await apiClient.getBooks(accountId: accountId, limit: pageSize, offset: books.count)
            books.append(contentsOf: response.items)
            hasMore = books.count < response.total
        } catch {}
    }
}

#Preview {
    BooksView(account: Account.previewAccounts[0])
        .environmentObject(APIClient())
        .preferredColorScheme(.dark)
}
