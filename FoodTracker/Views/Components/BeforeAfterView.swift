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
            } else {
                // Upload Windows
                uploadWindows
            }
        }
        .padding()
        .background(Color.white)
        .cornerRadius(24)
        .shadow(color: .black.opacity(0.03), radius: 10, y: 5)
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
}


