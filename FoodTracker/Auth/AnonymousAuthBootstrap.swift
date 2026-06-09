import Foundation
import FirebaseAuth

actor AnonymousAuthBootstrap {
    static let shared = AnonymousAuthBootstrap()
    
    private init() {}
    
    func ensureSignedIn() async throws -> FirebaseAuth.User {
        if let user = Auth.auth().currentUser {
            return user
        }
        
        let result = try await Auth.auth().signInAnonymously()
        return result.user
    }
}
