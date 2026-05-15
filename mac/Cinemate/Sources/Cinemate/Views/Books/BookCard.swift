import SwiftUI
import AppKit

struct BookCard: View {
    let book: Book
    let onTap: () -> Void
    let onRead: () -> Void
    let onFavorite: () -> Void
    var onMarkFinished: (() -> Void)? = nil

    @State private var isHovered = false
    @State private var coverImage: NSImage?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottom) {
                // Cover image area — portrait book ratio
                Color(white: 0.12)
                    .aspectRatio(0.7, contentMode: .fit)
                    .overlay {
                        if let image = coverImage {
                            Image(nsImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .layoutPriority(-1)
                        } else {
                            // Gradient placeholder
                            LinearGradient(
                                colors: [book.formatBadgeColor.opacity(0.4), Color(white: 0.15)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                            .overlay {
                                VStack(spacing: 8) {
                                    Image(systemName: "book.closed.fill")
                                        .font(.system(size: 32))
                                        .foregroundColor(.white.opacity(0.3))
                                    Text(book.title)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.white.opacity(0.5))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(3)
                                        .padding(.horizontal, 8)
                                }
                            }
                        }
                    }
                    // Subtle book shadow for depth
                    .overlay(alignment: .trailing) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.clear, .black.opacity(0.15)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 6)
                    }
                    .overlay(alignment: .leading) {
                        Rectangle()
                            .fill(
                                LinearGradient(
                                    colors: [.black.opacity(0.1), .clear],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: 3)
                    }
                    // Hover overlay
                    .overlay {
                        if isHovered {
                            Color.black.opacity(0.5)
                            VStack(spacing: 10) {
                                Button(action: onRead) {
                                    HStack(spacing: 6) {
                                        Image(systemName: book.format == "PDF" ? "book.fill" : "arrow.up.forward.app")
                                            .font(.system(size: 14))
                                        Text(book.format == "PDF"
                                             ? (book.readingProgress > 0 && !book.finished ? "Resume" : "Read")
                                             : "Open in Books")
                                            .font(.system(size: 13, weight: .semibold))
                                    }
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(red: 0.95, green: 0.8, blue: 0.2))
                                    .cornerRadius(6)
                                }
                                .buttonStyle(.plain)

                                HStack(spacing: 12) {
                                    Button(action: onFavorite) {
                                        Image(systemName: book.favorite ? "heart.fill" : "heart")
                                            .font(.system(size: 16))
                                            .foregroundColor(book.favorite ? .red : .white)
                                    }
                                    .buttonStyle(.plain)

                                    Button(action: { onMarkFinished?() }) {
                                        Image(systemName: book.finished ? "checkmark.circle.fill" : "checkmark.circle")
                                            .font(.system(size: 16))
                                            .foregroundColor(book.finished ? .green : .white)
                                    }
                                    .buttonStyle(.plain)

                                    if book.pageCount > 0 {
                                        Text("\(book.pageCount)p")
                                            .font(.system(size: 10))
                                            .foregroundColor(.white.opacity(0.5))
                                    }
                                }
                            }
                        }
                    }
                    // Format badge
                    .overlay(alignment: .topTrailing) {
                        HStack(spacing: 4) {
                            Text(book.format)
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                                .background(book.formatBadgeColor.opacity(0.85))
                                .cornerRadius(4)

                            if book.finished {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16))
                                    .foregroundColor(.green)
                                    .shadow(radius: 2)
                            }
                        }
                        .padding(6)
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))

                // Reading progress bar
                if book.readingProgress > 0 && !book.finished {
                    GeometryReader { geo in
                        VStack {
                            Spacer()
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color(red: 0.95, green: 0.8, blue: 0.2))
                                .frame(width: geo.size.width * CGFloat(book.readingProgress), height: 3)
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) { isHovered = hovering }
            }
            .scaleEffect(isHovered ? 1.05 : 1.0)
            .shadow(color: .black.opacity(isHovered ? 0.4 : 0.2), radius: isHovered ? 12 : 4, y: isHovered ? 6 : 2)
            .animation(.easeInOut(duration: 0.15), value: isHovered)
            .contextMenu {
                Button(action: onRead) {
                    Label("Read", systemImage: "book.fill")
                }
                Button(action: {
                    NSWorkspace.shared.open(URL(fileURLWithPath: book.filePath))
                }) {
                    Label("Open in Books.app", systemImage: "arrow.up.forward.app")
                }
                Divider()
                Button(action: { onMarkFinished?() }) {
                    Label(
                        book.finished ? "Mark as Unfinished" : "Mark as Finished",
                        systemImage: book.finished ? "xmark.circle" : "checkmark.circle"
                    )
                }
                Button(action: onFavorite) {
                    Label(
                        book.favorite ? "Remove Favorite" : "Toggle Favorite",
                        systemImage: book.favorite ? "heart.slash.fill" : "heart"
                    )
                }
                Divider()
                Button(action: {
                    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: book.filePath)])
                }) {
                    Label("Show in Finder", systemImage: "folder")
                }
            }

            Text(book.title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 6) {
                if let author = book.author {
                    Text(author)
                        .foregroundColor(.gray)
                }
                if let year = book.year {
                    Text(String(year))
                        .foregroundColor(.gray.opacity(0.7))
                }
            }
            .font(.system(size: 11))
        }
        .task { await loadCover() }
    }

    private func loadCover() async {
        if let path = book.coverPath, FileManager.default.fileExists(atPath: path) {
            coverImage = NSImage(contentsOfFile: path)
        }
    }
}
