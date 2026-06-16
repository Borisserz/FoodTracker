import XCTest
import SwiftData
@testable import FoodTracker

final class UserRepositoryTests: XCTestCase {
    var container: ModelContainer!

    override func setUpWithError() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
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
}
