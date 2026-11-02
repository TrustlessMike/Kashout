//
//  AuthViewModel.swift
//  Kashout
//
//  Authentication view model with state-based blocking
//

import Foundation

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

    // MARK: - Backend

    /// Firebase in normal builds, in-memory data in demo mode
    let backend: KashoutBackend

    /// Whether the app is running on local demo data
    var isDemoMode: Bool {
        backend is DemoBackend
    }

    // MARK: - Singleton

    static let shared = AuthViewModel(backend: AppEnvironment.current.makeBackend())

    init(backend: KashoutBackend) {
        self.backend = backend
        setupAuthStateListener()
    }

    // MARK: - Auth State Listener

    private func setupAuthStateListener() {
        backend.observeAuthState { [weak self] uid in
            guard let self = self else { return }

            Task { @MainActor in
                if let uid = uid {
                    await self.fetchUser(uid: uid)
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
        defer { isLoading = false }

        // Create the account
        let uid = try await backend.createAccount(email: email, password: password)

        // Create the user document
        let newUser = User(
            id: uid,
            email: email,
            state: state
        )

        try await backend.saveUser(newUser)

        authState = .authenticated(newUser)
    }

    // MARK: - Sign In

    /// Signs in an existing user
    /// - Parameters:
    ///   - email: User's email address
    ///   - password: User's password
    func signIn(email: String, password: String) async throws {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let uid = try await backend.signIn(email: email, password: password)
        await fetchUser(uid: uid)
    }

    /// Signs in the ready-made demo account (demo mode only)
    func signInDemoAccount() async throws {
        guard let demoBackend = backend as? DemoBackend else {
            throw AuthError.unknown("The demo account is only available in demo mode.")
        }

        let uid = try demoBackend.signInDemoAccount()
        await fetchUser(uid: uid)
    }

    // MARK: - Sign Out

    /// Signs out the current user
    func signOut() throws {
        try backend.signOut()
        authState = .unauthenticated
    }

    // MARK: - Fetch User

    /// Fetches the user document from the backend
    private func fetchUser(uid: String) async {
        do {
            guard let user = try await backend.fetchUser(uid: uid) else {
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

    /// Updates the user document in the backend
    func updateUser(_ user: User) async throws {
        guard user.id != nil else { return }

        try await backend.saveUser(user)

        if case .authenticated = authState {
            authState = .authenticated(user)
        }
    }

    // MARK: - Password Reset

    /// Sends a password reset email
    func sendPasswordReset(email: String) async throws {
        try await backend.sendPasswordReset(email: email)
    }

    // MARK: - Delete Account

    /// Deletes the user's account and data
    func deleteAccount() async throws {
        try await backend.deleteCurrentAccount()
        authState = .unauthenticated
    }

    // MARK: - Refresh User

    /// Refreshes the current user data from the backend
    func refreshUser() async {
        guard let uid = backend.currentUserID else { return }
        await fetchUser(uid: uid)
    }
}
