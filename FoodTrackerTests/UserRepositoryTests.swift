import XCTest
import SwiftData
@testable import FoodTracker

final class UserRepositoryTests: XCTestCase {
    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true, cloudKitDatabase: .none)
        container = try ModelContainer(for: User.self, configurations: config)
    }

    override func tearDownWithError() throws {
        container = nil
    }

    @MainActor
    func testFetchAndSaveUser() async throws {
        let repository = UserRepository(modelContainer: container)
        
        let initialUserID = try await repository.fetchPrimaryUserID()
        XCTAssertNil(initialUserID, "User should be nil initially")
        
        let user = User(name: "Test Repository", weight: 80, height: 180, age: 25)
        try await repository.saveUser(user)
        
        let rawUserID = try await repository.fetchPrimaryUserID()
        let fetchedUserID = try XCTUnwrap(rawUserID)
        let fetchedUser = try XCTUnwrap(container.mainContext.model(for: fetchedUserID) as? User)
        XCTAssertTrue(fetchedUser.modelContext === container.mainContext)
        XCTAssertEqual(fetchedUser.name, "Test Repository")
        XCTAssertEqual(fetchedUser.weight, 80)
    }

    @MainActor
    func testFetchUserDeduplicatesMultipleUsersToPrimary() async throws {
        let defaultAlex = User(name: "Alex", weight: 75, height: 180, age: 28)
        let customized = User(name: "Boris", weight: 82, height: 183, age: 30)
        customized.totalXP = 450
        customized.dailyCaloriesGoal = 2450
        container.mainContext.insert(defaultAlex)
        container.mainContext.insert(customized)
        try? container.mainContext.save()

        let repository = UserRepository(modelContainer: container)
        let rawFetchedID = try await repository.fetchPrimaryUserID()
        let fetchedID = try XCTUnwrap(rawFetchedID)
        let fetched = try XCTUnwrap(container.mainContext.model(for: fetchedID) as? User)
        XCTAssertTrue(fetched.modelContext === container.mainContext)
        XCTAssertEqual(fetched.name, "Boris")
        let all = (try? container.mainContext.fetch(FetchDescriptor<User>())) ?? []
        XCTAssertEqual(all.count, 1)
    }
}
