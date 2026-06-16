import SwiftUI
import AVFoundation
import VisionKit
import Combine

// MARK: - SmartScannerView
struct SmartScannerView: View {
    @Environment(\.dismiss) private var dismiss

    var onProductFound: (FoodItem) -> Void
    var onManualEntryRequest: (String?) -> Void

    var remainingCalories: Int
    var remainingProtein: Int

    @State private var recognizedBarcode: String? = nil
    @State private var isScanning: Bool = false
    @State private var isFlashlightOn: Bool = false

    @State private var selectedMode: ScannerMode
    @State private var cameraManager = LiveFoodCameraManager()
    @State private var isAnalyzingAI = false
    @State private var showShutterFlash = false

    @State private var menuResponse: VertexAIManager.MenuAIResponse? = nil

    @State private var isLoading: Bool = false
    @State private var notFoundError: Bool = false

    // Error state for AI failures — surfaced as an in-screen banner
    @State private var aiErrorMessage: String? = nil
    @State private var showAIError: Bool = false

    // Camera availability (checked once on appear)
    @State private var cameraPermissionDenied: Bool = false

    enum ScannerMode { case barcode, mealAI, menuAI }

    init(initialMode: ScannerMode = .barcode,
         remainingCalories: Int = 1000,
         remainingProtein: Int = 50,
         onProductFound: @escaping (FoodItem) -> Void,
         onManualEntryRequest: @escaping (String?) -> Void) {
        self.onProductFound = onProductFound
        self.onManualEntryRequest = onManualEntryRequest
        self.remainingCalories = remainingCalories
        self.remainingProtein = remainingProtein
        self._selectedMode = State(initialValue: initialMode)
    }

    // MARK: - Computed helpers
    private var barcodeAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    private var isCameraMode: Bool {
        selectedMode == .mealAI || selectedMode == .menuAI
    }

