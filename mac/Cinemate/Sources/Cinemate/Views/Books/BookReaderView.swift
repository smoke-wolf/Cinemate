import SwiftUI
import PDFKit

// MARK: - PDFKit NSViewRepresentable

struct PDFKitView: NSViewRepresentable {
    let url: URL
    let nightMode: Bool
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    @Binding var pdfView: PDFView?

    func makeNSView(context: Context) -> PDFView {
        let view = PDFView()
        view.autoScales = true
        view.displayMode = .singlePageContinuous
        view.displayDirection = .vertical
        view.backgroundColor = nightMode ? .black : NSColor(white: 0.12, alpha: 1)

        if let document = PDFDocument(url: url) {
            view.document = document
            DispatchQueue.main.async {
                totalPages = document.pageCount
            }
        }

        // Observe page changes
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: view
        )

        DispatchQueue.main.async {
            pdfView = view
        }

        return view
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.backgroundColor = nightMode ? .black : NSColor(white: 0.12, alpha: 1)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(currentPage: $currentPage, totalPages: $totalPages)
    }

    class Coordinator: NSObject {
        var currentPage: Binding<Int>
        var totalPages: Binding<Int>

        init(currentPage: Binding<Int>, totalPages: Binding<Int>) {
            self.currentPage = currentPage
            self.totalPages = totalPages
        }

        @objc func pageChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let currentPDFPage = pdfView.currentPage,
                  let document = pdfView.document else { return }
            let pageIndex = document.index(for: currentPDFPage)
            DispatchQueue.main.async {
                self.currentPage.wrappedValue = pageIndex + 1
            }
        }
    }
}

// MARK: - Book Reader View

struct BookReaderView: View {
    let book: Book
    let onClose: () -> Void
    var accountId: Int64? = nil

    @State private var currentPage: Int = 1
    @State private var totalPages: Int = 0
    @State private var nightMode: Bool = true
    @State private var pdfView: PDFView? = nil
    @State private var showBookmarkDialog = false
    @State private var bookmarkNote: String = ""
    @State private var lastSaveTime = Date()
    @State private var isBookmarked: Bool = false

    private let goldAccent = Color(red: 0.95, green: 0.8, blue: 0.2)

    var body: some View {
        if book.format == "PDF" {
            pdfReaderContent
        } else {
            epubPlaceholder
        }
    }

    private var pdfReaderContent: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 16) {
                Button(action: {
                    saveProgress()
                    onClose()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 13, weight: .semibold))
                        Text(book.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.ultraThinMaterial)
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Spacer()

                // Page indicator
                Text("Page \(currentPage) of \(totalPages)")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                // Controls
                HStack(spacing: 12) {
                    // Zoom out
                    Button(action: { zoomOut() }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)

                    // Zoom in
                    Button(action: { zoomIn() }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)

                    // Bookmark
                    Button(action: { showBookmarkDialog = true }) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 14))
                            .foregroundColor(Color(red: 0.95, green: 0.8, blue: 0.2))
                    }
                    .buttonStyle(.plain)

                    // Night mode
                    Button(action: { nightMode.toggle() }) {
                        Image(systemName: nightMode ? "sun.max.fill" : "moon.fill")
                            .font(.system(size: 14))
                            .foregroundColor(nightMode ? .yellow : .white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(white: 0.06))

            Divider().background(Color.gray.opacity(0.3))

            // PDF content
            PDFKitView(
                url: URL(fileURLWithPath: book.filePath),
                nightMode: nightMode,
                currentPage: $currentPage,
                totalPages: $totalPages,
                pdfView: $pdfView
            )
            .colorInvert(nightMode)

            Divider().background(Color.gray.opacity(0.3))

            // Bottom bar: page slider
            HStack(spacing: 16) {
                Text("1")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundColor(.gray)

                Slider(
                    value: Binding(
                        get: { Double(currentPage) },
                        set: { newVal in
                            let page = max(1, min(Int(newVal), totalPages))
                            goToPage(page)
                        }
                    ),
                    in: 1...max(Double(totalPages), 1),
                    step: 1
                )
                .tint(Color(red: 0.95, green: 0.8, blue: 0.2))

                Text("\(totalPages)")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 8)
            .background(Color(white: 0.06))
        }
        .background(nightMode ? Color.black : Color(white: 0.1))
        .onAppear {
            // Restore reading position
            if book.currentPage > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    goToPage(book.currentPage)
                }
            }
        }
        .onDisappear {
            saveProgress()
        }
        .onKeyPress(.escape) {
            saveProgress()
            onClose()
            return .handled
        }
        .sheet(isPresented: $showBookmarkDialog) {
            bookmarkDialog
        }
        .onChange(of: currentPage) { _, _ in
            // Auto-save every 10 seconds
            if Date().timeIntervalSince(lastSaveTime) > 10 {
                saveProgress()
                lastSaveTime = Date()
            }
        }
    }

    private var epubPlaceholder: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "book.closed.fill")
                .font(.system(size: 64))
                .foregroundColor(Color(red: 0.95, green: 0.8, blue: 0.2).opacity(0.5))

            Text("EPUB Reader Coming Soon")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Text("EPUB rendering support is under development.\nIn the meantime, you can open this book in Apple Books.")
                .font(.system(size: 14))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)

            Button(action: {
                NSWorkspace.shared.open(URL(fileURLWithPath: book.filePath))
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.forward.app")
                    Text("Open in Books.app")
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(red: 0.95, green: 0.8, blue: 0.2))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Button(action: onClose) {
                Text("Back to Library")
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.6))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(white: 0.08))
    }

    private var bookmarkDialog: some View {
        VStack(spacing: 16) {
            Text("Add Bookmark")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)

            Text("Page \(currentPage)")
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))

            TextField("Note (optional)", text: $bookmarkNote)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .padding(10)
                .background(Color.white.opacity(0.08))
                .cornerRadius(6)

            HStack(spacing: 12) {
                Button("Cancel") {
                    showBookmarkDialog = false
                    bookmarkNote = ""
                }
                .foregroundColor(.gray)
                .buttonStyle(.plain)

                Button("Save") {
                    if let aid = accountId {
                        BookDatabase.shared.addBookmark(
                            bookId: book.id,
                            page: currentPage,
                            note: bookmarkNote.isEmpty ? nil : bookmarkNote,
                            accountId: aid
                        )
                    }
                    showBookmarkDialog = false
                    bookmarkNote = ""
                }
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(Color(red: 0.95, green: 0.8, blue: 0.2))
                .cornerRadius(6)
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(width: 300)
        .background(Color(white: 0.1))
    }

    // MARK: - Actions

    private func goToPage(_ page: Int) {
        guard let pdfView = pdfView,
              let document = pdfView.document,
              page >= 1 && page <= document.pageCount else { return }
        if let pdfPage = document.page(at: page - 1) {
            pdfView.go(to: pdfPage)
            currentPage = page
        }
    }

    private func zoomIn() {
        guard let pdfView = pdfView else { return }
        pdfView.scaleFactor *= 1.25
    }

    private func zoomOut() {
        guard let pdfView = pdfView else { return }
        pdfView.scaleFactor *= 0.8
    }

    private func saveProgress() {
        guard totalPages > 0 else { return }
        let progress = Double(currentPage) / Double(totalPages)
        BookDatabase.shared.updateProgress(
            bookId: book.id,
            progress: progress,
            currentPage: currentPage,
            accountId: accountId
        )
    }
}

// MARK: - Color Invert Modifier

extension View {
    @ViewBuilder
    func colorInvert(_ active: Bool) -> some View {
        if active {
            self.colorInvert()
        } else {
            self
        }
    }
}
