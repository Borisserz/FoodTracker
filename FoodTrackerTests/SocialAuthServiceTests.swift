import XCTest
import FirebaseAuth
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
}
