import CoreMotion
import SwiftUI

@Observable
final class MotionManager {
    static let shared = MotionManager()
    private let manager = CMMotionManager()
    private(set) var activeConsumerCount: Int = 0
    
    var pitch: Double = 0.0
    var roll: Double = 0.0
    
    private init() {}
    
    /// Starts 60Hz CoreMotion updates on demand using reference counting so hardware sensors pause outside active views.
    func start() {
        activeConsumerCount += 1
        guard activeConsumerCount == 1 else { return }
        guard manager.isDeviceMotionAvailable else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 60.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion = motion else { return }
            // Smooth the values slightly
            self?.pitch = motion.attitude.pitch
            self?.roll = motion.attitude.roll
        }
    }
    
    /// Releases one consumer and stops CoreMotion hardware polling once no consumers remain.
    func stop() {
        guard activeConsumerCount > 0 else { return }
        activeConsumerCount -= 1
        guard activeConsumerCount == 0 else { return }
        manager.stopDeviceMotionUpdates()
        pitch = 0.0
        roll = 0.0
    }
    
    /// Immediately clears all consumers and stops device motion updates.
    func resetForTesting() {
        activeConsumerCount = 0
        manager.stopDeviceMotionUpdates()
        pitch = 0.0
        roll = 0.0
    }
}
