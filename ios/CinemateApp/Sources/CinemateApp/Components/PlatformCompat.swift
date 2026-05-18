import SwiftUI
import AVKit

// MARK: - Platform-agnostic haptics
func hapticImpact(_ style: HapticStyle = .medium) {
    #if os(iOS)
    let generator = UIImpactFeedbackGenerator(style: style.uiStyle)
    generator.impactOccurred()
    #endif
}

func hapticNotification(_ type: HapticNotificationType) {
    #if os(iOS)
    let generator = UINotificationFeedbackGenerator()
    generator.notificationOccurred(type.uiType)
    #endif
}

enum HapticStyle {
    case light, medium, heavy

    #if os(iOS)
    var uiStyle: UIImpactFeedbackGenerator.FeedbackStyle {
        switch self {
        case .light: return .light
        case .medium: return .medium
        case .heavy: return .heavy
        }
    }
    #endif
}

enum HapticNotificationType {
    case success, warning, error

    #if os(iOS)
    var uiType: UINotificationFeedbackGenerator.FeedbackType {
        switch self {
        case .success: return .success
        case .warning: return .warning
        case .error: return .error
        }
    }
    #endif
}

// MARK: - Screen utilities
enum ScreenInfo {
    static var width: CGFloat {
        #if os(iOS)
        UIScreen.main.bounds.width
        #else
        1024
        #endif
    }

    static var height: CGFloat {
        #if os(iOS)
        UIScreen.main.bounds.height
        #else
        768
        #endif
    }
}

// MARK: - Navigation bar modifiers (cross-platform)
extension View {
    @ViewBuilder
    func cinemateNavigationBarInline() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.inline)
        #else
        self
        #endif
    }

    @ViewBuilder
    func cinemateNavigationBarLarge() -> some View {
        #if os(iOS)
        self.navigationBarTitleDisplayMode(.large)
        #else
        self
        #endif
    }

    @ViewBuilder
    func cinemateToolbarBackground(_ color: Color) -> some View {
        #if os(iOS)
        self.toolbarBackground(color, for: .navigationBar)
        #else
        self
        #endif
    }

    @ViewBuilder
    func cinemateToolbarColorScheme(_ scheme: ColorScheme) -> some View {
        #if os(iOS)
        self.toolbarColorScheme(scheme, for: .navigationBar)
        #else
        self
        #endif
    }

    @ViewBuilder
    func cinemateToolbarHidden() -> some View {
        #if os(iOS)
        self.toolbarBackground(.hidden, for: .navigationBar)
        #else
        self
        #endif
    }

    @ViewBuilder
    func cinemateInsetGroupedListStyle() -> some View {
        #if os(iOS)
        self.listStyle(.insetGrouped)
        #else
        self.listStyle(.automatic)
        #endif
    }

    @ViewBuilder
    func cinemateTextFieldURL() -> some View {
        #if os(iOS)
        self
            .textInputAutocapitalization(.never)
            .keyboardType(.URL)
        #else
        self
        #endif
    }
}

// MARK: - AirPlay UIViewRepresentable (iOS only, stub for macOS)
#if os(iOS)
import UIKit

struct AirPlayButtonRepresentable: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let routePickerView = AVRoutePickerView()
        routePickerView.tintColor = UIColor(Theme.textSecondary)
        routePickerView.activeTintColor = UIColor(Theme.primaryGold)
        routePickerView.prioritizesVideoDevices = false
        return routePickerView
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}
#endif

struct CrossPlatformAirPlayButton: View {
    var body: some View {
        #if os(iOS)
        AirPlayButtonRepresentable()
        #else
        Image(systemName: "airplayaudio")
            .foregroundStyle(Theme.textSecondary)
        #endif
    }
}

// MARK: - PDFView representable (iOS only)
#if os(iOS)
import PDFKit

struct PDFViewRepresentable: UIViewRepresentable {
    let url: URL?
    @Binding var currentPage: Int
    @Binding var totalPages: Int
    let nightMode: Bool

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = nightMode ? .black : UIColor(Color(hex: "#1C1C1E"))

        if let url = url, let document = PDFDocument(url: url) {
            pdfView.document = document
            DispatchQueue.main.async {
                self.totalPages = document.pageCount
            }
            if currentPage > 0, let page = document.page(at: currentPage) {
                pdfView.go(to: page)
            }
        }

        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(PDFCoordinator.pageChanged(_:)),
            name: .PDFViewPageChanged,
            object: pdfView
        )

        return pdfView
    }

    func updateUIView(_ pdfView: PDFView, context: Context) {
        pdfView.backgroundColor = nightMode ? .black : UIColor(Color(hex: "#1C1C1E"))

        if let document = pdfView.document,
           let targetPage = document.page(at: currentPage),
           pdfView.currentPage != targetPage {
            pdfView.go(to: targetPage)
        }
    }

    func makeCoordinator() -> PDFCoordinator {
        PDFCoordinator(currentPage: $currentPage)
    }
}

class PDFCoordinator: NSObject {
    @Binding var currentPage: Int

    init(currentPage: Binding<Int>) {
        _currentPage = currentPage
    }

    @objc func pageChanged(_ notification: Notification) {
        guard let pdfView = notification.object as? PDFView,
              let currentPDFPage = pdfView.currentPage,
              let document = pdfView.document else { return }
        let pageIndex = document.index(for: currentPDFPage)
        DispatchQueue.main.async {
            self.currentPage = pageIndex
        }
    }
}
#endif

// MARK: - UIImage cross-platform
#if os(iOS)
import UIKit
typealias PlatformImage = UIImage
#else
import AppKit
typealias PlatformImage = NSImage
#endif

// NSImage and UIImage both have init?(data:) natively

// MARK: - VideoPlayer that works on both
struct CrossPlatformVideoPlayer: View {
    let url: URL?

    var body: some View {
        if let url = url {
            VideoPlayer(player: AVPlayer(url: url))
        } else {
            Color.black
        }
    }
}
