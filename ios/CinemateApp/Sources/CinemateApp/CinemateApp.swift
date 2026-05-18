import SwiftUI

private struct AccountIdKey: EnvironmentKey {
    static let defaultValue: Int = 0
}

extension EnvironmentValues {
    var accountId: Int {
        get { self[AccountIdKey.self] }
        set { self[AccountIdKey.self] = newValue }
    }
}

@main
struct CinemateApp: App {
    @StateObject private var apiClient = APIClient()
    @StateObject private var audioPlayer = AudioPlayer()
    @StateObject private var downloadManager = DownloadManager.shared

    @State private var appState: AppState = .splash
    @State private var connectingTask: Task<Void, Never>?

    enum AppState {
        case splash
        case connecting(String)
        case serverConnect
        case offline
        case accountSelect
        case main(Account)
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                Theme.background.ignoresSafeArea()

                switch appState {
                case .splash:
                    SplashScreen {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            if let savedURL = UserDefaults.standard.string(forKey: "savedServerURL"),
                               !savedURL.isEmpty {
                                appState = .connecting(savedURL)
                            } else {
                                appState = .serverConnect
                            }
                        }
                    }
                    .transition(.opacity)

                case .connecting(let savedURL):
                    ConnectingView(
                        serverURL: savedURL,
                        onCancel: {
                            connectingTask?.cancel()
                            withAnimation(.easeInOut(duration: 0.4)) {
                                appState = .serverConnect
                            }
                        }
                    )
                    .transition(.opacity)
                    .onAppear {
                        apiClient.configure(url: savedURL)
                        connectingTask = Task {
                            do {
                                _ = try await apiClient.testConnection()
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        appState = .accountSelect
                                    }
                                }
                            } catch {
                                guard !Task.isCancelled else { return }
                                await MainActor.run {
                                    withAnimation(.easeInOut(duration: 0.4)) {
                                        if !DownloadManager.shared.completedDownloads.isEmpty {
                                            appState = .offline
                                        } else {
                                            appState = .serverConnect
                                        }
                                    }
                                }
                            }
                        }
                    }

                case .serverConnect:
                    ServerConnectView {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            appState = .accountSelect
                        }
                    }
                    .environmentObject(apiClient)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))

                case .offline:
                    OfflineLibraryView(onReconnect: {
                        withAnimation(.easeInOut(duration: 0.4)) {
                            appState = .accountSelect
                        }
                    })
                    .environmentObject(apiClient)
                    .environmentObject(audioPlayer)
                    .environmentObject(downloadManager)
                    .transition(.opacity)

                case .accountSelect:
                    AccountSelectorView { account in
                        withAnimation(.easeInOut(duration: 0.4)) {
                            appState = .main(account)
                        }
                    }
                    .environmentObject(apiClient)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .scale(scale: 0.9).combined(with: .opacity)
                    ))

                case .main(let account):
                    MainTabView(account: account)
                        .environment(\.accountId, Int(account.id) ?? 0)
                        .environmentObject(apiClient)
                        .environmentObject(audioPlayer)
                        .environmentObject(downloadManager)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: appStateKey)
            .onChange(of: apiClient.isConnected) { _, connected in
                if !connected {
                    withAnimation(.easeInOut(duration: 0.4)) {
                        if !DownloadManager.shared.completedDownloads.isEmpty {
                            appState = .offline
                        } else {
                            appState = .serverConnect
                        }
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
    }

    // For animation tracking
    private var appStateKey: String {
        switch appState {
        case .splash: return "splash"
        case .connecting: return "connecting"
        case .serverConnect: return "serverConnect"
        case .offline: return "offline"
        case .accountSelect: return "accountSelect"
        case .main: return "main"
        }
    }
}
