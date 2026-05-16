import SwiftUI
import WebKit

// MARK: - EPUB Parser

class EPUBParser {
    struct Chapter: Identifiable {
        let id: Int
        let title: String
        let href: String
        let fullPath: URL
    }

    let extractDir: URL
    var chapters: [Chapter] = []
    var title: String = ""
    var contentBasePath: URL

    init?(epubPath: String) {
        let fm = FileManager.default
        let tmp = fm.temporaryDirectory.appendingPathComponent("cinemate_epub_\(UUID().uuidString)")
        self.extractDir = tmp
        self.contentBasePath = tmp

        do {
            try fm.createDirectory(at: tmp, withIntermediateDirectories: true)
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-o", "-q", epubPath, "-d", tmp.path]
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else { return nil }
        } catch { return nil }

        guard let containerURL = findFile(named: "container.xml", in: tmp) else { return nil }
        guard let containerData = try? Data(contentsOf: containerURL),
              let containerStr = String(data: containerData, encoding: .utf8) else { return nil }

        guard let rootfilePath = parseAttribute(xml: containerStr, tag: "rootfile", attribute: "full-path") else { return nil }
        let opfURL = tmp.appendingPathComponent(rootfilePath)
        self.contentBasePath = opfURL.deletingLastPathComponent()

        guard let opfData = try? Data(contentsOf: opfURL),
              let opfStr = String(data: opfData, encoding: .utf8) else { return nil }

        let manifest = parseManifest(opf: opfStr)
        let spineIds = parseSpine(opf: opfStr)
        self.title = parseTitle(opf: opfStr) ?? "Unknown"

        for (index, idref) in spineIds.enumerated() {
            guard let href = manifest[idref] else { continue }
            let fullPath = contentBasePath.appendingPathComponent(href)
            guard FileManager.default.fileExists(atPath: fullPath.path) else { continue }
            let chTitle = "Chapter \(index + 1)"
            chapters.append(Chapter(id: index, title: chTitle, href: href, fullPath: fullPath))
        }
    }