    // MARK: - Body
    var body: some View {
        ZStack {
            // ── Background layer ──────────────────────────────────────────
            cameraBackgroundLayer

            // ── Barcode viewfinder dim overlay ───────────────────────────
            if selectedMode == .barcode {
                barcodeOverlay
            }

            // ── Main content stack ────────────────────────────────────────
            VStack {
                topBar

                Spacer()

                if selectedMode == .barcode {
                    barcodeViewfinderContent
                } else {
                    cameraHintCard
                }

                Spacer()

                bottomControls
            }

            // ── Shutter flash ─────────────────────────────────────────────
            if showShutterFlash {
                Color.white.ignoresSafeArea()
            }

            // ── AI Analyzing overlay ──────────────────────────────────────
            if isAnalyzingAI {
                aiAnalyzingOverlay
                    .transition(.opacity)
                    .zIndex(100)
            }

            // ── Menu AI results sheet ─────────────────────────────────────
            if let menu = menuResponse {
                menuResultsLayer(menu: menu)
            }

            // ── AI error toast ────────────────────────────────────────────
            if showAIError, let msg = aiErrorMessage {
                aiErrorToast(message: msg)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(200)
            }

            // ── Camera permission denied fallback ─────────────────────────
            if cameraPermissionDenied {
                Color.black.opacity(0.7).ignoresSafeArea()
                CameraUnavailableView(reason: .permissionDenied)
            }
        }
        .onAppear {
            checkCameraPermission()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if selectedMode == .barcode { isScanning = true }
            }
        }
        .onDisappear {
            isScanning = false
            if isFlashlightOn { toggleFlashlight() }
            cameraManager.stop()
        }
        .onChange(of: selectedMode) { _, newMode in
            if isFlashlightOn { toggleFlashlight() }
            notFoundError = false
            recognizedBarcode = nil
            isScanning = (newMode == .barcode)
            if newMode == .barcode {
                cameraManager.stop()
            } else {
                cameraManager.capturedImage = nil
                cameraManager.checkPermissionAndStart()
            }
        }
        .onChange(of: recognizedBarcode) { _, newValue in
            if let code = newValue {
                searchBarcodeInDatabase(barcode: code)
            }
        }
        .onChange(of: cameraManager.capturedImage) { _, newImage in
            if let image = newImage {
                if selectedMode == .mealAI {
                    analyzeMealWithAI(image)
                } else if selectedMode == .menuAI {
                    analyzeMenuWithAI(image)
                }
            }
        }
    }

    // MARK: - View Layers

    @ViewBuilder
    private var cameraBackgroundLayer: some View {
        if selectedMode == .barcode {
            if barcodeAvailable {
                DataScannerRepresentable(recognizedBarcode: $recognizedBarcode, isScanning: $isScanning)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
        } else {
            LiveCameraPreviewView(session: cameraManager.session)
                .ignoresSafeArea()
                .onAppear { cameraManager.checkPermissionAndStart() }
                .onDisappear { cameraManager.stop() }
        }
    }

    private var barcodeOverlay: some View {
        Color.black.opacity(0.65)
            .ignoresSafeArea()
            .mask(
                Rectangle()
                    .overlay(RoundedRectangle(cornerRadius: 24).frame(width: 260, height: 260))
                    .compositingGroup()
                    .luminanceToAlpha()
            )
    }

    private var topBar: some View {
        HStack {
            Spacer()
            Button(action: { dismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 44, height: 44)
                    .background(.ultraThinMaterial)
                    .clipShape(Circle())
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 56)
    }

    @ViewBuilder
    private var barcodeViewfinderContent: some View {
        ZStack {
            // Animated corner brackets
            ScannerBracketFrame()
                .frame(width: 260, height: 260)

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView().tint(.white).scaleEffect(1.5)
                    Text("Searching database...")
                        .font(.headline.bold())
                        .foregroundColor(.white)
                }

            } else if notFoundError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(.themeOrange)

                    Text("Product not found")
                        .font(.headline)
                        .foregroundColor(.white)

                    Text("Scan the package or nutrition label with AI instead!")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 20)
                        .padding(.bottom, 8)

                    VStack(spacing: 12) {
                        Button(action: {
                            HapticManager.shared.impact(style: .heavy)
                            withAnimation(.spring()) {
                                selectedMode = .mealAI
                                notFoundError = false
                            }
                        }) {
                            Label("Scan with AI", systemImage: "sparkles")
                                .font(.headline.bold())
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(LinearGradient(colors: [.themePink, .blue], startPoint: .topLeading, endPoint: .bottomTrailing))
                                .clipShape(Capsule())
                        }
                        
                        HStack(spacing: 12) {
                            // Retry — reset and re-scan
                            Button(action: retryBarcodeScan) {
                                Label("Try Again", systemImage: "arrow.counterclockwise")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.2))
                                    .clipShape(Capsule())
                            }

                            // Manual entry fallback
                            Button(action: {
                                HapticManager.shared.impact(style: .medium)
                                dismiss()
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    onManualEntryRequest(recognizedBarcode)
                                }
                            }) {
                                Text("Enter Manually")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.white)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding(.horizontal, 32)
                }

            } else if !barcodeAvailable {
                // Device does not support DataScanner
                VStack(spacing: 12) {
                    Image(systemName: "viewfinder")
                        .font(.system(size: 50, weight: .ultraLight))
                        .foregroundColor(.white.opacity(0.5))
                    Text("Scanner not supported\non this device")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
            } else {
                // Idle hint
                Text("Align barcode or QR code\ninside the frame")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
                    .padding(.top, 110) // below the viewfinder centre
            }
        }
    }

    @ViewBuilder
    private var cameraHintCard: some View {
        let (icon, text): (String, String) = selectedMode == .mealAI
            ? ("fork.knife.circle", "Point at your meal\nand snap a photo")
            : ("text.book.closed.fill", "Scan a restaurant menu\nfor smart recommendations")

        VStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 56, weight: .ultraLight))
                .foregroundColor(.white.opacity(0.85))
                .symbolEffect(.pulse)

            Text(text)
                .font(.title3.bold())
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.5), radius: 5, y: 2)
        }
        .padding(24)
        .background(.ultraThinMaterial)
        .cornerRadius(24)
        .padding(.horizontal, 40)
    }

    private var bottomControls: some View {
        VStack(spacing: 20) {
            ScannerModePicker(selectedMode: $selectedMode)

            HStack {
                FloatingActionButton(icon: "pencil") {
                    HapticManager.shared.impact(style: .medium)
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        onManualEntryRequest(recognizedBarcode)
                    }
                }

                Spacer()

                if isCameraMode {
                    shutterButton
                } else {
                    Color.clear.frame(width: 76, height: 76)
                }

                Spacer()

                FloatingActionButton(icon: isFlashlightOn ? "bolt.fill" : "bolt.slash.fill") {
                    toggleFlashlight()
                }
            }
            .padding(.horizontal, 24)
        }
        .padding(.bottom, 44)
    }

    private var shutterButton: some View {
        Button(action: takePhoto) {
            ZStack {
                Circle()
                    .fill(selectedMode == .menuAI ? Color.blue : Color.themePink)
                    .frame(width: 76, height: 76)
                    .shadow(color: (selectedMode == .menuAI ? Color.blue : Color.themePink).opacity(0.4), radius: 12, y: 6)
                Circle()
                    .stroke(Color.white, lineWidth: 3)
                    .frame(width: 66, height: 66)
                Image(systemName: selectedMode == .menuAI ? "text.viewfinder" : "camera.fill")
                    .font(.title2)
                    .foregroundColor(.white)
            }
        }
        .offset(y: -20)
        .transition(.scale.combined(with: .opacity))
        .animation(.spring(response: 0.3), value: selectedMode)
    }

    private var aiAnalyzingOverlay: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundStyle(
                        LinearGradient(colors: [.themePink, .blue], startPoint: .top, endPoint: .bottom)
                    )
                    .symbolEffect(.pulse)

                Text(selectedMode == .menuAI
                    ? "AI is reading the menu...\nFinding the best options 🕵️‍♂️"
                    : "AI is analyzing your meal...\nCalculating macros 🪄")
                    .font(.headline)
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(6)
            }
        }
    }

    private func menuResultsLayer(menu: VertexAIManager.MenuAIResponse) -> some View {
        ZStack {
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture { menuResponse = nil }

            MenuHackerResultsView(response: menu) {
                menuResponse = nil
            }
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .zIndex(101)
        }
    }

    private func aiErrorToast(message: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.themeOrange)
            Text(message)
                .font(.subheadline.bold())
                .foregroundColor(.white)
            Spacer()
            Button(action: {
                withAnimation { showAIError = false }
            }) {
                Image(systemName: "xmark")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.6))
            }
        }
        .padding(16)
        .background(Color.black.opacity(0.85))
        .cornerRadius(16)
        .padding(.horizontal, 24)
        .padding(.top, 60)
        .frame(maxWidth: .infinity, alignment: .top)
        .frame(maxHeight: .infinity, alignment: .top)
    }

    // MARK: - Actions

    private func takePhoto() {
        HapticManager.shared.impact(style: .heavy)
        withAnimation(.linear(duration: 0.08)) { showShutterFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            withAnimation { showShutterFlash = false }
        }
        cameraManager.capturedImage = nil   // reset so onChange fires on next capture
        cameraManager.takePhoto()
    }

    private func retryBarcodeScan() {
        HapticManager.shared.impact(style: .medium)
        notFoundError = false
        recognizedBarcode = nil
        isScanning = true
    }

    private func checkCameraPermission() {
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        switch status {
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                DispatchQueue.main.async {
                    if !granted { self.cameraPermissionDenied = true }
                }
            }
        case .denied, .restricted:
            cameraPermissionDenied = true
        default:
            break
        }
    }

    private func searchBarcodeInDatabase(barcode: String) {
        isLoading = true
        notFoundError = false

        Task {
            if let foodItem = await NetworkManager.shared.fetchProduct(barcode: barcode) {
                await MainActor.run {
                    isLoading = false
                    HapticManager.shared.impact(style: .heavy)
                    onProductFound(foodItem)
                    dismiss()
                }
            } else {
                await MainActor.run {
                    isLoading = false
                    notFoundError = true
                    HapticManager.shared.impact(style: .rigid)
                }
            }
        }
    }

    private func analyzeMealWithAI(_ image: UIImage) {
        withAnimation { isAnalyzingAI = true }

        Task {
            if let foodItem = await VertexAIManager.shared.analyzeFoodImage(image) {
                await MainActor.run {
                    withAnimation { isAnalyzingAI = false }
                    HapticManager.shared.impact(style: .heavy)
                    onProductFound(foodItem)
                    dismiss()
                }
            } else {
                await MainActor.run {
                    withAnimation { isAnalyzingAI = false }
                    cameraManager.capturedImage = nil
                    showAIError(text: "Couldn't identify the food. Try better lighting or a clearer angle.")
                }
            }
        }
    }

    private func analyzeMenuWithAI(_ image: UIImage) {
        withAnimation { isAnalyzingAI = true }

        Task {
            if let response = await VertexAIManager.shared.analyzeMenuImage(
                image,
                remainingCalories: remainingCalories,
                targetProtein: remainingProtein
            ) {
                await MainActor.run {
                    withAnimation(.spring()) {
                        isAnalyzingAI = false
                        menuResponse = response
                        HapticManager.shared.impact(style: .heavy)
                    }
                }
            } else {
                await MainActor.run {
                    withAnimation { isAnalyzingAI = false }
                    cameraManager.capturedImage = nil
                    showAIError(text: "Couldn't read the menu. Make sure the text is visible and well-lit.")
                }
            }
        }
    }

    private func showAIError(text: String) {
        aiErrorMessage = text
        withAnimation(.spring(response: 0.3)) { showAIError = true }
        // Auto-dismiss after 4 s
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            withAnimation { showAIError = false }
        }
    }

    private func toggleFlashlight() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            if isFlashlightOn {
                device.torchMode = .off
            } else {
                try device.setTorchModeOn(level: 1.0)
            }
            device.unlockForConfiguration()
            isFlashlightOn.toggle()
            HapticManager.shared.impact(style: .light)
        } catch {
            print("❌ Flashlight error: \(error.localizedDescription)")
        }
    }
}

