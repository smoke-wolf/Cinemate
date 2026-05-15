import Foundation
import Network

@MainActor
final class ServerDiscovery: ObservableObject {
    @Published var discoveredServers: [ServerInfo] = []
    @Published var isSearching: Bool = false

    private var browser: NWBrowser?
    private var connection: NWConnection?

    func startDiscovery() {
        isSearching = true
        discoveredServers = []

        let parameters = NWParameters()
        parameters.includePeerToPeer = true

        let descriptor = NWBrowser.Descriptor.bonjour(type: "_cinemate._tcp", domain: nil)
        let browser = NWBrowser(for: descriptor, using: parameters)

        browser.stateUpdateHandler = { [weak self] state in
            Task { @MainActor in
                switch state {
                case .ready:
                    self?.isSearching = true
                case .failed, .cancelled:
                    self?.isSearching = false
                default:
                    break
                }
            }
        }

        browser.browseResultsChangedHandler = { [weak self] results, _ in
            Task { @MainActor in
                self?.handleResults(results)
            }
        }

        browser.start(queue: .main)
        self.browser = browser

        Task {
            try? await Task.sleep(for: .seconds(10))
            await MainActor.run {
                self.isSearching = false
            }
        }
    }

    func stopDiscovery() {
        browser?.cancel()
        browser = nil
        isSearching = false
    }

    private var resolveConnections: [NWConnection] = []

    private func handleResults(_ results: Set<NWBrowser.Result>) {
        discoveredServers = []
        for result in results {
            if case .service(let name, _, _, _) = result.endpoint {
                resolveService(name: name, endpoint: result.endpoint)
            }
        }
    }

    private func resolveService(name: String, endpoint: NWEndpoint) {
        let connection = NWConnection(to: endpoint, using: .tcp)
        resolveConnections.append(connection)

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                if let resolved = connection.currentPath?.remoteEndpoint,
                   case .hostPort(let host, let port) = resolved {
                    let ip = "\(host)"
                        .replacingOccurrences(of: "%.*", with: "", options: .regularExpression)
                    let portNum = Int(port.rawValue)
                    Task { @MainActor in
                        let server = ServerInfo(
                            name: name,
                            url: ip,
                            port: portNum,
                            isOnline: true
                        )
                        if !(self?.discoveredServers.contains(where: { $0.url == ip && $0.port == portNum }) ?? true) {
                            self?.discoveredServers.append(server)
                        }
                    }
                }
                connection.cancel()
            case .failed, .cancelled:
                Task { @MainActor in
                    self?.resolveConnections.removeAll { $0 === connection }
                }
            default:
                break
            }
        }

        connection.start(queue: .global(qos: .userInitiated))
    }

    func resolveAndConnect(server: ServerInfo) async -> String? {
        return "\(server.url):\(server.port)"
    }
}
