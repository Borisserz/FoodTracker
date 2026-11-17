import SwiftUI
import AVFoundation
import VisionKit
import Combine

struct SmartScannerView: View {
    @Environment(\.dismiss) private var dismiss

    var onProductFound: (FoodItem) -> Void
    var onManualEntryRequest: () -> Void

    var remainingCalories: Int = 1000
    var remainingProtein: Int = 50

    @State private var recognizedBarcode: String? = nil
    @State private var isScanning: Bool = false
    @State private var isFlashlightOn: Bool = false
    @State private var isPulseActive: Bool = false

    @State private var selectedMode: ScannerMode = .barcode
    // @State for @Observable class (replaces @StateObject for the migrated LiveFoodCameraManager)
    @State private var cameraManager = LiveFoodCameraManager()
    @State private var isAnalyzingAI = false
    @State private var showShutterFlash = false

    @State private var menuResponse: VertexAIManager.MenuAIResponse? = nil

    @State private var isLoading: Bool = false
    @State private var notFoundError: Bool = false
    @State private var scanErrorMessage: String? = nil
    @State private var barcodeTask: Task<Void, Never>? = nil
    @State private var aiTask: Task<Void, Never>? = nil

    enum ScannerMode { case barcode, mealAI, menuAI }

    var body: some View {
        ZStack {

            if selectedMode == .barcode && DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                DataScannerRepresentable(recognizedBarcode: $recognizedBarcode, isScanning: $isScanning)
                    .ignoresSafeArea()
            } else if selectedMode == .mealAI || selectedMode == .menuAI {
                LiveCameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()
                    .overlay {
                        if selectedMode == .mealAI {
                            ARFoodHUDOverlay()
                        }
                    }
                    .onAppear { cameraManager.checkPermissionAndStart() }
                    .onDisappear { cameraManager.stop() }
            } else {
                ZStack {
                    Color.black.ignoresSafeArea()
                    VStack(spacing: 16) {
                        Image(systemName: "barcode.viewfinder")
                            .font(.system(size: 48))
                            .foregroundColor(.white.opacity(0.6))
                        Text("Live barcode scanning is unavailable on this device.")
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                        Button("Use Meal AI Photo") {
                            selectedMode = .mealAI
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.themePink)
                    }
                }
            }

            if selectedMode == .barcode {
                Color.black.opacity(0.65)
                    .ignoresSafeArea()
                    .mask(
                        Rectangle()
                            .overlay(RoundedRectangle(cornerRadius: 24).frame(width: 250, height: 250))
                            .compositingGroup()
                            .luminanceToAlpha()
                    )
            }

            VStack {

                HStack {
                    Spacer()
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.black.opacity(0.4))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 50)

                Spacer()

                if selectedMode == .barcode {
                    ZStack {
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(Color.white.opacity(isPulseActive ? 0.3 : 1.0), lineWidth: isPulseActive ? 4 : 2)
                            .frame(width: 250, height: 250)
                            .scaleEffect(isPulseActive ? 1.02 : 1.0)
                            .animation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true), value: isPulseActive)
                            .onAppear { isPulseActive = true }
                            .onDisappear { isPulseActive = false }

                        if isLoading {
                            VStack(spacing: 12) {
                                ProgressView().tint(.white).scaleEffect(1.5)
                                Text("Searching Database...").font(.headline).foregroundColor(.white)
                            }
                        } else if notFoundError {
                            VStack(spacing: 16) {
                                Image(systemName: "exclamationmark.magnifyingglass")
                                    .font(.system(size: 40))
                                    .foregroundColor(.themeOrange)
                                Text("Product not found")
                                    .font(.headline)
                                    .foregroundColor(.white)

                                Button(action: {
                                    HapticManager.shared.impact(style: .medium)
                                    dismiss()
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                        onManualEntryRequest()
                                    }
                                }) {
                                    Text("Enter Manually")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                        .background(Color.white)
                                        .clipShape(Capsule())
                                }

                                Button(action: {
                                    HapticManager.shared.impact(style: .light)
                                    notFoundError = false
                                    recognizedBarcode = nil
                                    isScanning = true
                                }) {
                                    Text("Scan Again")
                                        .font(.subheadline.bold())
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.2))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                    }
                } else {

                    if selectedMode == .mealAI || selectedMode == .menuAI {
                        if cameraManager.isPermissionDenied {
                            VStack(spacing: 14) {
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(.themeOrange)
                                Text("Camera access is needed to scan meals and menus.")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                                    Link("Open Settings", destination: settingsURL)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 18)
                                        .padding(.vertical, 8)
                                        .background(Color.white)
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.horizontal, 32)
                        } else if selectedMode == .mealAI {
                            cameraHint(icon: "viewfinder", text: "Point at your meal\nand snap a photo")
                        } else if selectedMode == .menuAI {
                            cameraHint(icon: "text.book.closed.fill", text: "Scan a restaurant menu\nto get smart choices")
                        }
                    }
                }

                Spacer()

                VStack(spacing: 24) {
                    ScannerModePicker(selectedMode: $selectedMode)

                    HStack {
                        FloatingActionButton(icon: "pencil") {
                            HapticManager.shared.impact(style: .medium)
                            dismiss()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                onManualEntryRequest()
                            }
                        }

                        Spacer()

                        if selectedMode == .mealAI || selectedMode == .menuAI {
                            Button(action: takePhoto) {
                                ZStack {
                                    Circle()
                                        .fill(selectedMode == .menuAI ? Color.blue : Color.themePink)
                                        .frame(width: 76, height: 76)
                                    Circle()
                                        .stroke(Color.white, lineWidth: 3)
                                        .frame(width: 66, height: 66)
                                }
                                .shadow(color: (selectedMode == .menuAI ? Color.blue : Color.themePink).opacity(0.4), radius: 10, y: 5)
                            }
                            .offset(y: -20)
                            .transition(.scale.combined(with: .opacity))
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
                .padding(.bottom, 40)
            }

            if showShutterFlash {
                Color.white.ignoresSafeArea()
            }

            if isAnalyzingAI {
                ZStack {
                    Color.black.opacity(0.85).ignoresSafeArea()
                    VStack(spacing: 24) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 60))
                            .foregroundStyle(LinearGradient(colors: [.themePink, .blue], startPoint: .top, endPoint: .bottom))
                            .symbolEffect(.pulse)

                        Text(selectedMode == .menuAI ? "AI is reading the menu...\nFinding the best options 🕵️‍♂️" : "AI is analyzing your meal...\nCalculating macros 🪄")
                            .font(.headline)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.center)
                            .lineSpacing(6)
                    }
                }
                .zIndex(100)
                .transition(.opacity)
            }

            if let menu = menuResponse {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea().onTapGesture { menuResponse = nil }
                    MenuHackerResultsView(response: menu) {
                        menuResponse = nil
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(101)
                }
            }
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                if selectedMode == .barcode { isScanning = true }
            }
        }
        .alert(
            "Analysis Failed",
            isPresented: Binding(
                get: { scanErrorMessage != nil },
                set: { if !$0 { scanErrorMessage = nil } }
            )
        ) {
            Button("Enter Manually") {
                scanErrorMessage = nil
                dismiss()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onManualEntryRequest()
                }
            }
            Button("Try Again", role: .cancel) {
                scanErrorMessage = nil
            }
        } message: {
            Text(scanErrorMessage ?? "")
        }
        .onDisappear {
            isScanning = false
            barcodeTask?.cancel()
            barcodeTask = nil
            aiTask?.cancel()
            aiTask = nil

            if isFlashlightOn { toggleFlashlight() }
            cameraManager.stop()
        }
        .onChange(of: selectedMode) { _, newMode in
            barcodeTask?.cancel()
            barcodeTask = nil
            aiTask?.cancel()
            aiTask = nil
            isLoading = false
            isAnalyzingAI = false
            recognizedBarcode = nil

            if isFlashlightOn { toggleFlashlight() }

            isScanning = (newMode == .barcode)
            if newMode == .barcode {
                cameraManager.stop()
            } else {
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

    private func takePhoto() {
        HapticManager.shared.impact(style: .heavy)
        withAnimation(.linear(duration: 0.1)) { showShutterFlash = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            withAnimation { showShutterFlash = false }
        }
        cameraManager.takePhoto()
    }

    private func cameraHint(icon: String, text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 60, weight: .ultraLight))
                .foregroundColor(.white.opacity(0.8))
            Text(text)
                .font(.title3.bold())
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .shadow(color: .black.opacity(0.5), radius: 5, y: 2)
        }
        .padding()
        .background(Color.black.opacity(0.2))
        .cornerRadius(20)
    }

    private func searchBarcodeInDatabase(barcode: String) {
        guard !isLoading else { return }
        isLoading = true
        notFoundError = false
        barcodeTask?.cancel()

        barcodeTask = Task {
            let foodItem = await NetworkManager.shared.fetchProduct(barcode: barcode)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                isLoading = false
                if let foodItem {
                    HapticManager.shared.impact(style: .heavy)
                    onProductFound(foodItem)
                    dismiss()
                } else {
                    notFoundError = true
                    HapticManager.shared.impact(style: .rigid)
                }
            }
        }
    }

    private func analyzeMealWithAI(_ image: UIImage) {
        guard !isAnalyzingAI else { return }
        withAnimation { isAnalyzingAI = true }
        aiTask?.cancel()

        aiTask = Task {
            let result = await VertexAIManager.shared.analyzeFoodImageDetailed(image)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation { isAnalyzingAI = false }
                switch result {
                case .food(let foodItem):
                    HapticManager.shared.impact(style: .heavy)
                    onProductFound(foodItem)
                    dismiss()
                case .notFood(let message):
                    cameraManager.capturedImage = nil
                    HapticManager.shared.notification(type: .warning)
                    scanErrorMessage = message
                case .failed:
                    cameraManager.capturedImage = nil
                    HapticManager.shared.notification(type: .error)
                    scanErrorMessage = String(localized: "Couldn't recognize food in this photo or the AI service is temporarily unavailable. Please try again or enter manually.")
                }
            }
        }
    }

    private func analyzeMenuWithAI(_ image: UIImage) {
        guard !isAnalyzingAI else { return }
        withAnimation { isAnalyzingAI = true }
        aiTask?.cancel()
        aiTask = Task {
            let response = await VertexAIManager.shared.analyzeMenuImage(image, remainingCalories: remainingCalories, targetProtein: remainingProtein)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                cameraManager.capturedImage = nil
                if let response {
                    withAnimation(.spring()) {
                        isAnalyzingAI = false
                        menuResponse = response
                        HapticManager.shared.impact(style: .heavy)
                    }
                } else {
                    withAnimation {
                        isAnalyzingAI = false
                        scanErrorMessage = String(localized: "Couldn't analyze this menu right now. Please try a clearer photo.")
                    }
                }
            }
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
            print("❌ Ошибка при включении фонарика: \(error.localizedDescription)")
        }
    }
}

