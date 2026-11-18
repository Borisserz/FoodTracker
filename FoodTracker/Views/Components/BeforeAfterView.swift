import SwiftUI
import SwiftData
import PhotosUI

enum BeforeAfterStorage {
    private static let analysisDefaultsKey = "beforeAfterAnalysis_v1"

    private static var storageDirectory: URL? {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("BeforeAfterPhotos", isDirectory: true)
    }

    static func saveImage(_ image: UIImage, slot: String) {
        guard let dir = storageDirectory else { return }
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("\(slot).jpg")
        let normalized = VertexAIManager.downsampledImage(image, maxDimension: 1600)
        if let data = normalized.jpegData(compressionQuality: 0.8) {
            try? data.write(to: url, options: .atomic)
        }
    }

    static func loadImage(slot: String) -> UIImage? {
        guard let url = storageDirectory?.appendingPathComponent("\(slot).jpg"),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    static func saveAnalysis(_ analysis: VertexAIManager.TransformationAnalysisDTO) {
        if let encoded = try? JSONEncoder().encode(analysis) {
            UserDefaults.standard.set(encoded, forKey: analysisDefaultsKey)
        }
    }

    static func loadAnalysis() -> VertexAIManager.TransformationAnalysisDTO? {
        guard let data = UserDefaults.standard.data(forKey: analysisDefaultsKey) else { return nil }
        return try? JSONDecoder().decode(VertexAIManager.TransformationAnalysisDTO.self, from: data)
    }

    static func clearAll() {
        UserDefaults.standard.removeObject(forKey: analysisDefaultsKey)
        if let dir = storageDirectory {
            try? FileManager.default.removeItem(at: dir)
        }
    }
}

struct BeforeAfterView: View {
    @Environment(ThemeManager.self) private var themeManager
    @Query private var users: [User]

    @State private var beforeItem: PhotosPickerItem?
    @State private var afterItem: PhotosPickerItem?

    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?

    @State private var sliderPosition: CGFloat = 0.5 // 0.0 to 1.0
    @State private var isDragging = false

    @State private var isAnalyzing = false
    @State private var analysisResult: VertexAIManager.TransformationAnalysisDTO?
    @State private var analysisError: String?
    @State private var didRestorePersisted = false
    @State private var analysisTask: Task<Void, Never>?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Visual Progress")
                    .font(.headline)
                
                Spacer()
                
                if beforeImage != nil || afterImage != nil {
                    Button("Reset") {
                        analysisTask?.cancel()
                        analysisTask = nil
                        withAnimation {
                            beforeItem = nil
                            afterItem = nil
                            beforeImage = nil
                            afterImage = nil
                            sliderPosition = 0.5
                            isAnalyzing = false
                            analysisResult = nil
                            analysisError = nil
                            BeforeAfterStorage.clearAll()
                        }
                    }
                    .font(.caption.bold())
                    .foregroundStyle(themeManager.current.primaryAccent)
                }
            }
            .padding(.horizontal, 4)
            
