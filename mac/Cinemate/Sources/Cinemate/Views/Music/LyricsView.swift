import SwiftUI

struct LyricsView: View {
    @ObservedObject var lyricManager: LyricManager
    @ObservedObject var viewModel: MusicViewModel

    private let goldAccent = Color(red: 0.85, green: 0.65, blue: 0.13)

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()
                .background(Color.white.opacity(0.1))

            if lyricManager.lines.isEmpty {
                noLyricsView
            } else {
                lyricsScroll
            }
        }
        .frame(width: 340, height: 520)
        .background(Color(white: 0.08))
    }

    private var header: some View {
        HStack {
            Image(systemName: "quote.bubble")
                .font(.system(size: 12))
                .foregroundColor(goldAccent)

            Text("Lyrics")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            if let track = viewModel.nowPlaying.currentTrack {
                Text(track.title)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var noLyricsView: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "music.note.list")
                .font(.system(size: 36))
                .foregroundColor(.gray.opacity(0.3))
            Text("No lyrics available")
                .font(.system(size: 14))
                .foregroundColor(.gray.opacity(0.5))
            Text("Run lyric-matcher to generate LRC files")
                .font(.system(size: 11))
                .foregroundColor(.gray.opacity(0.3))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var lyricsScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 4) {
                    Spacer().frame(height: 180)

                    ForEach(lyricManager.lines) { line in
                        let isActive = line.id == lyricManager.currentLineIndex
                        let isPast = line.id < lyricManager.currentLineIndex

                        Text(line.text)
                            .font(.system(size: isActive ? 18 : 15, weight: isActive ? .bold : .medium))
                            .foregroundColor(
                                isActive ? .white :
                                isPast ? .white.opacity(0.25) :
                                .white.opacity(0.4)
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 6)
                            .id(line.id)
                            .onTapGesture {
                                viewModel.seek(to: line.time)
                            }
                    }

                    Spacer().frame(height: 200)
                }
            }
            .onChange(of: lyricManager.currentLineIndex) { _, newIndex in
                guard newIndex >= 0 else { return }
                withAnimation(.easeInOut(duration: 0.35)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
        }
    }
}
