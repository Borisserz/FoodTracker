import SwiftUI

struct ShareSheetManager {
    
    @MainActor
    static func renderAndShare<V: View>(view: V, title: String) {
        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
        renderer.scale = UIScreen.main.scale
        
        guard let image = renderer.uiImage else { return }
        
        // Present share sheet
        let activityVC = UIActivityViewController(
            activityItems: [image],
            applicationActivities: nil
        )
        
        // Find top most view controller on the active window scene
        let windowScene = (UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive } as? UIWindowScene)
            ?? (UIApplication.shared.connectedScenes.first as? UIWindowScene)
        if let windowScene,
           let rootVC = (windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first)?.rootViewController {
            
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            
            // Required for iPad
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            topVC.present(activityVC, animated: true)
        }
    }
}
