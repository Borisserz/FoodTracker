import XCTest
import AuthenticationServices
import FirebaseAuth
import GoogleSignIn
@testable import FoodTracker

@MainActor
final class SocialAuthServiceTests: XCTestCase {

    func testMakeGoogleCredentialSucceedsWhenIDTokenPresent() throws {
        let credential = try SocialAuthService.makeGoogleCredential(
            idToken: "mock-google-id-token",
            accessToken: "mock-google-access-token"
        )
        XCTAssertEqual(credential.provider, GoogleAuthProviderID)
    }

    func testMakeGoogleCredentialThrowsWhenIDTokenMissing() {
        XCTAssertThrowsError(
            try SocialAuthService.makeGoogleCredential(idToken: nil, accessToken: "mock-access")
        ) { error in
            guard case AuthError.invalidGoogleCredential = error else {
                XCTFail("Expected AuthError.invalidGoogleCredential, got \(error)")
                return
            }
        }
    }

    func testIsCancellationErrorRecognizesAppleAndGoogleCancellations() {
        let appleCancel = ASAuthorizationError(.canceled)
        let googleCancel = NSError(domain: kGIDSignInErrorDomain, code: GIDSignInError.canceled.rawValue)
        let networkFailure = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)

        XCTAssertTrue(SocialAuthService.isCancellationError(appleCancel))
        XCTAssertTrue(SocialAuthService.isCancellationError(googleCancel))
        XCTAssertFalse(SocialAuthService.isCancellationError(networkFailure))
        XCTAssertFalse(SocialAuthService.isCancellationError(AuthError.invalidAppleCredential))
    }

    func testDeleteCurrentUserThrowsWhenNoUserSignedIn() async {
        let authManager = AuthManager()
        do {
            try await authManager.deleteCurrentUser(userProvider: { nil })
            XCTFail("Expected AccountDeletionError.notSignedIn when user is nil")
        } catch let error as AccountDeletionError {
            guard case .notSignedIn = error else {
                XCTFail("Expected .notSignedIn, got \(error)")
                return
            }
        } catch {
            XCTFail("Expected AccountDeletionError.notSignedIn, got \(error)")
        }
    }

    func testDeletionSequenceDoesNotRevokeAppleTokenWhenDeletionFails() async {
        var events: [String] = []
        do {
            try await AuthManager.runDeletionSequence(
                reauthenticate: {
                    events.append("reauth")
                    return "apple-auth-code"
                },
                deleteAccount: {
                    events.append("delete-fail")
                    throw AccountDeletionError.serverCleanupFailed(statusCode: 500)
                },
                revokeAppleToken: { _ in
                    events.append("revoke")
                }
            )
            XCTFail("Expected serverCleanupFailed to propagate")
        } catch {
            XCTAssertEqual(events, ["reauth", "delete-fail"])
        }
    }

    func testDeletionSequenceRevokesAppleTokenAfterSuccessfulDeletion() async throws {
        var events: [String] = []
        try await AuthManager.runDeletionSequence(
            reauthenticate: {
                events.append("reauth")
                return "apple-auth-code"
            },
            deleteAccount: {
                events.append("delete")
            },
            revokeAppleToken: { code in
                events.append("revoke:\(code)")
            }
        )
        XCTAssertEqual(events, ["reauth", "delete", "revoke:apple-auth-code"])
    }

    func testDeletionSequenceClearsGoogleSessionOnlyAfterSuccessfulDeletion() async throws {
        var events: [String] = []
        try await AuthManager.runDeletionSequence(
            reauthenticate: {
                events.append("reauth")
                return nil
            },
            deleteAccount: {
                events.append("delete")
            },
            clearGoogleSession: {
                events.append("google-signout")
            },
            revokeAppleToken: { _ in
                events.append("revoke")
            }
        )
        XCTAssertEqual(events, ["reauth", "delete", "google-signout"])

        var failureEvents: [String] = []
        do {
            try await AuthManager.runDeletionSequence(
                reauthenticate: {
                    failureEvents.append("reauth")
                    return nil
                },
                deleteAccount: {
                    failureEvents.append("delete-fail")
                    throw AccountDeletionError.serverCleanupFailed(statusCode: 500)
                },
                clearGoogleSession: {
                    failureEvents.append("google-signout")
                },
                revokeAppleToken: { _ in
                    failureEvents.append("revoke")
                }
            )
            XCTFail("Expected failure")
        } catch {
            XCTAssertEqual(failureEvents, ["reauth", "delete-fail"])
        }
    }

    func testDeleteCurrentUserDoesNotSignOutGoogleWhenNoUserSignedIn() async {
        let authManager = AuthManager()
        var didSignOutGoogle = false
        do {
            try await authManager.deleteCurrentUser(
                userProvider: { nil },
                googleSignOut: { didSignOutGoogle = true }
            )
            XCTFail("Expected AccountDeletionError.notSignedIn")
        } catch {
            XCTAssertFalse(didSignOutGoogle)
        }
    }

    func testAccountDeletionDialogCopyWarnsRegisteredUsersAboutSharedEcosystem() {
        let registeredMessage = AccountDeletionDialogCopy.confirmationMessage(isAnonymous: false)
        let guestMessage = AccountDeletionDialogCopy.confirmationMessage(isAnonymous: true)

        XCTAssertFalse(registeredMessage.isEmpty)
        XCTAssertFalse(guestMessage.isEmpty)
        XCTAssertNotEqual(registeredMessage, guestMessage)
        XCTAssertTrue(registeredMessage.contains("WorkoutTracker"))
        XCTAssertFalse(guestMessage.contains("WorkoutTracker"))
    }

    func testAnonymousAuthBootstrapHandlesOutOfOrderEndBeforeBeginWithoutDeadlock() async {
        let bootstrap = AnonymousAuthBootstrap.shared
        await bootstrap.resetLeasesForTesting()

        let leaseID = UUID()
        await bootstrap.endInteractiveSignIn(leaseID)
        await bootstrap.beginInteractiveSignIn(id: leaseID)
        let countAfterOutOfOrder = await bootstrap.activeInteractiveLeaseCountForTesting()
        XCTAssertEqual(countAfterOutOfOrder, 0)

        let normalLease = await bootstrap.beginInteractiveSignIn()
        let countDuringLease = await bootstrap.activeInteractiveLeaseCountForTesting()
        XCTAssertEqual(countDuringLease, 1)

        await bootstrap.endInteractiveSignIn(normalLease)
        let countAfterEnd = await bootstrap.activeInteractiveLeaseCountForTesting()
        XCTAssertEqual(countAfterEnd, 0)
    }

    func testAuthManagerAccountDeletionTimeoutExceedsServerWindow() {
        XCTAssertGreaterThanOrEqual(AuthManager.accountDeletionTimeoutInterval, 120.0)
    }

    func testSocialAuthServiceDoubleTapGuardPreservesRecentNonce() {
        XCTAssertTrue(SocialAuthService.shouldReuseRecentNonce(existingNonce: "abc", elapsed: 0.3))
        XCTAssertFalse(SocialAuthService.shouldReuseRecentNonce(existingNonce: "abc", elapsed: 3.0))
        XCTAssertFalse(SocialAuthService.shouldReuseRecentNonce(existingNonce: nil as String?, elapsed: 0.1))
    }

    func testPerformServerAccountDeletionRetries401AndSucceedsOn200() async throws {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: config)
        defer { MockURLProtocol.requestHandler = nil }

        var attempts = 0
        var refreshFlags: [Bool] = []
        MockURLProtocol.requestHandler = { request in
            attempts += 1
            if attempts == 1 {
                XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer stale")
                let resp = HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!
                return (resp, Data())
            }
            XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fresh")
            XCTAssertEqual(request.value(forHTTPHeaderField: "X-Firebase-AppCheck"), "appcheck-fresh")
            let resp = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
            return (resp, Data("{\"ok\":true}".utf8))
        }

        try await AuthManager.performServerAccountDeletion(
            url: URL(string: "https://mock.local/foodDeleteAccount")!,
            urlSession: session,
            fetchTokens: { forceRefresh in
                refreshFlags.append(forceRefresh)
                return forceRefresh ? ("fresh", "appcheck-fresh") : ("stale", "appcheck-stale")
            }
        )
        XCTAssertEqual(attempts, 2)
        XCTAssertEqual(refreshFlags, [false, true])
    }

    func testDeletionSequenceRetriesAndSurfacesErrorWhenAppleRevocationFails() async {
        var events: [String] = []
        var revocationAttempts = 0
        do {
            try await AuthManager.runDeletionSequence(
                reauthenticate: {
                    events.append("reauth")
                    return "apple-auth-code"
                },
                deleteAccount: {
                    events.append("delete")
                },
                clearGoogleSession: {
                    events.append("google-signout")
                },
                revokeAppleToken: { _ in
                    revocationAttempts += 1
                    events.append("revoke-attempt-\(revocationAttempts)")
                    throw NSError(domain: "AppleRevoke", code: -1)
                }
            )
            XCTFail("Expected revocation failure to be surfaced rather than silently swallowed")
        } catch {
            XCTAssertEqual(revocationAttempts, 2)
            XCTAssertEqual(events, ["reauth", "delete", "google-signout", "revoke-attempt-1", "revoke-attempt-2"])
        }
    }

    func testDeletionSequenceSucceedsAfterTransientAppleRevocationFailure() async throws {
        var revocationAttempts = 0
        try await AuthManager.runDeletionSequence(
            reauthenticate: { "apple-auth-code" },
            deleteAccount: {},
            revokeAppleToken: { _ in
                revocationAttempts += 1
                if revocationAttempts == 1 {
                    throw NSError(domain: "AppleRevoke", code: -1)
                }
            }
        )
        XCTAssertEqual(revocationAttempts, 2)
    }

    func testExtractAppleAuthorizationCodeThrowsWhenNilOrEmpty() throws {
        XCTAssertThrowsError(try SocialAuthService.extractAppleAuthorizationCode(from: nil)) { error in
            guard case AuthError.missingAppleAuthorizationCode = error else {
                XCTFail("Expected missingAppleAuthorizationCode, got \(error)")
                return
            }
        }
        XCTAssertThrowsError(try SocialAuthService.extractAppleAuthorizationCode(from: Data())) { error in
            guard case AuthError.missingAppleAuthorizationCode = error else {
                XCTFail("Expected missingAppleAuthorizationCode, got \(error)")
                return
            }
        }
        let code = try SocialAuthService.extractAppleAuthorizationCode(from: Data("auth-code-123".utf8))
        XCTAssertEqual(code, "auth-code-123")
    }

    func testAnonymousAuthBootstrapExpiresStaleInteractiveLeases() async {
        let bootstrap = AnonymousAuthBootstrap.shared
        await bootstrap.resetLeasesForTesting()
        let staleID = UUID()
        let now = Date()
        await bootstrap.beginInteractiveSignIn(id: staleID, startedAt: now.addingTimeInterval(-300))
        await bootstrap.pruneExpiredLeases(now: now, ttl: 120)
        let remaining = await bootstrap.activeInteractiveLeaseCountForTesting()
        XCTAssertEqual(remaining, 0, "Stale interactive sign-in lease older than TTL must be pruned")
    }

    func testMapAuthErrorConvertsProviderCollisionToUserFacingMessage() {
        let collisionError = NSError(
            domain: AuthErrorDomain,
            code: AuthErrorCode.accountExistsWithDifferentCredential.rawValue,
            userInfo: nil
        )
        let mapped = SocialAuthService.mapAuthError(collisionError)
        guard case AuthError.accountExistsWithOtherProvider = mapped else {
            XCTFail("Expected accountExistsWithOtherProvider, got \(mapped)")
            return
        }
        XCTAssertFalse(mapped.localizedDescription.isEmpty)
    }
}
