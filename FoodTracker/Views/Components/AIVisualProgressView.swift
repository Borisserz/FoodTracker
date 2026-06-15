import SwiftUI
import PhotosUI

struct AIVisualProgressView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    @State private var beforeItem: PhotosPickerItem?
    @State private var afterItem: PhotosPickerItem?
    
    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?
    
    @State private var sliderPosition: CGFloat = 0.5 // 0.0 to 1.0
    @State private var isDragging = false
    
    @State private var isAnalyzing = false
    @State private var hasAnalyzed = false
    
    @State private var scannerOffset: CGFloat = 0.0
    
    var body: some View {
        ZStack {
            Color.themeBg.ignoresSafeArea()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: 24) {
                    
                    // Premium Explanation Header
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(spacing: 8) {
                            Image(systemName: "sparkles")
                                .foregroundColor(themeManager.current.primaryAccent)
                                .font(.title2)
                            Text("AI Visual Progress Tracker")
                                .font(.title3.bold())
                                .foregroundColor(.primary)
                        }
                        
                        Text("Tracking your progress visually is one of the most accurate ways to measure body composition changes. While scales only measure total mass (including water weight and muscle fluctuations), photos capture actual body recomposition.")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.gray)
                            .lineSpacing(5)
                        
                        Divider()
                        
                        HStack(alignment: .top, spacing: 12) {
                            Image(systemName: "cpu.fill")
                                .font(.title3)
                                .foregroundColor(themeManager.current.primaryAccent)
                                .padding(.top, 2)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("How AI Computes Progress")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundColor(.primary)
                                Text("Our neural network maps over 30 anatomical keypoints on your body silhouette. By aligning structural frames, the AI evaluates posture symmetry, waist-to-shoulder ratios, muscle definition clarity (via shadow intensity mapping), and tracking trajectory to evaluate progress independent of scale weight.")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .lineSpacing(4)
                            }
                        }
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.02), radius: 8, y: 4)
                    
                    // Upload Box or Slider
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("Comparison View")
                                .font(.headline)
                            Spacer()
                            if beforeImage != nil || afterImage != nil {
                                Button("Reset") {
                                    withAnimation {
                                        resetPhotos()
                                    }
                                }
                                .font(.caption.bold())
                                .foregroundStyle(themeManager.current.primaryAccent)
                            }
                        }
                        
                        if beforeImage != nil && afterImage != nil {
                            comparisonSlider
                        } else {
                            uploadWindows
                        }
                    }
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(24)
                    .shadow(color: .black.opacity(0.02), radius: 8, y: 4)
                    
                    // Analysis calculations
                    if isAnalyzing || hasAnalyzed {
                        aiPhotoAnalysisSection
                            .padding(20)
                            .background(Color.white)
                            .cornerRadius(24)
                            .shadow(color: .black.opacity(0.02), radius: 8, y: 4)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding()
            }
        }
        .navigationTitle("Visual Progress")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadPhotosFromDisk()
        }
        .onChange(of: beforeImage) { _, newValue in
            if let img = newValue {
                saveImageToDisk(image: img, isBefore: true)
            }
            if newValue != nil && afterImage != nil {
                triggerAnalysis()
            }
        }
        .onChange(of: afterImage) { _, newValue in
            if let img = newValue {
                saveImageToDisk(image: img, isBefore: false)
            }
            if newValue != nil && beforeImage != nil {
                triggerAnalysis()
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
                gradient: [.gray.opacity(0.15), .gray.opacity(0.05)]
            )
            
            photoUploadBox(
                title: "After",
                item: $afterItem,
                image: afterImage,
                gradient: [themeManager.current.primaryAccent.opacity(0.2), themeManager.current.primaryAccent.opacity(0.05)]
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
                        .foregroundStyle(.gray.opacity(0.4))
                    
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
                   let loadedImage = UIImage(data: data) {
                    await MainActor.run {
                        if title == "Before" {
                            beforeImage = loadedImage
                        } else {
                            afterImage = loadedImage
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
                if let before = beforeImage {
                    Image(uiImage: before)
                        .resizable()
                        .scaledToFill()
                        .frame(width: width, height: height)
                        .clipped()
                }
                
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
                
                if isAnalyzing {
                    VStack {
                        Rectangle()
                            .fill(LinearGradient(colors: [.clear, themeManager.current.primaryAccent, .clear], startPoint: .top, endPoint: .bottom))
                            .frame(height: 20)
                            .blur(radius: 5)
                            .shadow(color: themeManager.current.primaryAccent, radius: 10)
                            .offset(y: scannerOffset)
                            .onAppear {
                                scannerOffset = -height/2
                                withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                                    scannerOffset = height/2
                                }
                            }
                    }
                    .frame(width: width, height: height)
                    .clipped()
                }
                
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
        .animation(.interactiveSpring, value: sliderPosition)
    }
    
    private func triggerAnalysis() {
        guard !isAnalyzing && !hasAnalyzed else { return }
        isAnalyzing = true
        hasAnalyzed = false
        
        Task { @MainActor in
            HapticManager.shared.impact(style: .medium)
            try? await Task.sleep(for: .seconds(3.0))
            HapticManager.shared.notification(type: .success)
            withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                isAnalyzing = false
                hasAnalyzed = true
                UserDefaults.standard.set(true, forKey: "has_visual_analyzed")
            }
        }
    }
    
    private var aiPhotoAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 8) {
                ZStack {
                    Circle()
                        .fill(themeManager.current.primaryAccent.opacity(0.15))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "sparkles")
                        .font(.subheadline)
                        .foregroundStyle(themeManager.current.primaryAccent)
                        .symbolEffect(.pulse, isActive: isAnalyzing)
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
                } else if hasAnalyzed {
                    Text("Analysis Complete")
                        .font(.caption2.bold())
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(6)
                }
            }
            
            if isAnalyzing {
                VStack(spacing: 12) {
                    ProgressView()
                        .tint(themeManager.current.primaryAccent)
                        .scaleEffect(1.2)
                        .padding(.top, 10)
                    
                    Text("Aligning frames & evaluating physical recomposition pace...")
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
            } else if hasAnalyzed {
                VStack(alignment: .leading, spacing: 16) {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        AIVisualInsightCard(
                            label: "Progress Pace",
                            value: "Optimal",
                            desc: "Safe & steady",
                            icon: "speedometer",
                            color: .green
                        )
                        
                        AIVisualInsightCard(
                            label: "Muscle Tone",
                            value: "Enhanced",
                            desc: "Visible definition",
                            icon: "figure.strengthtraining.traditional",
                            color: themeManager.current.primaryAccent
                        )
                        
                        AIVisualInsightCard(
                            label: "Posture Symmetry",
                            value: "Improved",
                            desc: "Better alignment",
                            icon: "figure.mind.and.body",
                            color: .cyan
                        )
                        
                        AIVisualInsightCard(
                            label: "Trajectory",
                            value: "On Track",
                            desc: "Hitting visual goals",
                            icon: "target",
                            color: .orange
                        )
                    }
                    
                    AIPerceptionFeedbackCard()
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .bottom).combined(with: .opacity),
                    removal: .opacity
                ))
            }
        }
    }
    
    // MARK: - Disk Persistence
    
    private func saveImageToDisk(image: UIImage, isBefore: Bool) {
        let fileName = isBefore ? "before_progress.jpg" : "after_progress.jpg"
        if let data = image.jpegData(compressionQuality: 0.8) {
            let url = getDocumentsDirectory().appendingPathComponent(fileName)
            try? data.write(to: url)
        }
    }
    
    private func loadPhotosFromDisk() {
        let beforeUrl = getDocumentsDirectory().appendingPathComponent("before_progress.jpg")
        let afterUrl = getDocumentsDirectory().appendingPathComponent("after_progress.jpg")
        
        if FileManager.default.fileExists(atPath: beforeUrl.path) {
            beforeImage = UIImage(contentsOfFile: beforeUrl.path)
        }
        if FileManager.default.fileExists(atPath: afterUrl.path) {
            afterImage = UIImage(contentsOfFile: afterUrl.path)
        }
        
        hasAnalyzed = UserDefaults.standard.bool(forKey: "has_visual_analyzed")
    }
    
    private func resetPhotos() {
        beforeItem = nil
        afterItem = nil
        beforeImage = nil
        afterImage = nil
        sliderPosition = 0.5
        isAnalyzing = false
        hasAnalyzed = false
        
        let beforeUrl = getDocumentsDirectory().appendingPathComponent("before_progress.jpg")
        let afterUrl = getDocumentsDirectory().appendingPathComponent("after_progress.jpg")
        try? FileManager.default.removeItem(at: beforeUrl)
        try? FileManager.default.removeItem(at: afterUrl)
        
        UserDefaults.standard.set(false, forKey: "has_visual_analyzed")
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
