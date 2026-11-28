//
//  SocialAuthService.swift
//  FoodTracker
//
//  Created by Boris Serzhanovich on 30.05.2026.
//

import Foundation
import AuthenticationServices
import CryptoKit
import FirebaseAuth
import FirebaseCore
import GoogleSignIn
import UIKit

@MainActor
final class SocialAuthService {

    static let shared = SocialAuthService()
    private init() {}

    private var currentNonce: String?
    private var lastApplePrepareDate: Date?
    private var appleRequestLeaseID: UUID?
    private var isAppleAuthorizationInFlight = false
    private var isGoogleAuthorizationInFlight = false

    nonisolated static func shouldReuseRecentNonce(existingNonce: String?, elapsed: TimeInterval) -> Bool {
        existingNonce != nil && elapsed >= 0 && elapsed < 2.0
    }

    // MARK: - Apple

    func prepareAppleRequest(_ request: ASAuthorizationAppleIDRequest) {
        guard !isAppleAuthorizationInFlight else { return }
        let elapsed = lastApplePrepareDate.map { Date().timeIntervalSince($0) } ?? .infinity
        let reuseNonce = Self.shouldReuseRecentNonce(existingNonce: currentNonce, elapsed: elapsed)
        if !reuseNonce, let staleLease = appleRequestLeaseID {
            appleRequestLeaseID = nil
            Task { await AnonymousAuthBootstrap.shared.endInteractiveSignIn(staleLease) }
        }
        if appleRequestLeaseID == nil {
            let leaseID = UUID()
            appleRequestLeaseID = leaseID
            Task { await AnonymousAuthBootstrap.shared.beginInteractiveSignIn(id: leaseID) }
        }
        let nonce: String
        if reuseNonce, let existing = currentNonce {
            nonce = existing
        } else {
            nonce = Self.randomNonce()
            currentNonce = nonce
            lastApplePrepareDate = Date()
        }
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)
    }

    func handleAppleAuthorization(_ result: Result<ASAuthorization, Error>) async throws {
        isAppleAuthorizationInFlight = true
        let leaseID = appleRequestLeaseID
        defer {
            isAppleAuthorizationInFlight = false
            currentNonce = nil
            lastApplePrepareDate = nil
            appleRequestLeaseID = nil
            if let leaseID {
                Task { await AnonymousAuthBootstrap.shared.endInteractiveSignIn(leaseID) }
            }
        }
        let authorization = try result.get()

        guard
            let credential = authorization.credential as? ASAuthorizationAppleIDCredential,
            let nonce = currentNonce,
            let tokenData = credential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else {
            throw AuthError.invalidAppleCredential
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        try await linkOrSignIn(with: firebaseCredential)
    }

    nonisolated static func isCancellationError(_ error: Error) -> Bool {
        if let authError = error as? ASAuthorizationError, authError.code == .canceled {
            return true
        }
        let nsError = error as NSError
        if nsError.domain == ASAuthorizationError.errorDomain,
           nsError.code == ASAuthorizationError.canceled.rawValue {
            return true
        }
        if nsError.domain == kGIDSignInErrorDomain,
           nsError.code == GIDSignInError.canceled.rawValue {
            return true
        }
        return false
    }

    func signInWithApple() async throws {
        guard !isAppleAuthorizationInFlight else {
            throw AuthError.invalidAppleCredential
        }
        isAppleAuthorizationInFlight = true
        let leaseID = await AnonymousAuthBootstrap.shared.beginInteractiveSignIn()
        defer {
            isAppleAuthorizationInFlight = false
            currentNonce = nil
            Task { await AnonymousAuthBootstrap.shared.endInteractiveSignIn(leaseID) }
        }

        let nonce = Self.randomNonce()
        currentNonce = nonce

        let credential = try await performAppleAuthorization(nonce: nonce)
        
        guard let tokenData = credential.identityToken,
              let idToken = String(data: tokenData, encoding: .utf8) else {
            throw AuthError.invalidAppleCredential
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: credential.fullName
        )
        try await linkOrSignIn(with: firebaseCredential)
    }

    // MARK: - Google

    func signInWithGoogle() async throws {
        guard !isGoogleAuthorizationInFlight else {
            throw AuthError.invalidGoogleCredential
        }
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.missingGoogleClientID
        }
        isGoogleAuthorizationInFlight = true
        let leaseID = await AnonymousAuthBootstrap.shared.beginInteractiveSignIn()
        defer {
            isGoogleAuthorizationInFlight = false
            Task { await AnonymousAuthBootstrap.shared.endInteractiveSignIn(leaseID) }
        }
 
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        guard let presenter = Self.topViewController() else {
          throw AuthError.noPresentingController
        }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter)
        let credential = try Self.makeGoogleCredential(
            idToken: result.user.idToken?.tokenString,
            accessToken: result.user.accessToken.tokenString
        )
        try await linkOrSignIn(with: credential)
    }

    nonisolated static func makeGoogleCredential(idToken: String?, accessToken: String) throws -> AuthCredential {
        guard let idToken, !idToken.isEmpty else {
            throw AuthError.invalidGoogleCredential
        }
        return GoogleAuthProvider.credential(
            withIDToken: idToken,
            accessToken: accessToken
        )
    }

    // MARK: - Linking core


    private func linkOrSignIn(with credential: AuthCredential) async throws {
        if let user = Auth.auth().currentUser, user.isAnonymous {
            do {
                let result = try await user.link(with: credential)
                try? await result.user.reload()
                // Force an ID-token listener notification so UI reflects linked provider/email immediately.
                _ = try? await result.user.getIDTokenResult(forcingRefresh: true)
            } catch {
                let nsError = error as NSError
                let code = AuthErrorCode(rawValue: nsError.code)
                if code == .credentialAlreadyInUse || code == .emailAlreadyInUse {
                    let updated = nsError
                        .userInfo[AuthErrorUserInfoUpdatedCredentialKey] as? AuthCredential
                    let signedInResult: AuthDataResult
                    do {
                        signedInResult = try await Auth.auth().signIn(with: updated ?? credential)
                    } catch {
                        throw Self.mapAuthError(error)
                    }
                    if signedInResult.user.uid != user.uid {
                        try? await user.delete()
                    }
                } else {
                    throw Self.mapAuthError(error)
                }
            }
        } else {
            do {
                _ = try await Auth.auth().signIn(with: credential)
            } catch {
                throw Self.mapAuthError(error)
            }
        }
    }

    nonisolated static func mapAuthError(_ error: Error) -> Error {
        let nsError = error as NSError
        guard nsError.domain == AuthErrorDomain,
              let code = AuthErrorCode(rawValue: nsError.code) else {
            return error
        }
        if code == .accountExistsWithDifferentCredential {
            return AuthError.accountExistsWithOtherProvider
        }
        return error
    }

    // MARK: - Sign Out

    func signOut() async throws {
        GIDSignIn.sharedInstance.signOut()
        try Auth.auth().signOut()
        // Ensure a new anonymous account is created immediately
        _ = try await AnonymousAuthBootstrap.shared.ensureSignedIn()
    }

    // MARK: - Helpers

    private static func randomNonce(length: Int = 32) -> String {
        var bytes = [UInt8](repeating: 0, count: length)
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed: \(status)")
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz-._")
        return String(bytes.map { charset[Int($0) % charset.count] })
    }

    private static func sha256(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    private static func topViewController() -> UIViewController? {
        let scene = UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive } as? UIWindowScene
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController { top = presented }
        return top
    }
    // MARK: - Account deletion support (Guideline 5.1.1(v))

    /// Re-authenticates the current user immediately before deletion and returns
    /// any Apple authorization code so token revocation runs while currentUser is still active.
    func reauthenticateForDeletion() async throws -> String? {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.notSignedIn
        }

        // Anonymous users never linked a provider: no recent-login requirement,
        // and nothing to revoke.
        if user.isAnonymous { return nil }

        let providerIDs = user.providerData.map { $0.providerID }

        if providerIDs.contains("apple.com") {
            return try await reauthenticateWithApple(user: user)
        } else if providerIDs.contains("google.com") {
            try await reauthenticateWithGoogle(user: user)
            return nil
        }
        throw AuthError.unsupportedProviderReauth
    }

    func revokeAppleAuthorizationCode(
        _ authCode: String,
        hasCurrentUser: () -> Bool = { Auth.auth().currentUser != nil }
    ) async throws {
        guard hasCurrentUser() else {
            throw AccountDeletionError.notSignedIn
        }
        try await Auth.auth().revokeToken(withAuthorizationCode: authCode)
    }

    private func reauthenticateWithApple(user: FirebaseAuth.User) async throws -> String? {
        guard !isAppleAuthorizationInFlight else {
            throw AuthError.invalidAppleCredential
        }
        isAppleAuthorizationInFlight = true
        let nonce = Self.randomNonce()
        currentNonce = nonce
        defer {
            isAppleAuthorizationInFlight = false
            currentNonce = nil
        }

        let appleIDCredential = try await performAppleAuthorization(nonce: nonce)

        guard
            let tokenData = appleIDCredential.identityToken,
            let idToken = String(data: tokenData, encoding: .utf8)
        else {
            throw AuthError.invalidAppleCredential
        }

        let firebaseCredential = OAuthProvider.appleCredential(
            withIDToken: idToken,
            rawNonce: nonce,
            fullName: appleIDCredential.fullName
        )

        // Satisfy requiresRecentLogin; caller revokes the Apple token while currentUser is live, before deletion.
        try await user.reauthenticate(with: firebaseCredential)

        return try Self.extractAppleAuthorizationCode(from: appleIDCredential.authorizationCode)
    }

    nonisolated static func extractAppleAuthorizationCode(from codeData: Data?) throws -> String {
        guard let codeData,
              let authCode = String(data: codeData, encoding: .utf8),
              !authCode.isEmpty else {
            throw AuthError.missingAppleAuthorizationCode
        }
        return authCode
    }

    private func reauthenticateWithGoogle(user: FirebaseAuth.User) async throws {
        guard !isGoogleAuthorizationInFlight else {
            throw AuthError.invalidGoogleCredential
        }
        isGoogleAuthorizationInFlight = true
        defer { isGoogleAuthorizationInFlight = false }
        guard let clientID = FirebaseApp.app()?.options.clientID else {
            throw AuthError.missingGoogleClientID
        }
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
        guard let presenter = Self.topViewController() else {
            throw AuthError.noPresentingController
        }
        let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presenter, hint: user.email)
        let credential = try Self.makeGoogleCredential(
            idToken: result.user.idToken?.tokenString,
            accessToken: result.user.accessToken.tokenString
        )
        try await user.reauthenticate(with: credential)
        // Google does not require token revocation for App Store account deletion.
    }

    /// Programmatic Sign in with Apple (no SwiftUI button), bridged to async.
    private func performAppleAuthorization(
        nonce: String
    ) async throws -> ASAuthorizationAppleIDCredential {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256(nonce)

        return try await withCheckedThrowingContinuation { continuation in
            let delegate = AppleAuthorizationDelegate(continuation: continuation)
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = delegate
            controller.presentationContextProvider = delegate
            delegate.retainSelf()          // keep alive until the callback fires
            controller.performRequests()
        }
    }
}

