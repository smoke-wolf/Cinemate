import SwiftUI
import PDFKit

struct PDFAsEbookView: View {
    let book: Book
    @Binding var nightMode: Bool
    let onClose: () -> Void
    var accountId: Int64? = nil

    @State private var pages: [String] = []
    @State private var currentChapter: Int = 0
    @State private var fontSize: CGFloat = 16
    @State private var isLoading = true
    @State private var scrollPosition: Int? = 0

    private let goldAccent = Color(red: 0.95, green: 0.8, blue: 0.2)

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack(spacing: 12) {
                Button(action: onClose) {
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

                HStack(spacing: 4) {
                    Image(systemName: "book.fill")
                        .font(.system(size: 11))
                    Text("eBook Mode")
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(goldAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(goldAccent.opacity(0.15))
                .cornerRadius(5)

                Spacer()

                HStack(spacing: 8) {
                    Button(action: { fontSize = max(12, fontSize - 1) }) {
                        Image(systemName: "textformat.size.smaller")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)

                    Text("\(Int(fontSize))pt")
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundColor(.white.opacity(0.5))
                        .frame(width: 32)

                    Button(action: { fontSize = min(28, fontSize + 1) }) {
                        Image(systemName: "textformat.size.larger")
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)

                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 1, height: 18)

                    Button(action: { nightMode.toggle() }) {
                        Image(systemName: nightMode ? "sun.max.fill" : "moon.fill")
                            .font(.system(size: 13))
                            .foregroundColor(nightMode ? .yellow : .white.opacity(0.7))
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(5)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color(white: 0.05))

            if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .controlSize(.large)
                    Text("Extracting text from PDF...")
                        .font(.system(size: 14))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if pages.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "doc.text.magnifyingglass")
                        .font(.system(size: 48))
                        .foregroundColor(.gray)
                    Text("Could not extract text from this PDF")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.gray)
                    Text("This PDF may contain scanned images instead of text")
                        .font(.system(size: 13))
                        .foregroundColor(.gray.opacity(0.7))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(Array(pages.enumerated()), id: \.offset) { index, pageText in
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Page \(index + 1)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(goldAccent.opacity(0.4))
                                    .textCase(.uppercase)
                                    .tracking(1)
                                    .id(index)

                                Text(pageText)
                                    .font(.system(size: fontSize, design: .serif))
                                    .foregroundColor(nightMode ? .white.opacity(0.85) : Color(white: 0.15))
                                    .lineSpacing(fontSize * 0.5)
                                    .textSelection(.enabled)
                            }
                            .padding(.horizontal, 60)

                            if index < pages.count - 1 {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(height: 1)
                                    .padding(.horizontal, 80)
                            }
                        }
                    }
                    .padding(.vertical, 32)
                }
                .scrollPosition(id: $scrollPosition)
            }
        }
        .background(nightMode ? Color(white: 0.06) : Color(white: 0.95))
        .onAppear { extractText() }
        .onKeyPress(.escape) {
            onClose()
            return .handled
        }
    }

    private func extractText() {
        DispatchQueue.global(qos: .userInitiated).async {
            let url = URL(fileURLWithPath: book.filePath)
            guard let document = PDFDocument(url: url) else {
                DispatchQueue.main.async { isLoading = false }
                return
            }

            var extracted: [String] = []
            for i in 0..<document.pageCount {
                if let page = document.page(at: i), let text = page.string {
                    let cleaned = text
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if !cleaned.isEmpty {
                        extracted.append(cleaned)
                    }
                }
            }

            DispatchQueue.main.async {
                pages = extracted
                isLoading = false
            }
        }
    }
}
