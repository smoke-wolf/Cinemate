import SwiftUI

struct BooksView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var books: [Book] = Book.previewList
    @State private var selectedFilter: BookFilter = .all
    @State private var selectedBook: Book?
    @State private var sortOrder: SortOrder = .recent

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
        case .recent: return filtered.sorted { ($0.dateAdded ?? .distantPast) > ($1.dateAdded ?? .distantPast) }
        case .title: return filtered.sorted { $0.title < $1.title }
        case .author: return filtered.sorted { $0.author < $1.author }
        }
    }

    let columns = [
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
        GridItem(.flexible(), spacing: 14),
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
                    ScrollView(.vertical, showsIndicators: false) {
                        LazyVGrid(columns: columns, spacing: 20) {
                            ForEach(filteredBooks) { book in
                                BookCard(book: book) {
                                    selectedBook = book
                                }
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 100)
                    }
                    .refreshable {
                        await loadBooks()
                    }
                }
            }
            .navigationTitle("Books")
            .cinemateToolbarBackground(Theme.background)
            .cinemateToolbarColorScheme(.dark)
            .navigationDestination(item: $selectedBook) { book in
                BookDetailView(book: book)
            }
        }
        .task {
            await loadBooks()
        }
    }

    private func loadBooks() async {
        do {
            books = try await apiClient.getBooks()
        } catch {
            // Keep preview data
        }
    }
}

#Preview {
    BooksView()
        .environmentObject(APIClient())
        .preferredColorScheme(.dark)
}
