import SwiftUI
import AVFoundation
import VisionKit
import PhotosUI
import Combine

struct SmartScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    var onProductFound: (FoodItem) -> Void
    var onManualEntryRequest: () -> Void

    var remainingCalories: Int = 1000
    var remainingProtein: Int = 50

    @State private var recognizedBarcode: String? = nil
    @State private var isScanning: Bool = false
    @State private var isFlashlightOn: Bool = false
    @State private var isPulseActive: Bool = false

    @State private var selectedMode: ScannerMode = .barcode
    @State private var cameraManager = LiveFoodCameraManager()
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    @State private var isAnalyzingAI = false
    @State private var isCapturingPhoto = false
    @State private var showShutterFlash = false

    @State private var menuResponse: VertexAIManager.MenuAIResponse? = nil

    @State private var isLoading: Bool = false
    @State private var notFoundError: Bool = false
    @State private var scanErrorMessage: String? = nil
    @State private var barcodeTask: Task<Void, Never>? = nil
    @State private var aiTask: Task<Void, Never>? = nil
    @State private var startScanWorkItem: DispatchWorkItem? = nil
    @State private var barcodePermissionStatus: AVAuthorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)

    enum ScannerMode { case barcode, mealAI, menuAI }

    private var isBarcodePermissionDenied: Bool {
        barcodePermissionStatus == .denied || barcodePermissionStatus == .restricted
    }

    private var canCapturePhoto: Bool {
        (selectedMode == .mealAI || selectedMode == .menuAI)
        && cameraManager.isConfigured
        && !cameraManager.isPermissionDenied
        && !cameraManager.isCameraUnavailable
        && !isAnalyzingAI
        && !isCapturingPhoto
        && menuResponse == nil
    }

    var body: some View {
        ZStack {

            if selectedMode == .barcode {
                if isBarcodePermissionDenied {
                    cameraPermissionFallbackView
                } else if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                    DataScannerRepresentable(recognizedBarcode: $recognizedBarcode, isScanning: $isScanning)
                        .ignoresSafeArea()
                } else {
                    barcodeUnavailableFallbackView
                }
            } else {
                LiveCameraPreviewView(session: cameraManager.session)
                    .ignoresSafeArea()
                    .overlay {
                        if selectedMode == .mealAI && !cameraManager.isPermissionDenied && !cameraManager.isCameraUnavailable {
                            ARFoodHUDOverlay()
                        }
                    }
                    .onAppear { cameraManager.checkPermissionAndStart() }
                    .onDisappear { cameraManager.stop() }
            }

            if selectedMode == .barcode && !isBarcodePermissionDenied && DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                Color.black.opacity(0.65)
                    .ignoresSafeArea()
                    .mask(
                        Color.white
                            .overlay(
                                Color.black
                                    .clipShape(RoundedRectangle(cornerRadius: 24))
                                    .frame(width: 250, height: 250)
                            )
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
                    if cameraManager.isPermissionDenied {
                        cameraPermissionFallbackView
                    } else if cameraManager.isCameraUnavailable {
                        VStack(spacing: 14) {
                            Image(systemName: "video.slash.fill")
                                .font(.system(size: 36))
                                .foregroundColor(.themeOrange)
                            Text("Camera Unavailable")
                                .font(.headline)
                                .foregroundColor(.white)
                            Text("Choose a photo from your library to analyze with AI.")
                                .font(.subheadline)
                                .foregroundColor(.white.opacity(0.8))
                                .multilineTextAlignment(.center)
                            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                Label("Choose from Library", systemImage: "photo.on.rectangle")
                                    .font(.subheadline.bold())
                                    .foregroundColor(.black)
                                    .padding(.horizontal, 18)
                                    .padding(.vertical, 10)
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
                                .opacity(canCapturePhoto ? 1.0 : 0.45)
                                .shadow(color: (selectedMode == .menuAI ? Color.blue : Color.themePink).opacity(0.4), radius: 10, y: 5)
                            }
                            .disabled(!canCapturePhoto)
                            .offset(y: -20)
                            .transition(.scale.combined(with: .opacity))
                        } else {
                            Color.clear.frame(width: 76, height: 76)
                        }

                        Spacer()

                        if selectedMode == .mealAI || selectedMode == .menuAI {
                            HStack(spacing: 12) {
                                PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                                    Image(systemName: "photo.on.rectangle")
                                        .font(.system(size: 20, weight: .semibold))
                                        .foregroundColor(.white)
                                        .frame(width: 56, height: 56)
                                        .background(Color.black.opacity(0.4))
                                        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                                }
                                .disabled(isAnalyzingAI || menuResponse != nil)

                                FloatingActionButton(icon: isFlashlightOn ? "bolt.fill" : "bolt.slash.fill") {
                                    toggleFlashlight()
                                }
                            }
                        } else {
                            Color.clear.frame(width: 56, height: 56)
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

                        Button(action: cancelCurrentAIAnalysis) {
                            Text("Cancel")
                                .font(.subheadline.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 24)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.18))
                                .clipShape(Capsule())
                        }
                        .padding(.top, 8)
                    }
                }
                .zIndex(100)
                .transition(.opacity)
            }

            if let menu = menuResponse {
                ZStack {
                    Color.black.opacity(0.6).ignoresSafeArea().onTapGesture { menuResponse = nil }
                    MenuHackerResultsView(
                        response: menu,
                        onLogDish: { dishItem in
                            menuResponse = nil
                            deliverFoundProduct(dishItem)
                        },
                        onClose: {
                            menuResponse = nil
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(101)
                }
            }
        }
        .onAppear {
            barcodePermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
            startScanWorkItem?.cancel()
            let work = DispatchWorkItem { [self] in
                if selectedMode == .barcode {
                    isScanning = true
                }
            }
            startScanWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: work)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            barcodePermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
            if selectedMode == .mealAI || selectedMode == .menuAI {
                cameraManager.checkPermissionAndStart()
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
                if selectedMode == .barcode {
                    notFoundError = false
                    recognizedBarcode = nil
                    isScanning = true
                }
            }
        } message: {
            Text(scanErrorMessage ?? "")
        }
        .onDisappear {
            startScanWorkItem?.cancel()
            startScanWorkItem = nil
            isScanning = false
            barcodeTask?.cancel()
            barcodeTask = nil
            aiTask?.cancel()
            aiTask = nil
            isCapturingPhoto = false

            if isFlashlightOn {
                cameraManager.setTorch(enabled: false)
                isFlashlightOn = false
            }
            cameraManager.stop()
        }
        .onChange(of: selectedMode) { _, newMode in
            startScanWorkItem?.cancel()
            startScanWorkItem = nil
            barcodeTask?.cancel()
            barcodeTask = nil
            aiTask?.cancel()
            aiTask = nil
            isLoading = false
            isAnalyzingAI = false
            isCapturingPhoto = false
            notFoundError = false
            recognizedBarcode = nil
            cameraManager.capturedImage = nil

            if isFlashlightOn {
                cameraManager.setTorch(enabled: false)
                isFlashlightOn = false
            }

            if newMode == .barcode {
                isScanning = false
                barcodePermissionStatus = AVCaptureDevice.authorizationStatus(for: .video)
                cameraManager.stop {
                    guard selectedMode == .barcode else { return }
                    isScanning = true
                }
            } else {
                isScanning = false
            }
        }
        .onChange(of: recognizedBarcode) { _, newValue in
            if let code = newValue {
                searchBarcodeInDatabase(barcode: code)
            }
        }
        .onChange(of: cameraManager.capturedImage) { _, newImage in
            isCapturingPhoto = false
            if let image = newImage {
                if selectedMode == .mealAI {
                    analyzeMealWithAI(image)
                } else if selectedMode == .menuAI {
                    analyzeMenuWithAI(image)
                }
            }
        }
        .onChange(of: cameraManager.captureError) { _, err in
            guard let err else { return }
            isCapturingPhoto = false
            cameraManager.captureError = nil
            scanErrorMessage = err
        }
        .onChange(of: selectedPhotoItem) { _, newItem in
            guard let newItem else { return }
            selectedPhotoItem = nil
            let currentMode = selectedMode
            Task {
                if let data = try? await newItem.loadTransferable(type: Data.self),
                   let rawImage = UIImage(data: data) {
                    let downsampled = await Task.detached(priority: .userInitiated) {
                        VertexAIManager.downsampledImage(rawImage, maxDimension: 1280)
                    }.value
                    await MainActor.run {
                        if currentMode == .menuAI {
                            analyzeMenuWithAI(downsampled)
                        } else {
                            selectedMode = (currentMode == .barcode) ? .mealAI : currentMode
                            analyzeMealWithAI(downsampled)
                        }
                    }
                }
            }
        }
    }

    private var cameraPermissionFallbackView: some View {
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
    }

    private var barcodeUnavailableFallbackView: some View {
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

    private func deliverFoundProduct(_ item: FoodItem) {
        cameraManager.capturedImage = nil
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onProductFound(item)
        }
    }

    private func cancelCurrentAIAnalysis() {
        aiTask?.cancel()
        aiTask = nil
        isAnalyzingAI = false
        isCapturingPhoto = false
        cameraManager.capturedImage = nil
    }

    private func takePhoto() {
        guard canCapturePhoto else { return }
        isCapturingPhoto = true
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
                    deliverFoundProduct(foodItem)
                } else if let networkErr = NetworkManager.shared.lastBarcodeLookupError {
                    HapticManager.shared.notification(type: .error)
                    scanErrorMessage = networkErr
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
                    deliverFoundProduct(foodItem)
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
        guard selectedMode == .mealAI || selectedMode == .menuAI else { return }
        let targetState = !isFlashlightOn
        cameraManager.setTorch(enabled: targetState) { actualState in
            isFlashlightOn = actualState
            HapticManager.shared.impact(style: .light)
        }
    }
}

