import Foundation
import FirebaseAuth
import FirebaseAppCheck
import GoogleSignIn
import Observation

enum AccountDeletionDialogCopy {
    static func confirmationMessage(isAnonymous: Bool) -> String {
        if isAnonymous {
            return String(localized: "This permanently deletes your guest account and clears all meals, recipes, weight logs, and settings from this device.")
        }
        return String(localized: "This permanently deletes your shared ecosystem account (including WorkoutTracker sign-in) and clears all FoodTracker meals, recipes, weight logs, and settings from this device.")
    }
}

enum AccountDeletionError: LocalizedError {
    case serverCleanupFailed(statusCode: Int)
    case notSignedIn

    var errorDescription: String? {
        switch self {
        case .serverCleanupFailed(let statusCode):
            return "Failed to remove server account data (HTTP \(statusCode)). Please try again."
        case .notSignedIn:
            return "No active user session found to delete."
        }
    }
}

@Observable
@MainActor
final class AuthManager {
    static let accountDeletionTimeoutInterval: TimeInterval = 130.0
    var isAnonymous: Bool = true
    var isAuthenticated: Bool = false
    var currentUser: FirebaseAuth.User?

    @ObservationIgnored nonisolated(unsafe) private var authStateHandle: AuthStateDidChangeListenerHandle?
    @ObservationIgnored nonisolated(unsafe) private var idTokenHandle: IDTokenDidChangeListenerHandle?

    init() {
        applyUser(Auth.auth().currentUser)
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.applyUser(user)
            }
        }
        idTokenHandle = Auth.auth().addIDTokenDidChangeListener { [weak self] _, user in
            Task { @MainActor [weak self] in
                self?.applyUser(user)
            }
        }
    }

    deinit {
        if let authStateHandle {
            Auth.auth().removeStateDidChangeListener(authStateHandle)
        }
        if let idTokenHandle {
            Auth.auth().removeIDTokenDidChangeListener(idTokenHandle)
        }
    }

    private func applyUser(_ user: FirebaseAuth.User?) {
        self.currentUser = user
        self.isAnonymous = user?.isAnonymous ?? true
        self.isAuthenticated = user != nil && !(user?.isAnonymous ?? true)
    }

    var currentUserId: String {
        currentUser?.uid ?? Auth.auth().currentUser?.uid ?? "Unknown"
    }

    var currentUserEmail: String? {
        currentUser?.email ?? Auth.auth().currentUser?.email
    }

    func deleteCurrentUser(
        userProvider: (() -> FirebaseAuth.User?)? = nil,
        googleSignOut: () -> Void = { GIDSignIn.sharedInstance.signOut() },
        urlSession: URLSession = .shared,
        deleteURL: URL? = nil,
        tokenPairProvider: ((_ user: FirebaseAuth.User, _ forceRefresh: Bool) async throws -> (idToken: String, appCheckToken: String))? = nil
    ) async throws {
        let resolvedUser = userProvider != nil ? userProvider?() : (currentUser ?? Auth.auth().currentUser)
        guard let user = resolvedUser else {
            throw AccountDeletionError.notSignedIn
        }

        // Delete FoodTracker server state & Firebase Auth user while the ID token is still valid.
        let url: URL
        if let deleteURL {
            url = deleteURL
        } else {
            let configured = await RemoteConfigManager.shared.getString(forKey: AIProxyEndpoint.deleteAccountRemoteConfigKey)
            url = AIProxyEndpoint.resolve(configured: configured, fallback: AIProxyEndpoint.deleteAccountFallbackURL)
        }

        try await Self.performServerAccountDeletion(
            url: url,
            urlSession: urlSession,
            fetchTokens: { forceRefresh in
                if let tokenPairProvider {
                    return try await tokenPairProvider(user, forceRefresh)
                }
                let idToken = try await user.getIDTokenResult(forcingRefresh: forceRefresh).token
                let appCheckToken = try await AppCheck.appCheck().token(forcingRefresh: forceRefresh).token
                return (idToken, appCheckToken)
            }
        )

        // Server already deleted the Firebase Auth user atomically; never throw after HTTP 2xx
        // so local sign-out and SwiftData wipe always complete cleanly.
        try? await user.delete()
        try? Auth.auth().signOut()
        googleSignOut()
        applyUser(nil)
    }

    nonisolated static func performServerAccountDeletion(
        url: URL,
        urlSession: URLSession = .shared,
        fetchTokens: (_ forceRefresh: Bool) async throws -> (idToken: String, appCheckToken: String)
    ) async throws {
        var lastStatusCode = 500
        for forceRefresh in [false, true] {
            let tokens = try await fetchTokens(forceRefresh)

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = accountDeletionTimeoutInterval
            request.setValue("Bearer \(tokens.idToken)", forHTTPHeaderField: "Authorization")
            request.setValue(tokens.appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data("{}".utf8)

            let (_, response) = try await urlSession.data(for: request)
            if let http = response as? HTTPURLResponse {
                if (200...299).contains(http.statusCode) {
                    return
                }
                lastStatusCode = http.statusCode
                if http.statusCode == 401 && !forceRefresh {
                    continue
                }
            }
            break
        }

        throw AccountDeletionError.serverCleanupFailed(statusCode: lastStatusCode)
    }

    nonisolated static func isPermanentTokenInvalidationError(_ error: Error) -> Bool {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain,
              let code = AuthErrorCode(rawValue: nsError.code) else {
            return false
        }
        return code == .userTokenExpired || code == .userNotFound || code == .userDisabled
    }

    static func runDeletionSequence(
        reauthenticate: () async throws -> String?,
        deleteAccount: () async throws -> Void,
        clearGoogleSession: () -> Void = {},
        revokeAppleToken: (String) async throws -> Void
    ) async throws {
        let appleAuthorizationCode = try await reauthenticate()
        try await deleteAccount()
        clearGoogleSession()
        if let appleAuthorizationCode, !appleAuthorizationCode.isEmpty {
            do {
                try await revokeAppleToken(appleAuthorizationCode)
            } catch {
                // Server and Firebase Auth account deletion already succeeded; log and continue so local wipe completes.
                print("⚠️ Apple token revocation warning after account deletion: \(error.localizedDescription)")
            }
        }
    }
}
