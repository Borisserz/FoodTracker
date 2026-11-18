import Foundation
import FirebaseAuth

actor AnonymousAuthBootstrap {
    static let shared = AnonymousAuthBootstrap()

    private var inFlightTask: Task<FirebaseAuth.User, Error>?

    private init() {}

    func ensureSignedIn() async throws -> FirebaseAuth.User {
        if let user = Auth.auth().currentUser {
            return user
        }

        if let existingTask = inFlightTask {
            return try await existingTask.value
        }

        let task = Task<FirebaseAuth.User, Error> {
            // Yield once and re-check so concurrent Apple/Google sign-in isn't overwritten on startup.
            await Task.yield()
            if let existing = Auth.auth().currentUser {
                return existing
            }
            let result = try await Auth.auth().signInAnonymously()
            return result.user
        }
        inFlightTask = task
        defer { inFlightTask = nil }
        return try await task.value
    }
}