@Observable
final class LiveFoodCameraManager: NSObject, AVCapturePhotoCaptureDelegate {
    // Migrated from ObservableObject/@Published to @Observable (plain vars now notify observers)
    var session = AVCaptureSession()
    var capturedImage: UIImage? = nil
    var isPermissionDenied: Bool = false
    var isCameraUnavailable: Bool = false

    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.borisdev.FoodTracker.cameraSession")
    private var isConfigured = false
    private var shouldBeRunning = false

    func checkPermissionAndStart() {
        guard AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil else {
            isCameraUnavailable = true
            return
        }
        isCameraUnavailable = false

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            isPermissionDenied = false
            setupAndStart()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.isPermissionDenied = !granted
                    if granted {
                        self?.setupAndStart()
                    }
                }
            }
        default:
            isPermissionDenied = true
        }
    }

    private func setupAndStart() {
        shouldBeRunning = true
        sessionQueue.async { [weak self] in
            guard let self, self.shouldBeRunning else { return }

            if self.isConfigured {
                if !self.session.isRunning {
                    self.session.startRunning()
                }
                return
            }

            self.session.beginConfiguration()
            self.session.sessionPreset = .photo

            guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
                  let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
                  self.session.canAddInput(videoInput) else {
                self.session.commitConfiguration()
                DispatchQueue.main.async { self.isCameraUnavailable = true }
                return
            }

            do {
                try videoDevice.lockForConfiguration()
                if videoDevice.isFocusModeSupported(.continuousAutoFocus) {
                    videoDevice.focusMode = .continuousAutoFocus
                }
                if videoDevice.isExposureModeSupported(.continuousAutoExposure) {
                    videoDevice.exposureMode = .continuousAutoExposure
                }
                if videoDevice.isLowLightBoostSupported {
                    videoDevice.automaticallyEnablesLowLightBoostWhenAvailable = true
                }
                videoDevice.isSubjectAreaChangeMonitoringEnabled = true
                videoDevice.unlockForConfiguration()
            } catch {
                print("❌ Failed to configure camera: \(error.localizedDescription)")
            }

            self.session.addInput(videoInput)

            if self.session.canAddOutput(self.photoOutput) {
                self.session.addOutput(self.photoOutput)
            }

            self.session.commitConfiguration()
            self.isConfigured = true

            if self.shouldBeRunning {
                self.session.startRunning()
            }
        }
    }

    func stop() {
        shouldBeRunning = false
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func takePhoto() {
        sessionQueue.async { [weak self] in
            guard let self, self.isConfigured, self.session.isRunning else { return }
            let settings = AVCapturePhotoSettings()
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
        let renderer = UIGraphicsImageRenderer(size: img.size)
        return renderer.image { _ in
            img.draw(in: CGRect(origin: .zero, size: img.size))
        }
    }
}

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

struct ScannerModePicker: View {
    @Binding var selectedMode: SmartScannerView.ScannerMode
    var body: some View {
        HStack(spacing: 0) {
            ModeButton(title: "Barcode", isActive: selectedMode == .barcode) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedMode = .barcode }
            }
            ModeButton(title: "Meal AI", isActive: selectedMode == .mealAI) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedMode = .mealAI }
            }
            ModeButton(title: "Menu AI", isActive: selectedMode == .menuAI) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { selectedMode = .menuAI }
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.4))
        .clipShape(Capsule())
    }
}