// MARK: - ScannerBracketFrame
// Animated corner bracket corners (premium scanner aesthetic)
private struct ScannerBracketFrame: View {
    @State private var opacity: Double = 0.4
    private let cornerLength: CGFloat = 30
    private let lineWidth: CGFloat = 3

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let r: CGFloat = 12

            ZStack {
                // Top-left corner
                CornerBracket(width: cornerLength, height: cornerLength, radius: r)
                    .stroke(Color.white, lineWidth: lineWidth)
                    .frame(width: cornerLength, height: cornerLength)
                    .position(x: cornerLength / 2, y: cornerLength / 2)

                // Top-right corner
                CornerBracket(width: cornerLength, height: cornerLength, radius: r)
                    .stroke(Color.white, lineWidth: lineWidth)
                    .frame(width: cornerLength, height: cornerLength)
                    .rotationEffect(.degrees(90))
                    .position(x: w - cornerLength / 2, y: cornerLength / 2)

                // Bottom-left corner
                CornerBracket(width: cornerLength, height: cornerLength, radius: r)
                    .stroke(Color.white, lineWidth: lineWidth)
                    .frame(width: cornerLength, height: cornerLength)
                    .rotationEffect(.degrees(-90))
                    .position(x: cornerLength / 2, y: h - cornerLength / 2)

                // Bottom-right corner
                CornerBracket(width: cornerLength, height: cornerLength, radius: r)
                    .stroke(Color.white, lineWidth: lineWidth)
                    .frame(width: cornerLength, height: cornerLength)
                    .rotationEffect(.degrees(180))
                    .position(x: w - cornerLength / 2, y: h - cornerLength / 2)
            }
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                opacity = 1.0
            }
        }
    }
}

