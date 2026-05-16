import SwiftUI

struct ServerConnectView: View {
    @EnvironmentObject var apiClient: APIClient
    @StateObject private var discovery = ServerDiscovery()

    @State private var manualURL: String = ""
    @State private var isConnecting = false
    @State private var connectionStatus: ConnectionStatus = .idle
    @State private var rememberServer = true
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showQRScanner = false

    let onConnected: () -> Void

    enum ConnectionStatus: Equatable {
        case idle
        case connecting
        case success
        case failed(String)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 32) {
                    // Header
                    VStack(spacing: 12) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 44))
                            .foregroundStyle(Theme.goldGradient)
                            .padding(.top, 40)

                        Text("Connect to Server")
                            .font(.system(size: 28, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)

                        Text("Find your Cinemate server on your network\nor enter a URL manually")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }

                    // Discovered Servers
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Servers on Network")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(Theme.textPrimary)

                            Spacer()

                            if discovery.isSearching {
                                ProgressView()
                                    .tint(Theme.primaryGold)
                                    .scaleEffect(0.8)
                            }
                        }

                        if discovery.discoveredServers.isEmpty {
                            HStack(spacing: 12) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(Theme.textTertiary)
                                Text(discovery.isSearching ? "Searching for servers..." : "No servers found")
                                    .font(.system(size: 14))
                                    .foregroundStyle(Theme.textTertiary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .background(Theme.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerMedium))
                        } else {
                            ForEach(discovery.discoveredServers) { server in
                                ServerCard(server: server) {
                                    connectToServer(url: "http://\(server.url):\(server.port)")
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // QR Code Scanner
                    VStack(spacing: 12) {
                        GoldButton(
                            title: "Scan QR Code",
                            icon: "qrcode.viewfinder",
                            action: {
                                showQRScanner = true
                            },
                            isFullWidth: true
                        )
                    }
                    .padding(.horizontal)

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Theme.elevatedSurface)
                            .frame(height: 1)
                        Text("OR")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.textTertiary)
                        Rectangle()
                            .fill(Theme.elevatedSurface)
                            .frame(height: 1)
                    }
                    .padding(.horizontal)

                    // Manual Entry
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Manual Connection")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Theme.textPrimary)

                        VStack(spacing: 16) {
                            HStack {
                                Image(systemName: "globe")
                                    .foregroundStyle(Theme.textTertiary)
                                TextField("Server URL (e.g., 192.168.1.100:8080)", text: $manualURL)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Theme.textPrimary)
                                    .autocorrectionDisabled()
                                    .cinemateTextFieldURL()
                            }
                            .padding()
                            .background(Theme.cardSurface)
                            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerMedium))

                            Toggle(isOn: $rememberServer) {
                                HStack(spacing: 8) {
                                    Image(systemName: "bookmark.fill")
                                        .font(.system(size: 13))
                                        .foregroundStyle(Theme.primaryGold)
                                    Text("Remember this server")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                            }
                            .tint(Theme.primaryGold)

                            // Status
                            if case .connecting = connectionStatus {
                                HStack(spacing: 8) {
                                    ProgressView()
                                        .tint(Theme.primaryGold)
                                        .scaleEffect(0.8)
                                    Text("Connecting...")
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.textSecondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            } else if case .success = connectionStatus {
                                HStack(spacing: 8) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(Theme.success)
                                    Text("Connected!")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundStyle(Theme.success)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            } else if case .failed(let msg) = connectionStatus {
                                HStack(spacing: 8) {
                                    Image(systemName: "xmark.circle.fill")
                                        .foregroundStyle(Theme.error)
                                    Text(msg)
                                        .font(.system(size: 14))
                                        .foregroundStyle(Theme.error)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                            }

                            GoldButton(
                                title: "Connect",
                                icon: "link",
                                action: {
                                    connectToServer(url: manualURL)
                                },
                                isFullWidth: true
                            )
                            .disabled(manualURL.isEmpty || connectionStatus == .connecting)
                            .opacity(manualURL.isEmpty ? 0.5 : 1)
                        }
                    }
                    .padding(.horizontal)

                    // Demo mode
                    VStack(spacing: 8) {
                        Button(action: {
                            enterDemoMode()
                        }) {
                            Text("Continue in Demo Mode")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Theme.textTertiary)
                                .underline()
                        }

                        Text("Browse with sample data, no server needed")
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textTertiary.opacity(0.7))
                    }
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear {
            discovery.startDiscovery()
            checkSavedServer()
        }
        .onDisappear {
            discovery.stopDiscovery()
        }
        .fullScreenCover(isPresented: $showQRScanner) {
            QRScannerView { scannedURL in
                manualURL = scannedURL
                connectToServer(url: scannedURL)
            }
        }
    }

    private func connectToServer(url: String) {
        connectionStatus = .connecting
        apiClient.configure(url: url)

        Task {
            do {
                _ = try await apiClient.testConnection()
                connectionStatus = .success
                if rememberServer {
                    UserDefaults.standard.set(url, forKey: "savedServerURL")
                }
                try? await Task.sleep(for: .milliseconds(600))
                onConnected()
            } catch {
                connectionStatus = .failed(error.localizedDescription)
            }
        }
    }

    private func checkSavedServer() {
        if let savedURL = UserDefaults.standard.string(forKey: "savedServerURL") {
            manualURL = savedURL
        }
    }

    private func enterDemoMode() {
        apiClient.configure(url: "demo://localhost")
        apiClient.isConnected = true
        onConnected()
    }
}

struct ServerCard: View {
    let server: ServerInfo
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Theme.primaryGold.opacity(0.15))
                        .frame(width: 44, height: 44)
                    Image(systemName: "server.rack")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.primaryGold)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(server.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(server.displayURL)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.textSecondary)
                }

                Spacer()

                Circle()
                    .fill(Theme.success)
                    .frame(width: 10, height: 10)

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.textTertiary)
            }
            .padding()
            .background(Theme.cardSurface)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerMedium))
        }
        .buttonStyle(PressableButtonStyle())
    }
}

#Preview {
    ServerConnectView(onConnected: {})
        .environmentObject(APIClient())
}
