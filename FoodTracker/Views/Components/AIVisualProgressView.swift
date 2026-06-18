import SwiftUI
import PhotosUI
import SwiftData

struct AIVisualProgressView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ThemeManager.self) private var themeManager
    
    @State private var beforeItem: PhotosPickerItem?
    @State private var afterItem: PhotosPickerItem?
    
    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?
    
    @State private var sliderPosition: CGFloat = 0.5 // 0.0 to 1.0
    @State private var isDragging = false
    @State private var hasAnalyzed = false
    
    @Query private var users: [User]
    
    @State private var beforeWeight: Double?
    @State private var afterWeight: Double?
    
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
                                Button(action: {
                                    HapticManager.shared.impact(style: .light)
                                    withAnimation {
                                        resetPhotos()
                                    }
                                }) {
                                    Text("Reset")
                                        .font(.system(size: 13, weight: .bold))
                                        .foregroundStyle(themeManager.current.primaryAccent)
                                        .padding(.vertical, 6)
                                        .padding(.horizontal, 14)
                                        .background(themeManager.current.primaryAccent.opacity(0.15))
                                        .cornerRadius(12)
                                }
                                .buttonStyle(.plain)
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
                    if beforeImage != nil && afterImage != nil {
                        weightAnalysisSection
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
        }
        .onChange(of: afterImage) { _, newValue in
            if let img = newValue {
                saveImageToDisk(image: img, isBefore: false)
            }
        }
        .onChange(of: beforeWeight) { _, newValue in
            if let w = newValue {
                UserDefaults.standard.set(w, forKey: "visual_before_weight")
            } else {
                UserDefaults.standard.removeObject(forKey: "visual_before_weight")
            }
        }
        .onChange(of: afterWeight) { _, newValue in
            if let w = newValue {
                UserDefaults.standard.set(w, forKey: "visual_after_weight")
            } else {
                UserDefaults.standard.removeObject(forKey: "visual_after_weight")
            }
        }
    }
    
    // MARK: - Upload Windows
    
    private var uploadWindows: some View {
        HStack(spacing: 16) {
            photoUploadBox(
                title: String(localized: "Before"),
                isBefore: true,
                item: $beforeItem,
                image: beforeImage,
                gradient: [.gray.opacity(0.15), .gray.opacity(0.05)]
            )
            
            photoUploadBox(
                title: String(localized: "After"),
                isBefore: false,
                item: $afterItem,
                image: afterImage,
                gradient: [themeManager.current.primaryAccent.opacity(0.2), themeManager.current.primaryAccent.opacity(0.05)]
            )
        }
        .frame(height: 200)
    }
    
    private func photoUploadBox(title: String, isBefore: Bool, item: Binding<PhotosPickerItem?>, image: UIImage?, gradient: [Color]) -> some View {
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
                        if isBefore {
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
                                Spacer(minLength: 0)
                                Rectangle().frame(width: width - dividerX)
                            }
                        )
                }
                
                // 3. Laser Scanner Animation Removed
                
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
    
    private var weightAnalysisSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Weight Transformation")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
            
            HStack(spacing: 16) {
                WeightEntryCard(title: String(localized: "Before Weight"), weight: $beforeWeight)
                WeightEntryCard(title: String(localized: "Current Weight"), weight: $afterWeight)
            }
            
            if let bw = beforeWeight, let aw = afterWeight {
                let diff = aw - bw
                let isPositive = diff > 0
                let trendIcon = abs(diff) < 0.1 ? "minus" : (isPositive ? "arrow.up.right" : "arrow.down.right")
                let trendColor = abs(diff) < 0.1 ? Color.gray : (isPositive ? Color.red : Color.green)
                
                VStack(spacing: 16) {
                    HStack(alignment: .center, spacing: 20) {
                        VStack(alignment: .leading) {
                            Text("Total Change")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                            HStack(spacing: 4) {
                                Image(systemName: trendIcon)
                                Text(String(format: "%+.1f kg", diff))
                            }
                            .font(.title2.bold())
                            .foregroundColor(trendColor)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 40))
                            .foregroundColor(.gray.opacity(0.2))
                    }
                    .padding()
                    .background(Color.gray.opacity(0.04))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                    )
                    
                    if let user = users.first {
                        TransformationFeedbackCard(before: bw, after: aw, dietKey: user.activeDietKey)
                    }
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
        
        if let w = UserDefaults.standard.object(forKey: "visual_before_weight") as? Double {
            beforeWeight = w
        }
        if let w = UserDefaults.standard.object(forKey: "visual_after_weight") as? Double {
            afterWeight = w
        }
        
        hasAnalyzed = UserDefaults.standard.bool(forKey: "has_visual_analyzed")
    }
    
    private func resetPhotos() {
        beforeItem = nil
        afterItem = nil
        beforeImage = nil
        afterImage = nil
        sliderPosition = 0.5
        beforeWeight = nil
        afterWeight = nil
        
        let beforeUrl = getDocumentsDirectory().appendingPathComponent("before_progress.jpg")
        let afterUrl = getDocumentsDirectory().appendingPathComponent("after_progress.jpg")
        try? FileManager.default.removeItem(at: beforeUrl)
        try? FileManager.default.removeItem(at: afterUrl)
        let beforeWeightUrl = getDocumentsDirectory().appendingPathComponent("before_weight.txt")
        let afterWeightUrl = getDocumentsDirectory().appendingPathComponent("after_weight.txt")
        try? FileManager.default.removeItem(at: beforeWeightUrl)
        try? FileManager.default.removeItem(at: afterWeightUrl)
        
        UserDefaults.standard.removeObject(forKey: "visual_before_weight")
        UserDefaults.standard.removeObject(forKey: "visual_after_weight")
    }
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
}
