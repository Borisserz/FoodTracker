import Foundation
import SwiftData
import Observation

@Observable
final class DIContainer: @unchecked Sendable {
    let modelContainer: ModelContainer
    let appState: AppStateManager
    let authManager: AuthManager

    // Services
    let networkService: NetworkManager
    let healthKitService: HealthKitManager
    let fastingService: FastingManager
    let vertexAIService: VertexAIManager

    // Repositories
    let userRepository: UserRepositoryProtocol
    let summaryRepository: SummaryRepositoryProtocol

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        self.appState = AppStateManager()
        self.authManager = AuthManager()

        // Initialize Services (using their shared instances or instantiating them here)
        self.networkService = NetworkManager.shared
        self.healthKitService = HealthKitManager.shared
        self.fastingService = FastingManager.shared
        self.vertexAIService = VertexAIManager.shared

        // Initialize Repositories
        self.userRepository = UserRepository(modelContainer: modelContainer)
        self.summaryRepository = SummaryRepository(modelContainer: modelContainer)
    }

    @MainActor
    func makeAICoachViewModel() -> AICoachViewModel {
        AICoachViewModel(summaryRepository: summaryRepository, userRepository: userRepository)
    }

    @MainActor
    func makeProfileViewModel() -> ProfileViewModel {
        ProfileViewModel(summaryRepository: summaryRepository, userRepository: userRepository)
    }

    @MainActor
    func makeAnalyticsViewModel() -> AnalyticsViewModel {
        AnalyticsViewModel(summaryRepository: summaryRepository)
    }
}
