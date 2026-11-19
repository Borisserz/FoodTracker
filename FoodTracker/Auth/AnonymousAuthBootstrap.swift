import Foundation
import FirebaseAuth

actor AnonymousAuthBootstrap {
    static let shared = AnonymousAuthBootstrap()

    private var inFlightTask: Task<FirebaseAuth.User, Error>?
    private var inFlightGeneration: UInt64 = 0
    private var interactiveSignInCount = 0

    private init() {}

    func beginInteractiveSignIn() {
        interactiveSignInCount += 1
        inFlightGeneration &+= 1
        inFlightTask?.cancel()
        inFlightTask = nil
    }

    func endInteractiveSignIn() {
        interactiveSignInCount = max(0, interactiveSignInCount - 1)
    }

    func ensureSignedIn() async throws -> FirebaseAuth.User {
        if let user = Auth.auth().currentUser {
            return user
        }

        if let existingTask = inFlightTask {
            return try await existingTask.value
        }

        inFlightGeneration &+= 1
        let capturedGeneration = inFlightGeneration
        let task = Task<FirebaseAuth.User, Error> {
            // Yield once and re-check so concurrent Apple/Google sign-in isn't overwritten on startup.
            await Task.yield()
            if let existing = Auth.auth().currentUser {
                return existing
            }
            while interactiveSignInCount > 0 {
                try Task.checkCancellation()
                try await Task.sleep(for: .milliseconds(50))
                if let existing = Auth.auth().currentUser {
                    return existing
                }
            }
            try Task.checkCancellation()
            let result = try await Auth.auth().signInAnonymously()
            return result.user
        }
        inFlightTask = task
        defer {
            if inFlightGeneration == capturedGeneration {
                inFlightTask = nil
            }
        }
        return try await task.value
    }
}
