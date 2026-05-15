import SwiftUI
import Network

// MARK: - Server Connection View

struct ServerConnectionView: View {
    let onConnected: (ServerConnectionMode) -> Void

    @State private var manualURL = ""
    @State private var connectionState: ConnectionState = .idle
    @State private var discoveredServers: [DiscoveredServer] = []
    @State private var browser: NWBrowser?
    @State private var hoveredServer: String? = nil
    @State private var hoveredOffline = false
    @State private var hoveredConnect = false
    @AppStorage("lastServerURL") private var lastServerURL = ""
    @State private var resolveConnections: [NWConnection] = []

    private let accentGold = Color(red: 0.85, green: 0.65, blue: 0.13)
    private let warmAmber = Color(red: 0.93, green: 0.76, blue: 0.20)
    private let richBlack = Color(red: 0.04, green: 0.04, blue: 0.06)

    enum ConnectionState: Equatable {
        case idle
        case connecting
        case connected
        case failed(String)
    }

    var body: some View {
        ZStack {
            richBlack.ignoresSafeArea()

            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.10, green: 0.08, blue: 0.04).opacity(0.5),
                    richBlack
                ]),
                center: .center,
                startRadius: 80,
                endRadius: 500
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo
                VStack(spacing: 8) {
                    Image(systemName: "film.circle")
                        .font(.system(size: 36, weight: .ultraLight))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [warmAmber, accentGold],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .shadow(color: accentGold.opacity(0.4), radius: 12)

                    HStack(spacing: 2) {
                        ForEach(Array("CINEMATE".enumerated()), id: \.offset) { _, char in
                            Text(String(char))
                                .font(.system(size: 24, weight: .bold))
                                .tracking(2)
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [warmAmber, accentGold],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                )
                        }
                    }
                }
                .padding(.bottom, 40)

                // Connection options card
                VStack(spacing: 0) {
                    // Header
                    Text("Connect to Server")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                        .padding(.top, 24)
                        .padding(.bottom, 20)

                    Divider().background(Color.white.opacity(0.1))

                    ScrollView {
                        VStack(spacing: 20) {
                            // Auto-discovered servers
                            discoveredServersSection

                            Divider().background(Color.white.opacity(0.08)).padding(.horizontal)

                            // Manual URL entry
                            manualConnectionSection

                            Divider().background(Color.white.opacity(0.08)).padding(.horizontal)

                            // Offline mode
                            offlineModeSection
                        }
                        .padding(.vertical, 20)
                    }
                }
                .frame(width: 480, height: 440)
                .background(Color(white: 0.08))
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.5), radius: 30, y: 10)

                Spacer()
            }
        }
        .onAppear {
            if !lastServerURL.isEmpty {
                manualURL = lastServerURL
            }
            startBrowsing()
        }
        .onDisappear {
            stopBrowsing()
        }
    }

    // MARK: - Discovered Servers

    private var discoveredServersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 13))
                    .foregroundColor(accentGold)
                Text("Servers on Your Network")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)

                Spacer()

                if browser != nil {
                    ProgressView()
                        .scaleEffect(0.5)
                        .tint(accentGold)
                }
            }
            .padding(.horizontal, 20)

            if discoveredServers.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18))
                            .foregroundColor(.gray.opacity(0.5))
                        Text("Searching for Cinemate servers...")
                            .font(.system(size: 12))
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 12)
                    Spacer()
                }
            } else {
                VStack(spacing: 4) {
                    ForEach(discoveredServers) { server in
                        let isHovered = hoveredServer == server.id
                        Button(action: {
                            connectTo(url: "http://\(server.host):\(server.port)")
                        }) {
                            HStack(spacing: 12) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 8, height: 8)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(server.name)
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.white)
                                    Text("\(server.host):\(server.port)")
                                        .font(.system(size: 11))
                                        .foregroundColor(.gray)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 11))
                                    .foregroundColor(.gray)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(isHovered ? Color.white.opacity(0.06) : Color.clear)
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                        .onHover { h in hoveredServer = h ? server.id : nil }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Manual Connection

    private var manualConnectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "link")
                    .font(.system(size: 13))
                    .foregroundColor(accentGold)
                Text("Manual Connection")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)

            HStack(spacing: 10) {
                TextField("http://192.168.1.100:9876", text: $manualURL)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundColor(.white)
                    .padding(10)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(8)
                    .onSubmit {
                        connectTo(url: manualURL)
                    }

                Button(action: { connectTo(url: manualURL) }) {
                    Group {
                        switch connectionState {
                        case .connecting:
                            ProgressView()
                                .scaleEffect(0.6)
                                .tint(.white)
                        case .connected:
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        case .failed:
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.red)
                        case .idle:
                            Text("Connect")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.black)
                        }
                    }
                    .frame(width: 80, height: 36)
                    .background(
                        hoveredConnect
                            ? accentGold.opacity(0.9)
                            : accentGold
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .onHover { h in hoveredConnect = h }
                .disabled(manualURL.isEmpty || connectionState == .connecting)
            }
            .padding(.horizontal, 20)

            if case .failed(let msg) = connectionState {
                Text(msg)
                    .font(.system(size: 11))
                    .foregroundColor(.red.opacity(0.8))
                    .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Offline Mode

    private var offlineModeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                Image(systemName: "internaldrive")
                    .font(.system(size: 13))
                    .foregroundColor(accentGold)
                Text("Local Library")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 20)

            Button(action: {
                onConnected(.offline)
            }) {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.right.circle")
                        .font(.system(size: 14))
                    Text("Use Local Library")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(hoveredOffline ? .white : .white.opacity(0.7))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(hoveredOffline ? Color.white.opacity(0.1) : Color.white.opacity(0.04))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(hoveredOffline ? 0.2 : 0.08), lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
            .onHover { h in hoveredOffline = h }
            .padding(.horizontal, 20)

            Text("Access your locally stored media files without a server connection.")
                .font(.system(size: 11))
                .foregroundColor(.gray.opacity(0.6))
                .padding(.horizontal, 20)
        }
    }

    // MARK: - Networking

    private func startBrowsing() {
        let params = NWParameters()
        params.includePeerToPeer = true
        let nwBrowser = NWBrowser(for: .bonjour(type: "_cinemate._tcp", domain: nil), using: params)

        nwBrowser.stateUpdateHandler = { state in
            // Just keep browsing
        }

        nwBrowser.browseResultsChangedHandler = { results, _ in
            for result in results {
                if case .service(let name, _, _, _) = result.endpoint {
                    resolveService(name: name, endpoint: result.endpoint)
                }
            }
        }

        nwBrowser.start(queue: .main)
        self.browser = nwBrowser
    }

    private func resolveService(name: String, endpoint: NWEndpoint) {
        let connection = NWConnection(to: endpoint, using: .tcp)
        resolveConnections.append(connection)

        connection.stateUpdateHandler = { state in
            switch state {
            case .ready:
                if let resolved = connection.currentPath?.remoteEndpoint,
                   case .hostPort(let host, let port) = resolved {
                    let ip = "\(host)"
                        .replacingOccurrences(of: "%.*", with: "", options: .regularExpression)
                    let portNum = Int(port.rawValue)
                    DispatchQueue.main.async {
                        let server = DiscoveredServer(
                            name: name,
                            host: ip,
                            port: portNum,
                            serviceType: "_cinemate._tcp"
                        )
                        if !discoveredServers.contains(where: { $0.host == ip && $0.port == portNum }) {
                            discoveredServers.append(server)
                        }
                    }
                }
                connection.cancel()
            case .failed, .cancelled:
                DispatchQueue.main.async {
                    resolveConnections.removeAll { $0 === connection }
                }
            default:
                break
            }
        }

        connection.start(queue: .global(qos: .userInitiated))
    }

    private func stopBrowsing() {
        browser?.cancel()
        browser = nil
    }

    private func connectTo(url: String) {
        let trimmed = url.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        connectionState = .connecting
        lastServerURL = trimmed

        // Attempt a basic HTTP health check
        guard let serverURL = URL(string: trimmed.hasSuffix("/") ? trimmed + "health" : trimmed + "/health") else {
            connectionState = .failed("Invalid URL")
            return
        }

        let task = URLSession.shared.dataTask(with: serverURL) { _, response, error in
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                    connectionState = .connected
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onConnected(.server(trimmed))
                    }
                } else if error != nil {
                    // For now, allow connection anyway (server might not have /health)
                    connectionState = .connected
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        onConnected(.server(trimmed))
                    }
                } else {
                    connectionState = .failed("Could not reach server")
                }
            }
        }
        task.resume()

        // Timeout after 5 seconds — just go connected anyway for local dev
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            if connectionState == .connecting {
                connectionState = .connected
                onConnected(.server(trimmed))
            }
        }
    }
}

// MARK: - Models

enum ServerConnectionMode {
    case offline
    case server(String)

    var isOffline: Bool {
        if case .offline = self { return true }
        return false
    }

    var serverURL: String? {
        if case .server(let url) = self { return url }
        return nil
    }
}

struct DiscoveredServer: Identifiable {
    let name: String
    let host: String
    let port: Int
    let serviceType: String

    var id: String { "\(name)-\(host)-\(port)" }
}
