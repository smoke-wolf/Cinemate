import SwiftUI
import UniformTypeIdentifiers

struct NowPlayingBar: View {
    @ObservedObject var viewModel: MusicViewModel

    @State private var isDraggingSeek = false
    @State private var seekDragValue: Double = 0
    @State private var showQueuePopover = false

    private let goldAccent = Color(red: 0.85, green: 0.65, blue: 0.13)
    private let barHeight: CGFloat = 64

    var body: some View {
        if viewModel.nowPlaying.currentTrack != nil {
            VStack(spacing: 0) {
                // Top border
                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 1)

                HStack(spacing: 0) {
                    // Left: Track info
                    trackInfoSection
                        .frame(width: 240, alignment: .leading)

                    Spacer()

                    // Center: Controls + seek bar
                    VStack(spacing: 4) {
                        controlsSection
                        seekBarSection
                    }
                    .frame(maxWidth: 500)

                    Spacer()

                    // Right: Volume + extras
                    rightSection
                        .frame(width: 200, alignment: .trailing)
                }
                .padding(.horizontal, 16)
                .frame(height: barHeight)
            }
            .background(Color(white: 0.07))
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Track Info (Left)

    private var trackInfoSection: some View {
        HStack(spacing: 12) {
            ZStack {
                if let artPath = viewModel.nowPlaying.currentTrack?.albumArtPath,
                   let image = NSImage(contentsOfFile: artPath) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 48, height: 48)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                } else {
                    let title = viewModel.nowPlaying.currentTrack?.title ?? ""
                    let artist = viewModel.nowPlaying.currentTrack?.artist ?? ""
                    let hash = abs((title + artist).hashValue)
                    let hue = Double(hash % 360) / 360.0
                    RoundedRectangle(cornerRadius: 6)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hue: hue, saturation: 0.5, brightness: 0.35),
                                    Color(hue: hue, saturation: 0.6, brightness: 0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 48, height: 48)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 16))
                                .foregroundColor(.white.opacity(0.4))
                        }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(viewModel.nowPlaying.currentTrack?.title ?? "")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(viewModel.nowPlaying.currentTrack?.artist ?? "")
                    .font(.system(size: 12))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            // Favorite button
            if let track = viewModel.nowPlaying.currentTrack {
                Button(action: { viewModel.toggleFavorite(track) }) {
                    Image(systemName: track.favorite ? "heart.fill" : "heart")
                        .font(.system(size: 12))
                        .foregroundColor(track.favorite ? .red : .gray.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Playback Controls (Center)

    private var controlsSection: some View {
        HStack(spacing: 20) {
            // Shuffle
            Button(action: { viewModel.toggleShuffle() }) {
                Image(systemName: "shuffle")
                    .font(.system(size: 12))
                    .foregroundColor(viewModel.nowPlaying.shuffle ? goldAccent : .gray)
            }
            .buttonStyle(.plain)

            // Previous
            Button(action: { viewModel.previous() }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)

            // Play/Pause
            Button(action: { viewModel.togglePlayPause() }) {
                ZStack {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 32, height: 32)

                    Image(systemName: viewModel.nowPlaying.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.black)
                        .offset(x: viewModel.nowPlaying.isPlaying ? 0 : 1)
                }
            }
            .buttonStyle(.plain)

            // Next
            Button(action: { viewModel.next() }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.white)
            }
            .buttonStyle(.plain)

            // Repeat
            Button(action: { viewModel.cycleRepeat() }) {
                Image(systemName: repeatIcon)
                    .font(.system(size: 12))
                    .foregroundColor(viewModel.nowPlaying.repeatMode != .off ? goldAccent : .gray)
            }
            .buttonStyle(.plain)
        }
    }

    private var repeatIcon: String {
        switch viewModel.nowPlaying.repeatMode {
        case .off: return "repeat"
        case .all: return "repeat"
        case .one: return "repeat.1"
        }
    }

    // MARK: - Seek Bar (Center below controls)

    private var seekBarSection: some View {
        HStack(spacing: 8) {
            Text(viewModel.nowPlaying.progressFormatted)
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 40, alignment: .trailing)

            GeometryReader { geo in
                let totalWidth = geo.size.width
                let currentProgress = isDraggingSeek ? seekDragValue : viewModel.nowPlaying.progressPercent
                let fillWidth = totalWidth * CGFloat(currentProgress)

                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.15))
                        .frame(height: 4)

                    // Progress fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white)
                        .frame(width: max(0, fillWidth), height: 4)
                }
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            isDraggingSeek = true
                            seekDragValue = max(0, min(1, Double(value.location.x / totalWidth)))
                        }
                        .onEnded { value in
                            let percent = max(0, min(1, Double(value.location.x / totalWidth)))
                            if let track = viewModel.nowPlaying.currentTrack {
                                viewModel.seek(to: track.duration * percent)
                            }
                            isDraggingSeek = false
                        }
                )
            }
            .frame(height: 4)

            Text(viewModel.nowPlaying.currentTrack?.durationFormatted ?? "0:00")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.gray)
                .frame(width: 40, alignment: .leading)
        }
    }

    // MARK: - Right Section (Volume + Queue)

    private var rightSection: some View {
        HStack(spacing: 12) {
            // Queue button
            Button(action: { showQueuePopover.toggle() }) {
                Image(systemName: "list.bullet")
                    .font(.system(size: 13))
                    .foregroundColor(showQueuePopover ? goldAccent : .gray)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showQueuePopover, arrowEdge: .top) {
                QueuePanelView(viewModel: viewModel)
            }

            // Output button
            Button(action: {}) {
                Image(systemName: "airplayaudio")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            .buttonStyle(.plain)

            // Volume
            HStack(spacing: 6) {
                Image(systemName: volumeIcon)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .frame(width: 14)

                Slider(value: Binding(
                    get: { viewModel.nowPlaying.volume },
                    set: { viewModel.setVolume($0) }
                ), in: 0...1)
                .controlSize(.mini)
                .tint(.white)
                .frame(width: 80)
            }
        }
    }

    private var volumeIcon: String {
        let vol = viewModel.nowPlaying.volume
        if vol == 0 { return "speaker.slash.fill" }
        if vol < 0.33 { return "speaker.wave.1.fill" }
        if vol < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }
}

