import SwiftUI

struct SettingsView: View {
    @ObservedObject var viewModel: LibraryViewModel

    // MARK: - Server Connection State
    @State private var serverPing: String = "--"
    @State private var serverName: String = "--"
    @State private var serverVersion: String = "--"
    @State private var isServerReachable = false
    @State private var isTesting = false

    // MARK: - Library State
    @State private var scanDirectories: [String] = []
    @State private var lastScanTime: String = "Never"
    @State private var autoScanOnStartup = true
    @State private var showAddDirectory = false

    // MARK: - Playback State
    @State private var defaultVideoQuality = "Auto"
    @State private var autoPlayNextEpisode = true
    @State private var rememberPlaybackPosition = true
    @State private var subtitleLanguage = "English"
    @State private var subtitleSize = "Medium"

    // MARK: - Music State
    @State private var gaplessPlayback = true
    @State private var audioNormalization = false
    @State private var crossfadeDuration: Double = 0
    @State private var currentAudioDevice = "System Default"

    // MARK: - Cache State
    @State private var imageCacheSize: String = "Calculating..."
    @State private var artistCacheSize: String = "Calculating..."
    @State private var databaseSize: String = "Calculating..."
    @State private var totalStorageUsed: String = "Calculating..."
    @State private var showClearAllConfirm = false
    @State private var showClearImagesConfirm = false
    @State private var showClearArtistsConfirm = false
    @State private var isClearingCache = false

    // MARK: - Network State
    @State private var mDNSDiscovery = true
    @State private var defaultServerPort = "9876"

    // MARK: - Theme
    private let accentGold = Color(red: 0.85, green: 0.65, blue: 0.13)
    private let warmAmber = Color(red: 0.93, green: 0.76, blue: 0.20)
    private let cardBg = Color(white: 0.11)
    private let cardBorder = Color.white.opacity(0.06)

