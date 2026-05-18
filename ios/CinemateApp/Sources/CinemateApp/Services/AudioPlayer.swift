import Foundation
import AVFoundation
import MediaPlayer
import Combine

struct LyricLine: Identifiable {
    let id: Int
    let time: TimeInterval
    let text: String
}

@MainActor
final class AudioPlayer: ObservableObject {
    @Published var currentTrack: MusicTrack?
    @Published var isPlaying: Bool = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var queue: [MusicTrack] = []
    @Published var isShuffled: Bool = false
    @Published var repeatMode: RepeatMode = .off
    @Published var albumArtURL: URL?
    @Published var volume: Float = 1.0 {
        didSet { player?.volume = volume }
    }

    @Published var lyricLines: [LyricLine] = []
    @Published var currentLyricIndex: Int = -1
    @Published var hasLyrics: Bool = false

    var onTrackPlayed: ((MusicTrack) -> Void)?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var statusObserver: NSKeyValueObservation?
    private var originalQueue: [MusicTrack] = []
    private var currentIndex: Int = 0
    private var lastBaseURL: String = ""

    enum RepeatMode {
        case off, all, one

        var icon: String {
            switch self {
            case .off: return "repeat"
            case .all: return "repeat"
            case .one: return "repeat.1"
            }
        }

        var isActive: Bool {
            self != .off
        }

        mutating func toggle() {
            switch self {
            case .off: self = .all
            case .all: self = .one
            case .one: self = .off
            }
        }
    }

    init() {
        setupAudioSession()
        setupRemoteCommands()
    }

