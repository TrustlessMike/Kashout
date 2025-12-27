//
//  AuthViewModel.swift
//  Kashout
//
//  Authentication view model with state-based blocking
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

// MARK: - Auth State

enum AuthState: Equatable {
    case unknown
    case unauthenticated
    case authenticated(User)
    case blockedState(String) // User is in a restricted state

    var isAuthenticated: Bool {
        if case .authenticated = self { return true }
        return false
    }

    var isBlocked: Bool {
        if case .blockedState = self { return true }
        return false
    }

    var user: User? {
        if case .authenticated(let user) = self { return user }
        return nil
    }
}

// MARK: - Auth Error

enum AuthError: Error, LocalizedError {
    case invalidEmail
    case weakPassword
    case emailInUse
    case userNotFound
    case wrongPassword
    case networkError
    case restrictedState(String)
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidEmail:
            return "Please enter a valid email address."
        case .weakPassword:
            return "Password must be at least 6 characters."
        case .emailInUse:
            return "This email is already registered."
        case .userNotFound:
            return "No account found with this email."
        case .wrongPassword:
            return "Incorrect password."
        case .networkError:
            return "Network error. Please check your connection."
        case .restrictedState(let state):
            return "Sorry, Kashout is not available in \(state) due to local regulations."
        case .unknown(let message):
            return message
        }
    }
}

// MARK: - Auth View Model

@MainActor
class AuthViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var authState: AuthState = .unknown
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Private Properties

    private let auth = Auth.auth()
    private let db = Firestore.firestore()
    private var authStateListener: AuthStateDidChangeListenerHandle?

    // MARK: - Singleton

    static let shared = AuthViewModel()

    private init() {
        setupAuthStateListener()
    }

    deinit {
        if let listener = authStateListener {
            auth.removeStateDidChangeListener(listener)
        }
    }

    // MARK: - Auth State Listener

    private func setupAuthStateListener() {
        authStateListener = auth.addStateDidChangeListener { [weak self] _, firebaseUser in
            guard let self = self else { return }

            Task { @MainActor in
                if let firebaseUser = firebaseUser {
                    await self.fetchUser(uid: firebaseUser.uid)
                } else {
                    self.authState = .unauthenticated
                }
            }
        }
    }

    // MARK: - Sign Up

    /// Creates a new user account
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    ///   - state: User's US state abbreviation
    func signUp(email: String, password: String, state: String) async throws {
        // Check if state is restricted
        if Constants.restrictedStates.contains(state) {
            let stateName = Constants.stateNames[state] ?? state
            throw AuthError.restrictedState(stateName)
        }

        isLoading = true
        errorMessage = nil

        do {
            // Create Firebase Auth user
            let result = try await auth.createUser(withEmail: email, password: password)

            // Create user document in Firestore
            let newUser = User(
                id: result.user.uid,
                email: email,
                state: state
            )

            try db.collection(Constants.Firebase.usersCollection)
                .document(result.user.uid)
                .setData(from: newUser)

            authState = .authenticated(newUser)
            isLoading = false

        } catch let error as NSError {
            isLoading = false
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Sign In

    /// Signs in an existing user
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil

        do {
            let result = try await auth.signIn(withEmail: email, password: password)
            await fetchUser(uid: result.user.uid)
            isLoading = false

        } catch let error as NSError {
            isLoading = false
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Sign Out

    /// Signs out the current user
    func signOut() throws {
        do {
            try auth.signOut()
            authState = .unauthenticated
        } catch {
            throw AuthError.unknown(error.localizedDescription)
        }
    }

    // MARK: - Fetch User

    /// Fetches the user document from Firestore
    private func fetchUser(uid: String) async {
        do {
            let document = try await db.collection(Constants.Firebase.usersCollection)
                .document(uid)
                .getDocument()

            guard let user = try? document.data(as: User.self) else {
                authState = .unauthenticated
                return
            }

            // Check if user is in a restricted state
            if user.isInRestrictedState {
                let stateName = Constants.stateNames[user.state] ?? user.state
                authState = .blockedState(stateName)
            } else {
                authState = .authenticated(user)
            }

        } catch {
            print("Failed to fetch user: \(error)")
            authState = .unauthenticated
        }
    }

    // MARK: - Update User

    /// Updates the user document in Firestore
    func updateUser(_ user: User) async throws {
        guard let uid = user.id else { return }

        try db.collection(Constants.Firebase.usersCollection)
            .document(uid)
            .setData(from: user, merge: true)

        if case .authenticated = authState {
            authState = .authenticated(user)
        }
    }

    // MARK: - Password Reset

    /// Sends a password reset email
    func sendPasswordReset(email: String) async throws {
        do {
            try await auth.sendPasswordReset(withEmail: email)
        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Delete Account

    /// Deletes the user's account and data
    func deleteAccount() async throws {
        guard let firebaseUser = auth.currentUser,
              let uid = firebaseUser.uid as String? else {
            throw AuthError.userNotFound
        }

        do {
            // Delete user document from Firestore
            try await db.collection(Constants.Firebase.usersCollection)
                .document(uid)
                .delete()

            // Delete Firebase Auth account
            try await firebaseUser.delete()

            authState = .unauthenticated

        } catch let error as NSError {
            throw mapFirebaseError(error)
        }
    }

    // MARK: - Error Mapping

    private func mapFirebaseError(_ error: NSError) -> AuthError {
        guard let errorCode = AuthErrorCode.Code(rawValue: error.code) else {
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

    // MARK: - Refresh User

    /// Refreshes the current user data from Firestore
    func refreshUser() async {
        guard let uid = auth.currentUser?.uid else { return }
        await fetchUser(uid: uid)
    }
}
