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
}
