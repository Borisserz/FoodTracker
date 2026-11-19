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
    static let accountDeletionTimeoutInterval: TimeInterval = 90.0
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
        googleSignOut: () -> Void = { GIDSignIn.sharedInstance.signOut() }
    ) async throws {
        let resolvedUser = userProvider != nil ? userProvider?() : (currentUser ?? Auth.auth().currentUser)
        guard let user = resolvedUser else {
            throw AccountDeletionError.notSignedIn
        }

        // Delete FoodTracker server state & Firebase Auth user while the ID token is still valid.
        let configured = await RemoteConfigManager.shared.getString(forKey: AIProxyEndpoint.deleteAccountRemoteConfigKey)
        let url = AIProxyEndpoint.resolve(configured: configured, fallback: AIProxyEndpoint.deleteAccountFallbackURL)

        var lastStatusCode = 500
        var serverSucceeded = false
        for forceRefresh in [false, true] {
            let idToken = try await user.getIDTokenResult(forcingRefresh: forceRefresh).token
            let appCheckToken = try await AppCheck.appCheck().token(forcingRefresh: forceRefresh).token

            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.timeoutInterval = Self.accountDeletionTimeoutInterval
            request.setValue("Bearer \(idToken)", forHTTPHeaderField: "Authorization")
            request.setValue(appCheckToken, forHTTPHeaderField: "X-Firebase-AppCheck")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = Data("{}".utf8)

            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                if (200...299).contains(http.statusCode) {
                    serverSucceeded = true
                    break
                }
                lastStatusCode = http.statusCode
                if http.statusCode == 401 && !forceRefresh {
                    continue
                }
            }
            break
        }

        guard serverSucceeded else {
            throw AccountDeletionError.serverCleanupFailed(statusCode: lastStatusCode)
        }

        // Server deletes the Firebase Auth user atomically; still attempt client cleanup for older backends
        // and tolerate userNotFound/token errors once the server confirmed deletion.
        do {
            try await user.delete()
        } catch {
            let nsError = error as NSError
            let code = AuthErrorCode(rawValue: nsError.code)
            if code != .userNotFound && code != .userTokenExpired && code != .invalidUserToken && code != .requiresRecentLogin {
                throw error
            }
        }
        try? Auth.auth().signOut()
        googleSignOut()
        applyUser(nil)
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
