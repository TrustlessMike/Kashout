//
//  DemoBackend.swift
//  Kashout
//
//  In-memory KashoutBackend for demo mode and unit tests.
//  Nothing leaves the device and nothing survives an app restart.
//

import Foundation

// MARK: - Demo Backend

@MainActor
final class DemoBackend: KashoutBackend {

    // MARK: - State

    private(set) var currentUserID: String?
    private(set) var users: [String: User] = [:]
    private(set) var historyEntries: [LootBoxHistoryEntry] = []
    private(set) var redemptions: [Redemption] = []

    /// Demo accounts keyed by lowercased email
    private var accounts: [String: (uid: String, password: String)] = [:]
    private var authStateHandler: ((String?) -> Void)?
    private var nextID = 1

    // MARK: - Initialization

    /// - Parameter seedDemoAccount: Adds the ready-made demo account
    ///   (`Constants.Demo.accountEmail`) used by "Continue with Demo Account"
    init(seedDemoAccount: Bool = true) {
        if seedDemoAccount {
            let uid = makeID(prefix: "demo-user")
            accounts[Constants.Demo.accountEmail] = (uid, "")
            users[uid] = User(
                id: uid,
                email: Constants.Demo.accountEmail,
                state: Constants.Demo.accountState,
                points: Constants.Demo.startingPoints
            )
        }
    }

    // MARK: - Demo Account

    /// Signs in the seeded demo account without a password
    func signInDemoAccount() throws -> String {
        guard let account = accounts[Constants.Demo.accountEmail] else {
            throw AuthError.userNotFound
        }
        setCurrentUser(account.uid)
        return account.uid
    }

    // MARK: - Auth

    func observeAuthState(_ handler: @escaping (String?) -> Void) {
        authStateHandler = handler
        handler(currentUserID)
    }

    func createAccount(email: String, password: String) async throws -> String {
        let key = email.lowercased()

        guard key.contains("@"), key.contains(".") else {
            throw AuthError.invalidEmail
        }
        guard password.count >= 6 else {
            throw AuthError.weakPassword
        }
        guard accounts[key] == nil else {
            throw AuthError.emailInUse
        }

        let uid = makeID(prefix: "demo-user")
        accounts[key] = (uid, password)
        setCurrentUser(uid)
        return uid
    }

    func signIn(email: String, password: String) async throws -> String {
        guard let account = accounts[email.lowercased()] else {
            throw AuthError.userNotFound
        }
        // The seeded demo account has no password
        guard account.password.isEmpty || account.password == password else {
            throw AuthError.wrongPassword
        }
        setCurrentUser(account.uid)
        return account.uid
    }

    func signOut() throws {
        setCurrentUser(nil)
    }

    func sendPasswordReset(email: String) async throws {
        throw AuthError.unknown("Password reset emails are not sent in demo mode.")
    }

    func deleteCurrentAccount() async throws {
        guard let uid = currentUserID else {
            throw AuthError.userNotFound
        }
        users[uid] = nil
        accounts = accounts.filter { $0.value.uid != uid }
        setCurrentUser(nil)
    }

    // MARK: - Data

    func fetchUser(uid: String) async throws -> User? {
        users[uid]
    }

    func saveUser(_ user: User) async throws {
        guard let uid = user.id else { return }
        users[uid] = user
    }

    func addHistoryEntry(_ entry: LootBoxHistoryEntry) async throws {
        var entry = entry
        entry.id = makeID(prefix: "demo-history")
        historyEntries.append(entry)
    }

    func addRedemption(_ redemption: Redemption) async throws {
        var redemption = redemption
        redemption.id = makeID(prefix: "demo-redemption")
        redemptions.append(redemption)
    }

    func fetchRedemptions(userId: String, limit: Int) async throws -> [Redemption] {
        Array(
            redemptions
                .filter { $0.userId == userId }
                .sorted { $0.createdAt > $1.createdAt }
                .prefix(limit)
        )
    }

    // MARK: - Helpers

    private func setCurrentUser(_ uid: String?) {
        currentUserID = uid
        authStateHandler?(uid)
    }

    private func makeID(prefix: String) -> String {
        defer { nextID += 1 }
        return "\(prefix)-\(nextID)"
    }
}
