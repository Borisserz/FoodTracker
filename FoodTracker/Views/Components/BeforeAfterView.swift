import SwiftUI
import PhotosUI
import SwiftData

struct BeforeAfterView: View {
    @Environment(ThemeManager.self) private var themeManager
    
    @State private var beforeItem: PhotosPickerItem?
    @State private var afterItem: PhotosPickerItem?
    
    @State private var beforeImage: UIImage?
    @State private var afterImage: UIImage?
    
    @State private var sliderPosition: CGFloat = 0.5 // 0.0 to 1.0
    @State private var isDragging = false
    
    @Query private var users: [User]
    
    @State private var beforeWeight: Double?
    @State private var afterWeight: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Visual Progress")
                    .font(.headline)
                
                Spacer()
                
                if beforeImage != nil || afterImage != nil {
                    Button(action: {
                        HapticManager.shared.impact(style: .light)
                        withAnimation {
                            beforeItem = nil
                            afterItem = nil
                            beforeImage = nil
                            afterImage = nil
                            sliderPosition = 0.5
                            beforeWeight = nil
                            afterWeight = nil
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
            .padding(.horizontal, 4)
            
            if beforeImage != nil && afterImage != nil {
                // Interactive Slider View
                comparisonSlider
                
                // Weight Analysis View
                weightAnalysisSection
            } else {
                // Upload Windows
                uploadWindows
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.03), radius: 10, y: 5)
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
        .onAppear {
            loadPhotosFromDisk()
        }
    }
    
    // MARK: - Disk Operations
    
    private func getDocumentsDirectory() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    private func saveImageToDisk(image: UIImage, isBefore: Bool) {
        let fileName = isBefore ? "before_progress.jpg" : "after_progress.jpg"
        let url = getDocumentsDirectory().appendingPathComponent(fileName)
        if let data = image.jpegData(compressionQuality: 0.8) {
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
        
        UserDefaults.standard.removeObject(forKey: "visual_before_weight")
        UserDefaults.standard.removeObject(forKey: "visual_after_weight")
    }
    
    // MARK: - Upload Windows
    
    private var uploadWindows: some View {
        HStack(spacing: 16) {
            photoUploadBox(
                title: String(localized: "Before"),
                item: $beforeItem,
                image: beforeImage,
                gradient: [.gray.opacity(0.3), .gray.opacity(0.1)]
            )
            
            photoUploadBox(
                title: String(localized: "After"),
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
                                Spacer(minLength: 0)
                                Rectangle().frame(width: width - dividerX)
                            }
                        )
                }
                
                // 3. Laser Scanner Animation Removed
                
                // 4. Labels
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
                
                // 5. Slider Handle and Line
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
            Divider()
                .background(themeManager.current.primaryAccent.opacity(0.15))
                .padding(.vertical, 4)
            
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
}

// MARK: - Premium UI Components

struct WeightEntryCard: View {
    let title: String
    @Binding var weight: Double?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.gray)
            
            TextField("0.0", value: $weight, format: .number)
                .keyboardType(.decimalPad)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .textFieldStyle(.plain)
                .padding(12)
                .background(Color.gray.opacity(0.04))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.gray.opacity(0.1), lineWidth: 1)
                )
        }
    }
}

struct TransformationFeedbackCard: View {
    let before: Double
    let after: Double
    let dietKey: String
    
    @State private var displayedText: String = ""
    @State private var fullText: String = ""
    @State private var currentIndex: String.Index?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Analysis:")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.primary)
            
            Text(displayedText)
                .font(.system(size: 14, weight: .medium, design: .serif))
                .foregroundColor(.gray)
                .lineSpacing(4)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(minHeight: 90, alignment: .topLeading)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial)
                .background(Color.white.opacity(0.5))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(LinearGradient(colors: [.white, .clear, .white.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1.5)
        )
        .shadow(color: Color.black.opacity(0.03), radius: 10, y: 5)
        .onAppear {
            generateText()
        }
        .onChange(of: before) { _, _ in generateText() }
        .onChange(of: after) { _, _ in generateText() }
        .onChange(of: dietKey) { _, _ in generateText() }
    }
    
    private func generateText() {
        let diff = after - before
        let dietName = dietKey.capitalized
        
        if diff < -0.1 {
            fullText = "Incredible progress! You successfully lost \(String(format: "%.1f", abs(diff))) kg. You stayed disciplined and effectively adhered to the \(dietName) diet. Keep up the excellent work!"
        } else if diff > 0.1 {
            fullText = "You gained \(String(format: "%.1f", diff)) kg. Whether it's muscle mass or part of your goals on the \(dietName) diet, your dedication is visible. Stay focused on your targets!"
        } else {
            fullText = "You maintained your weight of \(String(format: "%.1f", after)) kg. Great job sustaining your physique and sticking to your \(dietName) diet!"
        }
        
        startTypewriter()
    }
    
    private func startTypewriter() {
        displayedText = ""
        currentIndex = fullText.startIndex
        
        Timer.scheduledTimer(withTimeInterval: 0.015, repeats: true) { timer in
            guard let idx = currentIndex, idx < fullText.endIndex else {
                timer.invalidate()
                return
            }
            
            displayedText.append(fullText[idx])
            currentIndex = fullText.index(after: idx)
            
            if displayedText.count % 5 == 0 {
                HapticManager.shared.impact(style: .rigid)
            }
        }
    }
}
