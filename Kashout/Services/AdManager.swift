//
//  AdManager.swift
//  Kashout
//
//  AdMob rewarded video integration
//

import Foundation
import GoogleMobileAds
import SwiftUI

// MARK: - Ad Manager

@MainActor
class AdManager: NSObject, ObservableObject {

    // MARK: - Published Properties

    @Published var isAdReady = false
    @Published var isLoading = false
    @Published var lastError: AdError?

    // MARK: - Private Properties

    private var rewardedAd: GADRewardedAd?
    private var adCompletionHandler: ((Result<Int, AdError>) -> Void)?

    // MARK: - Singleton

    static let shared = AdManager()

    private override init() {
        super.init()
    }

    // MARK: - Configuration

    /// Initialize the Mobile Ads SDK
    func configure() {
        GADMobileAds.sharedInstance().start { status in
            print("AdMob SDK initialized")
            // Log adapter status for debugging
            for (adapter, info) in status.adapterStatusesByClassName {
                print("Adapter: \(adapter), Status: \(info.state.rawValue)")
            }
        }
    }

    // MARK: - Load Ad

    /// Preloads a rewarded ad for faster display
    func loadRewardedAd() {
        guard !isLoading else { return }

        isLoading = true
        lastError = nil

        let adUnitID = Constants.AdMob.rewardedAdUnitID

        GADRewardedAd.load(
            withAdUnitID: adUnitID,
            request: GADRequest()
        ) { [weak self] ad, error in
            guard let self = self else { return }

            Task { @MainActor in
                self.isLoading = false

                if let error = error {
                    print("Failed to load rewarded ad: \(error.localizedDescription)")
                    self.lastError = .loadFailed(error.localizedDescription)
                    self.isAdReady = false
                    return
                }

                self.rewardedAd = ad
                self.rewardedAd?.fullScreenContentDelegate = self
                self.isAdReady = true
                print("Rewarded ad loaded successfully")
            }
        }
    }

    // MARK: - Show Ad

    /// Shows the rewarded ad and returns points on completion
    /// - Parameter completion: Callback with points earned or error
    func showRewardedAd(completion: @escaping (Result<Int, AdError>) -> Void) {
        guard let rewardedAd = rewardedAd else {
            completion(.failure(.notReady))
            // Try to load another ad for next time
            loadRewardedAd()
            return
        }

        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            completion(.failure(.noViewController))
            return
        }

        // Find the topmost presented view controller
        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }

        self.adCompletionHandler = completion

        rewardedAd.present(fromRootViewController: topController) { [weak self] in
            guard let self = self else { return }

            let points = Constants.AdMob.rewardedAdPoints
            print("User earned reward: \(points) points")

            Task { @MainActor in
                self.adCompletionHandler?(.success(points))
                self.adCompletionHandler = nil
            }
        }
    }

    // MARK: - Availability Check

    /// Checks if an ad is ready to show, loading one if needed
    func ensureAdReady() {
        if !isAdReady && !isLoading {
            loadRewardedAd()
        }
    }
}

// MARK: - GADFullScreenContentDelegate

extension AdManager: GADFullScreenContentDelegate {

    nonisolated func adDidDismissFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in
            print("Rewarded ad dismissed")
            self.rewardedAd = nil
            self.isAdReady = false
            // Preload next ad
            self.loadRewardedAd()
        }
    }

    nonisolated func ad(_ ad: GADFullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        Task { @MainActor in
            print("Failed to present rewarded ad: \(error.localizedDescription)")
            self.rewardedAd = nil
            self.isAdReady = false
            self.adCompletionHandler?(.failure(.presentationFailed(error.localizedDescription)))
            self.adCompletionHandler = nil
            // Try to load another ad
            self.loadRewardedAd()
        }
    }

    nonisolated func adWillPresentFullScreenContent(_ ad: GADFullScreenPresentingAd) {
        Task { @MainActor in
            print("Rewarded ad will present")
        }
    }
}

// MARK: - Ad Error

enum AdError: Error, LocalizedError {
    case notReady
    case noViewController
    case loadFailed(String)
    case presentationFailed(String)
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .notReady:
            return "Ad is not ready. Please try again in a moment."
        case .noViewController:
            return "Unable to present ad. Please try again."
        case .loadFailed(let message):
            return "Failed to load ad: \(message)"
        case .presentationFailed(let message):
            return "Failed to show ad: \(message)"
        case .userCancelled:
            return "Ad was cancelled."
        }
    }
}

// MARK: - SwiftUI View Modifier for Ad Preloading

struct AdPreloadModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .onAppear {
                AdManager.shared.ensureAdReady()
            }
    }
}

extension View {
    func preloadAds() -> some View {
        modifier(AdPreloadModifier())
    }
}
