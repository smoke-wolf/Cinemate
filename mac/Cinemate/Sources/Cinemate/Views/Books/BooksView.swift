import SwiftUI

struct BooksView: View {
    @ObservedObject var viewModel: BookViewModel

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 20)
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Sub-navigation bar
            HStack(spacing: 0) {
                ForEach(BookSubView.allCases, id: \.self) { subView in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.currentSubView = subView
                        }
                    }) {
                        Text(subView.rawValue)
                            .font(.system(size: 13, weight: viewModel.currentSubView == subView ? .semibold : .regular))
                            .foregroundColor(viewModel.currentSubView == subView ? .white : .gray)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                viewModel.currentSubView == subView
                                    ? Color.white.opacity(0.1)
                                    : Color.clear
                            )
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Format filter
                Menu {
                    Button("All Formats") { viewModel.filterByFormat(nil) }
                    Divider()
                    ForEach(["EPUB", "PDF", "MOBI", "AZW3", "CBZ", "CBR", "FB2", "DJVU"], id: \.self) { fmt in
                        Button(fmt) { viewModel.filterByFormat(fmt) }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease")
                            .font(.system(size: 10))
                        Text(viewModel.formatFilter ?? "All Formats")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()

                // Sort
                Menu {
                    ForEach(BookSortOption.allCases, id: \.self) { option in
                        Button(action: { viewModel.sort(by: option) }) {
                            HStack {
                                Text(option.rawValue)
                                if viewModel.sortOption == option {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.arrow.down")
                            .font(.system(size: 9))
                        Text(viewModel.sortOption.rawValue)
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(Color(white: 0.08))

            Divider().background(Color.gray.opacity(0.2))

            // Content
            switch viewModel.currentSubView {
            case .all:
                bookGrid(books: viewModel.books)
            case .currentlyReading:
                bookGrid(books: viewModel.currentlyReading)
            case .finished:
                bookGrid(books: viewModel.finishedBooks)
            case .authors:
                authorsView
            }
        }
    }

    @ViewBuilder
    private func bookGrid(books: [Book]) -> some View {
        if books.isEmpty {
            VStack(spacing: 16) {
                Image(systemName: "book.closed")
                    .font(.system(size: 48))
                    .foregroundColor(.gray)
                Text(emptyMessage)
                    .font(.title3)
                    .foregroundColor(.gray)
                if viewModel.books.isEmpty {
                    Text("Scan a folder to add books to your library")
                        .font(.system(size: 13))
                        .foregroundColor(.gray.opacity(0.7))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 24) {
                    ForEach(books) { book in
                        BookCard(
                            book: book,
                            onTap: { viewModel.showDetail(book) },
                            onRead: { viewModel.openReader(book) },
                            onFavorite: { viewModel.toggleFavorite(book) }
                        )
                    }
                }
                .padding(24)
            }
        }
    }

    private var emptyMessage: String {
        switch viewModel.currentSubView {
        case .all: return "No books found"
        case .currentlyReading: return "No books in progress"
        case .finished: return "No finished books"
        case .authors: return "No authors"
        }
    }

    private var authorsView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.authors) { author in
                    AuthorRow(author: author) {
                        // Show author's books in a detail view
                        viewModel.currentSubView = .all
                        viewModel.search(author.name)
                    }
                }
            }
            .padding(.vertical, 12)
        }
    }
}

// MARK: - Author Row

struct AuthorRow: View {
    let author: BookAuthor
    let onTap: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Author avatar
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.orange.opacity(0.6), .yellow.opacity(0.4)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(author.name.prefix(1)).uppercased())
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(author.name)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.white)
                    Text("\(author.bookCount) \(author.bookCount == 1 ? "book" : "books")")
                        .font(.system(size: 12))
                        .foregroundColor(.gray)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.gray.opacity(0.5))
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 10)
            .background(isHovered ? Color.white.opacity(0.05) : Color.clear)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}
