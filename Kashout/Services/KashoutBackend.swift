//
//  KashoutBackend.swift
//  Kashout
//
//  Account and data storage abstraction (Firebase or local demo)
//

import Foundation

// MARK: - Backend Protocol

/// Everything the view models need from an account/data service.
/// `FirebaseBackend` talks to Firebase Auth and Firestore;
/// `DemoBackend` keeps everything in memory for demo mode and tests.
@MainActor
protocol KashoutBackend: AnyObject {

    /// UID of the signed-in account, if any
    var currentUserID: String? { get }

    /// Registers a handler that is called with the signed-in UID (or nil)
    /// now and whenever the auth state changes
    func observeAuthState(_ handler: @escaping (String?) -> Void)

    /// Creates an account and signs it in, returning its UID
    func createAccount(email: String, password: String) async throws -> String

    /// Signs in an existing account, returning its UID
    func signIn(email: String, password: String) async throws -> String

    func signOut() throws

    func sendPasswordReset(email: String) async throws

    /// Deletes the signed-in account and its user document
    func deleteCurrentAccount() async throws

    func fetchUser(uid: String) async throws -> User?

    func saveUser(_ user: User) async throws

    func addHistoryEntry(_ entry: LootBoxHistoryEntry) async throws

    func addRedemption(_ redemption: Redemption) async throws

    func fetchRedemptions(userId: String, limit: Int) async throws -> [Redemption]
}

// MARK: - Backend Selection

extension AppEnvironment {

    /// Creates the backend that matches this environment
    @MainActor
    func makeBackend() -> KashoutBackend {
        switch self {
        case .firebase:
            return FirebaseBackend()
        case .demo:
            return DemoBackend()
        }
    }
}
