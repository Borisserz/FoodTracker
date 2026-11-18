import SwiftUI
import VisionKit

struct DataScannerRepresentable: UIViewControllerRepresentable {
    @Binding var recognizedBarcode: String?
    @Binding var isScanning: Bool

    func makeUIViewController(context: Context) -> DataScannerViewController {

        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isPinchToZoomEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        context.coordinator.parent = self
        let size = uiViewController.view.bounds.size
        if size.width > 250 && size.height > 250 {
            uiViewController.regionOfInterest = CGRect(
                x: (size.width - 250) / 2,
                y: (size.height - 250) / 2,
                width: 250,
                height: 250
            )
        }
        guard context.coordinator.lastIsScanning != isScanning else { return }
        context.coordinator.lastIsScanning = isScanning
        if isScanning {
            context.coordinator.hasEmittedScan = false
            try? uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
        uiViewController.delegate = nil
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: DataScannerRepresentable
        var lastIsScanning: Bool?
        var hasEmittedScan: Bool = false

        init(_ parent: DataScannerRepresentable) {
            self.parent = parent
        }

        func dataScanner(_ dataScanner: DataScannerViewController, becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable) {
            dataScanner.stopScanning()
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            guard !hasEmittedScan else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item {
                    guard let payload = barcode.payloadStringValue, !payload.isEmpty else { continue }
                    hasEmittedScan = true
                    HapticManager.shared.impact(style: .heavy)
                    parent.recognizedBarcode = payload
                    parent.isScanning = false
                    break
                }
            }
        }
    }
}