// MARK: - Queue Panel View

struct QueuePanelView: View {
    @ObservedObject var viewModel: MusicViewModel

    private let goldAccent = Color(red: 0.85, green: 0.65, blue: 0.13)
    private let panelBackground = Color(white: 0.08)

    private var totalQueueDuration: Double {
        viewModel.nowPlaying.queue.reduce(0) { $0 + $1.duration }
    }

    private var totalQueueDurationFormatted: String {
        let total = Int(totalQueueDuration)
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let seconds = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            queueHeader

            Divider()
                .background(Color.white.opacity(0.1))

            ScrollView {
                VStack(spacing: 0) {
                    // Now Playing section
                    if let currentTrack = viewModel.nowPlaying.currentTrack {
                        nowPlayingSection(track: currentTrack)
                    }

                    // Up Next section
                    upNextSection
                }
            }

            // Footer with Clear Queue
            if !viewModel.nowPlaying.queue.isEmpty {
                Divider()
                    .background(Color.white.opacity(0.1))

                clearQueueFooter
            }
        }
        .frame(width: 320, height: 500)
        .background(panelBackground)
    }

    // MARK: - Header

    private var queueHeader: some View {
        HStack {
            Text("Queue")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.white)

            Spacer()

            let count = viewModel.nowPlaying.queue.count
            if count > 0 {
                Text("\(count) track\(count == 1 ? "" : "s") \u{00B7} \(totalQueueDurationFormatted)")
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Now Playing Section

    private func nowPlayingSection(track: MusicTrack) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("NOW PLAYING")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(goldAccent)
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            HStack(spacing: 10) {
                queueTrackArt(track: track, size: 40)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(goldAccent)
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                        .lineLimit(1)
                }

                Spacer()

                Text(track.durationFormatted)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(goldAccent.opacity(0.08))

            Divider()
                .background(Color.white.opacity(0.06))
                .padding(.top, 8)
        }
    }

    // MARK: - Up Next Section

    private var upNextSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if viewModel.nowPlaying.queue.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "text.badge.plus")
                        .font(.system(size: 28))
                        .foregroundColor(.gray.opacity(0.4))

                    Text("Queue is empty")
                        .font(.system(size: 13))
                        .foregroundColor(.gray.opacity(0.6))

                    Text("Add tracks from your library")
                        .font(.system(size: 11))
                        .foregroundColor(.gray.opacity(0.4))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                Text("UP NEXT")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
                    .padding(.bottom, 4)

                ForEach(Array(viewModel.nowPlaying.queue.enumerated()), id: \.element.id) { index, track in
                    QueueTrackRow(
                        track: track,
                        goldAccent: goldAccent,
                        onRemove: {
                            viewModel.removeFromQueue(at: index)
                        },
                        onPlay: {
                            // Remove all tracks before this one, then play
                            for _ in 0..<index {
                                viewModel.removeFromQueue(at: 0)
                            }
                            viewModel.next()
                        }
                    )
                    .onDrag {
                        NSItemProvider(object: String(track.id) as NSString)
                    }
                    .onDrop(of: [.text], delegate: QueueDropDelegate(
                        viewModel: viewModel,
                        targetIndex: index
                    ))
                }
            }
        }
    }

    // MARK: - Clear Queue Footer

    private var clearQueueFooter: some View {
        Button(action: { viewModel.clearQueue() }) {
            HStack {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                Text("Clear Queue")
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundColor(.gray)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    // MARK: - Track Art Helper

    private func queueTrackArt(track: MusicTrack, size: CGFloat) -> some View {
        ZStack {
            if let artPath = track.albumArtPath,
               let image = NSImage(contentsOfFile: artPath) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            } else {
                let hash = abs((track.title + track.artist).hashValue)
                let hue = Double(hash % 360) / 360.0
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(hue: hue, saturation: 0.5, brightness: 0.35),
                                Color(hue: hue, saturation: 0.6, brightness: 0.15)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: size, height: size)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.system(size: size * 0.35))
                            .foregroundColor(.white.opacity(0.4))
                    }
            }
        }
    }
}