    private let videoQualities = ["Auto", "4K", "1080p", "720p", "480p"]
    private let subtitleLanguages = ["Off", "English", "Spanish", "French", "German", "Japanese", "Korean", "Chinese", "Portuguese", "Italian"]
    private let subtitleSizes = ["Small", "Medium", "Large", "Extra Large"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                headerSection
                serverConnectionCard
                libraryCard
                playbackCard
                musicCard
                cacheStorageCard
                accountCard
                networkCard
                aboutCard
            }
            .padding(32)
        }
        .background(Color(white: 0.1))
        .onAppear {
            loadInitialState()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            colors: [accentGold.opacity(0.2), accentGold.opacity(0.05)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 48, height: 48)
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [warmAmber, accentGold],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("Settings")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                Text("Configure your Cinemate experience")
                    .font(.system(size: 13))
                    .foregroundColor(.gray)
            }
            Spacer()
        }
    }

    // MARK: - Server Connection Card

    private var serverConnectionCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Server Connection")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                connectionStatusBadge
            }

            VStack(spacing: 0) {
                // Server URL row
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Server URL")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                        Text(viewModel.serverURL ?? "Not configured")
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundColor(.white)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    HStack(spacing: 4) {
                        Circle()
                            .fill(isServerReachable ? Color.green : Color.red)
                            .frame(width: 8, height: 8)
                        Text(serverPing)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(isServerReachable ? .green : .red.opacity(0.7))
                    }
                }
                .padding(14)

                Divider().background(Color.white.opacity(0.04))

                // Server name & version
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Server Name")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                        Text(serverName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Version")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                        Text(serverVersion)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                    }
                    Spacer()
                }
                .padding(14)

                Divider().background(Color.white.opacity(0.04))

                // Library stats summary
                HStack(spacing: 0) {
                    libraryStat(icon: "film", label: "Movies", count: viewModel.movies.count)
                    Divider().background(Color.white.opacity(0.04)).frame(height: 40)
                    libraryStat(icon: "tv", label: "TV Shows", count: viewModel.shows.count)
                    Divider().background(Color.white.opacity(0.04)).frame(height: 40)
                    libraryStat(icon: "music.note", label: "Tracks", count: viewModel.musicViewModel.tracks.count)
                    Divider().background(Color.white.opacity(0.04)).frame(height: 40)
                    libraryStat(icon: "book", label: "Books", count: viewModel.bookViewModel.books.count)
                }
                .padding(.vertical, 10)

                Divider().background(Color.white.opacity(0.04))

                // Action buttons
                HStack(spacing: 10) {
                    Button(action: { testConnection() }) {
                        HStack(spacing: 6) {
                            if isTesting {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .frame(width: 14, height: 14)
                            } else {
                                Image(systemName: "antenna.radiowaves.left.and.right")
                                    .font(.system(size: 12))
                            }
                            Text(isTesting ? "Testing..." : "Test Connection")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(accentGold)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(isTesting)

                    if viewModel.serverURL != nil {
                        Button(action: { disconnectServer() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "xmark.circle")
                                    .font(.system(size: 12))
                                Text("Disconnect")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.red.opacity(0.9))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }

                    Spacer()
                }
                .padding(14)
            }
            .background(Color.white.opacity(0.03))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Library Card

    private var libraryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Library")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                if viewModel.isScanning {
                    HStack(spacing: 6) {
                        ProgressView()
                            .scaleEffect(0.5)
                            .frame(width: 12, height: 12)
                        Text("Scanning... \(viewModel.scanProgress)%")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(accentGold)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(accentGold.opacity(0.1))
                    .cornerRadius(10)
                }
            }

            VStack(spacing: 0) {
                // Scan directories list
                VStack(alignment: .leading, spacing: 10) {
                    Text("Media Directories")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.gray)

                    if scanDirectories.isEmpty {
                        HStack(spacing: 8) {
                            Image(systemName: "folder.badge.questionmark")
                                .font(.system(size: 14))
                                .foregroundColor(.white.opacity(0.15))
                            Text("No directories configured")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.3))
                        }
                        .padding(.vertical, 8)
                    } else {
                        ForEach(scanDirectories, id: \.self) { dir in
                            HStack(spacing: 10) {
                                Image(systemName: "folder.fill")
                                    .font(.system(size: 12))
                                    .foregroundColor(accentGold.opacity(0.7))
                                Text(dir)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(.white.opacity(0.8))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                                Spacer()
                                Button(action: { scanDirectories.removeAll { $0 == dir } }) {
                                    Image(systemName: "trash")
                                        .font(.system(size: 11))
                                        .foregroundColor(.red.opacity(0.5))
                                }
                                .buttonStyle(.plain)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color.white.opacity(0.03))
                            .cornerRadius(6)
                        }
                    }

                    Button(action: { addDirectory() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 11))
                            Text("Add Directory")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(accentGold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(accentGold.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)

                Divider().background(Color.white.opacity(0.04))

                // Scan controls
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Last Scan")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                        Text(lastScanTime)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                    }

                    Spacer()

                    Button(action: { rescanLibrary() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12))
                            Text("Rescan Library")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(accentGold)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isScanning || scanDirectories.isEmpty)
                }
                .padding(14)

                Divider().background(Color.white.opacity(0.04))

                // Auto-scan toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Scan on Startup")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("Automatically scan media directories when the app launches")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Toggle("", isOn: $autoScanOnStartup)
                        .toggleStyle(.switch)
                        .tint(accentGold)
                        .labelsHidden()
                }
                .padding(14)
            }
            .background(Color.white.opacity(0.03))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Playback Card

    private var playbackCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Playback")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            VStack(spacing: 0) {
                // Default video quality
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Default Video Quality")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("Preferred quality when streaming from server")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Picker("", selection: $defaultVideoQuality) {
                        ForEach(videoQualities, id: \.self) { q in
                            Text(q).tag(q)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 120)
                    .tint(accentGold)
                }
                .padding(14)

                Divider().background(Color.white.opacity(0.04))

                // Auto-play next episode
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Play Next Episode")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("Automatically play the next episode in a series")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Toggle("", isOn: $autoPlayNextEpisode)
                        .toggleStyle(.switch)
                        .tint(accentGold)
                        .labelsHidden()
                }
                .padding(14)

                Divider().background(Color.white.opacity(0.04))

                // Remember playback position
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Remember Playback Position")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("Resume where you left off when rewatching")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Toggle("", isOn: $rememberPlaybackPosition)
                        .toggleStyle(.switch)
                        .tint(accentGold)
                        .labelsHidden()
                }
                .padding(14)

                Divider().background(Color.white.opacity(0.04))

                // Subtitles
                HStack(spacing: 24) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Subtitle Language")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                        Picker("", selection: $subtitleLanguage) {
                            ForEach(subtitleLanguages, id: \.self) { lang in
                                Text(lang).tag(lang)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                        .tint(accentGold)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Subtitle Size")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.gray)
                        Picker("", selection: $subtitleSize) {
                            ForEach(subtitleSizes, id: \.self) { size in
                                Text(size).tag(size)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                        .tint(accentGold)
                    }
                    Spacer()
                }
                .padding(14)
            }
            .background(Color.white.opacity(0.03))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Music Card

    private var musicCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Music")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            VStack(spacing: 0) {
                // Audio output device
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Audio Output Device")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("Current output for music playback")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    HStack(spacing: 6) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 11))
                            .foregroundColor(accentGold.opacity(0.7))
                        Text(currentAudioDevice)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(6)
                }
                .padding(14)

                Divider().background(Color.white.opacity(0.04))

                // Gapless playback
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Gapless Playback")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("Seamless transitions between tracks in albums")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Toggle("", isOn: $gaplessPlayback)
                        .toggleStyle(.switch)
                        .tint(accentGold)
                        .labelsHidden()
                }
                .padding(14)

                Divider().background(Color.white.opacity(0.04))

                // Audio normalization
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Audio Normalization")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("Keep volume consistent across different tracks")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Toggle("", isOn: $audioNormalization)
                        .toggleStyle(.switch)
                        .tint(accentGold)
                        .labelsHidden()
                }
                .padding(14)

                Divider().background(Color.white.opacity(0.04))

                // Crossfade
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Crossfade")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Text("Blend the end of one track into the next")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Text(crossfadeDuration == 0 ? "Off" : String(format: "%.1fs", crossfadeDuration))
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundColor(crossfadeDuration == 0 ? .gray : accentGold)
                    }
                    Slider(value: $crossfadeDuration, in: 0...12, step: 0.5)
                        .tint(accentGold)
                    HStack {
                        Text("Off")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                        Spacer()
                        Text("12s")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                }
                .padding(14)
            }
            .background(Color.white.opacity(0.03))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Cache & Storage Card

    private var cacheStorageCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Cache & Storage")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Text(totalStorageUsed)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.gray)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(10)
            }

            VStack(spacing: 0) {
                // Image cache
                cacheRow(
                    icon: "photo.stack",
                    label: "Image Cache",
                    detail: "Thumbnails, posters, and artwork",
                    size: imageCacheSize,
                    clearAction: { showClearImagesConfirm = true }
                )
                .alert("Clear Image Cache?", isPresented: $showClearImagesConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Clear", role: .destructive) { clearImageCache() }
                } message: {
                    Text("Thumbnails and artwork will be re-downloaded as needed.")
                }

                Divider().background(Color.white.opacity(0.04))

                // Artist profile cache
                cacheRow(
                    icon: "person.crop.circle",
                    label: "Artist Profiles",
                    detail: "Artist bios, images, and metadata",
                    size: artistCacheSize,
                    clearAction: { showClearArtistsConfirm = true }
                )
                .alert("Clear Artist Cache?", isPresented: $showClearArtistsConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Clear", role: .destructive) { clearArtistCache() }
                } message: {
                    Text("Artist profiles will be re-fetched when viewed.")
                }

                Divider().background(Color.white.opacity(0.04))

                // Database
                HStack {
                    HStack(spacing: 10) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 7)
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 32, height: 32)
                            Image(systemName: "cylinder")
                                .font(.system(size: 13))
                                .foregroundColor(.blue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Database")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.white)
                            Text("Library metadata and user data")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                    }
                    Spacer()
                    Text(databaseSize)
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundColor(.white.opacity(0.6))
                }
                .padding(14)

                Divider().background(Color.white.opacity(0.04))

                // Clear all caches
                HStack {
                    Spacer()
                    Button(action: { showClearAllConfirm = true }) {
                        HStack(spacing: 6) {
                            if isClearingCache {
                                ProgressView()
                                    .scaleEffect(0.5)
                                    .frame(width: 12, height: 12)
                            } else {
                                Image(systemName: "trash")
                                    .font(.system(size: 12))
                            }
                            Text("Clear All Caches")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.red.opacity(0.9))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red.opacity(0.1))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.red.opacity(0.15), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isClearingCache)
                    Spacer()
                }
                .padding(14)
                .alert("Clear All Caches?", isPresented: $showClearAllConfirm) {
                    Button("Cancel", role: .cancel) {}
                    Button("Clear Everything", role: .destructive) { clearAllCaches() }
                } message: {
                    Text("This will remove all cached images, artist profiles, and temporary data. Everything will be re-downloaded as needed.")
                }
            }
            .background(Color.white.opacity(0.03))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Account Card

    private var accountCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Account")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            VStack(spacing: 0) {
                // Current account
                HStack(spacing: 12) {
                    if let account = viewModel.currentAccount {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [colorFromHex(account.avatarColor), colorFromHex(account.avatarColor).opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 40, height: 40)
                            Text(account.initial)
                                .font(.system(size: 18, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(account.name)
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Text("Active profile")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                    } else {
                        ZStack {
                            Circle()
                                .fill(Color.gray.opacity(0.2))
                                .frame(width: 40, height: 40)
                            Image(systemName: "person.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Default Profile")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                            Text("No account selected")
                                .font(.system(size: 11))
                                .foregroundColor(.gray)
                        }
                    }

                    Spacer()

                    HStack(spacing: 8) {
                        Button(action: { viewModel.currentTab = .profile }) {
                            HStack(spacing: 6) {
                                Image(systemName: "person.crop.circle")
                                    .font(.system(size: 11))
                                Text("View Profile")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(accentGold)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(accentGold.opacity(0.1))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)

                        Button(action: { viewModel.switchProfile() }) {
                            HStack(spacing: 6) {
                                Image(systemName: "arrow.left.arrow.right")
                                    .font(.system(size: 11))
                                Text("Switch")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(Color.white.opacity(0.06))
                            .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(14)
            }
            .background(Color.white.opacity(0.03))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Network Card

    private var networkCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Network")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            VStack(spacing: 0) {
                // Quick link to LAN/WAN admin
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Server Administration")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("Manage LAN and WAN server settings")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Button(action: { viewModel.currentTab = .lanAdmin }) {
                        HStack(spacing: 6) {
                            Image(systemName: "network")
                                .font(.system(size: 11))
                            Text("Open Network Admin")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(accentGold)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
                .padding(14)

                Divider().background(Color.white.opacity(0.04))

                // mDNS discovery toggle
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("mDNS / Bonjour Discovery")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("Allow automatic server discovery on local network")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    Toggle("", isOn: $mDNSDiscovery)
                        .toggleStyle(.switch)
                        .tint(accentGold)
                        .labelsHidden()
                }
                .padding(14)

                Divider().background(Color.white.opacity(0.04))

                // Default server port
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Default Server Port")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                        Text("Port used when starting a local server")
                            .font(.system(size: 11))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                    TextField("9876", text: $defaultServerPort)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13, weight: .medium, design: .monospaced))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.06))
                        .cornerRadius(6)
                }
                .padding(14)
            }
            .background(Color.white.opacity(0.03))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - About Card

    private var aboutCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("About")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)

            VStack(spacing: 0) {
                // App identity
                HStack(spacing: 14) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(
                                LinearGradient(
                                    colors: [Color.red.opacity(0.3), Color.orange.opacity(0.15)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 48, height: 48)
                        Text("C")
                            .font(.system(size: 24, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.red, .orange],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cinemate")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                        Text("Your personal media server")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    Spacer()
                }
                .padding(14)

                Divider().background(Color.white.opacity(0.04))

                // Info grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 2) {
                    aboutInfoTile(label: "Version", value: appVersion)
                    aboutInfoTile(label: "Build", value: appBuild)
                    aboutInfoTile(label: "macOS", value: macOSVersion)
                    aboutInfoTile(label: "Architecture", value: cpuArchitecture)
                }
                .padding(4)

                Divider().background(Color.white.opacity(0.04))

                // Actions
                HStack(spacing: 10) {
                    Button(action: { checkForUpdates() }) {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.down.circle")
                                .font(.system(size: 12))
                            Text("Check for Updates")
                                .font(.system(size: 12, weight: .medium))
                        }
                        .foregroundColor(accentGold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 7)
                        .background(accentGold.opacity(0.1))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    Spacer()

                    Text("Built with SwiftUI + Python")
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.2))
                }
                .padding(14)
            }
            .background(Color.white.opacity(0.03))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.white.opacity(0.04), lineWidth: 1)
            )
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(cardBg)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(cardBorder, lineWidth: 1)
                )
        )
    }

    // MARK: - Subcomponents

    private var connectionStatusBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(isServerReachable ? Color.green : (viewModel.serverURL != nil ? Color.orange : Color(white: 0.4)))
                .frame(width: 7, height: 7)
            Text(isServerReachable ? "Connected" : (viewModel.serverURL != nil ? "Unreachable" : "Disconnected"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(isServerReachable ? .green : (viewModel.serverURL != nil ? .orange : Color(white: 0.4)))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background((isServerReachable ? Color.green : (viewModel.serverURL != nil ? Color.orange : Color(white: 0.4))).opacity(0.1))
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke((isServerReachable ? Color.green : (viewModel.serverURL != nil ? Color.orange : Color(white: 0.4))).opacity(0.2), lineWidth: 1)
        )
    }

    private func libraryStat(icon: String, label: String, count: Int) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(accentGold.opacity(0.7))
            Text("\(count)")
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(.white)
            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
    }

    private func cacheRow(icon: String, label: String, detail: String, size: String, clearAction: @escaping () -> Void) -> some View {
        HStack {
            HStack(spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(accentGold.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Image(systemName: icon)
                        .font(.system(size: 13))
                        .foregroundColor(accentGold)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.white)
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundColor(.gray)
                }
            }
            Spacer()
            Text(size)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.6))
                .padding(.trailing, 8)
            Button(action: clearAction) {
                Text("Clear")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(5)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
    }

    private func aboutInfoTile(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.02))
        .cornerRadius(6)
    }

    // MARK: - Computed Properties

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "3.0.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var macOSVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    private var cpuArchitecture: String {
        #if arch(arm64)
        return "Apple Silicon"
        #elseif arch(x86_64)
        return "Intel x86_64"
        #else
        return "Unknown"
        #endif
    }

    // MARK: - Actions

    private func loadInitialState() {
        pingServer()
        fetchServerInfo()
        calculateCacheSizes()
        detectAudioDevice()
        loadScanDirectories()
    }

    private func pingServer() {
        guard let serverURL = viewModel.serverURL, !serverURL.isEmpty else {
            serverPing = "N/A"
            isServerReachable = false
            return
        }
        let start = Date()
        guard let url = URL(string: "\(serverURL)/api/server/info") else { return }
        URLSession.shared.dataTask(with: url) { _, response, error in
            DispatchQueue.main.async {
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    let ms = Int(Date().timeIntervalSince(start) * 1000)
                    serverPing = "\(ms)ms"
                    isServerReachable = true
                } else {
                    serverPing = "Unreachable"
                    isServerReachable = false
                }
            }
        }.resume()
    }

    private func fetchServerInfo() {
        guard let serverURL = viewModel.serverURL, !serverURL.isEmpty else {
            serverName = "Not connected"
            serverVersion = "--"
            return
        }
        guard let url = URL(string: "\(serverURL)/api/server/info") else { return }
        URLSession.shared.dataTask(with: url) { data, response, _ in
            DispatchQueue.main.async {
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    serverName = "Cinemate Server"
                    serverVersion = "Unknown"
                    return
                }
                serverName = json["name"] as? String ?? "Cinemate Server"
                serverVersion = json["version"] as? String ?? "Unknown"
            }
        }.resume()
    }

    private func testConnection() {
        isTesting = true
        let start = Date()
        let urlString = viewModel.serverURL ?? "http://localhost:9876"
        guard let url = URL(string: "\(urlString)/api/server/info") else {
            isTesting = false
            return
        }
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isTesting = false
                if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    let ms = Int(Date().timeIntervalSince(start) * 1000)
                    serverPing = "\(ms)ms"
                    isServerReachable = true
                    if viewModel.serverURL == nil {
                        viewModel.serverURL = urlString
                        viewModel.musicViewModel.serverURL = urlString
                    }
                    // Parse server info
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        serverName = json["name"] as? String ?? "Cinemate Server"
                        serverVersion = json["version"] as? String ?? "Unknown"
                    }
                } else {
                    serverPing = "Unreachable"
                    isServerReachable = false
                }
            }
        }.resume()
    }

    private func disconnectServer() {
        viewModel.serverURL = nil
        viewModel.musicViewModel.serverURL = nil
        isServerReachable = false
        serverPing = "N/A"
        serverName = "Not connected"
        serverVersion = "--"
    }

    private func loadScanDirectories() {
        let defaults = UserDefaults.standard
        if let dirs = defaults.stringArray(forKey: "cinemate.scanDirectories") {
            scanDirectories = dirs
        } else {
            // Check for the common default path
            let defaultPath = "/Volumes/Maliq Backup/Movies RF"
            if FileManager.default.fileExists(atPath: defaultPath) {
                scanDirectories = [defaultPath]
            }
        }
        if let lastScan = defaults.object(forKey: "cinemate.lastScanTime") as? Date {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            lastScanTime = formatter.localizedString(for: lastScan, relativeTo: Date())
        }
    }

    private func addDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.message = "Select a media directory to scan"
        panel.prompt = "Add Directory"

        if panel.runModal() == .OK, let url = panel.url {
            let path = url.path
            if !scanDirectories.contains(path) {
                scanDirectories.append(path)
                UserDefaults.standard.set(scanDirectories, forKey: "cinemate.scanDirectories")
            }
        }
    }

    private func rescanLibrary() {
        for dir in scanDirectories {
            viewModel.scan(directory: dir)
        }
        UserDefaults.standard.set(Date(), forKey: "cinemate.lastScanTime")
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        lastScanTime = formatter.localizedString(for: Date(), relativeTo: Date())
    }

    private func calculateCacheSizes() {
        DispatchQueue.global(qos: .utility).async {
            let fm = FileManager.default
            let base = fm.homeDirectoryForCurrentUser.appendingPathComponent(".cinemate")

            // Image cache (thumbnails + artwork + cache dirs)
            let imageDirs = ["thumbnails", "artwork", "cache"]
            var imageTotal: Int64 = 0
            for dir in imageDirs {
                let dirURL = base.appendingPathComponent(dir)
                imageTotal += Self.directorySize(dirURL)
            }

            // Artist profiles specifically
            let artistDir = base.appendingPathComponent("thumbnails").appendingPathComponent("artists")
            let artistTotal = Self.directorySize(artistDir)

            // Database size
            let dbDir = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Cinemate")
            let dbTotal = Self.directorySize(dbDir)

            let grandTotal = imageTotal + dbTotal

            DispatchQueue.main.async {
                imageCacheSize = Self.formatBytes(imageTotal)
                artistCacheSize = Self.formatBytes(artistTotal)
                databaseSize = Self.formatBytes(dbTotal)
                totalStorageUsed = Self.formatBytes(grandTotal) + " total"
            }
        }
    }

    private static func directorySize(_ url: URL) -> Int64 {
        var total: Int64 = 0
        if let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let size = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    total += Int64(size)
                }
            }
        }
        return total
    }

    private static func formatBytes(_ bytes: Int64) -> String {
        if bytes > 1_073_741_824 {
            return String(format: "%.1f GB", Double(bytes) / 1_073_741_824)
        } else if bytes > 1_048_576 {
            return String(format: "%.1f MB", Double(bytes) / 1_048_576)
        } else if bytes > 1024 {
            return String(format: "%.0f KB", Double(bytes) / 1024)
        }
        return "0 KB"
    }

    private func clearImageCache() {
        isClearingCache = true
        DispatchQueue.global(qos: .utility).async {
            let dirs = ["thumbnails", "artwork", "cache"]
            let base = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cinemate")
            for dir in dirs {
                let path = base.appendingPathComponent(dir)
                try? FileManager.default.removeItem(at: path)
                try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
            }
            DispatchQueue.main.async {
                isClearingCache = false
                calculateCacheSizes()
            }
        }
    }

    private func clearArtistCache() {
        DispatchQueue.global(qos: .utility).async {
            let base = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(".cinemate")
                .appendingPathComponent("thumbnails")
                .appendingPathComponent("artists")
            try? FileManager.default.removeItem(at: base)
            try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
            DispatchQueue.main.async {
                calculateCacheSizes()
            }
        }
    }

    private func clearAllCaches() {
        isClearingCache = true
        DispatchQueue.global(qos: .utility).async {
            let dirs = ["thumbnails", "artwork", "cache"]
            let base = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".cinemate")
            for dir in dirs {
                let path = base.appendingPathComponent(dir)
                try? FileManager.default.removeItem(at: path)
                try? FileManager.default.createDirectory(at: path, withIntermediateDirectories: true)
            }
            DispatchQueue.main.async {
                isClearingCache = false
                calculateCacheSizes()
            }
        }
    }

    private func detectAudioDevice() {
        // Use the default output device name from CoreAudio if available
        currentAudioDevice = "System Default"
    }

    private func checkForUpdates() {
        // Placeholder: in a real app this would check a release endpoint
        // For now, this is a no-op that could be wired to a GitHub releases API
    }

    private func colorFromHex(_ hex: String) -> Color {
        let clean = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: clean).scanHexInt64(&int)
        let r, g, b: Double
        switch clean.count {
        case 6:
            r = Double((int >> 16) & 0xFF) / 255.0
            g = Double((int >> 8) & 0xFF) / 255.0
            b = Double(int & 0xFF) / 255.0
        default:
            r = 0.5; g = 0.5; b = 0.5
        }
        return Color(red: r, green: g, blue: b)
    }
}
