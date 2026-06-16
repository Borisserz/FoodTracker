import SwiftUI
import PhotosUI

struct BeforeAfterView: View {
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
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Visual Progress")
                    .font(.headline)
                
                Spacer()
                
                if beforeImage != nil || afterImage != nil {
                    Button("Reset") {
                        withAnimation {
                            beforeItem = nil
                            afterItem = nil
                            beforeImage = nil
                            afterImage = nil
                            sliderPosition = 0.5
                            isAnalyzing = false
                            hasAnalyzed = false
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
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.03), radius: 10, y: 5)
        .onChange(of: beforeImage) { _, newValue in
            if newValue != nil && afterImage != nil {
                triggerAnalysis()
            }
        }
        .onChange(of: afterImage) { _, newValue in
            if newValue != nil && beforeImage != nil {
                triggerAnalysis()
            }
        }
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
                
                // 3. Laser Scanner Animation
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
                            label: String(localized: "Progress Pace"),
                            value: "Optimal",
                            desc: String(localized: "Safe & steady"),
                            icon: "speedometer",
                            color: .green
                        )
                        
                        AIVisualInsightCard(
                            label: String(localized: "Muscle Tone"),
                            value: "Enhanced",
                            desc: String(localized: "Visible definition"),
                            icon: "figure.strengthtraining.traditional",
                            color: themeManager.current.primaryAccent
                        )
                        
                        AIVisualInsightCard(
                            label: String(localized: "Posture Symmetry"),
                            value: "Improved",
                            desc: String(localized: "Better alignment"),
                            icon: "figure.mind.and.body",
                            color: .cyan
                        )
                        
                        AIVisualInsightCard(
                            label: String(localized: "Trajectory"),
                            value: "On Track",
                            desc: String(localized: "Hitting visual goals"),
                            icon: "target",
                            color: .orange
                        )
                    }
                    
                    HStack(spacing: 12) {
                        FakeMetricCard(title: String(localized: "Est. Body Fat"), value: "-2.4%", isPositive: true)
                        FakeMetricCard(title: String(localized: "Est. Weight"), value: "-1.8 kg", isPositive: true)
                        FakeMetricCard(title: String(localized: "Muscle Mass"), value: "+0.5 kg", isPositive: true)
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
}

// MARK: - Premium UI Components

struct AIVisualInsightCard: View {
    let label: String
    let value: String
    let desc: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                    .padding(6)
                    .background(color.opacity(0.15))
                    .clipShape(Circle())
                
                Text(label)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(.gray)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(desc)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.gray.opacity(0.8))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.gray.opacity(0.04))
        .cornerRadius(16)
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

struct AIPerceptionFeedbackCard: View {
    @State private var displayedText: String = ""
    @State private var currentIndex: String.Index?
    
    private let fullText = "Based on the visual comparison, your rate of body recomposition is optimal. There is a noticeable enhancement in muscle definition and a visible improvement in posture alignment. This pace of visual change is highly sustainable and indicates that your current caloric deficit and protein intake are perfectly dialed in. Keep following your current protocol."
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AI Perception Feedback:")
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
            startTypewriter()
        }
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

struct FakeMetricCard: View {
    let title: String
    let value: String
    let isPositive: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
            
            HStack(spacing: 4) {
                Image(systemName: isPositive ? "arrow.down.right" : "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                Text(value)
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
            }
            .foregroundColor(isPositive ? .green : .red)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(Color.gray.opacity(0.04))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}
