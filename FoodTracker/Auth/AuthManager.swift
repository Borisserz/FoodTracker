import Foundation
import FirebaseAuth
import FirebaseAppCheck
import Observation

enum AccountDeletionError: LocalizedError {
    case serverCleanupFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .serverCleanupFailed(let statusCode):
            return "Failed to remove server account data (HTTP \(statusCode)). Please try again."
        }
    }
}

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
        guard let user = currentUser else { return }

        // Delete FoodTracker server state first while the user's ID token is still valid.
        let idToken = try await user.getIDToken()
        let appCheckToken = try await AppCheck.appCheck().token(forcingRefresh: false).token
        let configured = await RemoteConfigManager.shared.getString(forKey: AIProxyEndpoint.deleteAccountRemoteConfigKey)
        let url = AIProxyEndpoint.resolve(configured: configured, fallback: AIProxyEndpoint.deleteAccountFallbackURL)

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 20.0
        request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
        request.setValue(appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data("{}".utf8)

        let (_, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw AccountDeletionError.serverCleanupFailed(statusCode: http.statusCode)
        }

        try await user.delete()
    }
}
