import SwiftUI
import AVKit
import AVFoundation
import Combine
import IOKit.pwr_mgt

// MARK: - AVPlayerLayer NSViewRepresentable

struct VideoLayerView: NSViewRepresentable {
    let player: AVPlayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.videoGravity = .resizeAspect
        playerLayer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.wantsLayer = true
        view.layer = playerLayer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if let layer = nsView.layer as? AVPlayerLayer {
            layer.player = player
        }
    }
}

// MARK: - VideoPlayerView

struct VideoPlayerView: View {
    let item: MediaItem
    let onClose: () -> Void
    var accountId: Int64? = nil

    // Player
    @State private var player: AVPlayer?

    // Playback state
    @State private var currentTime: Double = 0
    @State private var totalDuration: Double = 0
    @State private var isPlaying: Bool = true
    @State private var volume: Float = 1.0
    @State private var previousVolume: Float = 1.0

    // UI state
    @State private var showControls: Bool = true
    @State private var showCommentSidebar: Bool = false
    @State private var isDragging: Bool = false
    @State private var isHoveringBar: Bool = false
    @State private var scrubTooltipTime: Double? = nil
    @State private var scrubTooltipX: CGFloat = 0

    // Comments
    @State private var comments: [TimestampComment] = []
    @State private var newCommentText: String = ""
    @State private var activeComment: TimestampComment? = nil
    @State private var shownCommentIds: Set<Int64> = []
    @FocusState private var isCommentFieldFocused: Bool

    // Sleep prevention
    @State private var sleepAssertionID: IOPMAssertionID = 0

    // Timers & tasks
    @State private var progressTimer: AnyCancellable?
    @State private var timeObserverToken: Any?
    @State private var hideTask: Task<Void, Never>?
    @State private var lastSaveTime: Double = 0
    @State private var saveTimer: AnyCancellable?
    @State private var pauseDebounce: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let player = player {
                // Video layer
                VideoLayerView(player: player)
                    .ignoresSafeArea()

                // Click to play/pause
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture(count: 2) {
                        toggleFullscreen()
                    }
                    .onTapGesture {
                        togglePlayPause()
                    }
            }

            // Controls overlay (top title bar + bottom controls)
            if showControls {
                VStack {
                    // MARK: Top Title Bar
                    topBar
                    Spacer()
                    // MARK: Bottom Controls
                    bottomControls
                }
                .transition(.opacity)
            }

