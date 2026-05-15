import SwiftUI

struct BookDetailView: View {
    let book: Book
    let onRead: () -> Void
    let onFavorite: () -> Void
    let onMarkFinished: () -> Void
    let onOpenInBooks: () -> Void
    @ObservedObject var viewModel: BookViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var coverImage: NSImage?
    @State private var showFullDescription = false
    @State private var bookmarks: [BookBookmark] = []
    @State private var selectedVoice = "af_bella"
    @State private var ttsSpeed: Double = 1.0

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 20) {
                        // Top section: cover + info
                        HStack(alignment: .top, spacing: 24) {
                            // Cover image
                            ZStack {
                                Color(white: 0.12)
                                if let image = coverImage {
                                    Image(nsImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                } else {
                                    LinearGradient(
                                        colors: [book.formatBadgeColor.opacity(0.4), Color(white: 0.15)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                    .overlay {
                                        VStack(spacing: 8) {
                                            Image(systemName: "book.closed.fill")
                                                .font(.system(size: 36))
                                                .foregroundColor(.white.opacity(0.3))
                                            Text(book.title)
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.white.opacity(0.5))
                                                .multilineTextAlignment(.center)
                                                .lineLimit(3)
                                                .padding(.horizontal, 12)
                                        }
                                    }
                                }
                            }
                            .frame(width: 200, height: 280)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .shadow(color: .black.opacity(0.4), radius: 10, y: 4)

                            // Book info
                            VStack(alignment: .leading, spacing: 10) {
                                Text(book.title)
                                    .font(.system(size: 24, weight: .bold))
                                    .foregroundColor(.white)

                                if let author = book.author {
                                    Text(author)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundColor(.white.opacity(0.7))
                                }

                                HStack(spacing: 8) {
                                    if let genre = book.genre, !genre.isEmpty {
                                        Text(genre)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 3)
                                            .background(Color.white.opacity(0.1))
                                            .cornerRadius(4)
                                    }
                                    Text(book.format)
                                        .font(.system(size: 11, weight: .bold))
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 3)
                                        .background(book.formatBadgeColor.opacity(0.7))
                                        .cornerRadius(4)
                                    if let year = book.year {
                                        Text(String(year))
                                    }
                                }
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.8))

                                // Reading progress
                                if book.readingProgress > 0 {
                                    VStack(alignment: .leading, spacing: 4) {
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color.white.opacity(0.15))
                                                    .frame(height: 6)
                                                RoundedRectangle(cornerRadius: 3)
                                                    .fill(Color(red: 0.95, green: 0.8, blue: 0.2))
                                                    .frame(width: geo.size.width * CGFloat(book.readingProgress), height: 6)
                                            }
                                        }
                                        .frame(height: 6)

                                        if book.pageCount > 0 {
                                            Text("Page \(book.pagesReadEstimate) of \(book.pageCount) (\(book.progressPercent)%)")
                                                .font(.system(size: 11))
                                                .foregroundColor(.white.opacity(0.5))
                                        } else {
                                            Text("\(book.progressPercent)% complete")
                                                .font(.system(size: 11))
                                                .foregroundColor(.white.opacity(0.5))
                                        }
                                    }
                                    .padding(.top, 4)
                                }

                                // Action buttons
                                HStack(spacing: 10) {
                                    if book.format == "PDF" {
                                        Button(action: {
                                            onRead()
                                            dismiss()
                                        }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "book.fill")
                                                Text(book.readingProgress > 0 && !book.finished ? "Resume" : "Read")
                                            }
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.black)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(Color(red: 0.95, green: 0.8, blue: 0.2))
                                            .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    } else {
                                        Button(action: {
                                            onOpenInBooks()
                                        }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "arrow.up.forward.app")
                                                Text("Open in Books.app")
                                            }
                                            .font(.system(size: 15, weight: .semibold))
                                            .foregroundColor(.black)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .background(Color(red: 0.95, green: 0.8, blue: 0.2))
                                            .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)
                                    }

                                    Button(action: onMarkFinished) {
                                        Image(systemName: book.finished ? "checkmark.circle.fill" : "checkmark.circle")
                                            .font(.system(size: 16))
                                            .foregroundColor(book.finished ? .green : .white)
                                            .frame(width: 44, height: 40)
                                            .background(Color.white.opacity(0.12))
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)

                                    Button(action: onFavorite) {
                                        Image(systemName: book.favorite ? "heart.fill" : "heart")
                                            .font(.system(size: 16))
                                            .foregroundColor(book.favorite ? .red : .white)
                                            .frame(width: 44, height: 40)
                                            .background(Color.white.opacity(0.12))
                                            .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.top, 8)

                                Spacer()
                            }
                        }
                        .padding(24)

                        // Description
                        if let desc = book.description_, !desc.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(desc)
                                    .font(.system(size: 13))
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineSpacing(4)
                                    .lineLimit(showFullDescription ? nil : 4)

                                if desc.count > 200 {
                                    Button(action: { showFullDescription.toggle() }) {
                                        Text(showFullDescription ? "Show Less" : "Show More")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(Color(red: 0.95, green: 0.8, blue: 0.2))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        Divider().background(Color.gray.opacity(0.2)).padding(.horizontal, 24)

                        // Details
                        VStack(alignment: .leading, spacing: 6) {
                            if let publisher = book.publisher, !publisher.isEmpty {
                                DetailInfoRow(label: "Publisher", value: publisher)
                            }
                            if let language = book.language, !language.isEmpty {
                                DetailInfoRow(label: "Language", value: language)
                            }
                            if book.pageCount > 0 {
                                DetailInfoRow(label: "Pages", value: "\(book.pageCount)")
                            }
                            DetailInfoRow(label: "Format", value: "\(book.format) \u{00B7} \(book.fileSizeFormatted)")
                            DetailInfoRow(label: "Added", value: book.dateAdded.formatted(date: .abbreviated, time: .omitted))
                            if !book.readingTimeFormatted.isEmpty {
                                DetailInfoRow(label: "Reading Time", value: book.readingTimeFormatted)
                            }
                            if book.finished, let finishedAt = book.finishedAt {
                                DetailInfoRow(label: "Finished", value: finishedAt.formatted(date: .abbreviated, time: .omitted))
                            }
                        }
                        .padding(.horizontal, 24)

                        // Audiobook / TTS section
                        Divider().background(Color.gray.opacity(0.2)).padding(.horizontal, 24)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: "waveform")
                                    .font(.system(size: 14))
                                    .foregroundColor(Color(red: 0.95, green: 0.8, blue: 0.2))
                                Text("Audiobook")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)
                            }

                            if !viewModel.ttsInstalled {
                                HStack(spacing: 12) {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("TTS Engine Not Installed")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.white.opacity(0.7))
                                        Text("Kokoro TTS — high-quality neural voice, ~100 MB")
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                    }
                                    Spacer()
                                    Button(action: { viewModel.installTTS() }) {
                                        HStack(spacing: 6) {
                                            if viewModel.ttsInstalling {
                                                ProgressView()
                                                    .controlSize(.small)
                                            } else {
                                                Image(systemName: "arrow.down.circle.fill")
                                            }
                                            Text(viewModel.ttsInstalling ? "Installing..." : "Install TTS")
                                        }
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(Color(red: 0.95, green: 0.8, blue: 0.2))
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(viewModel.ttsInstalling)
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(8)

                                if !viewModel.ttsInstallLog.isEmpty {
                                    Text(viewModel.ttsInstallLog)
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                        .lineLimit(2)
                                }
                            } else if viewModel.audiobookExists(for: book) {
                                if let meta = viewModel.audiobookMetadata(for: book) {
                                    VStack(alignment: .leading, spacing: 8) {
                                        HStack {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundColor(.green)
                                                .font(.system(size: 14))
                                            Text("Audiobook Ready")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(.white.opacity(0.8))
                                            Spacer()
                                            Text("\(meta.totalChapters) chapters \u{00B7} \(meta.totalDurationDisplay)")
                                                .font(.system(size: 11))
                                                .foregroundColor(.gray)
                                        }

                                        Button(action: {
                                            let dir = viewModel.audiobookDirectory(for: book)
                                            NSWorkspace.shared.open(URL(fileURLWithPath: dir))
                                        }) {
                                            HStack(spacing: 6) {
                                                Image(systemName: "headphones")
                                                Text("Open Audiobook Folder")
                                            }
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.black)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(Color(red: 0.95, green: 0.8, blue: 0.2))
                                            .cornerRadius(6)
                                        }
                                        .buttonStyle(.plain)

                                        ForEach(meta.chapters.prefix(5)) { chapter in
                                            HStack(spacing: 8) {
                                                Text("\(chapter.index).")
                                                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                                                    .foregroundColor(Color(red: 0.95, green: 0.8, blue: 0.2))
                                                    .frame(width: 24, alignment: .trailing)
                                                Text(chapter.title)
                                                    .font(.system(size: 11))
                                                    .foregroundColor(.white.opacity(0.7))
                                                    .lineLimit(1)
                                                Spacer()
                                                Text(chapter.durationDisplay)
                                                    .font(.system(size: 11, design: .monospaced))
                                                    .foregroundColor(.gray)
                                            }
                                        }

                                        if meta.chapters.count > 5 {
                                            Text("+ \(meta.chapters.count - 5) more chapters")
                                                .font(.system(size: 11))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.04))
                                    .cornerRadius(8)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 10) {
                                    HStack(spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Voice")
                                                .font(.system(size: 11))
                                                .foregroundColor(.gray)
                                            Picker("", selection: $selectedVoice) {
                                                ForEach(TTSVoice.allVoices) { v in
                                                    Text("\(v.name) (\(v.accent))")
                                                        .tag(v.id)
                                                }
                                            }
                                            .labelsHidden()
                                            .frame(width: 160)
                                        }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text("Speed")
                                                .font(.system(size: 11))
                                                .foregroundColor(.gray)
                                            HStack(spacing: 6) {
                                                Slider(value: $ttsSpeed, in: 0.5...2.0, step: 0.1)
                                                    .frame(width: 100)
                                                Text(String(format: "%.1fx", ttsSpeed))
                                                    .font(.system(size: 11, design: .monospaced))
                                                    .foregroundColor(.white.opacity(0.7))
                                                    .frame(width: 32)
                                            }
                                        }

                                        Spacer()
                                    }

                                    Button(action: {
                                        viewModel.generateAudiobook(book, voice: selectedVoice, speed: ttsSpeed)
                                    }) {
                                        HStack(spacing: 6) {
                                            if viewModel.ttsGenerating {
                                                ProgressView()
                                                    .controlSize(.small)
                                            } else {
                                                Image(systemName: "waveform.badge.plus")
                                            }
                                            Text(viewModel.ttsGenerating ? "Generating..." : "Generate Audiobook")
                                        }
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(.black)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Color(red: 0.95, green: 0.8, blue: 0.2))
                                        .cornerRadius(6)
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(viewModel.ttsGenerating)

                                    if viewModel.ttsGenerating {
                                        VStack(alignment: .leading, spacing: 4) {
                                            if viewModel.ttsChapterProgress.total > 0 {
                                                GeometryReader { geo in
                                                    ZStack(alignment: .leading) {
                                                        RoundedRectangle(cornerRadius: 3)
                                                            .fill(Color.white.opacity(0.15))
                                                            .frame(height: 6)
                                                        RoundedRectangle(cornerRadius: 3)
                                                            .fill(Color(red: 0.95, green: 0.8, blue: 0.2))
                                                            .frame(
                                                                width: geo.size.width * CGFloat(viewModel.ttsChapterProgress.current) / CGFloat(max(viewModel.ttsChapterProgress.total, 1)),
                                                                height: 6
                                                            )
                                                    }
                                                }
                                                .frame(height: 6)
                                            }
                                            Text(viewModel.ttsProgress)
                                                .font(.system(size: 11))
                                                .foregroundColor(.gray)
                                        }
                                    }
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.04))
                                .cornerRadius(8)
                            }
                        }
                        .padding(.horizontal, 24)

                        // Bookmarks section
                        if !bookmarks.isEmpty {
                            Divider().background(Color.gray.opacity(0.2)).padding(.horizontal, 24)

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Bookmarks")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.white)

                                ForEach(bookmarks) { bookmark in
                                    HStack(spacing: 10) {
                                        Image(systemName: "bookmark.fill")
                                            .font(.system(size: 12))
                                            .foregroundColor(Color(red: 0.95, green: 0.8, blue: 0.2))

                                        Text("Page \(bookmark.page)")
                                            .font(.system(size: 12, weight: .semibold))
                                            .foregroundColor(.white.opacity(0.8))

                                        if let note = bookmark.note, !note.isEmpty {
                                            Text(note)
                                                .font(.system(size: 12))
                                                .foregroundColor(.white.opacity(0.6))
                                                .lineLimit(1)
                                        }

                                        Spacer()

                                        Text(bookmark.createdAt.formatted(date: .abbreviated, time: .omitted))
                                            .font(.system(size: 11))
                                            .foregroundColor(.gray)
                                    }
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 10)
                                    .background(Color.white.opacity(0.04))
                                    .cornerRadius(6)
                                }
                            }
                            .padding(.horizontal, 24)
                        }

                        Spacer(minLength: 24)
                    }
                }
            }

            // Close button
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .padding(12)
        }
        .frame(width: 700, height: 600)
        .background(Color(white: 0.06))
        .task {
            await loadCover()
            loadBookmarks()
            viewModel.checkTTSInstalled()
        }
    }

    private func loadCover() async {
        if let path = book.coverPath, FileManager.default.fileExists(atPath: path) {
            coverImage = NSImage(contentsOfFile: path)
        }
    }

    private func loadBookmarks() {
        bookmarks = BookDatabase.shared.bookmarks(forBook: book.id, accountId: nil)
    }
}
