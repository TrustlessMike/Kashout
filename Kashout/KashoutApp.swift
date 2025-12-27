//
//  KashoutApp.swift
//  Kashout
//
//  Main app entry point
//

import SwiftUI
import FirebaseCore
import GoogleMobileAds

@main
struct KashoutApp: App {

    // MARK: - State

    @StateObject private var authViewModel = AuthViewModel.shared
    @StateObject private var storeManager = StoreManager.shared

    // MARK: - Initialization

    init() {
        // Configure Firebase
        FirebaseApp.configure()

        // Configure AdMob
        AdManager.shared.configure()
    }

    // MARK: - Body

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(storeManager)
        }
    }
}

// MARK: - Content View (Root Navigation)

struct ContentView: View {
    @EnvironmentObject private var authViewModel: AuthViewModel

    var body: some View {
        Group {
            switch authViewModel.authState {
            case .unknown:
                // Loading state
                LoadingView()

            case .unauthenticated:
                // Show onboarding/auth
                OnboardingView()

            case .authenticated:
                // Main app
                HomeView()

            case .blockedState(let stateName):
                // Blocked state screen
                BlockedStateView(stateName: stateName)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authViewModel.authState)
    }
}

// MARK: - Loading View

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                Image(systemName: "gift.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.linearGradient(
                        colors: [.purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                ProgressView()
                    .tint(.purple)
            }
        }
    }
}

// MARK: - Blocked State View

struct BlockedStateView: View {
    let stateName: String
    @StateObject private var authViewModel = AuthViewModel.shared

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Not Available in \(stateName)")
                .font(.title2.bold())
                .multilineTextAlignment(.center)

            Text("We're sorry, but Kashout is not available in your state due to local regulations regarding randomized reward systems.")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Spacer()

            Button {
                try? authViewModel.signOut()
            } label: {
                Text("Sign Out")
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.purple)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 40)
        }
    }
}

// MARK: - AuthState Equatable Extension

extension AuthState {
    static func == (lhs: AuthState, rhs: AuthState) -> Bool {
        switch (lhs, rhs) {
        case (.unknown, .unknown):
            return true
        case (.unauthenticated, .unauthenticated):
            return true
        case (.authenticated(let user1), .authenticated(let user2)):
            return user1.id == user2.id
        case (.blockedState(let state1), .blockedState(let state2)):
            return state1 == state2
        default:
            return false
        }
    }
}