private struct CornerBracket: Shape {
    let width: CGFloat
    let height: CGFloat
    let radius: CGFloat

    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: height))
        p.addLine(to: CGPoint(x: 0, y: radius))
        p.addQuadCurve(to: CGPoint(x: radius, y: 0), control: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: width, y: 0))
        return p
    }
}

// MARK: - LiveFoodCameraManager
@Observable
final class LiveFoodCameraManager: NSObject, AVCapturePhotoCaptureDelegate {
    var session = AVCaptureSession()
    var capturedImage: UIImage? = nil

    private let photoOutput = AVCapturePhotoOutput()
    private var isConfigured = false
    private let sessionQueue = DispatchQueue(label: "com.foodtracker.camera.sessionQueue")

    func checkPermissionAndStart() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            setupAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.setupAndStart()
                }
            }
        case .denied, .restricted:
            break
        @unknown default:
            break
        }
    }

    private func setupAndStart() {
        sessionQueue.async {
            guard !self.isConfigured else {
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            guard
                let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                self.session.canAddInput(videoInput)
            else {
                self.session.commitConfiguration()
                return
            }

            self.session.addInput(videoInput)

            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }

            self.session.commitConfiguration()
            self.isConfigured = true
            self.session.startRunning()
        }
    }

    func stop() {
        sessionQueue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func takePhoto() {
        sessionQueue.async {
            let settings = AVCapturePhotoSettings()
            if let connection = self.photoOutput.connection(with: .video) {
                connection.videoRotationAngle = 90 // portrait orientation
            }
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard let data = photo.fileDataRepresentation(), let image = UIImage(data: data) else { return }
        let fixedImage = fixOrientation(img: image)
        DispatchQueue.main.async {
            self.capturedImage = fixedImage
        }
    }

    private func fixOrientation(img: UIImage) -> UIImage {
        guard img.imageOrientation != .up else { return img }
        UIGraphicsBeginImageContextWithOptions(img.size, false, img.scale)
        img.draw(in: CGRect(origin: .zero, size: img.size))
        let normalized = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return normalized ?? img
    }
}

// MARK: - LiveCameraPreviewView
struct LiveCameraPreviewView: UIViewRepresentable {
    let session: AVCaptureSession

    class VideoPreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var videoPreviewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> VideoPreviewView {
        let view = VideoPreviewView()
        view.videoPreviewLayer.session = session
        view.videoPreviewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: VideoPreviewView, context: Context) {}
}

// MARK: - ScannerModePicker
struct ScannerModePicker: View {
    @Binding var selectedMode: SmartScannerView.ScannerMode

    var body: some View {
        HStack(spacing: 0) {
            ModeButton(
                icon: "barcode.viewfinder",
                title: "Barcode",
                isActive: selectedMode == .barcode,
                accent: .green
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedMode = .barcode }
            }
            ModeButton(
                icon: "camera.macro",
                title: "Meal AI",
                isActive: selectedMode == .mealAI,
                accent: .themePink
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedMode = .mealAI }
            }
            ModeButton(
                icon: "text.viewfinder",
                title: "Menu AI",
                isActive: selectedMode == .menuAI,
                accent: .blue
            ) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedMode = .menuAI }
            }
        }
        .padding(4)
        .background(.ultraThinMaterial)
        .clipShape(Capsule())
    }
}

