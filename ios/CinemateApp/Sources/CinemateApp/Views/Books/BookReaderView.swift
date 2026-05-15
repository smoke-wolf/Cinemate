import SwiftUI
import PDFKit

struct BookReaderView: View {
    @EnvironmentObject var apiClient: APIClient
    let book: Book

    @State private var currentPage: Int
    @State private var totalPages: Int = 0
    @State private var nightMode = false
    @State private var showControls = true
    @State private var isBookmarked = false
    @Environment(\.dismiss) var dismiss

    init(book: Book) {
        self.book = book
        _currentPage = State(initialValue: book.currentPage)
    }

    var body: some View {
        ZStack {
            // Background
            (nightMode ? Color.black : Color(hex: "#1C1C1E"))
                .ignoresSafeArea()

            // PDF View
            #if os(iOS)
            PDFViewRepresentable(
                url: book.fileURL.flatMap { apiClient.streamURL(for: $0) },
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
            #else
            Text("PDF Reader requires iOS")
                .foregroundStyle(Theme.textSecondary)
            #endif

            // Controls overlay
            if showControls {
                VStack {
                    // Top bar
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

                        // Bookmark
                        Button(action: {
                            isBookmarked.toggle()
                            hapticImpact(.medium)
                            Task {
                                try? await apiClient.addBookBookmark(
                                    bookId: book.id,
                                    page: currentPage,
                                    title: nil
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

                        // Night mode
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

                    // Bottom bar
                    VStack(spacing: 8) {
                        // Page slider
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
                    .padding()
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerMedium))
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .transition(.opacity)
            }
        }
        .onDisappear {
            saveProgress()
        }
        .persistentSystemOverlays(.hidden)
    }

    private func saveProgress() {
        Task {
            try? await apiClient.updateBookProgress(bookId: book.id, page: currentPage)
        }
    }
}

#Preview {
    BookReaderView(book: .preview)
        .environmentObject(APIClient())
}