enum AuthError: LocalizedError {
    case invalidAppleCredential
    case missingAppleAuthorizationCode
    case invalidGoogleCredential
    case missingGoogleClientID
    case noPresentingController
    case notSignedIn
    case accountExistsWithOtherProvider
    case unsupportedProviderReauth

    var errorDescription: String? {
        switch self {
        case .invalidAppleCredential:
            return String(localized: "Unable to retrieve Apple ID information.")
        case .missingAppleAuthorizationCode:
            return String(localized: "Missing Apple authorization code. Please try signing in with Apple again before deleting your account.")
        case .invalidGoogleCredential:
            return String(localized: "Failed to obtain Google token.")
        case .missingGoogleClientID:
            return String(localized: "Google sign-in is not configured (no clientID).")
        case .noPresentingController:
            return String(localized: "Failed to open login window.")
        case .notSignedIn:
            return String(localized: "You are not signed in.")
        case .accountExistsWithOtherProvider:
            return String(localized: "An account already exists with this email using a different sign-in method. Please sign in with your original provider.")
        case .unsupportedProviderReauth:
            return String(localized: "For security, please sign out and sign in again with Apple or Google before deleting your account.")
        }
    }
}
@MainActor
private final class AppleAuthorizationDelegate: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    private let continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>
    private var selfRef: AppleAuthorizationDelegate?

    init(continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>) {
        self.continuation = continuation
    }

    func retainSelf() { selfRef = self }
    private func releaseSelf() { selfRef = nil }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        defer { releaseSelf() }
        guard let credential = authorization.credential
                as? ASAuthorizationAppleIDCredential else {
            continuation.resume(throwing: AuthError.invalidAppleCredential)
            return
        }
        continuation.resume(returning: credential)
    }

    func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithError error: Error
    ) {
        defer { releaseSelf() }
        continuation.resume(throwing: error)
    }

    func presentationAnchor(
        for controller: ASAuthorizationController
    ) -> ASPresentationAnchor {
        let scene = UIApplication.shared.connectedScenes
            .first { $0.activationState == .foregroundActive } as? UIWindowScene
        return scene?.keyWindow ?? ASPresentationAnchor()
    }
}
