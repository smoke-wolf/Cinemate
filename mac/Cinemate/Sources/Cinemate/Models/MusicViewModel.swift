import SwiftUI
import AVFoundation
import AppKit
import MediaPlayer

// MARK: - Music Sub-Tab

enum MusicSubTab: String, CaseIterable {
    case browse = "Browse"
    case artists = "Artists"
    case albums = "Albums"
    case playlists = "Playlists"
}


// MARK: - Sort Options

enum TrackSortOption: String, CaseIterable {
    case artist = "Artist"
    case title = "Title"
    case album = "Album"
    case duration = "Duration"
    case recentlyAdded = "Recently Added"
}

enum ArtistSortOption: String, CaseIterable {
    case name = "Name"
    case trackCount = "Tracks"
    case albumCount = "Albums"
}

enum AlbumSortOption: String, CaseIterable {
    case name = "Name"
    case artist = "Artist"
    case year = "Year"
    case trackCount = "Tracks"
}

// MARK: - Music View Model

@MainActor
final class MusicViewModel: ObservableObject {
    // Library data
    @Published var tracks: [MusicTrack] = []
    @Published var albums: [MusicAlbum] = []
    @Published var artists: [MusicArtist] = []
    @Published var playlists: [Playlist] = []

    // Loading state
    @Published var isLoading = false
    @Published var isScanning = false
    @Published var scanProgress: String = ""
    @Published var hasLoaded = false

    // Navigation
    @Published var currentSubTab: MusicSubTab = .browse
    @Published var searchQuery: String = ""
    @Published var selectedArtist: MusicArtist?
    @Published var selectedAlbum: MusicAlbum?
    @Published var selectedPlaylist: Playlist?


    // Sort options
    @Published var trackSortOption: TrackSortOption = .artist
    @Published var trackSortAscending: Bool = true
    @Published var artistSortOption: ArtistSortOption = .name
    @Published var artistSortAscending: Bool = true
    @Published var albumSortOption: AlbumSortOption = .name
    @Published var albumSortAscending: Bool = true

    // File modification date cache (for "Recently Added" sort)
    var fileModificationDates: [String: Date] = [:]

    // Server connection
    var serverURL: String?

    // Playback
    @Published var nowPlaying = NowPlayingState()
    private var audioPlayer: AVAudioPlayer?
    private var progressTimer: Timer?

    // Directory watcher
    private var directoryWatchTimer: Timer?
    private var knownFilePaths: Set<String> = []
    private var nextTrackId: Int64 = 1

