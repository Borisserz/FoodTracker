import XCTest
import SwiftData
@testable import FoodTracker

@MainActor
final class AICoachViewModelTests: XCTestCase {
    var container: ModelContainer!
    var viewModel: AICoachViewModel!
    var repository: SummaryRepository!
    var userRepository: UserRepository!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: DailySummary.self, User.self, Meal.self, FoodItem.self, Beverage.self, ActivityLog.self, configurations: config)
        repository = SummaryRepository(modelContainer: container)
        userRepository = UserRepository(modelContainer: container)
        viewModel = AICoachViewModel(summaryRepository: repository, userRepository: userRepository)
        
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [MockURLProtocol.self]
        GeminiProxyClient.shared.session = URLSession(configuration: sessionConfig)
    }

    override func tearDownWithError() throws {
        viewModel = nil
        repository = nil
        userRepository = nil
        container = nil
        GeminiProxyClient.shared.session = .shared
        MockURLProtocol.requestHandler = nil
    }

    func testRunDailyAnalysisSuccess() async throws {
        let user = User(name: "Test", weight: 70, height: 175, age: 25)
        let summary = DailySummary(date: Date())
        
        let jsonResponse = """
        {
            "title": "Excellent Job",
            "message": "You hit your goals!",
            "mood": "perfect"
        }
        """
        
        MockURLProtocol.requestHandler = { request in
            let data = jsonResponse.data(using: .utf8)!
            let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (response, data)
        }
        
        viewModel.runDailyAnalysis(currentSummary: summary, currentUser: user)
        
        // Wait for task to finish
        try await Task.sleep(nanoseconds: 200_000_000)
        
        XCTAssertTrue(viewModel.hasAnalyzedToday)
        XCTAssertEqual(viewModel.verdictTitle, "Excellent Job")
        XCTAssertEqual(viewModel.verdictMood, "perfect")
    }
    
    func testRunDailyAnalysisFallback() async throws {
        let user = User(name: "Test", weight: 70, height: 175, age: 25)
        user.dailyCaloriesGoal = 2000
        let summary = DailySummary(date: Date())
        summary.totalFoodCalories = 2500 // Over goal
        
        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }
        
        viewModel.runDailyAnalysis(currentSummary: summary, currentUser: user)
        try await Task.sleep(nanoseconds: 200_000_000)
        
        // Should use fallback logic
        XCTAssertTrue(viewModel.hasAnalyzedToday)
        XCTAssertEqual(viewModel.verdictTitle, "Data Collected")
        XCTAssertEqual(viewModel.verdictMood, "danger")
    }
}
