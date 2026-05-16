import SwiftUI
import PDFKit
import WebKit

struct BookReaderView: View {
    @EnvironmentObject var apiClient: APIClient
    let book: Book
    let account: Account

    @State private var currentPage: Int
    @State private var totalPages: Int = 0
    @State private var currentChapter: Int = 0
    @State private var totalChapters: Int = 0
    @State private var nightMode = true
    @State private var showControls = true
    @State private var isBookmarked = false
    @Environment(\.dismiss) var dismiss

    private var isEpub: Bool { book.format.uppercased() == "EPUB" }

    init(book: Book, account: Account) {
        self.book = book
        self.account = account
        _currentPage = State(initialValue: book.currentPage)
    }

    var body: some View {
        ZStack {
            (nightMode ? Color.black : Color(hex: "#1C1C1E"))
                .ignoresSafeArea()

            #if os(iOS)
            if isEpub {
                EPUBWebView(
                    url: apiClient.bookEpubURL(bookId: book.id, chapter: currentChapter),
                    nightMode: nightMode,
                    totalChapters: $totalChapters
                )
                .ignoresSafeArea(edges: .bottom)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showControls.toggle()
                    }
                }
            } else {
                PDFViewRepresentable(
                    url: apiClient.bookReadURL(bookId: book.id),
                    currentPage: $currentPage,
                    totalPages: $totalPages,
                    nightMode: nightMode
                )
                .ignoresSafeArea(edges: .bottom)
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showControls.toggle()
                    }
                }
            }
            #else
            Text("Reader requires iOS")
                .foregroundStyle(Theme.textSecondary)
            #endif

            if showControls {
                controlsOverlay
                    .transition(.opacity)
            }
        }
        .onDisappear {
            saveProgress()
        }
        .task {
            if isEpub {
                await loadTOC()
            }
        }
        .persistentSystemOverlays(.hidden)
    }

    private var controlsOverlay: some View {
        VStack {
            HStack(spacing: 16) {
                Button(action: {
                    saveProgress()
                    dismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                Spacer()

                Text(book.title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Spacer()

                Button(action: {
                    isBookmarked.toggle()
                    hapticImpact(.medium)
                    Task {
                        try? await apiClient.addBookBookmark(
                            accountId: Int(account.id) ?? 0,
                            bookId: book.id,
                            page: isEpub ? currentChapter : currentPage,
                            note: nil
                        )
                    }
                }) {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isBookmarked ? Theme.primaryGold : .white)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }

                Button(action: { nightMode.toggle() }) {
                    Image(systemName: nightMode ? "sun.max.fill" : "moon.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(nightMode ? Theme.warmAmber : .white)
                        .padding(10)
                        .background(.ultraThinMaterial)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Spacer()

            VStack(spacing: 8) {
                if isEpub && totalChapters > 1 {
                    HStack(spacing: 16) {
                        Button(action: {
                            if currentChapter > 0 {
                                currentChapter -= 1
                            }
                        }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(currentChapter > 0 ? .white : .white.opacity(0.3))
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .disabled(currentChapter <= 0)

                        Slider(
                            value: Binding(
                                get: { Double(currentChapter) },
                                set: { currentChapter = Int($0) }
                            ),
                            in: 0...Double(max(totalChapters - 1, 1)),
                            step: 1
                        )
                        .tint(Theme.primaryGold)

                        Button(action: {
                            if currentChapter < totalChapters - 1 {
                                currentChapter += 1
                            }
                        }) {
                            Image(systemName: "chevron.right")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(currentChapter < totalChapters - 1 ? .white : .white.opacity(0.3))
                                .padding(10)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                        .disabled(currentChapter >= totalChapters - 1)
                    }

                    Text("Chapter \(currentChapter + 1) of \(totalChapters)")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))

                } else if !isEpub {
                    if totalPages > 0 {
                        Slider(
                            value: Binding(
                                get: { Double(currentPage) },
                                set: { currentPage = Int($0) }
                            ),
                            in: 0...Double(max(totalPages - 1, 1)),
                            step: 1
                        )
                        .tint(Theme.primaryGold)
                    }

                    HStack {
                        Text("Page \(currentPage + 1)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                        Spacer()
                        if totalPages > 0 {
                            Text("of \(totalPages)")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                        }
                    }
                }
            }
            .padding()
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerMedium))
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
        .transition(.opacity)
    }

    private func saveProgress() {
        if isEpub {
            let progress = totalChapters > 0 ? Double(currentChapter) / Double(totalChapters) : 0
            Task {
                try? await apiClient.updateBookProgress(
                    accountId: Int(account.id) ?? 0,
                    bookId: book.id,
                    progress: progress,
                    page: currentChapter
                )
            }
        } else {
            let progress = book.pageCount > 0 ? Double(currentPage) / Double(book.pageCount) : 0
            Task {
                try? await apiClient.updateBookProgress(
                    accountId: Int(account.id) ?? 0,
                    bookId: book.id,
                    progress: progress,
                    page: currentPage
                )
            }
        }
    }

    private func loadTOC() async {
        guard let url = URL(string: "\(apiClient.baseURL)/api/books/read/\(book.id)/toc") else { return }
        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
               let total = json["total"] as? Int {
                totalChapters = total
                if currentChapter == 0, let firstContent = json["first_content_index"] as? Int {
                    currentChapter = firstContent
                }
            }
        } catch {}
    }
}

#if os(iOS)
struct EPUBWebView: UIViewRepresentable {
    let url: URL?
    let nightMode: Bool
    @Binding var totalChapters: Int

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = nightMode ? .black : UIColor(white: 0.98, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor
        webView.navigationDelegate = context.coordinator
        if let url {
            webView.load(URLRequest(url: url))
        }
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.backgroundColor = nightMode ? .black : UIColor(white: 0.98, alpha: 1)
        webView.scrollView.backgroundColor = webView.backgroundColor

        let bodyClass = nightMode ? "dark" : "light"
        webView.evaluateJavaScript("document.body.className = '\(bodyClass)'")

        if let url, context.coordinator.currentURL != url {
            context.coordinator.currentURL = url
            webView.load(URLRequest(url: url))
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: EPUBWebView
        var currentURL: URL?

        init(parent: EPUBWebView) {
            self.parent = parent
            self.currentURL = parent.url
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            if let response = webView.url {
                currentURL = response
            }
            if let totalStr = webView.value(forKey: "URL") as? URL {
                // Total chapters come from response headers, already loaded via TOC endpoint
            }
        }
    }
}
#endif

#Preview {
    BookReaderView(book: .preview, account: Account.previewAccounts[0])
        .environmentObject(APIClient())
}
