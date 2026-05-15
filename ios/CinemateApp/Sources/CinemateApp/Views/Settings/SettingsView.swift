import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var apiClient: APIClient
    @State private var selectedQuality: StreamQuality = .auto
    @State private var showChangeServer = false

    enum StreamQuality: String, CaseIterable {
        case auto = "Auto"
        case high = "High (1080p)"
        case medium = "Medium (720p)"
        case low = "Low (480p)"
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            List {
                // Server
                Section {
                    HStack {
                        Label {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Server URL")
                                    .foregroundStyle(Theme.textPrimary)
                                Text(apiClient.baseURL.isEmpty ? "Not connected" : apiClient.baseURL)
                                    .font(.system(size: 13))
                                    .foregroundStyle(Theme.textSecondary)
                            }
                        } icon: {
                            Image(systemName: "server.rack")
                                .foregroundStyle(Theme.primaryGold)
                        }

                        Spacer()

                        if apiClient.isConnected {
                            Circle()
                                .fill(Theme.success)
                                .frame(width: 8, height: 8)
                        }
                    }

                    Button(action: {
                        showChangeServer = true
                    }) {
                        Label("Change Server", systemImage: "arrow.triangle.2.circlepath")
                            .foregroundStyle(Theme.primaryGold)
                    }

                    if let status = apiClient.serverStatus {
                        HStack {
                            Label("Server Version", systemImage: "info.circle")
                                .foregroundStyle(Theme.textPrimary)
                            Spacer()
                            Text(status.version)
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                } header: {
                    Text("Server Connection")
                        .foregroundStyle(Theme.textSecondary)
                }
                .listRowBackground(Theme.cardSurface)

                // Playback
                Section {
                    Picker(selection: $selectedQuality) {
                        ForEach(StreamQuality.allCases, id: \.self) { quality in
                            Text(quality.rawValue).tag(quality)
                        }
                    } label: {
                        Label("Stream Quality", systemImage: "waveform")
                            .foregroundStyle(Theme.textPrimary)
                    }
                    .tint(Theme.primaryGold)
                } header: {
                    Text("Playback")
                        .foregroundStyle(Theme.textSecondary)
                }
                .listRowBackground(Theme.cardSurface)

                // Appearance
                Section {
                    HStack {
                        Label("Theme", systemImage: "moon.fill")
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("Dark")
                            .foregroundStyle(Theme.textSecondary)
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(Theme.textTertiary)
                    }
                } header: {
                    Text("Appearance")
                        .foregroundStyle(Theme.textSecondary)
                }
                .listRowBackground(Theme.cardSurface)

                // Storage
                Section {
                    Button(action: {
                        Task {
                            await ImageCacheService.shared.clearCache()
                        }
                    }) {
                        Label("Clear Image Cache", systemImage: "trash")
                            .foregroundStyle(Theme.error)
                    }
                } header: {
                    Text("Storage")
                        .foregroundStyle(Theme.textSecondary)
                }
                .listRowBackground(Theme.cardSurface)

                // About
                Section {
                    HStack {
                        Label("Version", systemImage: "info.circle")
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("1.0.0")
                            .foregroundStyle(Theme.textSecondary)
                    }

                    HStack {
                        Label("Build", systemImage: "hammer")
                            .foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Text("2026.05.14")
                            .foregroundStyle(Theme.textSecondary)
                    }

                    Link(destination: URL(string: "https://github.com/cinemate")!) {
                        Label("Source Code", systemImage: "chevron.left.forwardslash.chevron.right")
                            .foregroundStyle(Theme.primaryGold)
                    }
                } header: {
                    Text("About Cinemate")
                        .foregroundStyle(Theme.textSecondary)
                } footer: {
                    Text("Cinemate - Your Private Cinema")
                        .foregroundStyle(Theme.textTertiary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)
                }
                .listRowBackground(Theme.cardSurface)
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
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(APIClient())
    }
    .preferredColorScheme(.dark)
}
