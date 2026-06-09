import CoreMotion
import SwiftUI

@Observable
final class MotionManager {
    static let shared = MotionManager()
    private let manager = CMMotionManager()
    
    var pitch: Double = 0.0
    var roll: Double = 0.0
    
    private init() {
        if manager.isDeviceMotionAvailable {
            manager.deviceMotionUpdateInterval = 1/60
            manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
                guard let motion = motion else { return }
                // Smooth the values slightly
                self?.pitch = motion.attitude.pitch
                self?.roll = motion.attitude.roll
            }
        }
    }
    
    func stop() {
        manager.stopDeviceMotionUpdates()
    }
}
