//
//  SmartScannerView.swift
//  FoodTracker
//
//  Created by Boris Serzhanovich on 15.04.26.
//

import SwiftUI
import AVFoundation
import VisionKit

struct SmartScannerView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var recognizedBarcode: String? = nil
    @State private var isScanning: Bool = false
    @State private var isFlashlightOn: Bool = false
    @State private var selectedMode: ScannerMode = .barcode
    var onProductFound: (FoodItem) -> Void
    // Стейты для загрузки из сети
    @State private var isLoading: Bool = false
    @State private var notFoundError: Bool = false
    
    enum ScannerMode { case barcode, mealAI }
    
    var body: some View {
        ZStack {
            // 1. КАМЕРА
            if DataScannerViewController.isSupported && DataScannerViewController.isAvailable {
                DataScannerRepresentable(recognizedBarcode: $recognizedBarcode, isScanning: $isScanning)
                    .ignoresSafeArea()
            } else {
                Color.black.ignoresSafeArea()
            }
            
            // 2. ИДЕАЛЬНАЯ МАСКА С ВЫРЕЗОМ
            Color.black.opacity(0.65)
                .ignoresSafeArea()
                .mask(
                    // Используем eoFill (Even-Odd), чтобы "продырявить" центр
                    Rectangle()
                        .overlay(
                            RoundedRectangle(cornerRadius: 24)
                                .frame(width: 250, height: 250)
                        )
                        .compositingGroup()
                        .luminanceToAlpha()
                )
            
            // 3. UI ПОВЕРХ
            VStack {
                // Шапка
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
                
                // РАМКА СКАНЕРА
                ZStack {
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(Color.white, lineWidth: 2)
                        .frame(width: 250, height: 250)
                    
                    // Анимация загрузки
                    if isLoading {
                        VStack(spacing: 12) {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(1.5)
                            Text("Searching Database...")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    } else if notFoundError {
                        VStack(spacing: 8) {
                            Image(systemName: "exclamationmark.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundColor(.themeOrange)
                            Text("Product not found")
                                .font(.headline)
                                .foregroundColor(.white)
                        }
                    }
                }
                
                Spacer()
                
                // НИЖНЯЯ ПАНЕЛЬ
                VStack(spacing: 24) {
                    ScannerModePicker(selectedMode: $selectedMode)
                    
                    HStack {
                        FloatingActionButton(icon: "pencil") {
                            // Ручной ввод
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
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { isScanning = true }
        }
        .onDisappear {
            isScanning = false
            if isFlashlightOn { toggleFlashlight() }
        }
        // МАГИЯ ЗДЕСЬ: Когда нашли штрихкод, идем в интернет
        .onChange(of: recognizedBarcode) { _, newValue in
            if let code = newValue {
                searchProduct(barcode: code)
            }
        }
    }
    
    private func toggleFlashlight() {
        guard let device = AVCaptureDevice.default(for: .video), device.hasTorch else { return }
        do {
            try device.lockForConfiguration()
            isFlashlightOn.toggle()
            device.torchMode = isFlashlightOn ? .on : .off
            device.unlockForConfiguration()
        } catch {}
    }
    
    // ФУНКЦИЯ ПОИСКА ПРОДУКТА
    private func searchProduct(barcode: String) {
        isLoading = true
        notFoundError = false
        HapticManager.shared.impact(style: .medium)
        Task {
                   if let product = await NetworkManager.shared.fetchProduct(barcode: barcode) {
                       // ПРИ УСПЕХЕ:
                       await MainActor.run {
                           isLoading = false
                           dismiss() // 1. Закрываем сканер
                           
                           // 2. Ждем долю секунды, чтобы сканер успел уехать вниз,
                           // и передаем продукт на главный экран
                           DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                               onProductFound(product)
                           }
                       }
                   } else {
                print("❌ ПРОДУКТ НЕ НАЙДЕН В БАЗЕ")
                isLoading = false
                notFoundError = true
                
                // Через 2 секунды снова запускаем сканер
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    notFoundError = false
                    recognizedBarcode = nil
                    isScanning = true
                }
            }
        }
    }
}

// MARK: - ВСПОМОГАТЕЛЬНЫЕ UI КОМПОНЕНТЫ

// 1. Хитрый слой: Темный экран с "прорезанным" прозрачным квадратом
struct ScannerOverlayMask: View {
    var body: some View {
        Rectangle()
            .fill(Color.black.opacity(0.6))
            .ignoresSafeArea()
            // .reverseMask вырезает фигуру из фона
            .reverseMask {
                RoundedRectangle(cornerRadius: 24)
                    .frame(width: 250, height: 250)
            }
    }
}

// 2. Красивый переключатель режимов в стиле Apple
struct ScannerModePicker: View {
    @Binding var selectedMode: SmartScannerView.ScannerMode
    
    var body: some View {
        HStack(spacing: 0) {
            ModeButton(title: "Barcode", isActive: selectedMode == .barcode) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedMode = .barcode
                }
            }
            
            ModeButton(title: "Meal AI", isActive: selectedMode == .mealAI) {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedMode = .mealAI
                }
            }
        }
        .padding(4)
        .background(Color.black.opacity(0.4))
        .clipShape(Capsule())
    }
}

// Кнопка для переключателя
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
                // Зеленый цвет для активного Barcode, как на твоем скрине (либо можно Color.themePink)
                .foregroundColor(isActive ? .green : .white.opacity(0.7))
                .padding(.vertical, 10)
                .padding(.horizontal, 20)
                .background(
                    Capsule()
                        .fill(isActive ? Color(white: 0.2) : Color.clear)
                )
        }
    }
}

// 3. Плавающая круглая кнопка
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

// Расширение для "вырезания" дырки (Reverse Mask)
extension View {
    @inlinable
    public func reverseMask<Mask: View>(
        @ViewBuilder _ mask: () -> Mask
    ) -> some View {
        self.mask(
            ZStack {
                Rectangle()
                mask()
                    .blendMode(.destinationOut)
            }
        )
    }
}
