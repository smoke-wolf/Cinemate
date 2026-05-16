import SwiftUI
import UIKit

struct MainTabView: View {
    @EnvironmentObject var apiClient: APIClient
    @EnvironmentObject var audioPlayer: AudioPlayer
    @EnvironmentObject var downloadManager: DownloadManager
    let account: Account

    @State private var selectedTab: Tab = .movies
    @State private var showNowPlaying = false
    @State private var heartbeatTimer: Timer?

    enum Tab: String, CaseIterable {
        case movies = "Movies"
        case tvShows = "TV Shows"
        case music = "Music"
        case books = "Books"
        case downloads = "Downloads"
        case profile = "Profile"

        var icon: String {
            switch self {
            case .movies: return "film"
            case .tvShows: return "tv"
            case .music: return "music.note"
            case .books: return "book"
            case .downloads: return "arrow.down.circle"
            case .profile: return "person.circle"
            }
        }

        var selectedIcon: String {
            switch self {
            case .movies: return "film.fill"
            case .tvShows: return "tv.fill"
            case .music: return "music.note"
            case .books: return "book.fill"
            case .downloads: return "arrow.down.circle.fill"
            case .profile: return "person.circle.fill"
            }
        }
    }

    private var tabBarHeight: CGFloat { 70 }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            Group {
                switch selectedTab {
                case .movies: MoviesView(account: account)
                case .tvShows: TVShowsView()
                case .music: MusicView(account: account)
                case .books: BooksView(account: account)
                case .downloads: DownloadsView()
                case .profile: ProfileView(account: account)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom stack: now-playing + tab bar
            VStack(spacing: 0) {
                if audioPlayer.currentTrack != nil {
                    NowPlayingBar {
                        showNowPlaying = true
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                customTabBar
            }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView(account: account)
        }
        .task {
            downloadManager.configure(serverBaseURL: apiClient.baseURL)
            await registerAndStartHeartbeat()
        }
        .onDisappear {
            heartbeatTimer?.invalidate()
        }
    }

    private var deviceId: String {
        if let saved = UserDefaults.standard.string(forKey: "cinemate_device_id"), !saved.isEmpty {
            return saved
        }
        let id = UIDevice.current.identifierForVendor?.uuidString ?? UUID().uuidString
        UserDefaults.standard.set(id, forKey: "cinemate_device_id")
        return id
    }

    private func registerAndStartHeartbeat() async {
        let name = await UIDevice.current.name
        let accountId = Int(account.id) ?? 0
        _ = try? await apiClient.registerDevice(
            deviceId: deviceId,
            name: name,
            deviceType: "iphone",
            accountId: accountId
        )

        await MainActor.run {
            heartbeatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                Task {
                    try? await apiClient.deviceHeartbeat(deviceId: deviceId)
                }
            }
        }
    }

    private var customTabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button(action: {
                    hapticImpact(.light)
                    withAnimation(Theme.quickSpring) {
                        selectedTab = tab
                    }
                }) {
                    VStack(spacing: 4) {
                        let iconName: String = selectedTab == tab ? tab.selectedIcon : tab.icon
                        Image(systemName: iconName)
                            .font(.system(size: 20))
                            .symbolRenderingMode(.hierarchical)

                        Text(tab.rawValue)
                            .font(.system(size: 10, weight: .medium))
                    }
                    .foregroundStyle(selectedTab == tab ? Theme.primaryGold : Theme.textTertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
                }
            }
        }
        .padding(.bottom, 20)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .colorScheme(.dark)
                .overlay(alignment: .top) {
                    Rectangle()
                        .fill(Theme.elevatedSurface.opacity(0.5))
                        .frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        )
    }
}

#Preview {
    MainTabView(account: Account.previewAccounts[0])
        .environmentObject(APIClient())
        .environmentObject(AudioPlayer())
        .preferredColorScheme(.dark)
}