// MARK: - ModeButton
struct ModeButton: View {
    let icon: String
    let title: String
    let isActive: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .light)
            action()
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                Text(title)
                    .font(.system(size: 14, weight: isActive ? .semibold : .medium, design: .rounded))
            }
            .foregroundColor(isActive ? accent : .white.opacity(0.65))
            .padding(.vertical, 10)
            .padding(.horizontal, 14)
            .background(
                Capsule().fill(isActive ? Color.white.opacity(0.18) : Color.clear)
            )
        }
    }
}

// MARK: - FloatingActionButton
struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

// MARK: - MenuHackerResultsView
struct MenuHackerResultsView: View {
    let response: VertexAIManager.MenuAIResponse
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Menu Analysis")
                        .font(.title2.bold())
                    Text("Based on your remaining macros")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 14) {
                    MenuRecCard(rec: response.ideal,  type: "Ideal Match", icon: "checkmark.seal.fill",        color: .green)
                    MenuRecCard(rec: response.caution, type: "With Caution", icon: "exclamationmark.triangle.fill", color: .orange)
                    MenuRecCard(rec: response.avoid,   type: "Avoid Today",  icon: "xmark.octagon.fill",           color: .red)
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(32)
        .shadow(color: .black.opacity(0.15), radius: 30, y: -10)
        .padding()
    }
}

// MARK: - MenuRecCard
struct MenuRecCard: View {
    let rec: VertexAIManager.MenuRecommendation
    let type: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundColor(color)
                Text(type)
                    .font(.caption.bold())
                    .foregroundColor(color)
                    .textCase(.uppercase)
                Spacer()
                Text("~ \(rec.estimatedCalories) kcal")
                    .font(.headline)
                    .foregroundColor(.primary)
            }

            Text(rec.dishName)
                .font(.title3.bold())
                .foregroundColor(.primary)

            Text(rec.reasoning)
                .font(.subheadline)
                .foregroundColor(.gray)
                .lineSpacing(3)

            HStack {
                Text("Est. Protein:")
                    .font(.caption)
                    .foregroundColor(.gray)
                Text("\(Int(rec.protein))g")
                    .font(.caption.bold())
                    .foregroundColor(color)
            }
            .padding(.top, 2)
        }
        .padding(16)
        .background(color.opacity(0.08))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.25), lineWidth: 1)
        )
    }
}
