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
        XCTAssertGreaterThanOrEqual(AuthManager.accountDeletionTimeoutInterval, 60.0)
    }
}