// MARK: - Queue Track Row

struct QueueTrackRow: View {
    let track: MusicTrack
    let goldAccent: Color
    let onRemove: () -> Void
    let onPlay: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 10) {
            // Album art
            ZStack {
                if let artPath = track.albumArtPath,
                   let image = NSImage(contentsOfFile: artPath) {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                } else {
                    let hash = abs((track.title + track.artist).hashValue)
                    let hue = Double(hash % 360) / 360.0
                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hue: hue, saturation: 0.5, brightness: 0.35),
                                    Color(hue: hue, saturation: 0.6, brightness: 0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 36, height: 36)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.system(size: 12))
                                .foregroundColor(.white.opacity(0.4))
                        }
                }

                // Play overlay on hover
                if isHovering {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.5))
                        .frame(width: 36, height: 36)
                        .overlay {
                            Image(systemName: "play.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                        }
                        .onTapGesture { onPlay() }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
                    .lineLimit(1)
            }

            Spacer()

            if isHovering {
                Button(action: onRemove) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.gray)
                        .frame(width: 20, height: 20)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            } else {
                Text(track.durationFormatted)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.gray)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Queue Drop Delegate

struct QueueDropDelegate: DropDelegate {
    let viewModel: MusicViewModel
    let targetIndex: Int

    func performDrop(info: DropInfo) -> Bool {
        guard let item = info.itemProviders(for: [.text]).first else { return false }
        item.loadObject(ofClass: NSString.self) { reading, _ in
            guard let idString = reading as? NSString,
                  let draggedId = Int64(idString as String) else { return }
            Task { @MainActor in
                guard let sourceIndex = viewModel.nowPlaying.queue.firstIndex(where: { $0.id == draggedId }) else { return }
                let from = IndexSet(integer: sourceIndex)
                let to = targetIndex > sourceIndex ? targetIndex + 1 : targetIndex
                viewModel.moveQueueItem(from: from, to: to)
            }
        }
        return true
    }

    func validateDrop(info: DropInfo) -> Bool {
        info.hasItemsConforming(to: [.text])
    }

    func dropEntered(info: DropInfo) {}
}
