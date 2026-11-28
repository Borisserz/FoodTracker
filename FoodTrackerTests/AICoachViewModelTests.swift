import XCTest
import SwiftData
@testable import FoodTracker

@MainActor
final class AICoachViewModelTests: XCTestCase {
    var container: ModelContainer!
    var viewModel: AICoachViewModel!
    var originalSession: URLSession!
    var originalConsent: Bool = false

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: DailySummary.self, User.self, Meal.self, FoodItem.self, Beverage.self, ActivityLog.self, configurations: config)
        viewModel = AICoachViewModel()
        originalSession = GeminiProxyClient.shared.session
        originalConsent = AIPhotoConsentManager.shared.hasConsented
        AIPhotoConsentManager.shared.grantConsent()
        
        let sessionConfig = URLSessionConfiguration.ephemeral
        sessionConfig.protocolClasses = [MockURLProtocol.self]
        GeminiProxyClient.shared.session = URLSession(configuration: sessionConfig)
        GeminiProxyClient.shared.tokenProvider = { ("mock-auth-token", "mock-appcheck-token") }
    }

    override func tearDownWithError() throws {
        viewModel = nil
        container = nil
        if let originalSession {
            GeminiProxyClient.shared.session = originalSession
        }
        if !originalConsent {
            AIPhotoConsentManager.shared.revokeConsent()
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

    func testChatUserContextBuilderIncludesCaloriesMacrosAndHydration() {
        let ctx = AIChatTitleHelper.buildUserContext(
            userGoal: 2200,
            consumed: 1500,
            consumedProtein: 110,
            targetProtein: 150,
            consumedFats: 48,
            targetFats: 70,
            consumedCarbs: 155,
            targetCarbs: 230,
            hydrationLiters: 1.75
        )
        XCTAssertTrue(ctx.contains("2200"))
        XCTAssertTrue(ctx.contains("1500"))
        XCTAssertTrue(ctx.contains("700"))
        XCTAssertTrue(ctx.contains("110/150g protein"))
        XCTAssertTrue(ctx.contains("48/70g fats"))
        XCTAssertTrue(ctx.contains("155/230g carbs"))
        XCTAssertTrue(ctx.contains("1.8 L water") || ctx.contains("1.75 L water"))
    }

    func testAnalyzeMacrosExcludesHealthKitActiveCaloriesFromAIPrompt() async throws {
        let user = User(name: "ActiveUser", weight: 75, height: 180, age: 29)
        user.dailyCaloriesGoal = 2000
        let summary = DailySummary(date: Date())
        summary.activeCaloriesBurned = 450
        let meal = Meal(
            title: "Lunch",
            date: Date(),
            foodItems: [FoodItem(name: "Chicken Rice", weight: 300, calories: 1800, protein: 90, fats: 40, carbs: 200)]
        )
        summary.meals = [meal]

        var capturedBodyText = ""
        MockURLProtocol.requestHandler = { request in
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
            let payload = #"{"title":"Refuel","explanation":"You have room for 200 kcal.","suggestedSnacks":[]}"#
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(payload.utf8))
        }

        viewModel.analyzeMacros(currentSummary: summary, currentUser: user)
        for _ in 0..<40 where viewModel.isFixingMacros {
            try await Task.sleep(for: .milliseconds(50))
        }

        // Guideline 5.1.3(i): Base goal = 2000, eaten = 1800 -> remaining 200 kcal (HealthKit 450 kcal excluded)
        XCTAssertTrue(capturedBodyText.contains("200 kcal left"), "Expected base-goal 200 kcal deficit in prompt, got: \(capturedBodyText)")
        XCTAssertFalse(capturedBodyText.contains("650"), "Prompt must not include HealthKit-adjusted 650 kcal deficit, got: \(capturedBodyText)")
        XCTAssertFalse(capturedBodyText.contains("450"), "Prompt must not include HealthKit 450 active calories, got: \(capturedBodyText)")
    }

    func testGenerateSmartRecipeExcludesHealthKitActiveCaloriesFromAIPrompt() async throws {
        let user = User(name: "ActiveUser", weight: 75, height: 180, age: 29)
        user.dailyCaloriesGoal = 2000
        let summary = DailySummary(date: Date())
        summary.activeCaloriesBurned = 450
        let meal = Meal(
            title: "Lunch",
            date: Date(),
            foodItems: [FoodItem(name: "Chicken Rice", weight: 300, calories: 1800, protein: 90, fats: 40, carbs: 200)]
        )
        summary.meals = [meal]
        viewModel.fridgeInput = "eggs, spinach"

        var capturedBodyText = ""
        MockURLProtocol.requestHandler = { request in
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
            let payload = #"{"name":"Spinach Omelette","info":"Cook eggs with spinach.","calories":200,"protein":18,"fats":12,"carbs":3,"cookingTime":10}"#
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data(payload.utf8))
        }

        viewModel.generateSmartRecipe(currentSummary: summary, currentUser: user)
        for _ in 0..<40 where viewModel.isGeneratingRecipe {
            try await Task.sleep(for: .milliseconds(50))
        }

        // Guideline 5.1.3(i): Base goal = 2000, eaten = 1800 -> remaining 200 kcal (HealthKit 450 kcal excluded)
        XCTAssertTrue(capturedBodyText.contains("200 kcal"), "Expected base-goal 200 kcal in recipe prompt, got: \(capturedBodyText)")
        XCTAssertFalse(capturedBodyText.contains("650"), "Recipe prompt must not include HealthKit-adjusted 650 kcal, got: \(capturedBodyText)")
        XCTAssertFalse(capturedBodyText.contains("450"), "Recipe prompt must not include HealthKit 450 active calories, got: \(capturedBodyText)")
    }
}
