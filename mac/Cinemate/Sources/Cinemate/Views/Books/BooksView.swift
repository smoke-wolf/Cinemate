import SwiftUI
import AppKit

struct BooksView: View {
    @ObservedObject var viewModel: BookViewModel
    @FocusState private var isSearchFocused: Bool

    private let columns = [
        GridItem(.adaptive(minimum: 140, maximum: 180), spacing: 20)
    ]

    private let goldAccent = Color(red: 0.95, green: 0.8, blue: 0.2)

    var body: some View {
        VStack(spacing: 0) {
            // Sub-navigation bar
            subNavBar

            Divider().background(Color.gray.opacity(0.2))

            // Stats bar
            statsBar

            Divider().background(Color.gray.opacity(0.15))

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

    // MARK: - Sub-Navigation Bar

    private var subNavBar: some View {
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

            // Scanning indicator
            if viewModel.isScanning {
                HStack(spacing: 6) {
                    ProgressView()
                        .controlSize(.small)
                    Text("\(viewModel.scanProgress)%")
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
                .padding(.trailing, 8)
            }

            // Scan Folder button
            Button(action: pickBookFolder) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)
            .help("Scan a folder for books")
            .padding(.trailing, 8)

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
            .padding(.trailing, 8)

            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)

                TextField("Search books...", text: $viewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .frame(width: 160)
                    .focused($isSearchFocused)
                    .onSubmit {
                        viewModel.search(viewModel.searchQuery)
                    }
                    .onChange(of: viewModel.searchQuery) { _, newValue in
                        viewModel.search(newValue)
                    }

                if !viewModel.searchQuery.isEmpty {
                    Button(action: {
                        viewModel.searchQuery = ""
                        viewModel.search("")
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
        .background(Color(white: 0.08))
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        HStack(spacing: 16) {
            statItem(icon: "book.closed.fill", value: "\(viewModel.books.count)", label: "books")
            statDivider
            statItem(icon: "book.fill", value: "\(viewModel.currentlyReading.count)", label: "currently reading")
            statDivider
            statItem(icon: "checkmark.circle.fill", value: "\(viewModel.finishedBooks.count)", label: "finished")
            statDivider
            statItem(icon: "clock.fill", value: totalReadingTimeFormatted, label: "reading time")
            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 8)
        .background(Color(white: 0.07))
    }

    private var statDivider: some View {
        Rectangle()
            .fill(Color.gray.opacity(0.2))
            .frame(width: 1, height: 14)
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 10))
                .foregroundColor(goldAccent.opacity(0.7))
            Text("\(value) \(label)")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.5))
        }
    }

    private var totalReadingTimeFormatted: String {
        let totalSeconds = viewModel.books.reduce(0.0) { $0 + $1.totalReadingTime }
            + viewModel.currentlyReading.reduce(0.0) { $0 + $1.totalReadingTime }
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60
        if hours > 0 { return "\(hours)h \(minutes)m" }
        if minutes > 0 { return "\(minutes)m" }
        return "0m"
    }

    // MARK: - Folder Picker

    private func pickBookFolder() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Choose a folder containing books"
        panel.prompt = "Scan"
        if panel.runModal() == .OK, let url = panel.url {
            viewModel.scan(directory: url.path)
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
                            onFavorite: { viewModel.toggleFavorite(book) },
                            onMarkFinished: { viewModel.markFinished(book) }
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
