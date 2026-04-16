//
//  BarcodeScannerController.swift
//  FoodTracker
//
//  Created by Boris Serzhanovich on 15.04.26.
//

import SwiftUI
import VisionKit

// Обертка для нативного сканера Apple
struct DataScannerRepresentable: UIViewControllerRepresentable {
    @Binding var recognizedBarcode: String?
    @Binding var isScanning: Bool

    func makeUIViewController(context: Context) -> DataScannerViewController {
        // Настраиваем: ищем только штрих-коды (EAN, QR и т.д.)
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode()],
            qualityLevel: .fast,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: true,
            isHighlightingEnabled: true // Apple сама красиво подсветит найденный код
        )
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {
        if isScanning {
            try? uiViewController.startScanning()
        } else {
            uiViewController.stopScanning()
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // "Посыльный", который ловит штрих-код и передает нам
    class Coordinator: NSObject, DataScannerViewControllerDelegate {
        var parent: DataScannerRepresentable

        init(_ parent: DataScannerRepresentable) {
            self.parent = parent
        }

        func dataScanner(_ dataScanner: DataScannerViewController, didAdd addedItems: [RecognizedItem], allItems: [RecognizedItem]) {
            for item in addedItems {
                if case .barcode(let barcode) = item {
                    guard let payload = barcode.payloadStringValue else { continue }
                    
                    // Как только поймали код, вибрируем и передаем строку в UI
                    HapticManager.shared.impact(style: .heavy)
                    parent.recognizedBarcode = payload
                    parent.isScanning = false // Останавливаем сканирование
                }
            }
        }
    }
}