    private let artCacheDir: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Cinemate")
            .appendingPathComponent("album_art")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private static let playlistsFileURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cinemate")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("playlists.json")
    }()

    private static let musicStatsFileURL: URL = {
        let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cinemate")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("music_stats.json")
    }()

    private struct TrackStats: Codable {
        var favorite: Bool
        var playCount: Int
        var lastPlayed: Date?
    }

    // MARK: - Computed Properties

    var filteredTracks: [MusicTrack] {
        guard !searchQuery.isEmpty else { return tracks }
        let query = searchQuery.lowercased()
        return tracks.filter {
            $0.title.lowercased().contains(query) ||
            $0.artist.lowercased().contains(query) ||
            $0.album.lowercased().contains(query)
        }
    }

    var recentlyPlayed: [MusicTrack] {
        tracks.filter { $0.lastPlayed != nil }
            .sorted { ($0.lastPlayed ?? .distantPast) > ($1.lastPlayed ?? .distantPast) }
            .prefix(20)
            .map { $0 }
    }

    var favoriteTracks: [MusicTrack] {
        tracks.filter(\.favorite)
    }

    var genreRows: [(genre: String, tracks: [MusicTrack])] {
        let grouped = Dictionary(grouping: tracks) { $0.genre ?? "Unknown" }
        return grouped
            .sorted { $0.value.count > $1.value.count }
            .filter { $0.value.count >= 2 }
            .prefix(10)
            .map { (genre: $0.key, tracks: $0.value) }
    }

    var genreAlbums: [(genre: String, albums: [MusicAlbum])] {
        let grouped = Dictionary(grouping: albums) { $0.genre ?? "Unknown" }
        return grouped
            .sorted { $0.value.count > $1.value.count }
            .filter { $0.value.count >= 2 }
            .prefix(8)
            .map { (genre: $0.key, albums: $0.value) }
    }


    var sortedTracks: [MusicTrack] {
        let sorted: [MusicTrack]
        switch trackSortOption {
        case .artist:
            sorted = tracks.sorted {
                $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending
            }
        case .title:
            sorted = tracks.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case .album:
            sorted = tracks.sorted {
                let cmp = $0.album.localizedCaseInsensitiveCompare($1.album)
                if cmp == .orderedSame {
                    return $0.trackNumber < $1.trackNumber
                }
                return cmp == .orderedAscending
            }
        case .duration:
            sorted = tracks.sorted { $0.duration < $1.duration }
        case .recentlyAdded:
            sorted = tracks.sorted {
                let d0 = fileModificationDates[$0.filePath] ?? .distantPast
                let d1 = fileModificationDates[$1.filePath] ?? .distantPast
                return d0 > d1
            }
        }
        return trackSortAscending ? sorted : sorted.reversed()
    }

    var sortedArtists: [MusicArtist] {
        let sorted: [MusicArtist]
        switch artistSortOption {
        case .name:
            sorted = artists.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .trackCount:
            sorted = artists.sorted { $0.trackCount > $1.trackCount }
        case .albumCount:
            sorted = artists.sorted { $0.albumCount > $1.albumCount }
        }
        return artistSortAscending ? sorted : sorted.reversed()
    }

    var sortedAlbums: [MusicAlbum] {
        let sorted: [MusicAlbum]
        switch albumSortOption {
        case .name:
            sorted = albums.sorted {
                $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
        case .artist:
            sorted = albums.sorted {
                $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending
            }
        case .year:
            sorted = albums.sorted { ($0.year ?? 0) > ($1.year ?? 0) }
        case .trackCount:
            sorted = albums.sorted { $0.trackCount > $1.trackCount }
        }
        return albumSortAscending ? sorted : sorted.reversed()
    }

    var recentlyAddedTracks: [MusicTrack] {
        tracks.sorted {
            let d0 = fileModificationDates[$0.filePath] ?? .distantPast
            let d1 = fileModificationDates[$1.filePath] ?? .distantPast
            return d0 > d1
        }
        .prefix(20)
        .map { $0 }
    }

    // MARK: - Initialization

    init() {
        loadPlaylists()
        setupRemoteCommands()
    }

    // MARK: - System Media Keys (Now Playing)

    private func setupRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()

        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                if !self.nowPlaying.isPlaying {
                    self.togglePlayPause()
                }
            }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                if self.nowPlaying.isPlaying {
                    self.togglePlayPause()
                }
            }
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                self.togglePlayPause()
            }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                self.next()
            }
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self = self else { return .commandFailed }
            Task { @MainActor in
                self.previous()
            }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let positionEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                self.seek(to: positionEvent.positionTime)
            }
            return .success
        }
    }

    private func updateNowPlayingInfo() {
        guard let track = nowPlaying.currentTrack else {
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: track.title,
            MPMediaItemPropertyArtist: track.artist,
            MPMediaItemPropertyAlbumTitle: track.album,
            MPMediaItemPropertyPlaybackDuration: track.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: nowPlaying.progress,
            MPNowPlayingInfoPropertyPlaybackRate: nowPlaying.isPlaying ? 1.0 : 0.0,
        ]

        if let artPath = track.albumArtPath, let image = NSImage(contentsOfFile: artPath) {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
        }

        if let trackNumber = Optional(track.trackNumber), trackNumber > 0 {
            info[MPMediaItemPropertyAlbumTrackNumber] = trackNumber
        }

        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private nonisolated func tearDownRemoteCommands() {
        let commandCenter = MPRemoteCommandCenter.shared()
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }

    // MARK: - Playlist Persistence

    private func savePlaylists() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(playlists)
            try data.write(to: Self.playlistsFileURL, options: .atomic)
        } catch {
            print("Failed to save playlists: \(error)")
        }
    }

    private func loadPlaylists() {
        let url = Self.playlistsFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            playlists = try decoder.decode([Playlist].self, from: data)
        } catch {
            print("Failed to load playlists: \(error)")
        }
    }

    // MARK: - Music Stats Persistence

    private func saveMusicStats() {
        var statsDict: [String: TrackStats] = [:]
        for track in tracks {
            if track.favorite || track.playCount > 0 || track.lastPlayed != nil {
                statsDict[track.filePath] = TrackStats(
                    favorite: track.favorite,
                    playCount: track.playCount,
                    lastPlayed: track.lastPlayed
                )
            }
        }
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            let data = try encoder.encode(statsDict)
            try data.write(to: Self.musicStatsFileURL, options: .atomic)
        } catch {
            print("Failed to save music stats: \(error)")
        }
    }

    private func loadMusicStats() {
        let url = Self.musicStatsFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let statsDict = try decoder.decode([String: TrackStats].self, from: data)
            for i in tracks.indices {
                if let stats = statsDict[tracks[i].filePath] {
                    tracks[i].favorite = stats.favorite
                    tracks[i].playCount = stats.playCount
                    tracks[i].lastPlayed = stats.lastPlayed
                }
            }
        } catch {
            print("Failed to load music stats: \(error)")
        }
    }

    private func applyStatsToTrack(_ track: inout MusicTrack) {
        let url = Self.musicStatsFileURL
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        guard let data = try? Data(contentsOf: url),
              let statsDict = try? {
                  let decoder = JSONDecoder()
                  decoder.dateDecodingStrategy = .iso8601
                  return try decoder.decode([String: TrackStats].self, from: data)
              }() else { return }
        if let stats = statsDict[track.filePath] {
            track.favorite = stats.favorite
            track.playCount = stats.playCount
            track.lastPlayed = stats.lastPlayed
        }
    }

    // MARK: - Library Loading

    private static let defaultMusicPath = NSHomeDirectory() + "/audio"

    func loadLibrary() {
        guard !hasLoaded else { return }
        hasLoaded = true

        let musicPath = Self.defaultMusicPath
        if FileManager.default.fileExists(atPath: musicPath) {
            scanMusicDirectory(musicPath)
            startDirectoryWatcher()
        }
    }

    func scanMusicDirectory(_ path: String) {
        guard !isScanning else { return }
        isScanning = true
        isLoading = true
        scanProgress = "Scanning..."

        Task {
            let fm = FileManager.default
            guard let enumerator = fm.enumerator(atPath: path) else {
                isScanning = false
                isLoading = false
                return
            }

            let audioExtensions: Set<String> = ["mp3", "flac", "aac", "m4a", "wav", "alac", "ogg", "opus", "aiff"]
            var scannedTracks: [MusicTrack] = []
            var scannedDates: [String: Date] = [:]
            var trackId: Int64 = 1

            var files: [String] = []
            while let file = enumerator.nextObject() as? String {
                let ext = (file as NSString).pathExtension.lowercased()
                if audioExtensions.contains(ext) { files.append(file) }
            }

            for (i, file) in files.enumerated() {
                let ext = (file as NSString).pathExtension.lowercased()
                let fullPath = (path as NSString).appendingPathComponent(file)

                scanProgress = "Scanning \(i + 1)/\(files.count)..."

                // Cache file modification date for "Recently Added" sort
                if let attrs = try? fm.attributesOfItem(atPath: fullPath),
                   let modDate = attrs[.modificationDate] as? Date {
                    scannedDates[fullPath] = modDate
                }

                var title = (file as NSString).lastPathComponent
                    .replacingOccurrences(of: ".\(ext)", with: "")
                var artist = "Unknown Artist"
                var album = "Unknown Album"
                var albumArtist: String?
                var trackNumber = 0
                var discNumber = 1
                var year: Int?
                var genre: String?
                var duration: Double = 0
                var artPath: String?

                // Try JSON sidecar first (spotisnare metadata)
                let jsonPath = fullPath.replacingOccurrences(of: ".\(ext)", with: ".json")
                if fm.fileExists(atPath: jsonPath),
                   let jsonData = fm.contents(atPath: jsonPath),
                   let meta = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    if let t = meta["title"] as? String { title = t }
                    if let a = meta["artist"] as? String { artist = a }
                    if let al = meta["album"] as? String { album = al }
                    if let d = meta["duration_s"] as? Double { duration = d }
                    if let artwork = meta["artwork"] as? [String: Any],
                       let hasArt = artwork["has_artwork"] as? Bool, hasArt,
                       let ap = artwork["path"] as? String, fm.fileExists(atPath: ap) {
                        artPath = ap
                    }
                } else {
                    // Fallback: read AVAsset metadata
                    let url = URL(fileURLWithPath: fullPath)
                    let asset = AVURLAsset(url: url)

                    if let metadata = try? await asset.load(.metadata) {
                        for item in metadata {
                            guard let key = item.commonKey?.rawValue else { continue }
                            switch key {
                            case "title":
                                if let val = try? await item.load(.stringValue) { title = val }
                            case "artist":
                                if let val = try? await item.load(.stringValue) { artist = val }
                            case "albumName":
                                if let val = try? await item.load(.stringValue) { album = val }
                            case "type":
                                if let val = try? await item.load(.stringValue) { genre = val }
                            case "artwork":
                                if let data = try? await item.load(.dataValue) {
                                    artPath = cacheArtwork(data: data, artist: artist, album: album)
                                }
                            default:
                                break
                            }
                        }

                        for item in metadata {
                            if let id = item.identifier {
                                let idStr = id.rawValue
                                if idStr.contains("trackNumber"),
                                   let val = try? await item.load(.numberValue) {
                                    trackNumber = val.intValue
                                } else if idStr.contains("discNumber"),
                                          let val = try? await item.load(.numberValue) {
                                    discNumber = val.intValue
                                } else if idStr.contains("albumArtist") || idStr.contains("TPE2"),
                                          let val = try? await item.load(.stringValue) {
                                    albumArtist = val
                                } else if idStr.contains("year") || idStr.contains("TDRC") || idStr.contains("©day"),
                                          let val = try? await item.load(.stringValue) {
                                    year = Int(val.prefix(4))
                                }
                            }
                        }
                    }

                    if duration == 0, let dur = try? await AVURLAsset(url: URL(fileURLWithPath: fullPath)).load(.duration) {
                        duration = CMTimeGetSeconds(dur)
                    }
                }

                // Filename fallback for artist/title
                if artist == "Unknown Artist" && title.contains(" - ") {
                    let parts = title.split(separator: " - ", maxSplits: 1)
                    if parts.count == 2 {
                        artist = String(parts[0])
                        title = String(parts[1])
                    }
                }

                let track = MusicTrack(
                    id: trackId,
                    title: title,
                    artist: artist,
                    album: album,
                    albumArtist: albumArtist,
                    trackNumber: trackNumber,
                    discNumber: discNumber,
                    year: year,
                    genre: genre,
                    duration: duration,
                    bitrate: nil,
                    format: ext,
                    filePath: fullPath,
                    albumArtPath: artPath,
                    favorite: false,
                    playCount: 0,
                    lastPlayed: nil,
                    isExplicit: false
                )
                scannedTracks.append(track)
                trackId += 1
            }

            self.tracks = scannedTracks
            self.fileModificationDates = scannedDates
            self.knownFilePaths = Set(scannedTracks.map { $0.filePath })
            self.nextTrackId = trackId
            self.loadMusicStats()
            self.buildAlbumsAndArtists()
            self.isScanning = false
            self.isLoading = false
            self.scanProgress = ""
        }
    }

    private func cacheArtwork(data: Data, artist: String, album: String) -> String? {
        let safeArtist = artist.replacingOccurrences(of: "/", with: "_")
        let safeAlbum = album.replacingOccurrences(of: "/", with: "_")
        let filename = "\(safeArtist) - \(safeAlbum).jpg"
        let dest = artCacheDir.appendingPathComponent(filename)

        if FileManager.default.fileExists(atPath: dest.path) {
            return dest.path
        }

        guard let image = NSImage(data: data) else { return nil }
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let jpegData = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.85]) else {
            return nil
        }

        do {
            try jpegData.write(to: dest)
            return dest.path
        } catch {
            return nil
        }
    }

    private func buildAlbumsAndArtists() {
        // Build albums from tracks
        let groupedByAlbum = Dictionary(grouping: tracks) { "\($0.artist):::\($0.album)" }
        albums = groupedByAlbum.map { key, albumTracks in
            let sorted = albumTracks.sorted { $0.trackNumber < $1.trackNumber }
            let first = sorted.first!
            return MusicAlbum(
                id: key,
                name: first.album,
                artist: first.artist,
                year: first.year,
                genre: first.genre,
                trackCount: sorted.count,
                totalDuration: sorted.reduce(0) { $0 + $1.duration },
                artPath: first.albumArtPath,
                tracks: sorted
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

        // Build artists from albums
        let groupedByArtist = Dictionary(grouping: albums) { $0.artist }
        artists = groupedByArtist.map { name, artistAlbums in
            let sorted = artistAlbums.sorted { ($0.year ?? 0) > ($1.year ?? 0) }
            let totalTracks = sorted.reduce(0) { $0 + $1.trackCount }
            let totalDuration = sorted.reduce(0) { $0 + $1.totalDuration }
            return MusicArtist(
                name: name,
                trackCount: totalTracks,
                albumCount: sorted.count,
                totalDuration: totalDuration,
                albums: sorted
            )
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    // MARK: - Directory Watcher

    private func startDirectoryWatcher() {
        directoryWatchTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkForNewFiles()
            }
        }
    }

    private func stopDirectoryWatcher() {
        directoryWatchTimer?.invalidate()
        directoryWatchTimer = nil
    }

    private func checkForNewFiles() {
        let musicPath = Self.defaultMusicPath
        let fm = FileManager.default
        guard let enumerator = fm.enumerator(atPath: musicPath) else { return }

        let audioExtensions: Set<String> = ["mp3", "flac", "aac", "m4a", "wav", "alac", "ogg", "opus", "aiff"]
        var newFiles: [String] = []

        while let file = enumerator.nextObject() as? String {
            let ext = (file as NSString).pathExtension.lowercased()
            if audioExtensions.contains(ext) {
                let fullPath = (musicPath as NSString).appendingPathComponent(file)
                if !knownFilePaths.contains(fullPath) {
                    newFiles.append(fullPath)
                }
            }
        }

        guard !newFiles.isEmpty else { return }

        Task {
            for fullPath in newFiles {
                await scanSingleFile(fullPath)
            }
            buildAlbumsAndArtists()
        }
    }

    private func scanSingleFile(_ fullPath: String) async {
        let fm = FileManager.default
        let ext = (fullPath as NSString).pathExtension.lowercased()

        var title = (fullPath as NSString).lastPathComponent
            .replacingOccurrences(of: ".\(ext)", with: "")
        var artist = "Unknown Artist"
        var album = "Unknown Album"
        var albumArtist: String?
        var trackNumber = 0
        var discNumber = 1
        var year: Int?
        var genre: String?
        var duration: Double = 0
        var artPath: String?

        // Try JSON sidecar first (spotisnare metadata)
        let jsonPath = fullPath.replacingOccurrences(of: ".\(ext)", with: ".json")
        if fm.fileExists(atPath: jsonPath),
           let jsonData = fm.contents(atPath: jsonPath),
           let meta = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            if let t = meta["title"] as? String { title = t }
            if let a = meta["artist"] as? String { artist = a }
            if let al = meta["album"] as? String { album = al }
            if let d = meta["duration_s"] as? Double { duration = d }
            if let artwork = meta["artwork"] as? [String: Any],
               let hasArt = artwork["has_artwork"] as? Bool, hasArt,
               let ap = artwork["path"] as? String, fm.fileExists(atPath: ap) {
                artPath = ap
            }
        } else {
            // Fallback: read AVAsset metadata
            let url = URL(fileURLWithPath: fullPath)
            let asset = AVURLAsset(url: url)

            if let metadata = try? await asset.load(.metadata) {
                for item in metadata {
                    guard let key = item.commonKey?.rawValue else { continue }
                    switch key {
                    case "title":
                        if let val = try? await item.load(.stringValue) { title = val }
                    case "artist":
                        if let val = try? await item.load(.stringValue) { artist = val }
                    case "albumName":
                        if let val = try? await item.load(.stringValue) { album = val }
                    case "type":
                        if let val = try? await item.load(.stringValue) { genre = val }
                    case "artwork":
                        if let data = try? await item.load(.dataValue) {
                            artPath = cacheArtwork(data: data, artist: artist, album: album)
                        }
                    default:
                        break
                    }
                }

                for item in metadata {
                    if let id = item.identifier {
                        let idStr = id.rawValue
                        if idStr.contains("trackNumber"),
                           let val = try? await item.load(.numberValue) {
                            trackNumber = val.intValue
                        } else if idStr.contains("discNumber"),
                                  let val = try? await item.load(.numberValue) {
                            discNumber = val.intValue
                        } else if idStr.contains("albumArtist") || idStr.contains("TPE2"),
                                  let val = try? await item.load(.stringValue) {
                            albumArtist = val
                        } else if idStr.contains("year") || idStr.contains("TDRC") || idStr.contains("©day"),
                                  let val = try? await item.load(.stringValue) {
                            year = Int(val.prefix(4))
                        }
                    }
                }
            }

            if duration == 0, let dur = try? await AVURLAsset(url: URL(fileURLWithPath: fullPath)).load(.duration) {
                duration = CMTimeGetSeconds(dur)
            }
        }

        // Filename fallback for artist/title
        if artist == "Unknown Artist" && title.contains(" - ") {
            let parts = title.split(separator: " - ", maxSplits: 1)
            if parts.count == 2 {
                artist = String(parts[0])
                title = String(parts[1])
            }
        }

        let track = MusicTrack(
            id: nextTrackId,
            title: title,
            artist: artist,
            album: album,
            albumArtist: albumArtist,
            trackNumber: trackNumber,
            discNumber: discNumber,
            year: year,
            genre: genre,
            duration: duration,
            bitrate: nil,
            format: ext,
            filePath: fullPath,
            albumArtPath: artPath,
            favorite: false,
            playCount: 0,
            lastPlayed: nil,
            isExplicit: false
        )
        var mutableTrack = track
        applyStatsToTrack(&mutableTrack)
        tracks.append(mutableTrack)
        knownFilePaths.insert(fullPath)
        // Cache file modification date
        if let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
           let modDate = attrs[.modificationDate] as? Date {
            fileModificationDates[fullPath] = modDate
        }
        nextTrackId += 1
    }

    deinit {
        directoryWatchTimer?.invalidate()
        progressTimer?.invalidate()
        tearDownRemoteCommands()
    }

    // MARK: - Playback Controls

    func play(track: MusicTrack) {
        stopProgressTimer()
        let url = URL(fileURLWithPath: track.filePath)
        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.volume = Float(nowPlaying.volume)
            audioPlayer?.play()

            // Update play stats
            if let index = tracks.firstIndex(where: { $0.id == track.id }) {
                tracks[index].playCount += 1
                tracks[index].lastPlayed = Date()
                nowPlaying.currentTrack = tracks[index]
            } else {
                nowPlaying.currentTrack = track
            }

            nowPlaying.isPlaying = true
            nowPlaying.progress = 0
            updateNowPlayingInfo()
            saveMusicStats()
            startProgressTimer()
        } catch {
            print("Failed to play: \(error)")
        }
    }

    func playAlbum(_ album: MusicAlbum, startingAt index: Int = 0) {
        let tracks = album.tracks
        guard !tracks.isEmpty, index < tracks.count else { return }
        nowPlaying.queue = Array(tracks.dropFirst(index + 1))
        nowPlaying.queueIndex = 0
        play(track: tracks[index])
    }

    func playTracks(_ tracks: [MusicTrack], startingAt index: Int = 0) {
        guard !tracks.isEmpty, index < tracks.count else { return }
        nowPlaying.queue = Array(tracks.dropFirst(index + 1))
        nowPlaying.queueIndex = 0
        play(track: tracks[index])
    }

    func togglePlayPause() {
        guard audioPlayer != nil else { return }
        if nowPlaying.isPlaying {
            audioPlayer?.pause()
            nowPlaying.isPlaying = false
            stopProgressTimer()
        } else {
            audioPlayer?.play()
            nowPlaying.isPlaying = true
            startProgressTimer()
        }
        updateNowPlayingInfo()
    }

    func next() {
        guard !nowPlaying.queue.isEmpty else {
            if nowPlaying.repeatMode == .all, let track = nowPlaying.currentTrack {
                // Restart current track if repeat is on and queue is empty
                play(track: track)
            }
            return
        }
        if nowPlaying.shuffle {
            let randomIndex = Int.random(in: 0..<nowPlaying.queue.count)
            let track = nowPlaying.queue.remove(at: randomIndex)
            play(track: track)
        } else {
            let track = nowPlaying.queue.removeFirst()
            play(track: track)
        }
    }

    func previous() {
        // If more than 3 seconds in, restart current track
        if nowPlaying.progress > 3 {
            seek(to: 0)
        } else if let current = nowPlaying.currentTrack {
            // Go to beginning
            seek(to: 0)
            _ = current // suppress unused warning
        }
    }

    func seek(to time: Double) {
        audioPlayer?.currentTime = time
        nowPlaying.progress = time
        updateNowPlayingInfo()
    }

    func setVolume(_ volume: Double) {
        nowPlaying.volume = volume
        audioPlayer?.volume = Float(volume)
    }

    func volumeUp() {
        setVolume(min(nowPlaying.volume + 0.1, 1.0))
    }

    func volumeDown() {
        setVolume(max(nowPlaying.volume - 0.1, 0.0))
    }

    /// Navigate back from any detail view to the grid
    func navigateBack() {
        if selectedArtist != nil {
            selectedArtist = nil
        } else if selectedAlbum != nil {
            selectedAlbum = nil
        } else if selectedPlaylist != nil {
            selectedPlaylist = nil
        }
    }

    /// Whether the user is in a detail (artist/album/playlist) view
    var isInDetailView: Bool {
        selectedArtist != nil || selectedAlbum != nil || selectedPlaylist != nil
    }

    func toggleShuffle() {
        nowPlaying.shuffle.toggle()
    }

    func cycleRepeat() {
        switch nowPlaying.repeatMode {
        case .off: nowPlaying.repeatMode = .all
        case .all: nowPlaying.repeatMode = .one
        case .one: nowPlaying.repeatMode = .off
        }
    }

    // MARK: - Queue Management

    func addToQueue(_ track: MusicTrack) {
        nowPlaying.queue.append(track)
    }

    func removeFromQueue(at index: Int) {
        guard index < nowPlaying.queue.count else { return }
        nowPlaying.queue.remove(at: index)
    }

    func clearQueue() {
        nowPlaying.queue.removeAll()
    }

    func moveQueueItem(from source: IndexSet, to destination: Int) {
        nowPlaying.queue.move(fromOffsets: source, toOffset: destination)
    }

    // MARK: - Favorites

    func toggleFavorite(_ track: MusicTrack) {
        if let index = tracks.firstIndex(where: { $0.id == track.id }) {
            tracks[index].favorite.toggle()
            saveMusicStats()
        }
    }

    // MARK: - Playlist Management

    func createPlaylist(name: String, description: String? = nil) {
        let playlist = Playlist(
            id: UUID().uuidString,
            name: name,
            description: description,
            trackCount: 0,
            totalDuration: 0,
            tracks: [],
            createdAt: Date()
        )
        playlists.append(playlist)
        savePlaylists()
    }

    func addToPlaylist(_ playlistId: String, track: MusicTrack) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else { return }
        playlists[index].tracks.append(track)
        playlists[index].trackCount = playlists[index].tracks.count
        playlists[index].totalDuration = playlists[index].tracks.reduce(0) { $0 + $1.duration }
        savePlaylists()
    }

    func removeFromPlaylist(_ playlistId: String, trackId: Int64) {
        guard let index = playlists.firstIndex(where: { $0.id == playlistId }) else { return }
        playlists[index].tracks.removeAll { $0.id == trackId }
        playlists[index].trackCount = playlists[index].tracks.count
        playlists[index].totalDuration = playlists[index].tracks.reduce(0) { $0 + $1.duration }
        savePlaylists()
    }

    func deletePlaylist(_ playlistId: String) {
        playlists.removeAll { $0.id == playlistId }
        savePlaylists()
    }

    func savePlaylistEdits() {
        savePlaylists()
    }

    // MARK: - Progress Timer

    private var nowPlayingUpdateCounter: Int = 0

    private func startProgressTimer() {
        nowPlayingUpdateCounter = 0
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self, let player = self.audioPlayer else { return }
                self.nowPlaying.progress = player.currentTime

                // Update Now Playing info every 5 seconds (every 10th tick) to avoid excessive updates
                self.nowPlayingUpdateCounter += 1
                if self.nowPlayingUpdateCounter >= 10 {
                    self.nowPlayingUpdateCounter = 0
                    self.updateNowPlayingInfo()
                }

                if !player.isPlaying && self.nowPlaying.isPlaying {
                    // Track ended
                    if self.nowPlaying.repeatMode == .one {
                        if let track = self.nowPlaying.currentTrack {
                            self.play(track: track)
                        }
                    } else {
                        self.next()
                    }
                }
            }
        }
    }

    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
}
