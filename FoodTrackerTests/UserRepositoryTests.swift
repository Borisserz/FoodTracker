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

    func testFetchAndSaveUser() async throws {
        let repository = UserRepository(modelContainer: container)
        
        let initialUser = try await repository.fetchUser()
        XCTAssertNil(initialUser, "User should be nil initially")
        
        let user = await MainActor.run {
            User(name: "Test Repository", weight: 80, height: 180, age: 25)
        }
        
        try await repository.saveUser(user)
        
        let fetchedUser = try await repository.fetchUser()
        XCTAssertNotNil(fetchedUser)
        await MainActor.run {
            XCTAssertEqual(fetchedUser?.name, "Test Repository")
            XCTAssertEqual(fetchedUser?.weight, 80)
        }
    }

    func testFetchUserDeduplicatesMultipleUsersToPrimary() async throws {
        await MainActor.run {
            let defaultAlex = User(name: "Alex", weight: 75, height: 180, age: 28)
            let customized = User(name: "Boris", weight: 82, height: 183, age: 30)
            customized.totalXP = 450
            customized.dailyCaloriesGoal = 2450
            container.mainContext.insert(defaultAlex)
            container.mainContext.insert(customized)
            try? container.mainContext.save()
        }

        let repository = UserRepository(modelContainer: container)
        let fetched = try await repository.fetchUser()
        await MainActor.run {
            XCTAssertEqual(fetched?.name, "Boris")
            let all = (try? container.mainContext.fetch(FetchDescriptor<User>())) ?? []
            XCTAssertEqual(all.count, 1)
        }
    }
}
