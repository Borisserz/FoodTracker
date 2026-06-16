import XCTest
import SwiftData
@testable import FoodTracker

@MainActor
final class ProfileViewModelTests: XCTestCase {
    var container: ModelContainer!
    var viewModel: ProfileViewModel!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: User.self, DailySummary.self, Meal.self, FoodItem.self, Beverage.self, ActivityLog.self, configurations: config)
        
        let repo = UserRepository(modelContainer: container)
        viewModel = ProfileViewModel(userRepository: repo)
    }

    override func tearDownWithError() throws {
        viewModel = nil
        container = nil
    }

    func testLoadUserCreatesNewIfNotExists() async throws {
        XCTAssertNil(viewModel.user)
        
        // This will create a default user if none exists
        await viewModel.loadUser()
        
        XCTAssertNotNil(viewModel.user)
        XCTAssertEqual(viewModel.user?.name, "User")
        XCTAssertEqual(viewModel.user?.weight, 70.0)
        XCTAssertEqual(viewModel.user?.height, 175.0)
    }

    func testLoadUserFetchesExisting() async throws {
        let user = User(name: "Existing User", weight: 65, height: 170, age: 28)
        container.mainContext.insert(user)
        try container.mainContext.save()
        
        await viewModel.loadUser()
        
        XCTAssertNotNil(viewModel.user)
        XCTAssertEqual(viewModel.user?.name, "Existing User")
        XCTAssertEqual(viewModel.user?.weight, 65.0)
    }

    func testSaveUser() async throws {
        await viewModel.loadUser()
        
        viewModel.user?.name = "Updated Name"
        viewModel.user?.weight = 75.0
        
        await viewModel.saveUser()
        
        // Refetch to verify
        let fetchDescriptor = FetchDescriptor<User>()
        let users = try container.mainContext.fetch(fetchDescriptor)
        XCTAssertEqual(users.count, 1)
        XCTAssertEqual(users.first?.name, "Updated Name")
        XCTAssertEqual(users.first?.weight, 75.0)
    }
}
