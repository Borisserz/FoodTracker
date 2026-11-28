import Foundation
import SwiftData
import SwiftUI

@MainActor
@Observable
class ProfileViewModel {
    private let summaryRepository: SummaryRepositoryProtocol

    var currentStreak: Int = 0

    init(summaryRepository: SummaryRepositoryProtocol) {
        self.summaryRepository = summaryRepository
    }

    func loadData() {
        Task {
            do {
                self.currentStreak = try await summaryRepository.calculateCurrentStreak()
            } catch {
                #if DEBUG
                print("Failed to calculate streak: \(error)")
                #endif
            }
        }
    }
}
