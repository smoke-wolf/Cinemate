import SwiftUI

@main
struct CinemateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            CinemateRootView()
                .frame(minWidth: 1000, minHeight: 650)
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: false))
        .defaultSize(width: 1280, height: 800)
    }
}

/// The phases the app moves through on launch.
enum AppPhase {
    case splash
    case serverConnect
    case accountSelect
    case main
}

/// Root view that orchestrates the splash -> server -> accounts -> content transitions.
struct CinemateRootView: View {
    @State private var phase: AppPhase = .splash
    @State private var previousPhase: AppPhase? = nil
    @StateObject private var viewModel = LibraryViewModel()
    @AppStorage("selectedAccountId") private var selectedAccountId: Int = 0
    @AppStorage("savedConnectionMode") private var savedConnectionMode: String = ""

    var body: some View {
        ZStack {
            Color(red: 0.04, green: 0.04, blue: 0.06)
                .ignoresSafeArea()

            switch phase {
            case .splash:
                SplashScreenView()
                    .transition(.opacity)
                    .zIndex(4)

            case .serverConnect:
                ServerConnectionView { mode in
                    switch mode {
                    case .offline:
                        viewModel.serverURL = nil
                        savedConnectionMode = "offline"
                    case .server(let url):
                        viewModel.serverURL = url
                        savedConnectionMode = "server:\(url)"
                    }
                    transitionTo(.accountSelect)
                }
                .transition(.opacity)
                .zIndex(3)

            case .accountSelect:
                AccountSelectorView(onAccountSelected: { account in
                    viewModel.setAccount(account)
                    selectedAccountId = Int(account.id)
                    transitionTo(.main)
                }, onChangeServer: {
                    savedConnectionMode = ""
                    transitionTo(.serverConnect)
                })
                .transition(.opacity)
                .zIndex(2)

            case .main:
                ContentView(viewModel: viewModel) {
                    viewModel.switchProfile()
                    transitionTo(.accountSelect)
                }
                .transition(.opacity)
                .zIndex(1)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) {
                if !savedConnectionMode.isEmpty {
                    if savedConnectionMode == "offline" {
                        viewModel.serverURL = nil
                    } else if savedConnectionMode.hasPrefix("server:") {
                        let url = String(savedConnectionMode.dropFirst(7))
                        viewModel.serverURL = url
                    }
                    transitionTo(.accountSelect)
                } else {
                    transitionTo(.serverConnect)
                }
            }
        }
    }

    private func transitionTo(_ newPhase: AppPhase) {
        withAnimation(.easeInOut(duration: 0.6)) {
            previousPhase = phase
            phase = newPhase
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
