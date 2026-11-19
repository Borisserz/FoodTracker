import Foundation
import SwiftData

protocol UserRepositoryProtocol: Sendable {
    func fetchPrimaryUserID() async throws -> PersistentIdentifier?
    func saveUser(_ user: User) async throws
}

@ModelActor
actor UserRepository: UserRepositoryProtocol {
    // modelContext and init(modelContainer:) are provided by the @ModelActor macro.

    func fetchPrimaryUserID() async throws -> PersistentIdentifier? {
        let user = User.deduplicatedPrimary(in: modelContext)
        if modelContext.hasChanges {
            try modelContext.save()
        }
        return user?.persistentModelID
    }

    func saveUser(_ user: User) async throws {
        modelContext.insert(user)
        try modelContext.save()
    }
}
