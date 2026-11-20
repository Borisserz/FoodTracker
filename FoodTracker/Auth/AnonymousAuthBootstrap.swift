import Foundation
import FirebaseAuth

actor AnonymousAuthBootstrap {
    static let shared = AnonymousAuthBootstrap()

    private var inFlightTask: Task<FirebaseAuth.User, Error>?
    private var inFlightGeneration: UInt64 = 0
    private var activeInteractiveLeases: [UUID: Date] = [:]
    private var endedEarlyLeases: Set<UUID> = []
    private let defaultLeaseTTL: TimeInterval = 120

    private init() {}

    @discardableResult
    func beginInteractiveSignIn(id: UUID = UUID(), startedAt: Date = Date()) -> UUID {
        if endedEarlyLeases.remove(id) == nil {
            activeInteractiveLeases[id] = startedAt
        }
        inFlightGeneration &+= 1
        inFlightTask?.cancel()
        inFlightTask = nil
        return id
    }

    func pruneExpiredLeases(now: Date = Date(), ttl: TimeInterval = 120) {
        activeInteractiveLeases = activeInteractiveLeases.filter { _, startedAt in
            now.timeIntervalSince(startedAt) < ttl
        }
    }

    func endInteractiveSignIn(_ id: UUID) {
        if activeInteractiveLeases.removeValue(forKey: id) == nil {
            if endedEarlyLeases.count > 64 {
                endedEarlyLeases.removeAll()
            }
            endedEarlyLeases.insert(id)
        }
    }

    func activeInteractiveLeaseCountForTesting() -> Int {
        pruneExpiredLeases(ttl: defaultLeaseTTL)
        return activeInteractiveLeases.count
    }

    func resetLeasesForTesting() {
        activeInteractiveLeases.removeAll()
        endedEarlyLeases.removeAll()
    }

    func ensureSignedIn() async throws -> FirebaseAuth.User {
        if let user = Auth.auth().currentUser {
            return user
        }

        if let existingTask = inFlightTask {
            return try await existingTask.value
        }

        inFlightGeneration &+= 1
        let capturedGeneration = inFlightGeneration
        let task = Task<FirebaseAuth.User, Error> {
            // Yield once and re-check so concurrent Apple/Google sign-in isn't overwritten on startup.
            await Task.yield()
            if let existing = Auth.auth().currentUser {
                return existing
            }
            var waitCycles = 0
            pruneExpiredLeases(ttl: defaultLeaseTTL)
            while !activeInteractiveLeases.isEmpty && waitCycles < 1200 {
                try Task.checkCancellation()
                try await Task.sleep(for: .milliseconds(50))
                waitCycles += 1
                pruneExpiredLeases(ttl: defaultLeaseTTL)
                if let existing = Auth.auth().currentUser {
                    return existing
                }
            }
            try Task.checkCancellation()
            let result = try await Auth.auth().signInAnonymously()
            return result.user
        }
        inFlightTask = task
        defer {
            if inFlightGeneration == capturedGeneration {
                inFlightTask = nil
            }
        }
        return try await task.value
    }
}
