//
//  FirebaseBackend.swift
//  Kashout
//
//  Firebase Auth + Firestore implementation of KashoutBackend
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Firebase Backend

@MainActor
final class FirebaseBackend: KashoutBackend {

    // MARK: - Private Properties

    // Lazy so nothing touches Firebase before FirebaseApp.configure()
    private lazy var auth = Auth.auth()
    private lazy var db = Firestore.firestore()
    private var authStateListener: AuthStateDidChangeListenerHandle?

    // MARK: - Auth

    var currentUserID: String? {
        auth.currentUser?.uid
    }

    func observeAuthState(_ handler: @escaping (String?) -> Void) {
        if let listener = authStateListener {
            auth.removeStateDidChangeListener(listener)
        }
        authStateListener = auth.addStateDidChangeListener { _, firebaseUser in
            handler(firebaseUser?.uid)
        }
    }

    func createAccount(email: String, password: String) async throws -> String {
        do {
            let result = try await auth.createUser(withEmail: email, password: password)
            return result.user.uid
        } catch let error as NSError {
            throw Self.mapFirebaseError(error)
        }
    }

    func signIn(email: String, password: String) async throws -> String {
        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            return result.user.uid
        } catch let error as NSError {
            throw Self.mapFirebaseError(error)
        }
    }

    func signOut() throws {
        do {
            try auth.signOut()
        } catch {
            throw AuthError.unknown(error.localizedDescription)
        }
    }

    func sendPasswordReset(email: String) async throws {
        do {
            try await auth.sendPasswordReset(withEmail: email)
        } catch let error as NSError {
            throw Self.mapFirebaseError(error)
        }
    }

    func deleteCurrentAccount() async throws {
        guard let firebaseUser = auth.currentUser else {
            throw AuthError.userNotFound
        }

        do {
            // Delete user document from Firestore
            try await db.collection(Constants.Firebase.usersCollection)
                .document(firebaseUser.uid)
                .delete()

            // Delete Firebase Auth account
            try await firebaseUser.delete()
        } catch let error as NSError {
            throw Self.mapFirebaseError(error)
        }
    }

    // MARK: - Firestore

    func fetchUser(uid: String) async throws -> User? {
        let document = try await db.collection(Constants.Firebase.usersCollection)
            .document(uid)
            .getDocument()

        return try? document.data(as: User.self)
    }

    func saveUser(_ user: User) async throws {
        guard let uid = user.id else { return }

        try db.collection(Constants.Firebase.usersCollection)
            .document(uid)
            .setData(from: user, merge: true)
    }

    func addHistoryEntry(_ entry: LootBoxHistoryEntry) async throws {
        try db.collection(Constants.Firebase.lootBoxHistoryCollection)
            .addDocument(from: entry)
    }

    func addRedemption(_ redemption: Redemption) async throws {
        try db.collection(Constants.Firebase.redemptionsCollection)
            .addDocument(from: redemption)
    }

    func fetchRedemptions(userId: String, limit: Int) async throws -> [Redemption] {
        let snapshot = try await db.collection(Constants.Firebase.redemptionsCollection)
            .whereField("userId", isEqualTo: userId)
            .order(by: "createdAt", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap {
            try? $0.data(as: Redemption.self)
        }
    }

    // MARK: - Error Mapping

    private static func mapFirebaseError(_ error: NSError) -> AuthError {
        guard error.domain == AuthErrorDomain,
              let errorCode = AuthErrorCode(rawValue: error.code) else {
            return .unknown(error.localizedDescription)
        }

        switch errorCode {
        case .invalidEmail:
            return .invalidEmail
        case .weakPassword:
            return .weakPassword
        case .emailAlreadyInUse:
            return .emailInUse
        case .userNotFound:
            return .userNotFound
        case .wrongPassword:
            return .wrongPassword
        case .networkError:
            return .networkError
        default:
            return .unknown(error.localizedDescription)
        }
    }
}
