//
//  AppEnvironment.swift
//  Kashout
//
//  Chooses between the Firebase backend and the local demo mode
//

import Foundation

// MARK: - App Environment

enum AppEnvironment: Equatable {

    /// Firebase Auth/Firestore, real StoreKit and Google Mobile Ads test units
    case firebase

    /// Local in-memory data, mock account, simulated ads and purchases
    case demo

    /// Launch argument that forces demo mode even when a Firebase config exists
    static let forceDemoArgument = "-KashoutDemoMode"

    /// Name of the Firebase configuration file expected in the app bundle
    static let firebaseConfigResource = "GoogleService-Info"

    /// The environment for this launch
    static let current: AppEnvironment = detect(
        hasFirebaseConfig: Bundle.main.path(forResource: firebaseConfigResource, ofType: "plist") != nil,
        arguments: ProcessInfo.processInfo.arguments
    )

    /// Demo mode runs whenever there is no Firebase config, or when forced
    static func detect(hasFirebaseConfig: Bool, arguments: [String]) -> AppEnvironment {
        if arguments.contains(forceDemoArgument) || !hasFirebaseConfig {
            return .demo
        }
        return .firebase
    }

    var isDemo: Bool {
        self == .demo
    }
}
