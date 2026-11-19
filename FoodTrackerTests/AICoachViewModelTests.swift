import XCTest
import SwiftData
@testable import FoodTracker

@MainActor
final class AICoachViewModelTests: XCTestCase {
    var container: ModelContainer!
    var viewModel: AICoachViewModel!
    var repository: SummaryRepository!
    var userRepository: UserRepository!
    var originalSession: URLSession!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: DailySummary.self, User.self, Meal.self, FoodItem.self, Beverage.self, ActivityLog.self, configurations: config)
        repository = SummaryRepository(modelContainer: container)
        userRepository = UserRepository(modelContainer: container)
        viewModel = AICoachViewModel(summaryRepository: repository, userRepository: userRepository)
        originalSession = GeminiProxyClient.shared.session
        
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [MockURLProtocol.self]
        GeminiProxyClient.shared.session = URLSession(configuration: sessionConfig)
        GeminiProxyClient.shared.tokenProvider = { ("mock-auth-token", "mock-appcheck-token") }
    }

    override func tearDownWithError() throws {
        viewModel = nil
        repository = nil
        userRepository = nil
        container = nil
        if let originalSession {
            GeminiProxyClient.shared.session = originalSession
        }
        GeminiProxyClient.shared.tokenProvider = nil
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
        
        for _ in 0..<40 where viewModel.isAnalyzing {
            try await Task.sleep(for: .milliseconds(50))
        }
        
        XCTAssertTrue(viewModel.hasAnalyzedToday)
        XCTAssertEqual(viewModel.verdictTitle, "Excellent Job")
        XCTAssertEqual(viewModel.verdictMood, "perfect")
    }
    
    func testRunDailyAnalysisErrorSurfacesMessageInsteadOfFakeSuccess() async throws {
        let user = User(name: "Test", weight: 70, height: 175, age: 25)
        user.dailyCaloriesGoal = 2000
        let summary = DailySummary(date: Date())
        let meal = Meal(
            title: "Dinner",
            date: Date(),
            foodItems: [FoodItem(name: "Feast", weight: 500, calories: 2500, protein: 80, fats: 100, carbs: 300)]
        )
        summary.meals = [meal]

        MockURLProtocol.requestHandler = { request in
            let response = HTTPURLResponse(url: request.url!, statusCode: 500, httpVersion: nil, headerFields: nil)!
            return (response, Data())
        }

        viewModel.runDailyAnalysis(currentSummary: summary, currentUser: user)
        for _ in 0..<40 where viewModel.isAnalyzing {
            try await Task.sleep(for: .milliseconds(50))
        }

        XCTAssertFalse(viewModel.isAnalyzing)
        XCTAssertFalse(viewModel.hasAnalyzedToday)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testAnalyzeMacrosIncludesActiveDietAndGuardsDuplicateCalls() async throws {
        let user = User(name: "KetoUser", weight: 75, height: 180, age: 29)
        user.activeDietKey = "keto"
        let summary = DailySummary(date: Date())

        var capturedBodyText = ""
        var requestCount = 0
        MockURLProtocol.requestHandler = { request in
            requestCount += 1
            var data = request.httpBody ?? Data()
            if data.isEmpty, let stream = request.httpBodyStream {
                stream.open()
                defer { stream.close() }
                var buf = [UInt8](repeating: 0, count: 4096)
                while stream.hasBytesAvailable {
                    let read = stream.read(&buf, maxLength: buf.count)
                    if read > 0 { data.append(contentsOf: buf.prefix(read)) } else { break }
                }
            }
            capturedBodyText = String(data: data, encoding: .utf8) ?? ""
            let payload = #"{"title":"Keto Fix","explanation":"Focus on healthy fats.","suggestedSnacks":[]}"#
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(payload.utf8))
        }

        viewModel.analyzeMacros(currentSummary: summary, currentUser: user)
        viewModel.analyzeMacros(currentSummary: summary, currentUser: user) // duplicate tap while in-flight
        for _ in 0..<40 where viewModel.isFixingMacros {
            try await Task.sleep(for: .milliseconds(50))
        }

        XCTAssertEqual(requestCount, 1)
        XCTAssertTrue(capturedBodyText.localizedCaseInsensitiveContains("keto"))
    }

    func testLocalChatTitleHelperDerivesCleanTitleWithoutNetwork() {
        let title = AIChatTitleHelper.deriveTitle(from: "   What should I eat after a heavy leg day workout?   ")
        XCTAssertFalse(title.isEmpty)
        XCTAssertLessThanOrEqual(title.count, 40)
        XCTAssertEqual(AIChatTitleHelper.deriveTitle(from: "   "), String(localized: "Diet Chat"))
    }
}
