import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
class ProfileViewModel {
    private let summaryRepository: SummaryRepositoryProtocol
    private let userRepository: UserRepositoryProtocol

    var currentStreak: Int = 0

    init(summaryRepository: SummaryRepositoryProtocol, userRepository: UserRepositoryProtocol) {
        self.summaryRepository = summaryRepository
        self.userRepository = userRepository
    }

    func loadData() {
        Task {
            do {
                self.currentStreak = try await summaryRepository.calculateCurrentStreak()
            } catch {
                print("Failed to calculate streak: \(error)")
            }
        }
    }
}
