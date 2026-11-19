import SwiftUI
import VisionKit
import AVFoundation

struct DataScannerRepresentable: UIViewControllerRepresentable {
    @Binding var recognizedBarcode: String?
    @Binding var isScanning: Bool
    var onBecameUnavailable: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> DataScannerViewController {

        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
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
            do {
                try uiViewController.startScanning()
            } catch {
                print("⚠️ DataScanner startScanning failed: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    self.isScanning = false
                    self.onBecameUnavailable?()
                }
            }
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
            DispatchQueue.main.async {
                self.parent.isScanning = false
                self.parent.onBecameUnavailable?()
            }
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

/// AVFoundation barcode scanner fallback for devices where VisionKit DataScannerViewController is unavailable.
struct AVBarcodeScannerRepresentable: UIViewControllerRepresentable {
    @Binding var recognizedBarcode: String?
    @Binding var isScanning: Bool
    var onPermissionDenied: (() -> Void)? = nil
    var onUnavailable: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> AVBarcodeScannerViewController {
        let vc = AVBarcodeScannerViewController()
        vc.onBarcodeDetected = { payload in
            DispatchQueue.main.async {
                guard !context.coordinator.hasEmittedScan else { return }
                context.coordinator.hasEmittedScan = true
                HapticManager.shared.impact(style: .heavy)
                self.recognizedBarcode = payload
                self.isScanning = false
            }
        }
        vc.onPermissionDenied = {
            DispatchQueue.main.async {
                self.isScanning = false
                self.onPermissionDenied?()
            }
        }
        vc.onUnavailable = {
            DispatchQueue.main.async {
                self.isScanning = false
                self.onUnavailable?()
            }
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: AVBarcodeScannerViewController, context: Context) {
        if isScanning {
            context.coordinator.hasEmittedScan = false
            uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }

    static func dismantleUIViewController(_ uiViewController: AVBarcodeScannerViewController, coordinator: Coordinator) {
        uiViewController.stopScanning()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator {
        var hasEmittedScan = false
    }
}

final class AVBarcodeScannerViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    var onBarcodeDetected: ((String) -> Void)?
    var onPermissionDenied: (() -> Void)?
    var onUnavailable: (() -> Void)?

    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "com.borisdev.FoodTracker.avBarcodeSession")
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private var isConfigured = false
    private var shouldRun = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.videoGravity = .resizeAspectFill
        layer.frame = view.bounds
        view.layer.addSublayer(layer)
        self.previewLayer = layer
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    func startScanning() {
        shouldRun = true
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .authorized:
            configureAndRunIfNeeded()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                guard let self else { return }
                if granted {
                    self.configureAndRunIfNeeded()
                } else {
                    self.onPermissionDenied?()
                }
            }
        case .denied, .restricted:
            onPermissionDenied?()
        @unknown default:
            onUnavailable?()
        }
    }

    func stopScanning() {
        shouldRun = false
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else { return }
            self.session.stopRunning()
        }
    }

    private func configureAndRunIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured {
                guard let device = AVCaptureDevice.default(for: .video),
                      let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input) else {
                    self.onUnavailable?()
                    return
                }
                self.session.beginConfiguration()
                self.session.addInput(input)
                let metadataOutput = AVCaptureMetadataOutput()
                if self.session.canAddOutput(metadataOutput) {
                    self.session.addOutput(metadataOutput)
                    metadataOutput.setMetadataObjectsDelegate(self, queue: self.sessionQueue)
                    let supported: [AVMetadataObject.ObjectType] = [
                        .ean8, .ean13, .upce, .code128, .code39, .code93, .itf14, .pdf417, .qr
                    ].filter { metadataOutput.availableMetadataObjectTypes.contains($0) }
                    metadataOutput.metadataObjectTypes = supported
                } else {
                    self.session.commitConfiguration()
                    self.onUnavailable?()
                    return
                }
                self.session.commitConfiguration()
                self.isConfigured = true
            }
            if self.shouldRun && !self.session.isRunning {
                self.session.startRunning()
            }
        }
    }

    func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput metadataObjects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let readable = metadataObjects.first as? AVMetadataMachineReadableCodeObject,
              let payload = readable.stringValue,
              !payload.isEmpty else {
            return
        }
        onBarcodeDetected?(payload)
    }
}