            if beforeImage != nil && afterImage != nil {
                // Interactive Slider View
                comparisonSlider
                
                // AI Photo Analysis View
                aiPhotoAnalysisSection
            } else {
                // Upload Windows
                uploadWindows
            }
        }
        .padding()
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.ultraThinMaterial)
                
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [
                                .white.opacity(0.25),
                                .white.opacity(0.05)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            }
            .shadow(color: .black.opacity(0.04), radius: 10, y: 4)
        }
        .onAppear {
            guard !didRestorePersisted else { return }
            beforeImage = BeforeAfterStorage.loadImage(slot: "before")
            afterImage = BeforeAfterStorage.loadImage(slot: "after")
            analysisResult = BeforeAfterStorage.loadAnalysis()
            didRestorePersisted = true
        }
        .onChange(of: beforeImage) { oldValue, newValue in
            guard didRestorePersisted, let newValue else { return }
            guard oldValue !== newValue else { return }
            BeforeAfterStorage.saveImage(newValue, slot: "before")
            analysisResult = nil
            if afterImage != nil {
                triggerAnalysis(force: true)
            }
        }
        .onChange(of: afterImage) { oldValue, newValue in
            guard didRestorePersisted, let newValue else { return }
            guard oldValue !== newValue else { return }
            BeforeAfterStorage.saveImage(newValue, slot: "after")
            analysisResult = nil
            if beforeImage != nil {
                triggerAnalysis(force: true)
            }
        }
    }
    
    // MARK: - Upload Windows
    
    private var uploadWindows: some View {
        HStack(spacing: 16) {
            photoUploadBox(
                title: "Before",
                item: $beforeItem,
                image: beforeImage,
                gradient: [.gray.opacity(0.3), .gray.opacity(0.1)]
            )
            
            photoUploadBox(
                title: "After",
                item: $afterItem,
                image: afterImage,
                gradient: [themeManager.current.primaryAccent.opacity(0.3), themeManager.current.primaryAccent.opacity(0.1)]
            )
        }
        .frame(height: 200)
    }
    
    private func photoUploadBox(title: String, item: Binding<PhotosPickerItem?>, image: UIImage?, gradient: [Color]) -> some View {
        PhotosPicker(selection: item, matching: .images, photoLibrary: .shared()) {
            ZStack {
                RoundedRectangle(cornerRadius: 16)
                    .fill(LinearGradient(colors: gradient, startPoint: .topLeading, endPoint: .bottomTrailing))
                
                if let uiImage = image {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    
                    // Overlay edit icon
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Image(systemName: "pencil.circle.fill")
                                .font(.title)
                                .foregroundStyle(.white)
                                .shadow(radius: 4)
                                .padding(8)
                        }
                    }
                } else {
                    RoundedRectangle(cornerRadius: 16)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .foregroundStyle(.gray.opacity(0.5))
                    
                    VStack(spacing: 12) {
                        Image(systemName: "photo.badge.plus")
                            .font(.system(size: 32))
                        Text(title)
                            .font(.headline)
                    }
                    .foregroundStyle(.gray)
                }
            }
        }
        .buttonStyle(.plain)
        .onChange(of: item.wrappedValue) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let rawImage = UIImage(data: data) {
                    let downsampled = await Task.detached(priority: .userInitiated) {
                        VertexAIManager.downsampledImage(rawImage, maxDimension: 1600)
                    }.value
                    await MainActor.run {
                        if title == "Before" {
                            beforeImage = downsampled
                        } else {
                            afterImage = downsampled
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Comparison Slider
    
    private var comparisonSlider: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let dividerX = width * sliderPosition
            
            ZStack(alignment: .leading) {
                // 1. Before Image (Background)
                if let before = beforeImage {
                    Image(uiImage: before)
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: height)
                        .clipped()
                }
                
                // 2. After Image (Foreground, Masked)
                if let after = afterImage {
                    Image(uiImage: after)
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: height)
                        .clipped()
                        .mask(
                            HStack(spacing: 0) {
                                Rectangle().frame(width: dividerX)
                                Spacer(minLength: 0)
                            }
                        )
                }
                
                // 3. Labels
                VStack {
                    HStack {
                        Text("Before")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                            .opacity(sliderPosition > 0.2 ? 1 : 0)
                        
                        Spacer()
                        
                        Text("After")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                            .opacity(sliderPosition < 0.8 ? 1 : 0)
                    }
                    .padding(12)
                    Spacer()
                }
                
                // 4. Slider Handle and Line
                ZStack {
                    Rectangle()
                        .fill(Color.white)
                        .frame(width: 4, height: height)
                        .shadow(radius: 2)
                    
                    Circle()
                        .fill(Color.white)
                        .frame(width: 40, height: 40)
                        .shadow(radius: 4)
                        .overlay(
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Image(systemName: "chevron.right")
                            }
                            .font(.caption.bold())
                            .foregroundStyle(themeManager.current.primaryAccent)
                        )
                }
                .position(x: dividerX, y: height / 2)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            isDragging = true
                            let newPos = value.location.x / width
                            sliderPosition = min(max(newPos, 0), 1)
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
            .cornerRadius(16)
        }
        .frame(height: 350)
        .animation(isDragging ? nil : .interactiveSpring, value: sliderPosition)
    }
    
    private func triggerAnalysis(force: Bool = false) {
        if force {
            analysisTask?.cancel()
            analysisTask = nil
            isAnalyzing = false
        }
        guard !isAnalyzing else { return }
        if !force && analysisResult != nil { return }
        guard let before = beforeImage, let after = afterImage else { return }

        isAnalyzing = true
        analysisError = nil
        let goal = users.first?.weightGoalType

        analysisTask = Task {
            HapticManager.shared.impact(style: .medium)
            do {
                let result = try await VertexAIManager.shared.analyzeBeforeAfterPhotos(
                    before: before,
                    after: after,
                    goal: goal
                )
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    BeforeAfterStorage.saveAnalysis(result)
                    HapticManager.shared.notification(type: .success)
                    withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                        isAnalyzing = false
                        analysisResult = result
                    }
                }
            } catch {
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    HapticManager.shared.notification(type: .error)
                    withAnimation {
                        isAnalyzing = false
                        analysisError = String(localized: "Couldn't analyze these photos right now. Check your connection and try again.")
                    }
                }
            }
        }
    }

    private var aiPhotoAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Divider()
                .background(themeManager.current.primaryAccent.opacity(0.15))
                .padding(.vertical, 4)

            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(themeManager.current.primaryAccent.opacity(0.15))
                        .frame(width: 32, height: 32)

                    Image(systemName: "sparkles")
                        .font(.subheadline)
                        .foregroundStyle(themeManager.current.primaryAccent)
                }

                Text("AI Fitness Scanner")
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)

                Spacer()

                if isAnalyzing {
                    Text("Scanning...")
                        .font(.caption2.bold())
                        .foregroundStyle(themeManager.current.primaryAccent)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(themeManager.current.primaryAccent.opacity(0.1))
                        .cornerRadius(6)
                } else if analysisResult != nil {
                    Button {
                        triggerAnalysis(force: true)
                    } label: {
                        Label("Re-analyze", systemImage: "arrow.clockwise")
                            .font(.caption2.bold())
                            .foregroundStyle(.green)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }

            if isAnalyzing {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(themeManager.current.primaryAccent)
                        .scaleEffect(1.2)
                        .padding(.top, 10)

                    Text("Comparing posture, lighting, and visual composition...")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color.gray.opacity(0.03))
                .cornerRadius(16)
                .transition(.opacity)
            } else if let error = analysisError {
                VStack(spacing: 12) {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Button("Retry Analysis") {
                        triggerAnalysis(force: true)
                    }
                    .font(.caption.bold())
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(themeManager.current.primaryAccent.opacity(0.15))
                    .foregroundStyle(themeManager.current.primaryAccent)
                    .cornerRadius(10)
                }
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.red.opacity(0.05))
                .cornerRadius(14)
            } else if let result = analysisResult {
                VStack(alignment: .leading, spacing: 16) {
                    if !result.metrics.isEmpty {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(result.metrics.prefix(4)) { metric in
                                MetricDeltaCard(
                                    label: metric.label,
                                    delta: metric.value,
                                    desc: metric.detail,
                                    color: metric.isPositive ? .green : themeManager.current.primaryAccent,
                                    isLoss: !metric.isPositive
                                )
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("AI Feedback:")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)

                        Text(result.feedback)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.gray)
                            .lineSpacing(3)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .background(Color.gray.opacity(0.04))
                    .cornerRadius(14)
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
    }
}

struct MetricDeltaCard: View {
    let label: String
    let delta: String
    let desc: String
    let color: Color
    let isLoss: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.gray)
            
            HStack(alignment: .bottom, spacing: 4) {
                Text(delta)
                    .font(.system(size: 20, weight: .black, design: .rounded))
                    .foregroundColor(isLoss ? .orange : .green)
                
                Image(systemName: isLoss ? "arrow.down.forward" : "arrow.up.forward")
                    .font(.caption2.bold())
                    .foregroundColor(isLoss ? .orange : .green)
                    .padding(.bottom, 3)
            }
            
            Text(desc)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.gray.opacity(0.8))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.gray.opacity(0.03))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isLoss ? Color.orange.opacity(0.15) : Color.green.opacity(0.15), lineWidth: 1)
        )
    }
}


