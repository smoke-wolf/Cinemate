import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var apiClient: APIClient
    @EnvironmentObject var downloadManager: DownloadManager

    var account: Account?
    var onSwitchAccount: (() -> Void)?

    // MARK: - State

    @State private var selectedQuality: StreamQuality = .auto
    @State private var showChangeServer = false
    @State private var autoPlayNextEpisode = true
    @State private var skipIntro = true

    // Downloads
    @State private var downloadQuality: DownloadQuality = .high
    @State private var autoDeleteWatched = false
    @State private var downloadOverCellular = false

    // Notifications
    @State private var notifyNewContent = true
    @State private var notifyDownloadComplete = true

    // Server ping
    @State private var pingLatencyMs: Int?
    @State private var isPinging = false
    @State private var testConnectionResult: ConnectionTestResult?

    // Storage
    @State private var imageCacheSize: Int64 = 0
    @State private var showClearCacheConfirm = false
    @State private var cacheCleared = false

    // About
    @State private var showAcknowledgements = false

    // MARK: - Enums

    enum StreamQuality: String, CaseIterable {
        case auto = "Auto"
        case high = "High (1080p)"
        case medium = "Medium (720p)"
        case low = "Low (480p)"
    }

    enum DownloadQuality: String, CaseIterable {
        case original = "Original"
        case high = "High"
        case medium = "Medium"
        case low = "Low"
    }

    enum ConnectionTestResult {
        case success(latency: Int)
        case failure(String)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            List {
                serverSection
                if account != nil {
                    accountSection
                }
                playbackSection
                downloadsSection
                storageSection
                notificationsSection
                aboutSection
            }
            .cinemateInsetGroupedListStyle()
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Settings")
        .cinemateNavigationBarLarge()
        .cinemateToolbarBackground(Theme.background)
        .cinemateToolbarColorScheme(.dark)
        .alert("Change Server", isPresented: $showChangeServer) {
            Button("Disconnect", role: .destructive) {
                UserDefaults.standard.removeObject(forKey: "savedServerURL")
                apiClient.isConnected = false
                apiClient.baseURL = ""
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Disconnect from the current server? You will need to reconnect.")
        }
        .alert("Clear Cache", isPresented: $showClearCacheConfirm) {
            Button("Clear", role: .destructive) {
                Task {
                    await ImageCacheService.shared.clearCache()
                    imageCacheSize = 0
                    cacheCleared = true
                    hapticNotification(.success)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Remove all cached images? They will be re-downloaded as needed.")
        }
        .sheet(isPresented: $showAcknowledgements) {
            AcknowledgementsSheet()
        }
        .task {
            await loadStorageInfo()
            await measurePing()
        }
    }

    // MARK: - Server Section

    private var serverSection: some View {
        Section {
            // Server name + URL + status
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Theme.primaryGold.opacity(0.15))
                        .frame(width: 40, height: 40)

                    Image(systemName: "server.rack")
                        .font(.system(size: 17))
                        .foregroundStyle(Theme.primaryGold)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(apiClient.serverStatus?.name ?? "Server")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)

                    Text(apiClient.baseURL.isEmpty ? "Not connected" : apiClient.baseURL)
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                // Ping indicator
                pingIndicator
            }
            .padding(.vertical, 4)

            // Server version
            if let status = apiClient.serverStatus {
                settingsRow(icon: "tag", title: "Version", value: status.version)

                // Media count
                if let mediaCount = status.mediaCount {
                    settingsRow(icon: "film.stack", title: "Library Items", value: "\(mediaCount)")
                }

                // Uptime
                if let uptime = status.uptime {
                    settingsRow(icon: "clock.arrow.circlepath", title: "Uptime", value: formatUptime(uptime))
                }
            }

            // Test Connection
            Button(action: {
                Task { await testConnection() }
            }) {
                HStack {
                    Label {
                        Text("Test Connection")
                            .font(.system(size: 15))
                    } icon: {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                    }
                    .foregroundStyle(Theme.primaryGold)

                    Spacer()

                    if isPinging {
                        ProgressView()
                            .tint(Theme.textTertiary)
                            .scaleEffect(0.8)
                    } else if let result = testConnectionResult {
                        testResultBadge(result)
                    }
                }
            }
            .disabled(isPinging)

            // Change Server
            Button(action: { showChangeServer = true }) {
                Label("Change Server", systemImage: "arrow.triangle.2.circlepath")
                    .font(.system(size: 15))
                    .foregroundStyle(Theme.primaryGold)
            }
        } header: {
            sectionHeader("Server Connection")
        }
        .listRowBackground(Theme.cardSurface)
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section {
            if let account = account {
                HStack(spacing: 12) {
                    Circle()
                        .fill(account.color.gradient)
                        .frame(width: 44, height: 44)
                        .overlay {
                            Text(account.initials)
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .shadow(color: account.color.opacity(0.3), radius: 6, x: 0, y: 2)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(account.name)
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Theme.textPrimary)

                        Text("Active Profile")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Spacer()

                    if account.hasPIN {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .padding(.vertical, 4)

                if let onSwitchAccount {
                    Button(action: onSwitchAccount) {
                        Label("Switch Account", systemImage: "person.2")
                            .font(.system(size: 15))
                            .foregroundStyle(Theme.primaryGold)
                    }
                }
            }
        } header: {
            sectionHeader("Account")
        }
        .listRowBackground(Theme.cardSurface)
    }

    // MARK: - Playback Section

    private var playbackSection: some View {
        Section {
            Picker(selection: $selectedQuality) {
                ForEach(StreamQuality.allCases, id: \.self) { quality in
                    Text(quality.rawValue).tag(quality)
                }
            } label: {
                Label {
                    Text("Stream Quality")
                        .font(.system(size: 15))
                } icon: {
                    Image(systemName: "waveform")
                }
                .foregroundStyle(Theme.textPrimary)
            }
            .tint(Theme.primaryGold)

            settingsToggle(
                icon: "play.circle",
                title: "Auto-Play Next Episode",
                isOn: $autoPlayNextEpisode
            )

            settingsToggle(
                icon: "forward.end",
                title: "Skip Intro",
                isOn: $skipIntro
            )
        } header: {
            sectionHeader("Playback")
        }
        .listRowBackground(Theme.cardSurface)
    }

    // MARK: - Downloads Section

    private var downloadsSection: some View {
        Section {
            // Total download size
            settingsRow(
                icon: "internaldrive",
                title: "Downloaded",
                value: ByteCountFormatter.string(
                    fromByteCount: downloadManager.totalDownloadedSize(),
                    countStyle: .file
                )
            )

            Picker(selection: $downloadQuality) {
                ForEach(DownloadQuality.allCases, id: \.self) { quality in
                    Text(quality.rawValue).tag(quality)
                }
            } label: {
                Label {
                    Text("Download Quality")
                        .font(.system(size: 15))
                } icon: {
                    Image(systemName: "arrow.down.circle")
                }
                .foregroundStyle(Theme.textPrimary)
            }
            .tint(Theme.primaryGold)

            settingsToggle(
                icon: "trash.circle",
                title: "Auto-Delete Watched",
                isOn: $autoDeleteWatched
            )

            settingsToggle(
                icon: "antenna.radiowaves.left.and.right",
                title: "Download Over Cellular",
                isOn: $downloadOverCellular
            )
        } header: {
            sectionHeader("Downloads")
        }
        .listRowBackground(Theme.cardSurface)
    }

    // MARK: - Storage Section

    private var storageSection: some View {
        Section {
            // Image cache
            HStack {
                Label {
                    Text("Image Cache")
                        .font(.system(size: 15))
                } icon: {
                    Image(systemName: "photo.stack")
                        .foregroundStyle(Theme.primaryGold)
                }
                .foregroundStyle(Theme.textPrimary)

                Spacer()

                if cacheCleared {
                    Text("Cleared")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.success)
                } else {
                    Text(ByteCountFormatter.string(fromByteCount: imageCacheSize, countStyle: .file))
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }
            }

            // Download storage
            settingsRow(
                icon: "arrow.down.doc",
                title: "Downloads Storage",
                value: ByteCountFormatter.string(
                    fromByteCount: downloadManager.totalDownloadedSize(),
                    countStyle: .file
                )
            )

            // Total app storage
            settingsRow(
                icon: "chart.pie",
                title: "Total App Storage",
                value: ByteCountFormatter.string(
                    fromByteCount: imageCacheSize + downloadManager.totalDownloadedSize(),
                    countStyle: .file
                )
            )

            // Clear cache button
            Button(action: {
                if imageCacheSize > 0 {
                    showClearCacheConfirm = true
                }
            }) {
                Label("Clear Image Cache", systemImage: "trash")
                    .font(.system(size: 15))
                    .foregroundStyle(imageCacheSize > 0 ? Theme.error : Theme.textTertiary)
            }
            .disabled(imageCacheSize == 0 && !cacheCleared)
        } header: {
            sectionHeader("Storage")
        }
        .listRowBackground(Theme.cardSurface)
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        Section {
            settingsToggle(
                icon: "bell.badge",
                title: "New Content Available",
                isOn: $notifyNewContent
            )

            settingsToggle(
                icon: "checkmark.circle",
                title: "Download Complete",
                isOn: $notifyDownloadComplete
            )
        } header: {
            sectionHeader("Notifications")
        }
        .listRowBackground(Theme.cardSurface)
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section {
            settingsRow(icon: "info.circle", title: "Version", value: appVersion)
            settingsRow(icon: "hammer", title: "Build", value: appBuild)
            settingsRow(icon: "iphone", title: "Device", value: deviceName)

            // Appearance (locked)
            HStack {
                Label {
                    Text("Theme")
                        .font(.system(size: 15))
                } icon: {
                    Image(systemName: "moon.fill")
                        .foregroundStyle(Theme.primaryGold)
                }
                .foregroundStyle(Theme.textPrimary)

                Spacer()

                Text("Dark")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
            }

            // Acknowledgements
            Button(action: { showAcknowledgements = true }) {
                HStack {
                    Label {
                        Text("Acknowledgements")
                            .font(.system(size: 15))
                    } icon: {
                        Image(systemName: "heart")
                            .foregroundStyle(Theme.primaryGold)
                    }
                    .foregroundStyle(Theme.textPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }

            // Source code
            Link(destination: URL(string: "https://github.com/cinemate")!) {
                HStack {
                    Label {
                        Text("Source Code")
                            .font(.system(size: 15))
                    } icon: {
                        Image(systemName: "chevron.left.forwardslash.chevron.right")
                    }
                    .foregroundStyle(Theme.primaryGold)

                    Spacer()

                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(Theme.textTertiary)
                }
            }
        } header: {
            sectionHeader("About Cinemate")
        } footer: {
            VStack(spacing: 6) {
                Text("Cinemate - Your Private Cinema")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textTertiary)

                Text("Self-hosted media streaming")
                    .font(.system(size: 11))
                    .foregroundStyle(Theme.textTertiary.opacity(0.6))
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 20)
        }
        .listRowBackground(Theme.cardSurface)
    }

    // MARK: - Reusable Row Components

    private func settingsRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Label {
                Text(title)
                    .font(.system(size: 15))
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(Theme.primaryGold)
            }
            .foregroundStyle(Theme.textPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func settingsToggle(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        Toggle(isOn: isOn) {
            Label {
                Text(title)
                    .font(.system(size: 15))
            } icon: {
                Image(systemName: icon)
                    .foregroundStyle(Theme.primaryGold)
            }
            .foregroundStyle(Theme.textPrimary)
        }
        .tint(Theme.primaryGold)
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .foregroundStyle(Theme.textSecondary)
    }

    // MARK: - Ping Indicator

    @ViewBuilder
    private var pingIndicator: some View {
        HStack(spacing: 6) {
            if let ms = pingLatencyMs {
                Circle()
                    .fill(pingColor(ms: ms))
                    .frame(width: 8, height: 8)

                Text("\(ms)ms")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.textTertiary)
            } else if apiClient.isConnected {
                Circle()
                    .fill(Theme.success)
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func pingColor(ms: Int) -> Color {
        switch ms {
        case 0..<100: return Theme.success
        case 100..<300: return Theme.warning
        default: return Theme.error
        }
    }

    @ViewBuilder
    private func testResultBadge(_ result: ConnectionTestResult) -> some View {
        switch result {
        case .success(let latency):
            HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                Text("\(latency)ms")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
            .foregroundStyle(Theme.success)

        case .failure:
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(Theme.error)
        }
    }

    // MARK: - Actions

    private func measurePing() async {
        guard !apiClient.baseURL.isEmpty,
              let url = URL(string: "\(apiClient.baseURL)/api/status") else { return }

        let start = CFAbsoluteTimeGetCurrent()
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                let elapsed = CFAbsoluteTimeGetCurrent() - start
                pingLatencyMs = Int(elapsed * 1000)
            }
        } catch {
            pingLatencyMs = nil
        }
    }

    private func testConnection() async {
        isPinging = true
        testConnectionResult = nil

        let start = CFAbsoluteTimeGetCurrent()
        do {
            _ = try await apiClient.testConnection()
            let elapsed = CFAbsoluteTimeGetCurrent() - start
            let ms = Int(elapsed * 1000)
            pingLatencyMs = ms
            testConnectionResult = .success(latency: ms)
            hapticNotification(.success)
        } catch {
            testConnectionResult = .failure(error.localizedDescription)
            hapticNotification(.error)
        }

        isPinging = false
    }

    private func loadStorageInfo() async {
        imageCacheSize = await ImageCacheService.shared.cacheSize()
    }

    // MARK: - Computed Properties

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }

    private var appBuild: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    private var deviceName: String {
        #if os(iOS)
        UIDevice.current.name
        #else
        Host.current().localizedName ?? "Mac"
        #endif
    }

    // MARK: - Helpers

    private func formatUptime(_ seconds: TimeInterval) -> String {
        let totalSeconds = Int(seconds)
        let days = totalSeconds / 86400
        let hours = (totalSeconds % 86400) / 3600
        let minutes = (totalSeconds % 3600) / 60

        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Acknowledgements Sheet

struct AcknowledgementsSheet: View {
    @Environment(\.dismiss) var dismiss

    private let acknowledgements: [(name: String, license: String)] = [
        ("SwiftUI", "Apple Inc."),
        ("AVFoundation", "Apple Inc."),
        ("PDFKit", "Apple Inc."),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.background.ignoresSafeArea()

                List {
                    Section {
                        Text("Cinemate is built with open-source software and Apple frameworks. Thank you to all the developers and communities that make this possible.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                            .padding(.vertical, 4)
                    }
                    .listRowBackground(Theme.cardSurface)

                    Section {
                        ForEach(acknowledgements, id: \.name) { item in
                            HStack {
                                Text(item.name)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundStyle(Theme.textPrimary)

                                Spacer()

                                Text(item.license)
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                        }
                    } header: {
                        Text("Frameworks")
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .listRowBackground(Theme.cardSurface)
                }
                .cinemateInsetGroupedListStyle()
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Acknowledgements")
            .cinemateNavigationBarInline()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.primaryGold)
                }
            }
            .cinemateToolbarBackground(Theme.background)
            .cinemateToolbarColorScheme(.dark)
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SettingsView(
            account: Account.previewAccounts[0],
            onSwitchAccount: {}
        )
        .environmentObject(APIClient())
        .environmentObject(DownloadManager.shared)
    }
    .preferredColorScheme(.dark)
}