    private func findFile(named name: String, in dir: URL) -> URL? {
        let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil)
        while let url = enumerator?.nextObject() as? URL {
            if url.lastPathComponent == name { return url }
        }
        return nil
    }

    private func parseAttribute(xml: String, tag: String, attribute: String) -> String? {
        guard let tagRange = xml.range(of: "<\(tag)") else { return nil }
        let after = xml[tagRange.upperBound...]
        let attrPattern = "\(attribute)=\""
        guard let attrStart = after.range(of: attrPattern) else { return nil }
        let valueStart = after[attrStart.upperBound...]
        guard let quoteEnd = valueStart.firstIndex(of: "\"") else { return nil }
        return String(valueStart[..<quoteEnd])
    }

    private func parseManifest(opf: String) -> [String: String] {
        var result: [String: String] = [:]
        var search = opf[...]
        while let itemRange = search.range(of: "<item ") {
            let rest = search[itemRange.upperBound...]
            guard let closeRange = rest.range(of: "/>") ?? rest.range(of: ">") else { break }
            let tag = String(rest[..<closeRange.lowerBound])

            if let id = extractAttr(tag, "id"), let href = extractAttr(tag, "href") {
                result[id] = href.removingPercentEncoding ?? href
            }
            search = rest[closeRange.upperBound...]
        }
        return result
    }

    private func parseSpine(opf: String) -> [String] {
        var result: [String] = []
        var search = opf[...]
        while let itemRange = search.range(of: "<itemref ") {
            let rest = search[itemRange.upperBound...]
            guard let closeRange = rest.range(of: "/>") ?? rest.range(of: ">") else { break }
            let tag = String(rest[..<closeRange.lowerBound])
            if let idref = extractAttr(tag, "idref") {
                result.append(idref)
            }
            search = rest[closeRange.upperBound...]
        }
        return result
    }

    private func parseTitle(opf: String) -> String? {
        guard let start = opf.range(of: "<dc:title>") ?? opf.range(of: "<dc:title ") else { return nil }
        let after: Substring
        if opf[start].description.last == ">" {
            after = opf[start.upperBound...]
        } else {
            guard let gt = opf[start.upperBound...].range(of: ">") else { return nil }
            after = opf[gt.upperBound...]
        }
        guard let end = after.range(of: "</dc:title>") else { return nil }
        return String(after[..<end.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractAttr(_ tag: String, _ attr: String) -> String? {
        let patterns = ["\(attr)=\"", "\(attr)='"]
        for pattern in patterns {
            guard let start = tag.range(of: pattern) else { continue }
            let rest = tag[start.upperBound...]
            let quote: Character = pattern.last == "\"" ? "\"" : "'"
            guard let end = rest.firstIndex(of: quote) else { continue }
            return String(rest[..<end])
        }
        return nil
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: extractDir)
    }
}

// MARK: - WebView

struct EPUBWebView: NSViewRepresentable {
    let htmlURL: URL
    let baseURL: URL
    let nightMode: Bool
    let fontSize: Int

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        loadContent(webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        let js = """
        document.body.style.backgroundColor = '\(nightMode ? "#0a0a0a" : "#1a1a1a")';
        document.body.style.color = '\(nightMode ? "#c8c8c8" : "#d4d4d4")';
        document.body.style.fontSize = '\(fontSize)px';
        document.querySelectorAll('img').forEach(i => { i.style.maxWidth = '100%'; });
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    private func loadContent(_ webView: WKWebView) {
        guard let htmlData = try? Data(contentsOf: htmlURL),
              var htmlStr = String(data: htmlData, encoding: .utf8) else { return }

        let css = """
        <style>
        * { box-sizing: border-box; }
        body {
            background-color: \(nightMode ? "#0a0a0a" : "#1a1a1a");
            color: \(nightMode ? "#c8c8c8" : "#d4d4d4");
            font-family: -apple-system, 'Georgia', serif;
            font-size: \(fontSize)px;
            line-height: 1.8;
            max-width: 750px;
            margin: 0 auto;
            padding: 40px 30px 80px;
            -webkit-font-smoothing: antialiased;
        }
        h1, h2, h3, h4, h5, h6 {
            color: \(nightMode ? "#e8e8e8" : "#f0f0f0");
            line-height: 1.3;
            margin-top: 1.5em;
        }
        a { color: #d4a836; }
        img { max-width: 100%; height: auto; border-radius: 4px; }
        blockquote {
            border-left: 3px solid #d4a836;
            margin-left: 0;
            padding-left: 20px;
            color: \(nightMode ? "#999" : "#aaa");
            font-style: italic;
        }
        pre, code {
            background: rgba(255,255,255,0.05);
            padding: 2px 6px;
            border-radius: 3px;
            font-size: 0.9em;
        }
        ::selection { background: rgba(212, 168, 54, 0.3); }
        </style>
        """

        if let headEnd = htmlStr.range(of: "</head>", options: .caseInsensitive) {
            htmlStr.insert(contentsOf: css, at: headEnd.lowerBound)
        } else if let bodyStart = htmlStr.range(of: "<body", options: .caseInsensitive) {
            htmlStr.insert(contentsOf: "<head>\(css)</head>", at: bodyStart.lowerBound)
        } else {
            htmlStr = "<html><head>\(css)</head><body>\(htmlStr)</body></html>"
        }

        let styledFile = baseURL.appendingPathComponent("_cinemate_styled_\(htmlURL.lastPathComponent)")
        try? htmlStr.data(using: .utf8)?.write(to: styledFile)
        webView.loadFileURL(styledFile, allowingReadAccessTo: baseURL)
    }
}

// MARK: - EPUB Reader View

struct EPUBReaderView: View {
    let book: Book
    @Binding var nightMode: Bool
    let onClose: () -> Void
    var accountId: Int64?

    @State private var parser: EPUBParser?
    @State private var currentChapter: Int = 0
    @State private var fontSize: Int = 18
    @State private var showTOC = false
    @State private var loading = true

    private let goldAccent = Color(red: 0.95, green: 0.8, blue: 0.2)

    var body: some View {
        VStack(spacing: 0) {
            topBar
            progressBar

            if loading {
                Spacer()
                ProgressView()
                    .scaleEffect(1.2)
                    .tint(goldAccent)
                Spacer()
            } else if let parser, !parser.chapters.isEmpty {
                EPUBWebView(
                    htmlURL: parser.chapters[currentChapter].fullPath,
                    baseURL: parser.contentBasePath,
                    nightMode: nightMode,
                    fontSize: fontSize
                )
                .id("\(currentChapter)_\(nightMode)_\(fontSize)")
            } else {
                Spacer()
                Text("Could not parse EPUB")
                    .foregroundColor(.gray)
                Spacer()
            }

            bottomBar
        }
        .background(nightMode ? Color.black : Color(white: 0.08))
        .task { await loadEPUB() }
        .onDisappear { saveProgress(); parser?.cleanup() }
        .onKeyPress(.leftArrow) { prevChapter(); return .handled }
        .onKeyPress(.rightArrow) { nextChapter(); return .handled }
        .onKeyPress(.escape) { onClose(); return .handled }
        .sheet(isPresented: $showTOC) { tocSheet }
    }

    // MARK: - Top Bar

    private var topBar: some View {
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

            if let parser, !parser.chapters.isEmpty {
                Text("Chapter \(currentChapter + 1) of \(parser.chapters.count)")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundColor(.white.opacity(0.6))
            }

            Spacer()

            HStack(spacing: 8) {
                Button(action: { showTOC = true }) {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)
                .help("Table of Contents")

                Button(action: { fontSize = max(12, fontSize - 2) }) {
                    Image(systemName: "textformat.size.smaller")
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.7))
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(5)
                }
                .buttonStyle(.plain)

                Button(action: { fontSize = min(32, fontSize + 2) }) {
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
    }

    // MARK: - Progress Bar

    private var progressBar: some View {
        GeometryReader { geo in
            Rectangle()
                .fill(goldAccent.opacity(0.6))
                .frame(width: totalChapters > 0 ? geo.size.width * CGFloat(currentChapter + 1) / CGFloat(totalChapters) : 0, height: 2)
                .animation(.easeInOut(duration: 0.2), value: currentChapter)
        }
        .frame(height: 2)
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        HStack(spacing: 16) {
            Button(action: prevChapter) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .semibold))
                    Text("Previous")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundColor(currentChapter > 0 ? .white.opacity(0.7) : .gray.opacity(0.3))
            }
            .buttonStyle(.plain)
            .disabled(currentChapter <= 0)

            Spacer()

            Text("\(progressPercent)%")
                .font(.system(size: 11, weight: .medium).monospacedDigit())
                .foregroundColor(goldAccent.opacity(0.7))

            Spacer()

            Button(action: nextChapter) {
                HStack(spacing: 4) {
                    Text("Next")
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(currentChapter < totalChapters - 1 ? .white.opacity(0.7) : .gray.opacity(0.3))
            }
            .buttonStyle(.plain)
            .disabled(currentChapter >= totalChapters - 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
        .background(Color(white: 0.05))
    }

    // MARK: - TOC Sheet

    private var tocSheet: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Contents")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Button("Done") { showTOC = false }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(goldAccent)
                    .buttonStyle(.plain)
            }
            .padding(16)

            Divider().background(Color.gray.opacity(0.2))

            ScrollView {
                VStack(spacing: 0) {
                    if let parser {
                        ForEach(parser.chapters) { ch in
                            Button(action: {
                                currentChapter = ch.id
                                showTOC = false
                                saveProgress()
                            }) {
                                HStack {
                                    Text(ch.title)
                                        .font(.system(size: 14, weight: ch.id == currentChapter ? .bold : .regular))
                                        .foregroundColor(ch.id == currentChapter ? goldAccent : .white)
                                    Spacer()
                                    if ch.id == currentChapter {
                                        Image(systemName: "book.fill")
                                            .font(.system(size: 11))
                                            .foregroundColor(goldAccent)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(ch.id == currentChapter ? goldAccent.opacity(0.08) : Color.clear)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)

                            if ch.id < (parser.chapters.count - 1) {
                                Divider().background(Color.gray.opacity(0.1)).padding(.leading, 16)
                            }
                        }
                    }
                }
            }
        }
        .frame(width: 360, height: 500)
        .background(Color(white: 0.08))
    }

    // MARK: - Computed

    private var totalChapters: Int {
        parser?.chapters.count ?? 0
    }

    private var progressPercent: Int {
        guard totalChapters > 0 else { return 0 }
        return min(Int(Double(currentChapter + 1) / Double(totalChapters) * 100), 100)
    }

    // MARK: - Actions

    private func loadEPUB() async {
        let path = book.filePath
        let parsed = await Task.detached {
            EPUBParser(epubPath: path)
        }.value

        await MainActor.run {
            self.parser = parsed
            if book.currentPage > 0 && book.currentPage <= (parsed?.chapters.count ?? 0) {
                self.currentChapter = book.currentPage - 1
            }
            self.loading = false
        }
    }

    private func nextChapter() {
        guard currentChapter < totalChapters - 1 else { return }
        currentChapter += 1
        saveProgress()
    }

    private func prevChapter() {
        guard currentChapter > 0 else { return }
        currentChapter -= 1
        saveProgress()
    }

    private func saveProgress() {
        guard totalChapters > 0 else { return }
        let progress = Double(currentChapter + 1) / Double(totalChapters)
        BookDatabase.shared.updateProgress(
            bookId: book.id,
            progress: progress,
            currentPage: currentChapter + 1,
            accountId: accountId
        )
    }
}
