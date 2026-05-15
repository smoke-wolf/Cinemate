import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var apiClient: APIClient
    @EnvironmentObject var audioPlayer: AudioPlayer
    let account: Account

    @State private var selectedTab: Tab = .movies
    @State private var showNowPlaying = false

    enum Tab: String, CaseIterable {
        case movies = "Movies"
        case tvShows = "TV Shows"
        case music = "Music"
        case books = "Books"
        case profile = "Profile"

        var icon: String {
            switch self {
            case .movies: return "film"
            case .tvShows: return "tv"
            case .music: return "music.note"
            case .books: return "book"
            case .profile: return "person.circle"
            }
        }

        var selectedIcon: String {
            switch self {
            case .movies: return "film.fill"
            case .tvShows: return "tv.fill"
            case .music: return "music.note"
            case .books: return "book.fill"
            case .profile: return "person.circle.fill"
            }
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Content
            TabView(selection: $selectedTab) {
                MoviesView()
                    .tag(Tab.movies)

                TVShowsView()
                    .tag(Tab.tvShows)

                MusicView()
                    .tag(Tab.music)

                BooksView()
                    .tag(Tab.books)

                ProfileView(account: account)
                    .tag(Tab.profile)
            }
            .tint(Theme.primaryGold)

            // Now Playing Bar (above tab bar)
            if audioPlayer.currentTrack != nil {
                VStack(spacing: 0) {
                    NowPlayingBar {
                        showNowPlaying = true
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))

                    // Spacer for tab bar
                    Color.clear.frame(height: 49)
                }
            }

            // Custom tab bar overlay
            VStack(spacing: 0) {
                Spacer()
                customTabBar
            }
        }
        .sheet(isPresented: $showNowPlaying) {
            NowPlayingView()
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