    private func setupAudioSession() {
        #if os(iOS)
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            print("Audio session setup failed: \(error)")
        }
        #endif
    }

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.play()
            }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.pause()
            }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.next()
            }
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                self?.previous()
            }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in
                self?.seek(to: event.positionTime)
            }
            return .success
        }
    }

    func playTrack(_ track: MusicTrack, from baseURL: String, queue: [MusicTrack] = []) {
        self.currentTrack = track
        self.duration = track.duration
        if !baseURL.isEmpty {
            self.lastBaseURL = baseURL
        }

        if !queue.isEmpty {
            self.originalQueue = queue
            self.queue = queue
            self.currentIndex = queue.firstIndex(where: { $0.id == track.id }) ?? 0
        }

        let effectiveBase = baseURL.isEmpty ? lastBaseURL : baseURL

        if let artPath = track.artworkURL {
            self.albumArtURL = URL(string: "\(effectiveBase)\(artPath)")
        } else {
            self.albumArtURL = nil
        }

        // Check for locally downloaded file first
        let downloadManager = DownloadManager.shared
        let url: URL
        if let localURL = downloadManager.localFileURL(contentType: .musicTrack, contentId: track.id) {
            url = localURL
        } else {
            guard let streamURL = track.streamURL,
                  let remoteURL = URL(string: "\(effectiveBase)\(streamURL)") else {
                return
            }
            url = remoteURL
        }

        // Clean up previous
        removeTimeObserver()
        statusObserver?.invalidate()

        let playerItem = AVPlayerItem(url: url)
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
            player?.volume = volume
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }

        statusObserver = playerItem.observe(\.status) { [weak self] item, _ in
            Task { @MainActor in
                if item.status == .readyToPlay {
                    self?.player?.play()
                    self?.isPlaying = true
                    if let dur = item.asset.duration.seconds.isNaN ? nil : item.asset.duration.seconds {
                        self?.duration = dur
                    }
                }
            }
        }

        addTimeObserver()
        updateNowPlayingInfo()
        fetchLyrics(baseURL: effectiveBase)
        onTrackPlayed?(track)

        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleTrackEnd()
            }
        }
    }

    func playDownloadedTrack(record: DownloadRecord) {
        guard let localURL = DownloadManager.shared.localFileURL(contentType: record.contentType, contentId: record.contentId) else { return }

        let track = MusicTrack(
            id: record.contentId,
            title: record.title,
            artist: record.subtitle ?? "Unknown Artist",
            albumTitle: nil,
            albumId: nil,
            trackNumber: nil,
            duration: 0,
            isFavorite: false,
            playCount: 0
        )

        self.currentTrack = track
        self.duration = 0
        self.queue = []
        self.originalQueue = []
        self.currentIndex = 0
        self.albumArtURL = nil

        // Clean up previous
        removeTimeObserver()
        statusObserver?.invalidate()

        let playerItem = AVPlayerItem(url: localURL)
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
            player?.volume = volume
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }

        statusObserver = playerItem.observe(\.status) { [weak self] item, _ in
            Task { @MainActor in
                if item.status == .readyToPlay {
                    self?.player?.play()
                    self?.isPlaying = true
                    if let dur = item.asset.duration.seconds.isNaN ? nil : item.asset.duration.seconds {
                        self?.duration = dur
                    }
                }
            }
        }

        addTimeObserver()
        updateNowPlayingInfo()

        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleTrackEnd()
            }
        }
    }

    func playLocalFile(url: URL, title: String, artist: String) {
        let track = MusicTrack(
            id: 0,
            title: title,
            artist: artist,
            albumTitle: nil,
            albumId: nil,
            trackNumber: nil,
            duration: 0,
            isFavorite: false,
            playCount: 0
        )

        self.currentTrack = track
        self.duration = 0
        self.queue = []
        self.originalQueue = []
        self.currentIndex = 0
        self.albumArtURL = nil

        // Clean up previous
        removeTimeObserver()
        statusObserver?.invalidate()

        let playerItem = AVPlayerItem(url: url)
        if player == nil {
            player = AVPlayer(playerItem: playerItem)
            player?.volume = volume
        } else {
            player?.replaceCurrentItem(with: playerItem)
        }

        statusObserver = playerItem.observe(\.status) { [weak self] item, _ in
            Task { @MainActor in
                if item.status == .readyToPlay {
                    self?.player?.play()
                    self?.isPlaying = true
                    if let dur = item.asset.duration.seconds.isNaN ? nil : item.asset.duration.seconds {
                        self?.duration = dur
                    }
                }
            }
        }

        addTimeObserver()
        updateNowPlayingInfo()

        NotificationCenter.default.removeObserver(self, name: .AVPlayerItemDidPlayToEndTime, object: nil)
        NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: playerItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.handleTrackEnd()
            }
        }
    }

    func play() {
        player?.play()
        isPlaying = true
        updateNowPlayingInfo()
    }

    func pause() {
        player?.pause()
        isPlaying = false
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        if isPlaying { pause() } else { play() }
    }

    func next() {
        guard !queue.isEmpty else { return }
        if currentIndex < queue.count - 1 {
            currentIndex += 1
        } else if repeatMode == .all {
            currentIndex = 0
        } else {
            pause()
            return
        }
        let track = queue[currentIndex]
        playTrack(track, from: lastBaseURL, queue: queue)
    }

    func previous() {
        if currentTime > 3 {
            seek(to: 0)
            return
        }
        guard !queue.isEmpty else { return }
        if currentIndex > 0 {
            currentIndex -= 1
        } else if repeatMode == .all {
            currentIndex = queue.count - 1
        } else {
            seek(to: 0)
            return
        }
        let track = queue[currentIndex]
        playTrack(track, from: lastBaseURL, queue: queue)
    }

    func seek(to time: TimeInterval) {
        let cmTime = CMTime(seconds: time, preferredTimescale: 600)
        player?.seek(to: cmTime)
        currentTime = time
        updateNowPlayingInfo()
    }

    func toggleShuffle() {
        isShuffled.toggle()
        if isShuffled {
            var shuffled = queue
            if let current = currentTrack, let idx = shuffled.firstIndex(where: { $0.id == current.id }) {
                shuffled.remove(at: idx)
                shuffled.shuffle()
                shuffled.insert(current, at: 0)
                currentIndex = 0
            } else {
                shuffled.shuffle()
            }
            queue = shuffled
        } else {
            queue = originalQueue
            if let current = currentTrack {
                currentIndex = queue.firstIndex(where: { $0.id == current.id }) ?? 0
            }
        }
    }

    func toggleRepeat() {
        repeatMode.toggle()
    }

    func stop() {
        player?.pause()
        player = nil
        currentTrack = nil
        isPlaying = false
        currentTime = 0
        duration = 0
        albumArtURL = nil
        removeTimeObserver()
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    private func handleTrackEnd() {
        if repeatMode == .one {
            seek(to: 0)
            play()
        } else {
            next()
        }
    }

    private func addTimeObserver() {
        let interval = CMTime(seconds: 0.25, preferredTimescale: 600)
        timeObserver = player?.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            Task { @MainActor in
                let t = time.seconds.isNaN ? 0 : time.seconds
                self?.currentTime = t
                self?.updateLyricIndex()
            }
        }
    }

    private func removeTimeObserver() {
        if let observer = timeObserver {
            player?.removeTimeObserver(observer)
            timeObserver = nil
        }
    }

    private func updateNowPlayingInfo() {
        guard let track = currentTrack else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyPlaybackDuration: duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1.0 : 0.0,
        ]
        if let album = track.albumTitle {
            info[MPMediaItemPropertyAlbumTitle] = album
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    // MARK: - Lyrics

    private var lyricsTask: Task<Void, Never>?

    func fetchLyrics(baseURL: String) {
        lyricsTask?.cancel()
        lyricLines = []
        currentLyricIndex = -1
        hasLyrics = false

        guard let track = currentTrack else { return }
        let effectiveBase = baseURL.isEmpty ? lastBaseURL : baseURL
        guard let url = URL(string: "\(effectiveBase)/api/music/lyrics/\(track.id)") else { return }

        lyricsTask = Task {
            do {
                let (data, _) = try await URLSession.shared.data(from: url)
                guard !Task.isCancelled else { return }
                struct LyricsResponse: Decodable {
                    let has_lyrics: Bool
                    let lines: [LineDef]
                    struct LineDef: Decodable {
                        let time: Double
                        let text: String
                    }
                }
                let resp = try JSONDecoder().decode(LyricsResponse.self, from: data)
                self.lyricLines = resp.lines.enumerated().map { i, l in
                    LyricLine(id: i, time: l.time, text: l.text)
                }
                self.hasLyrics = resp.has_lyrics
            } catch {
                // Silently fail — lyrics are optional
            }
        }
    }

    var lyricOffset: TimeInterval = 1.5

    func updateLyricIndex() {
        guard !lyricLines.isEmpty else { return }
        let adjusted = currentTime - lyricOffset
        var newIndex = -1
        for i in lyricLines.indices {
            if lyricLines[i].time <= adjusted {
                newIndex = i
            } else {
                break
            }
        }
        if newIndex != currentLyricIndex {
            currentLyricIndex = newIndex
        }
    }
}
