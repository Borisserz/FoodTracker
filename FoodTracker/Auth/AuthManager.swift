import Foundation
import FirebaseAuth
import Observation

@Observable
@MainActor
final class AuthManager {
    var isAnonymous: Bool = true
    var isAuthenticated: Bool = false
    var currentUser: FirebaseAuth.User?

    init() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self = self else { return }
            self.currentUser = user
            self.isAnonymous = user?.isAnonymous ?? true
            self.isAuthenticated = user != nil && !(user?.isAnonymous ?? true)
        }
    }

    var currentUserId: String {
        currentUser?.uid ?? "Unknown"
    }

    var currentUserEmail: String? {
        currentUser?.email
    }

    func deleteCurrentUser() async throws {
        try await currentUser?.delete()
    }
}
