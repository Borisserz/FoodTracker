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
}
