import SwiftUI
import Vision
import VisionKit
import AVFoundation

final class DataScannerContainerViewController: UIViewController {
    let scanner: DataScannerViewController

    init(scanner: DataScannerViewController) {
        self.scanner = scanner
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black
        addChild(scanner)
        scanner.view.frame = view.bounds
        scanner.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(scanner.view)
        scanner.didMove(toParent: self)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        let size = view.bounds.size
        guard size.width > 250 && size.height > 250 else { return }
        let roi = CGRect(
            x: (size.width - 250) / 2,
            y: (size.height - 250) / 2,
            width: 250,
            height: 250
        )
        if scanner.regionOfInterest != roi {
            scanner.regionOfInterest = roi
        }
    }
}

struct DataScannerRepresentable: UIViewControllerRepresentable {
    @Binding var recognizedBarcode: String?
    @Binding var isScanning: Bool
    var onBecameUnavailable: (() -> Void)? = nil

    func makeUIViewController(context: Context) -> DataScannerContainerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [
                .barcode(symbologies: [
                    .ean8, .ean13, .upce, .code128, .code39, .code93, .i2of5, .itf14
                ])
            ],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isPinchToZoomEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        return DataScannerContainerViewController(scanner: scanner)
    }

    func updateUIViewController(_ uiViewController: DataScannerContainerViewController, context: Context) {
        context.coordinator.parent = self
        guard context.coordinator.lastIsScanning != isScanning else { return }
        context.coordinator.lastIsScanning = isScanning
        let scanner = uiViewController.scanner
        if isScanning {
            context.coordinator.hasEmittedScan = false
            do {
                try scanner.startScanning()
            } catch {
                #if DEBUG
                print("⚠️ DataScanner startScanning failed: \(error.localizedDescription)")
                #endif
                DispatchQueue.main.async {
                    self.isScanning = false
                    self.onBecameUnavailable?()
                }
            }
        } else {
            scanner.stopScanning()
        }
    }

    static func dismantleUIViewController(_ uiViewController: DataScannerContainerViewController, coordinator: Coordinator) {
        uiViewController.scanner.stopScanning()
        uiViewController.scanner.delegate = nil
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
        let coordinator = context.coordinator
        vc.onBarcodeDetected = { [weak coordinator] payload in
            DispatchQueue.main.async {
                guard let coordinator, !coordinator.hasEmittedScan else { return }
                coordinator.hasEmittedScan = true
                HapticManager.shared.impact(style: .heavy)
                coordinator.parent.recognizedBarcode = payload
                coordinator.parent.isScanning = false
            }
        }
        vc.onPermissionDenied = { [weak coordinator] in
            DispatchQueue.main.async {
                guard let coordinator else { return }
                coordinator.parent.isScanning = false
                coordinator.parent.onPermissionDenied?()
            }
        }
        vc.onUnavailable = { [weak coordinator] in
            DispatchQueue.main.async {
                guard let coordinator else { return }
                coordinator.parent.isScanning = false
                coordinator.parent.onUnavailable?()
            }
        }
        return vc
    }

    func updateUIViewController(_ uiViewController: AVBarcodeScannerViewController, context: Context) {
        context.coordinator.parent = self
        guard context.coordinator.lastIsScanning != isScanning else { return }
        context.coordinator.lastIsScanning = isScanning
        if isScanning {
            context.coordinator.hasEmittedScan = false
            uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }

    static func dismantleUIViewController(_ uiViewController: AVBarcodeScannerViewController, coordinator: Coordinator) {
        uiViewController.teardownSession()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    final class Coordinator {
        var parent: AVBarcodeScannerRepresentable
        var lastIsScanning: Bool?
        var hasEmittedScan = false

        init(_ parent: AVBarcodeScannerRepresentable) {
            self.parent = parent
        }
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

    deinit {
        teardownSession()
    }

    func startScanning() {
        sessionQueue.async { [weak self] in
            self?.shouldRun = true
        }
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
                    self.sessionQueue.async { [weak self] in
                        self?.shouldRun = false
                    }
                    self.onPermissionDenied?()
                }
            }
        case .denied, .restricted:
            sessionQueue.async { [weak self] in
                self?.shouldRun = false
            }
            onPermissionDenied?()
        @unknown default:
            sessionQueue.async { [weak self] in
                self?.shouldRun = false
            }
            onUnavailable?()
        }
    }

    func stopScanning() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.shouldRun = false
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func teardownSession() {
        if Thread.isMainThread {
            previewLayer?.session = nil
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.previewLayer?.session = nil
            }
        }
        let captureSession = session
        sessionQueue.async { [weak self] in
            self?.shouldRun = false
            self?.isConfigured = false
            if captureSession.isRunning {
                captureSession.stopRunning()
            }
            for input in captureSession.inputs {
                captureSession.removeInput(input)
            }
            for output in captureSession.outputs {
                captureSession.removeOutput(output)
            }
        }
    }

    private func configureAndRunIfNeeded() {
        sessionQueue.async { [weak self] in
            guard let self, self.shouldRun else { return }
            if !self.isConfigured {
                guard let device = AVCaptureDevice.default(for: .video),
                      let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input) else {
                    DispatchQueue.main.async { [weak self] in self?.onUnavailable?() }
                    return
                }
                self.session.beginConfiguration()
                self.session.addInput(input)
                let metadataOutput = AVCaptureMetadataOutput()
                if self.session.canAddOutput(metadataOutput) {
                    self.session.addOutput(metadataOutput)
                    metadataOutput.setMetadataObjectsDelegate(self, queue: self.sessionQueue)
                    let supported: [AVMetadataObject.ObjectType] = [
                        .ean8, .ean13, .upce, .code128, .code39, .code93, .itf14
                    ].filter { metadataOutput.availableMetadataObjectTypes.contains($0) }
                    metadataOutput.metadataObjectTypes = supported
                } else {
                    self.session.removeInput(input)
                    self.session.commitConfiguration()
                    DispatchQueue.main.async { [weak self] in self?.onUnavailable?() }
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
