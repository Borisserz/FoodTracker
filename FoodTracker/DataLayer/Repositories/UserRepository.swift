import Foundation
import SwiftData

protocol UserRepositoryProtocol: Sendable {
    func fetchUser() async throws -> User?
    func saveUser(_ user: User) async throws
}

@ModelActor
actor UserRepository: UserRepositoryProtocol {
    // modelContext and init(modelContainer:) are provided by the @ModelActor macro.

    func fetchUser() async throws -> User? {
        let user = User.deduplicatedPrimary(in: modelContext)
        if modelContext.hasChanges {
            try modelContext.save()
        }
        return user
    }

    func saveUser(_ user: User) async throws {
        modelContext.insert(user)
        try modelContext.save()
    }
}
