import SwiftUI

@main
struct CinemateApp: App {
    @StateObject private var apiClient = APIClient()
    @StateObject private var audioPlayer = AudioPlayer()

    @State private var appState: AppState = .splash

    enum AppState {
        case splash
        case serverConnect
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
                            // Check for saved server
                            if let savedURL = UserDefaults.standard.string(forKey: "savedServerURL"),
                               !savedURL.isEmpty {
                                apiClient.configure(url: savedURL)
                                Task {
                                    do {
                                        _ = try await apiClient.testConnection()
                                        await MainActor.run {
                                            withAnimation {
                                                appState = .accountSelect
                                            }
                                        }
                                    } catch {
                                        await MainActor.run {
                                            withAnimation {
                                                appState = .serverConnect
                                            }
                                        }
                                    }
                                }
                            } else {
                                appState = .serverConnect
                            }
                        }
                    }
                    .transition(.opacity)

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
                        .environmentObject(apiClient)
                        .environmentObject(audioPlayer)
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.3), value: appStateKey)
            .preferredColorScheme(.dark)
        }
    }

    // For animation tracking
    private var appStateKey: String {
        switch appState {
        case .splash: return "splash"
        case .serverConnect: return "serverConnect"
        case .accountSelect: return "accountSelect"
        case .main: return "main"
        }
    }
}
