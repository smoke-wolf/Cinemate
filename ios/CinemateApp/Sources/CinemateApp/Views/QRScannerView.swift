import SwiftUI
import AVFoundation
import AudioToolbox

struct QRScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isTorchOn = false
    @State private var scannedCode: String?
    @State private var scannerError: String?

    let onCodeScanned: (String) -> Void

    var body: some View {
        ZStack {
            // Camera feed
            QRScannerRepresentable(
                isTorchOn: $isTorchOn,
                scannedCode: $scannedCode,
                scannerError: $scannerError
            )
            .ignoresSafeArea()

            // Overlay
            VStack {
                // Top bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.85))
                            .shadow(color: .black.opacity(0.5), radius: 4)
                    }

                    Spacer()

                    Button(action: { isTorchOn.toggle() }) {
                        Image(systemName: isTorchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(isTorchOn ? Theme.primaryGold : .white.opacity(0.85))
                            .padding(10)
                            .background(.ultraThinMaterial, in: Circle())
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)

                Spacer()

                // Viewfinder frame
                ZStack {
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Theme.primaryGold, lineWidth: 3)
                        .frame(width: 260, height: 260)
                        .shadow(color: Theme.goldGlow, radius: 12)

                    // Corner accents
                    ViewfinderCorners()
                        .stroke(Theme.warmAmber, lineWidth: 4)
                        .frame(width: 260, height: 260)
                }

                Spacer()

                // Instructions
                VStack(spacing: 8) {
                    Text("Scan QR Code")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Point the camera at the QR code\non your Mac's LAN Admin page")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 24)
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
            }

            // Error overlay
            if let error = scannerError {
                VStack(spacing: 16) {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.error)

                    Text("Camera Unavailable")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(Theme.textPrimary)

                    Text(error)
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)

                    GoldButton(title: "Close", icon: "xmark", action: { dismiss() })
                        .padding(.top, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Theme.background.opacity(0.95))
            }
        }
        .onChange(of: scannedCode) { _, code in
            guard let code = code else { return }
            handleScannedCode(code)
        }
    }

    private func handleScannedCode(_ code: String) {
        // Validate it looks like an HTTP URL
        let trimmed = code.trimmingCharacters(in: .whitespacesAndNewlines)

        guard let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              (scheme == "http" || scheme == "https"),
              url.host != nil else {
            // Reset so user can scan again
            scannedCode = nil
            return
        }

        hapticImpact(.heavy)
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onCodeScanned(trimmed)
        }
    }
}

// MARK: - UIViewControllerRepresentable

struct QRScannerRepresentable: UIViewControllerRepresentable {
    @Binding var isTorchOn: Bool
    @Binding var scannedCode: String?
    @Binding var scannerError: String?

    func makeUIViewController(context: Context) -> QRScannerViewController {
        let controller = QRScannerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QRScannerViewController, context: Context) {
        uiViewController.setTorch(on: isTorchOn)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, QRScannerViewControllerDelegate {
        let parent: QRScannerRepresentable

        init(_ parent: QRScannerRepresentable) {
            self.parent = parent
        }

        func didScanCode(_ code: String) {
            parent.scannedCode = code
        }

        func didFailWithError(_ error: String) {
            parent.scannerError = error
        }
    }
}

// MARK: - Camera ViewController

protocol QRScannerViewControllerDelegate: AnyObject {
    func didScanCode(_ code: String)
    func didFailWithError(_ error: String)
}

class QRScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    weak var delegate: QRScannerViewControllerDelegate?

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var hasScanned = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        checkPermissionsAndSetup()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        stopSession()
    }

    private func checkPermissionsAndSetup() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupCamera()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.setupCamera()
                    } else {
                        self?.delegate?.didFailWithError("Camera access was denied. Enable it in Settings > Privacy > Camera.")
                    }
                }
            }
        case .denied, .restricted:
            delegate?.didFailWithError("Camera access is required to scan QR codes. Enable it in Settings > Privacy > Camera.")
        @unknown default:
            delegate?.didFailWithError("Unable to access the camera.")
        }
    }

    private func setupCamera() {
        let session = AVCaptureSession()

        guard let device = AVCaptureDevice.default(for: .video) else {
            delegate?.didFailWithError("No camera available on this device.")
            return
        }

        guard let input = try? AVCaptureDeviceInput(device: device) else {
            delegate?.didFailWithError("Could not access the camera input.")
            return
        }

        if session.canAddInput(input) {
            session.addInput(input)
        } else {
            delegate?.didFailWithError("Could not add camera input to capture session.")
            return
        }

        let metadataOutput = AVCaptureMetadataOutput()
        if session.canAddOutput(metadataOutput) {
            session.addOutput(metadataOutput)
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
            metadataOutput.metadataObjectTypes = [.qr]
        } else {
            delegate?.didFailWithError("Could not add metadata output to capture session.")
            return
        }

        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        preview.frame = view.bounds
        view.layer.addSublayer(preview)
        previewLayer = preview

        captureSession = session

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.startRunning()
        }
    }

    private func stopSession() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
        }
    }

    func setTorch(on: Bool) {
        guard let device = AVCaptureDevice.default(for: .video),
              device.hasTorch else { return }

        try? device.lockForConfiguration()
        device.torchMode = on ? .on : .off
        device.unlockForConfiguration()
    }

    // MARK: - AVCaptureMetadataOutputObjectsDelegate

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard !hasScanned,
              let metadataObject = metadataObjects.first,
              let readable = metadataObject as? AVMetadataMachineReadableCodeObject,
              let stringValue = readable.stringValue else {
            return
        }

        hasScanned = true
        AudioServicesPlaySystemSound(SystemSoundID(kSystemSoundID_Vibrate))
        delegate?.didScanCode(stringValue)
    }
}

// MARK: - Viewfinder Corner Shape

struct ViewfinderCorners: Shape {
    func path(in rect: CGRect) -> Path {
        let cornerLength: CGFloat = 30
        let cornerRadius: CGFloat = 20

        var path = Path()

        // Top-left
        path.move(to: CGPoint(x: rect.minX, y: rect.minY + cornerLength))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX + cornerRadius, y: rect.minY),
            control: CGPoint(x: rect.minX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.minX + cornerLength, y: rect.minY))

        // Top-right
        path.move(to: CGPoint(x: rect.maxX - cornerLength, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX - cornerRadius, y: rect.minY))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX, y: rect.minY + cornerRadius),
            control: CGPoint(x: rect.maxX, y: rect.minY)
        )
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY + cornerLength))

        // Bottom-right
        path.move(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerLength))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - cornerRadius))
        path.addQuadCurve(
            to: CGPoint(x: rect.maxX - cornerRadius, y: rect.maxY),
            control: CGPoint(x: rect.maxX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.maxX - cornerLength, y: rect.maxY))

        // Bottom-left
        path.move(to: CGPoint(x: rect.minX + cornerLength, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX + cornerRadius, y: rect.maxY))
        path.addQuadCurve(
            to: CGPoint(x: rect.minX, y: rect.maxY - cornerRadius),
            control: CGPoint(x: rect.minX, y: rect.maxY)
        )
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - cornerLength))

        return path
    }
}

