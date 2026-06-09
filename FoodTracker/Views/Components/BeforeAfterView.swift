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
        .animation(.interactiveSpring, value: sliderPosition)
    }
    
    private func triggerAnalysis() {
        guard !isAnalyzing && !hasAnalyzed else { return }
        isAnalyzing = true
        hasAnalyzed = false
        
        Task { @MainActor in
            HapticManager.shared.impact(style: .medium)
            try? await Task.sleep(for: .seconds(2.5))
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
                    
                    Text("Aligning frames & estimating body fat composition...")
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
                        MetricDeltaCard(
                            label: "Waist / Abs",
                            delta: "-4.2 cm",
                            desc: "Fat Reduction",
                            color: themeManager.current.primaryAccent,
                            isLoss: true
                        )
                        
                        MetricDeltaCard(
                            label: "Shoulders / Back",
                            delta: "+1.8 cm",
                            desc: "Muscle Gained",
                            color: .green,
                            isLoss: false
                        )
                        
                        MetricDeltaCard(
                            label: "Upper Arms",
                            delta: "+0.6 cm",
                            desc: "Tone Gained",
                            color: .green,
                            isLoss: false
                        )
                        
                        MetricDeltaCard(
                            label: "Est. Body Fat",
                            delta: "-3.4%",
                            desc: "Overall Lean",
                            color: themeManager.current.primaryAccent,
                            isLoss: true
                        )
                    }
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text("AI Feedback:")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.primary)
                        
                        Text("AI analysis detected noticeable chest and shoulder hypertrophy (+1.8cm). The abdominal region shows significant tightening (-4.2cm waist), corresponding to a fat reduction of ~3.4%. Posture alignment is also visibly improved, indicating stronger core stabilization. Keep up the high-protein pacing!")
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


