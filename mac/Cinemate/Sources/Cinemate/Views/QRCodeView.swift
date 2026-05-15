import SwiftUI
import CoreImage.CIFilterBuiltins

struct QRCodeView: View {
    let url: String
    var size: CGFloat = 160

    private let accentGold = Color(red: 0.85, green: 0.65, blue: 0.13)

    var body: some View {
        if let image = generateQRCode(from: url) {
            Image(nsImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .colorMultiply(accentGold)
                .background(Color.white)
                .cornerRadius(8)
        } else {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.06))
                .frame(width: size, height: size)
                .overlay(
                    VStack(spacing: 6) {
                        Image(systemName: "qrcode")
                            .font(.system(size: 28))
                            .foregroundColor(.gray)
                        Text("QR unavailable")
                            .font(.system(size: 10))
                            .foregroundColor(.gray)
                    }
                )
        }
    }

    private func generateQRCode(from string: String) -> NSImage? {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }

        // Scale up so it's not blurry
        let scale = size / outputImage.extent.width
        let scaledImage = outputImage.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            return nil
        }

        return NSImage(cgImage: cgImage, size: NSSize(width: size, height: size))
    }
}