            // Comment sidebar
            if showCommentSidebar {
                HStack(spacing: 0) {
                    Spacer()
                    commentSidebar
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }

            // Active comment overlay (bottom-left)
            if let comment = activeComment {
                VStack {
                    Spacer()
                    HStack {
                        commentOverlay(comment: comment)
                            .padding(.leading, 24)
                            .padding(.bottom, showControls ? 100 : 24)
                        Spacer()
                    }
                }
                .transition(.opacity)
                .allowsHitTesting(false)
            }
        }
        .background(Color.black)
        .onAppear(perform: setupPlayer)
        .onDisappear(perform: cleanup)
        .onHover { hovering in
            if hovering {
                showControlsTemporarily()
            }
        }
        .onContinuousHover { phase in
            switch phase {
            case .active:
                showControlsTemporarily()
            case .ended:
                break
            }
        }
        .onKeyPress(.space) {
            guard !isCommentFieldFocused else { return .ignored }
            togglePlayPause()
            return .handled
        }
        .onKeyPress(.leftArrow) {
            skip(seconds: -10)
            return .handled
        }
        .onKeyPress(.rightArrow) {
            skip(seconds: 10)
            return .handled
        }
        .onKeyPress(.upArrow) {
            adjustVolume(delta: 0.1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            adjustVolume(delta: -0.1)
            return .handled
        }
        .onKeyPress(.escape) {
            saveProgress()
            onClose()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "f")) { _ in
            toggleFullscreen()
            return .handled
        }
        .onKeyPress(characters: CharacterSet(charactersIn: "m")) { _ in
            toggleMute()
            return .handled
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack {
            Button(action: {
                saveProgress()
                onClose()
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text(item.mediaType == .tvEpisode ? (item.showName ?? item.title) : item.title)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)
                    if item.mediaType == .tvEpisode {
                        Text(item.episodeLabel)
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.ultraThinMaterial)
                .cornerRadius(8)
            }
            .buttonStyle(.plain)

            Spacer()

            if let q = item.quality {
                Text(q)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial)
                    .cornerRadius(6)
            }
        }
        .padding(20)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 0) {
            // Scrub bar
            scrubBar
                .padding(.horizontal, 16)

            // Control buttons row
            HStack(spacing: 0) {
                // Left side controls
                HStack(spacing: 16) {
                    // Play/Pause
                    Button(action: togglePlayPause) {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.white)
                            .frame(width: 36, height: 36)
                    }
                    .buttonStyle(.plain)

                    // Skip back 10s
                    Button(action: { skip(seconds: -10) }) {
                        Image(systemName: "gobackward.10")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .buttonStyle(.plain)

                    // Skip forward 10s
                    Button(action: { skip(seconds: 10) }) {
                        Image(systemName: "goforward.10")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .buttonStyle(.plain)

                    // Volume
                    HStack(spacing: 6) {
                        Button(action: toggleMute) {
                            Image(systemName: volumeIcon)
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.9))
                                .frame(width: 20)
                        }
                        .buttonStyle(.plain)

                        Slider(value: Binding(
                            get: { Double(volume) },
                            set: { newVal in
                                volume = Float(newVal)
                                player?.volume = volume
                            }
                        ), in: 0...1)
                        .frame(width: 70)
                        .tint(.white)
                    }

                    // Time display
                    Text("\(formatTime(currentTime)) / \(formatTime(totalDuration))")
                        .font(.system(size: 12, weight: .medium).monospacedDigit())
                        .foregroundColor(.white.opacity(0.7))
                }

                Spacer()

                // Right side controls
                HStack(spacing: 16) {
                    // Comment toggle
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.25)) {
                            showCommentSidebar.toggle()
                        }
                    }) {
                        Image(systemName: showCommentSidebar ? "bubble.left.fill" : "bubble.left")
                            .font(.system(size: 15))
                            .foregroundColor(showCommentSidebar ? Color(red: 1.0, green: 0.84, blue: 0.0) : .white.opacity(0.9))
                    }
                    .buttonStyle(.plain)

                    // Fullscreen toggle
                    Button(action: toggleFullscreen) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 14)
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: [.clear, .black.opacity(0.7), .black.opacity(0.85)]),
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Scrub Bar

    private var scrubBar: some View {
        GeometryReader { geo in
            let barWidth = geo.size.width
            let progress = totalDuration > 0 ? currentTime / totalDuration : 0
            let barHeight: CGFloat = isHoveringBar || isDragging ? 6 : 3
            let handleSize: CGFloat = isDragging ? 16 : (isHoveringBar ? 14 : 0)

            ZStack(alignment: .leading) {
                // Background track
                RoundedRectangle(cornerRadius: barHeight / 2)
                    .fill(Color.white.opacity(0.2))
                    .frame(height: barHeight)

                // Buffered portion (estimate: slightly ahead of current)
                let buffered = min(progress + 0.05, 1.0)
                RoundedRectangle(cornerRadius: barHeight / 2)
                    .fill(Color.white.opacity(0.15))
                    .frame(width: barWidth * CGFloat(buffered), height: barHeight)

                // Played portion (red)
                RoundedRectangle(cornerRadius: barHeight / 2)
                    .fill(Color.red)
                    .frame(width: barWidth * CGFloat(progress), height: barHeight)

                // Comment markers
                ForEach(comments) { comment in
                    if totalDuration > 0 {
                        let markerX = barWidth * CGFloat(comment.timestamp / totalDuration)
                        Circle()
                            .fill(Color(red: 1.0, green: 0.84, blue: 0.0))
                            .frame(width: isHoveringBar ? 6 : 4, height: isHoveringBar ? 6 : 4)
                            .offset(x: markerX - (isHoveringBar ? 3 : 2))
                    }
                }

                // Scrub handle (white circle)
                Circle()
                    .fill(Color.white)
                    .frame(width: handleSize, height: handleSize)
                    .shadow(color: .black.opacity(0.3), radius: 2, y: 1)
                    .offset(x: barWidth * CGFloat(progress) - handleSize / 2)
                    .opacity(handleSize > 0 ? 1 : 0)

                // Tooltip
                if let tooltipTime = scrubTooltipTime, (isHoveringBar || isDragging) {
                    Text(formatTime(tooltipTime))
                        .font(.system(size: 11, weight: .medium).monospacedDigit())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.black.opacity(0.8))
                        .cornerRadius(4)
                        .offset(x: min(max(scrubTooltipX - 28, 0), barWidth - 56), y: -28)
                }
            }
            .frame(height: max(barHeight, handleSize, 20))
            .contentShape(Rectangle().inset(by: -8))
            .onHover { hovering in
                withAnimation(.easeOut(duration: 0.15)) {
                    isHoveringBar = hovering
                }
                if !hovering && !isDragging {
                    scrubTooltipTime = nil
                }
            }
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    let fraction = max(0, min(1, Double(location.x / barWidth)))
                    scrubTooltipTime = fraction * totalDuration
                    scrubTooltipX = location.x
                case .ended:
                    if !isDragging {
                        scrubTooltipTime = nil
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        isDragging = true
                        let fraction = max(0, min(1, Double(value.location.x / barWidth)))
                        let seekTime = fraction * totalDuration
                        currentTime = seekTime
                        scrubTooltipTime = seekTime
                        scrubTooltipX = value.location.x
                    }
                    .onEnded { value in
                        let fraction = max(0, min(1, Double(value.location.x / barWidth)))
                        let seekTime = fraction * totalDuration
                        player?.seek(to: CMTime(seconds: seekTime, preferredTimescale: 600), toleranceBefore: .zero, toleranceAfter: .zero)
                        currentTime = seekTime
                        isDragging = false
                        scrubTooltipTime = nil
                    }
            )
        }
        .frame(height: 20)
    }

    // MARK: - Comment Sidebar

    private var commentSidebar: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Comments")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                Spacer()
                Text(formatTime(currentTime))
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundColor(.white.opacity(0.5))
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        showCommentSidebar = false
                    }
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.6))
                        .frame(width: 24, height: 24)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Divider().background(Color.white.opacity(0.15))

            // Add comment
            HStack(spacing: 8) {
                TextField("Add a comment at \(formatTime(currentTime))...", text: $newCommentText)
                    .focused($isCommentFieldFocused)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(8)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(6)
                    .onSubmit {
                        addCurrentComment()
                    }

                Button(action: addCurrentComment) {
                    Text("Add")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(newCommentText.isEmpty ? Color.gray : Color(red: 1.0, green: 0.84, blue: 0.0))
                        .cornerRadius(6)
                }
                .buttonStyle(.plain)
                .disabled(newCommentText.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider().background(Color.white.opacity(0.15))

            // Comments list
            ScrollViewReader { scrollProxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(comments) { comment in
                            commentRow(comment: comment)
                        }
                    }
                }
            }
        }
        .frame(width: 320)
        .background(Color.black.opacity(0.92))
    }

    private func commentRow(comment: TimestampComment) -> some View {
        let isCurrent = abs(comment.timestamp - currentTime) < 3.0
        return HStack(alignment: .top, spacing: 10) {
            // Timestamp (clickable)
            Button(action: {
                player?.seek(to: CMTime(seconds: comment.timestamp, preferredTimescale: 600))
                currentTime = comment.timestamp
            }) {
                Text(comment.timestampFormatted)
                    .font(.system(size: 12, weight: .semibold).monospacedDigit())
                    .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
            }
            .buttonStyle(.plain)
            .frame(width: 50, alignment: .leading)

            // Comment text
            Text(comment.text)
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.9))
                .lineLimit(4)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Delete button
            Button(action: {
                Database.shared.deleteComment(id: comment.id)
                loadComments()
            }) {
                Image(systemName: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.3))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isCurrent ? Color.white.opacity(0.08) : Color.clear)
    }

    // MARK: - Comment Overlay (during playback)

    private func commentOverlay(comment: TimestampComment) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left.fill")
                .font(.system(size: 12))
                .foregroundColor(Color(red: 1.0, green: 0.84, blue: 0.0))
            Text(comment.text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
                .lineLimit(2)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 300, alignment: .leading)
        .background(Color.black.opacity(0.7))
        .cornerRadius(10)
    }

    // MARK: - Helpers

    private var volumeIcon: String {
        if volume == 0 { return "speaker.slash.fill" }
        if volume < 0.33 { return "speaker.wave.1.fill" }
        if volume < 0.66 { return "speaker.wave.2.fill" }
        return "speaker.wave.3.fill"
    }

    private func formatTime(_ seconds: Double) -> String {
        guard seconds.isFinite && seconds >= 0 else { return "0:00" }
        let total = Int(seconds)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        if h > 0 {
            return String(format: "%d:%02d:%02d", h, m, s)
        }
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Actions

    private func togglePlayPause() {
        guard let player = player else { return }
        if isPlaying {
            player.pause()
        } else {
            player.play()
        }
        isPlaying.toggle()
        showControlsTemporarily()
    }

    private func skip(seconds: Double) {
        guard let player = player else { return }
        let target = max(0, min(currentTime + seconds, totalDuration))
        player.seek(to: CMTime(seconds: target, preferredTimescale: 600))
        currentTime = target
        showControlsTemporarily()
    }

    private func adjustVolume(delta: Float) {
        volume = max(0, min(1, volume + delta))
        player?.volume = volume
        showControlsTemporarily()
    }

    private func toggleMute() {
        if volume > 0 {
            previousVolume = volume
            volume = 0
        } else {
            volume = previousVolume > 0 ? previousVolume : 1.0
        }
        player?.volume = volume
        showControlsTemporarily()
    }

    private func toggleFullscreen() {
        if let window = NSApp.keyWindow {
            window.toggleFullScreen(nil)
        }
        showControlsTemporarily()
    }

    private func showControlsTemporarily() {
        withAnimation(.easeOut(duration: 0.2)) { showControls = true }
        scheduleHide()
    }

    private func scheduleHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            if !Task.isCancelled && isPlaying && !isDragging && !showCommentSidebar {
                withAnimation(.easeOut(duration: 0.5)) { showControls = false }
            }
        }
    }

    private func addCurrentComment() {
        let trimmed = newCommentText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        Database.shared.addComment(mediaId: item.id, timestamp: currentTime, text: trimmed)
        newCommentText = ""
        loadComments()
    }

    private func loadComments() {
        comments = Database.shared.comments(forMedia: item.id)
    }

    // MARK: - Setup & Teardown

    private func setupPlayer() {
        preventSleep()
        let avPlayer = AVPlayer(url: URL(fileURLWithPath: item.filePath))
        avPlayer.audiovisualBackgroundPlaybackPolicy = .continuesIfPossible
        avPlayer.volume = volume
        if item.watchProgress > 0 && !item.watched {
            avPlayer.seek(to: CMTime(seconds: item.watchProgress, preferredTimescale: 600))
        }
        avPlayer.play()
        self.player = avPlayer
        self.isPlaying = true
        self.lastSaveTime = (item.watchProgress > 0 && !item.watched) ? item.watchProgress : 0
        Database.shared.markPlayed(movieId: item.id, accountId: accountId)

        // Get duration once available
        if let dur = avPlayer.currentItem?.duration, CMTimeGetSeconds(dur) > 0 && CMTimeGetSeconds(dur).isFinite {
            totalDuration = CMTimeGetSeconds(dur)
        }
        avPlayer.currentItem?.publisher(for: \.duration)
            .sink { dur in
                let secs = CMTimeGetSeconds(dur)
                if secs > 0 && secs.isFinite {
                    self.totalDuration = secs
                }
            }
            .store(in: &cancellables)

        // Periodic time observer (every 0.5s)
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserverToken = avPlayer.addPeriodicTimeObserver(forInterval: interval, queue: .main) { time in
            guard !isDragging else { return }
            let secs = CMTimeGetSeconds(time)
            if secs.isFinite {
                currentTime = secs
            }
            // Check duration again
            if totalDuration == 0, let dur = avPlayer.currentItem?.duration {
                let d = CMTimeGetSeconds(dur)
                if d > 0 && d.isFinite { totalDuration = d }
            }
            // Show comment overlays
            checkCommentOverlays()
        }

        // Detect play/pause from the player itself
        avPlayer.publisher(for: \.timeControlStatus)
            .receive(on: DispatchQueue.main)
            .sink { status in
                switch status {
                case .playing:
                    isPlaying = true
                    pauseDebounce?.cancel()
                case .paused:
                    isPlaying = false
                    // Show controls when paused
                    withAnimation(.easeOut(duration: 0.2)) { showControls = true }
                    hideTask?.cancel()
                    // Auto-show comment sidebar after 1s pause
                    pauseDebounce?.cancel()
                    pauseDebounce = Task {
                        try? await Task.sleep(nanoseconds: 1_000_000_000)
                        if !Task.isCancelled && !isPlaying {
                            withAnimation(.easeInOut(duration: 0.25)) {
                                showCommentSidebar = true
                            }
                        }
                    }
                default:
                    break
                }
            }
            .store(in: &cancellables)

        saveTimer = Timer.publish(every: 1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in saveProgress() }

        loadComments()
        scheduleHide()
    }

    @State private var cancellables: Set<AnyCancellable> = []

    private func checkCommentOverlays() {
        guard isPlaying else { return }
        // Find a comment within 1 second of current time that hasn't been shown yet
        let nearby = comments.first { comment in
            abs(comment.timestamp - currentTime) < 1.0 && !shownCommentIds.contains(comment.id)
        }
        if let comment = nearby {
            shownCommentIds.insert(comment.id)
            withAnimation(.easeIn(duration: 0.3)) {
                activeComment = comment
            }
            // Fade out after 4 seconds
            Task {
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                if activeComment?.id == comment.id {
                    withAnimation(.easeOut(duration: 0.5)) {
                        activeComment = nil
                    }
                }
            }
        }
    }

    private func cleanup() {
        allowSleep()
        saveTimer?.cancel()
        hideTask?.cancel()
        pauseDebounce?.cancel()
        saveProgress()
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
        }
        player?.pause()
        player = nil
        cancellables.removeAll()
    }

    private func preventSleep() {
        IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Cinemate video playback" as CFString,
            &sleepAssertionID
        )
    }

    private func allowSleep() {
        if sleepAssertionID != 0 {
            IOPMAssertionRelease(sleepAssertionID)
            sleepAssertionID = 0
        }
    }

    private func saveProgress() {
        guard let player = player else { return }
        let time = CMTimeGetSeconds(player.currentTime())
        if time > 0 {
            Database.shared.updateProgress(movieId: item.id, progress: time, accountId: accountId)
            if let dur = player.currentItem?.duration, CMTimeGetSeconds(dur) > 0 {
                let duration = CMTimeGetSeconds(dur)
                Database.shared.updateDuration(movieId: item.id, duration: duration)
                if duration > 0 && time / duration >= 0.9 {
                    Database.shared.markWatched(movieId: item.id, accountId: accountId)
                }
            }
            if time > lastSaveTime {
                let delta = time - lastSaveTime
                Database.shared.addWatchTime(movieId: item.id, seconds: delta, accountId: accountId)
            }
            lastSaveTime = time
        }
    }
}