@Observable
final class LiveFoodCameraManager: NSObject, AVCapturePhotoCaptureDelegate {
    var session = AVCaptureSession()
    var capturedImage: UIImage? = nil
    var captureError: String? = nil
    var isPermissionDenied: Bool = false
    var isCameraUnavailable: Bool = false
    var isConfigured = false

    private let photoOutput = AVCapturePhotoOutput()
    private let sessionQueue = DispatchQueue(label: "com.borisdev.FoodTracker.cameraSession")
    private var shouldBeRunning = false
    private var queueConfigured = false
    private var activeDevice: AVCaptureDevice?

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
            sessionQueue.async { [weak self] in
                self?.shouldBeRunning = true
            }
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isPermissionDenied = !granted
                    if granted {
                        self.sessionQueue.async { [weak self] in
                            guard let self, self.shouldBeRunning else { return }
                            self.configureAndStartOnQueue()
                        }
                    }
                }
            }
        default:
            isPermissionDenied = true
        }
    }

    private func setupAndStart() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.shouldBeRunning = true
            self.configureAndStartOnQueue()
        }
    }

    private func configureAndStartOnQueue() {
        guard shouldBeRunning else { return }

        if queueConfigured {
            if !session.isRunning {
                session.startRunning()
            }
            return
        }

        session.beginConfiguration()
        session.sessionPreset = .photo

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let videoInput = try? AVCaptureDeviceInput(device: videoDevice),
              session.canAddInput(videoInput) else {
            session.commitConfiguration()
            DispatchQueue.main.async { [weak self] in self?.isCameraUnavailable = true }
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
            videoDevice.unlockForConfiguration()
        } catch {
            print("❌ Failed to configure camera: \(error.localizedDescription)")
        }

        session.addInput(videoInput)
        activeDevice = videoDevice

        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }

        session.commitConfiguration()
        queueConfigured = true
        DispatchQueue.main.async { [weak self] in
            self?.isConfigured = true
        }

        if shouldBeRunning {
            session.startRunning()
        }
    }

    func stop(completion: (() -> Void)? = nil) {
        sessionQueue.async { [weak self] in
            guard let self else {
                if let completion {
                    DispatchQueue.main.async { completion() }
                }
                return
            }
            self.shouldBeRunning = false
            self.updateTorchOnQueue(enabled: false)
            if self.session.isRunning {
                self.session.stopRunning()
            }
            if let completion {
                DispatchQueue.main.async { completion() }
            }
        }
    }

    func setTorch(enabled: Bool, completion: ((Bool) -> Void)? = nil) {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            let actual = self.updateTorchOnQueue(enabled: enabled)
            if let completion {
                DispatchQueue.main.async { completion(actual) }
            }
        }
    }

    @discardableResult
    private func updateTorchOnQueue(enabled: Bool) -> Bool {
        guard let device = activeDevice ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              device.hasTorch else {
            return false
        }
        guard !enabled || (device.isTorchAvailable && device.isTorchModeSupported(.on)) else {
            return false
        }
        do {
            try device.lockForConfiguration()
            defer { device.unlockForConfiguration() }
            if enabled {
                try device.setTorchModeOn(level: 1.0)
                return true
            } else {
                device.torchMode = .off
                return false
            }
        } catch {
            return false
        }
    }

    func takePhoto() {
        sessionQueue.async { [weak self] in
            guard let self, self.session.isRunning else {
                DispatchQueue.main.async { [weak self] in
                    self?.captureError = String(localized: "Camera is not ready yet. Please try again.")
                }
                return
            }
            let settings = AVCapturePhotoSettings()
            self.photoOutput.capturePhoto(with: settings, delegate: self)
        }
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        if let error {
            DispatchQueue.main.async { [weak self] in
                self?.captureError = error.localizedDescription
            }
            return
        }
        guard let data = photo.fileDataRepresentation(), let rawImage = UIImage(data: data) else {
            DispatchQueue.main.async { [weak self] in
                self?.captureError = String(localized: "Could not read captured photo. Please try again.")
            }
            return
        }

        let downsampled = VertexAIManager.downsampledImage(rawImage, maxDimension: 1280)
        DispatchQueue.main.async { [weak self] in
            self?.capturedImage = downsampled
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
    var onLogDish: ((FoodItem) -> Void)? = nil
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
                    MenuRecCard(rec: response.ideal, type: "Ideal Match", icon: "checkmark.seal.fill", color: .green, onLogDish: onLogDish)
                    MenuRecCard(rec: response.caution, type: "Caution", icon: "exclamationmark.triangle.fill", color: .orange, onLogDish: onLogDish)
                    MenuRecCard(rec: response.avoid, type: "Avoid", icon: "xmark.octagon.fill", color: .red, onLogDish: onLogDish)
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
    var onLogDish: ((FoodItem) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).foregroundColor(color)
                Text(LocalizedStringKey(type)).font(.caption.bold()).foregroundColor(color).textCase(.uppercase)
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
                if let fats = rec.fats, fats > 0 {
                    Text("• F: \(Int(fats))g").font(.caption).foregroundColor(.gray)
                }
                if let carbs = rec.carbs, carbs > 0 {
                    Text("• C: \(Int(carbs))g").font(.caption).foregroundColor(.gray)
                }
                Spacer()
                if let onLogDish {
                    Button(action: {
                        HapticManager.shared.impact(style: .medium)
                        let item = FoodItem(
                            name: rec.dishName,
                            weight: 250.0,
                            calories: rec.estimatedCalories,
                            protein: rec.protein,
                            fats: rec.fats ?? 0,
                            carbs: rec.carbs ?? 0
                        )
                        onLogDish(item)
                    }) {
                        Label("Log Dish", systemImage: "plus.circle.fill")
                            .font(.caption.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(color)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
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
