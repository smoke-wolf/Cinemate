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
    var readAsEbook: Bool = false

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
        if book.format == "PDF" && !readAsEbook {
            pdfReaderContent
        } else if book.format == "PDF" && readAsEbook {
            PDFAsEbookView(book: book, nightMode: $nightMode, onClose: {
                saveProgress()
                onClose()
            }, accountId: accountId)
        } else {
            epubPlaceholder
        }
    }

    private var pdfReaderContent: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 12) {
                Button(action: {
                    saveProgress()
                    onClose()
                }) {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 12, weight: .semibold))
                        Text(book.title)
                            .font(.system(size: 13, weight: .semibold))
                            .lineLimit(1)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
                }
                .buttonStyle(.plain)

                Spacer()

                // Page navigation buttons
                HStack(spacing: 4) {
                    Button(action: { goToPage(currentPage - 1) }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(currentPage <= 1 ? .gray.opacity(0.3) : .white.opacity(0.7))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .disabled(currentPage <= 1)

                    Text("Page \(currentPage) of \(totalPages)")
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.horizontal, 8)

                    Button(action: { goToPage(currentPage + 1) }) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(currentPage >= totalPages ? .gray.opacity(0.3) : .white.opacity(0.7))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .disabled(currentPage >= totalPages)
                }

                Spacer()

                // Controls
                HStack(spacing: 8) {
                    // Font size controls
                    Button(action: { decreaseFontSize() }) {
                        Image(systemName: "textformat.size.smaller")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Decrease text size")

                    Button(action: { increaseFontSize() }) {
                        Image(systemName: "textformat.size.larger")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Increase text size")

                    // Divider
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 1, height: 18)

                    // Zoom controls
                    Button(action: { zoomOut() }) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Zoom out")

                    Button(action: { zoomIn() }) {
                        Image(systemName: "plus.magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Zoom in")

                    // Divider
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 1, height: 18)

                    // Bookmark
                    Button(action: { showBookmarkDialog = true }) {
                        Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                            .font(.system(size: 13))
                            .foregroundColor(isBookmarked ? goldAccent : .white.opacity(0.7))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help("Add bookmark")

                    // Night mode
                    Button(action: { nightMode.toggle() }) {
                        Image(systemName: nightMode ? "sun.max.fill" : "moon.fill")
                            .font(.system(size: 13))
                            .foregroundColor(nightMode ? .yellow : .white.opacity(0.7))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                    .help(nightMode ? "Light mode" : "Dark mode")
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(white: 0.05))

            // Reading progress indicator
            GeometryReader { geo in
                Rectangle()
                    .fill(goldAccent.opacity(0.6))
                    .frame(width: totalPages > 0 ? geo.size.width * CGFloat(currentPage) / CGFloat(totalPages) : 0, height: 2)
                    .animation(.easeInOut(duration: 0.2), value: currentPage)
            }
            .frame(height: 2)

            // PDF content
            PDFKitView(
                url: URL(fileURLWithPath: book.filePath),
                nightMode: nightMode,
                currentPage: $currentPage,
                totalPages: $totalPages,
                pdfView: $pdfView
            )
            .colorInvert(nightMode)

            // Bottom bar: page slider
            HStack(spacing: 16) {
                Text("1")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundColor(.gray.opacity(0.6))

                if totalPages > 1 {
                    Slider(
                        value: Binding(
                            get: { Double(currentPage) },
                            set: { newVal in
                                let page = max(1, min(Int(newVal), totalPages))
                                goToPage(page)
                            }
                        ),
                        in: 1...Double(totalPages),
                        step: 1
                    )
                    .tint(goldAccent)
                } else {
                    Spacer()
                }

                Text("\(totalPages)")
                    .font(.system(size: 10).monospacedDigit())
                    .foregroundColor(.gray.opacity(0.6))

                // Progress percentage
                Text("\(progressPercent)%")
                    .font(.system(size: 11, weight: .medium).monospacedDigit())
                    .foregroundColor(goldAccent.opacity(0.7))
                    .frame(width: 40, alignment: .trailing)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 6)
            .background(Color(white: 0.05))
        }
        .background(nightMode ? Color.black : Color(white: 0.08))
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
        .onKeyPress(.leftArrow) {
            goToPage(currentPage - 1)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            goToPage(currentPage + 1)
            return .handled
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
        EPUBReaderView(
            book: book,
            nightMode: $nightMode,
            onClose: {
                saveProgress()
                onClose()
            },
            accountId: accountId
        )
    }

    private var bookmarkDialog: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 14))
                    .foregroundColor(goldAccent)
                Text("Add Bookmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }

            Text("Page \(currentPage)")
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundColor(.white.opacity(0.5))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .cornerRadius(4)

            TextField("Note (optional)", text: $bookmarkNote)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundColor(.white)
                .padding(10)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )

            HStack(spacing: 12) {
                Button("Cancel") {
                    showBookmarkDialog = false
                    bookmarkNote = ""
                }
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.gray)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Color.white.opacity(0.06))
                .cornerRadius(6)
                .buttonStyle(.plain)

                Button("Save Bookmark") {
                    if let aid = accountId {
                        BookDatabase.shared.addBookmark(
                            bookId: book.id,
                            page: currentPage,
                            note: bookmarkNote.isEmpty ? nil : bookmarkNote,
                            accountId: aid
                        )
                        isBookmarked = true
                    }
                    showBookmarkDialog = false
                    bookmarkNote = ""
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.black)
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(goldAccent)
                .cornerRadius(6)
                .buttonStyle(.plain)
            }
        }
        .padding(24)
        .frame(width: 320)
        .background(Color(white: 0.08))
    }

    // MARK: - Computed

    private var progressPercent: Int {
        guard totalPages > 0 else { return 0 }
        return min(Int(Double(currentPage) / Double(totalPages) * 100), 100)
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

    private func increaseFontSize() {
        // PDF doesn't have "font size" per se, but we can zoom in proportionally
        guard let pdfView = pdfView else { return }
        pdfView.scaleFactor *= 1.1
    }

    private func decreaseFontSize() {
        guard let pdfView = pdfView else { return }
        pdfView.scaleFactor *= 0.9
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
