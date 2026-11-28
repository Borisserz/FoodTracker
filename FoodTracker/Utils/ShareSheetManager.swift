import SwiftUI
import LinkPresentation

private final class ShareCardActivityItem: NSObject, UIActivityItemSource {
    let image: UIImage
    let title: String

    init(image: UIImage, title: String) {
        self.image = image
        self.title = title
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        image
    }

    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        image
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = title
        metadata.iconProvider = NSItemProvider(object: image)
        return metadata
    }
}

struct ShareSheetManager {
    
    @MainActor
    static func renderAndShare<V: View>(view: V, title: String) {
        let windowScene = (UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive } as? UIWindowScene)
            ?? (UIApplication.shared.connectedScenes.first as? UIWindowScene)

        let renderer = ImageRenderer(content: view.environment(\.colorScheme, .dark))
        renderer.scale = windowScene?.screen.scale ?? 3.0
        
        guard let image = renderer.uiImage else { return }
        
        // Present share sheet
        let activityVC = UIActivityViewController(
            activityItems: [ShareCardActivityItem(image: image, title: title)],
            applicationActivities: nil
        )
        
        // Find top most view controller on the active window scene
        if let windowScene,
           let rootVC = (windowScene.windows.first(where: { $0.isKeyWindow }) ?? windowScene.windows.first)?.rootViewController {
            
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }
            
            // Required for iPad
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = topVC.view
                popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            topVC.present(activityVC, animated: true)
        }
    }
}