struct ModeButton: View {
    let title: String
    let isActive: Bool
    let action: () -> Void
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(style: .light)
            action()
        }) {
            Text(title)
                .font(.system(size: 15, weight: isActive ? .semibold : .medium, design: .rounded))
                .foregroundColor(isActive ? .green : .white.opacity(0.7))
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(Capsule().fill(isActive ? Color(white: 0.2) : Color.clear))
        }
    }
}

struct FloatingActionButton: View {
    let icon: String
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
                .frame(width: 56, height: 56)
                .background(Color.black.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }
}

struct MenuHackerResultsView: View {
    let response: VertexAIManager.MenuAIResponse
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            HStack {
                Text("AI Menu Analysis").font(.title2.bold())
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.gray)
                }
            }

            ScrollView(showsIndicators: false) {
                VStack(spacing: 16) {
                    MenuRecCard(rec: response.ideal, type: "Ideal Match", icon: "checkmark.seal.fill", color: .green)
                    MenuRecCard(rec: response.caution, type: "Caution", icon: "exclamationmark.triangle.fill", color: .orange)
                    MenuRecCard(rec: response.avoid, type: "Avoid", icon: "xmark.octagon.fill", color: .red)
                }
            }
        }
        .padding(24)
        .background(Color.white)
        .cornerRadius(32)
        .padding()
    }
}

struct MenuRecCard: View {
    let rec: VertexAIManager.MenuRecommendation
    let type: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundColor(color)
                Text(type).font(.caption.bold()).foregroundColor(color).textCase(.uppercase)
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

            HStack {
                Text("Est. Protein:").font(.caption).foregroundColor(.gray)
                Text("\(Int(rec.protein))g").font(.caption.bold()).foregroundColor(color)
            }
            .padding(.top, 4)
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(color.opacity(0.3), lineWidth: 1)
        )
    }
}
