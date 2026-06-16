import SwiftUI
import Vision
import VisionKit
import AVFoundation

// MARK: - DataScannerRepresentable
// Wraps VisionKit's DataScannerViewController for live QR + barcode scanning.
// Requires A12 Bionic chip or later and camera permissions in build settings.
struct DataScannerRepresentable: UIViewControllerRepresentable {
    @Binding var recognizedBarcode: String?
    @Binding var isScanning: Bool

    func makeUIViewController(context: Context) -> DataScannerViewController {
        // Explicitly include .qr plus the most common retail barcode symbologies
        let barcodeDataType = DataScannerViewController.RecognizedDataType.barcode(
            symbologies: [
                .qr,          // QR codes
                .ean13,       // Standard retail EAN-13
                .ean8,        // Short EAN-8
                .upce,        // UPC-E compact
                .code128,     // General-purpose Code 128
                .code39,      // Industrial / logistics
                .pdf417,      // 2D stacked barcode (boarding passes, etc.)
                .aztec,       // Aztec 2D codes
                .dataMatrix,  // GS1 DataMatrix
                .itf14        // Shipping cartons
            ]
        )

        let scanner = DataScannerViewController(
            recognizedDataTypes: [barcodeDataType],
            qualityLevel: .balanced,          // balanced = good for both close and distant codes
            recognizesMultipleItems: false,   // stop after first hit for UX speed
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true       // shows a visual highlight on the detected code
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if isScanning {
            try? uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: DataScannerRepresentable

        init(_ parent: DataScannerRepresentable) {
            self.parent = parent
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            for item in addedItems {
                if case .barcode(let barcode) = item {
                    guard let payload = barcode.payloadStringValue else { continue }
                    HapticManager.shared.impact(style: .heavy)
                    parent.recognizedBarcode = payload
                    parent.isScanning = false
                    return  // process first valid code only
                }
            }
        }
    }
}

// MARK: - CameraUnavailableView
// Shown when DataScannerViewController.isSupported == false (pre-A12 devices)
// or when camera permission is denied.
struct CameraUnavailableView: View {
    let reason: CameraUnavailableReason

    enum CameraUnavailableReason {
        case notSupported
        case permissionDenied
    }

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: reason == .permissionDenied ? "camera.slash.fill" : "xmark.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(colors: [.themePink, .themeOrange], startPoint: .top, endPoint: .bottom)
                )

            VStack(spacing: 8) {
                Text(reason == .permissionDenied ? "Camera Access Required" : "Scanner Not Available")
                    .font(.title3.bold())
                    .foregroundColor(.white)

                Text(reason == .permissionDenied
                    ? "Please allow camera access in Settings to scan barcodes and food."
                    : "Live scanning requires an A12 chip or newer iPhone.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            if reason == .permissionDenied {
                Button(action: openSettings) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Open Settings")
                    }
                    .font(.headline)
                    .foregroundColor(.black)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 14)
                    .background(Color.white)
                    .clipShape(Capsule())
                    .shadow(color: .white.opacity(0.2), radius: 8, y: 4)
                }
            }
        }
        .padding(32)
        .background(Color.black.opacity(0.6))
        .cornerRadius(28)
        .padding(.horizontal, 24)
    }

    private func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
    }
}
