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

    private var rewardedAd: RewardedAd?
    private var adCompletionHandler: ((Result<Int, AdError>) -> Void)?

    /// Demo mode shows a simulated ad and never contacts an ad network
    let isDemoMode: Bool

    // MARK: - Singleton

    static let shared = AdManager()

    init(environment: AppEnvironment = .current) {
        isDemoMode = environment.isDemo
        super.init()
    }

    // MARK: - Configuration

    /// Initialize the Mobile Ads SDK
    func configure() {
        guard !isDemoMode else {
            isAdReady = true
            return
        }

        MobileAds.shared.start { status in
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
        guard !isDemoMode else {
            isAdReady = true
            return
        }
        guard !isLoading else { return }

        isLoading = true
        lastError = nil

        let adUnitID = Constants.AdMob.rewardedAdUnitID

        RewardedAd.load(
            with: adUnitID,
            request: Request()
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
        if isDemoMode {
            showDemoRewardedAd(completion: completion)
            return
        }

        guard let rewardedAd = rewardedAd else {
            completion(.failure(.notReady))
            // Try to load another ad for next time
            loadRewardedAd()
            return
        }

        guard let topController = topViewController() else {
            completion(.failure(.noViewController))
            return
        }

        self.adCompletionHandler = completion

        rewardedAd.present(from: topController) { [weak self] in
            guard let self = self else { return }

            let points = Constants.AdMob.rewardedAdPoints
            print("User earned reward: \(points) points")

            Task { @MainActor in
                self.adCompletionHandler?(.success(points))
                self.adCompletionHandler = nil
            }
        }
    }

    // MARK: - Demo Ad

    /// Presents a local stand-in for a rewarded video (demo mode only)
    private func showDemoRewardedAd(completion: @escaping (Result<Int, AdError>) -> Void) {
        guard let topController = topViewController() else {
            completion(.failure(.noViewController))
            return
        }

        var hostingController: UIViewController?
        let adView = DemoRewardedAdView { rewardEarned in
            hostingController?.dismiss(animated: true) {
                if rewardEarned {
                    completion(.success(Constants.AdMob.rewardedAdPoints))
                } else {
                    completion(.failure(.userCancelled))
                }
            }
            hostingController = nil
        }

        let controller = UIHostingController(rootView: adView)
        controller.modalPresentationStyle = .fullScreen
        hostingController = controller
        topController.present(controller, animated: true)
    }

    // MARK: - Presentation Helper

    /// Finds the topmost presented view controller
    private func topViewController() -> UIViewController? {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootViewController = windowScene.windows.first?.rootViewController else {
            return nil
        }

        var topController = rootViewController
        while let presented = topController.presentedViewController {
            topController = presented
        }
        return topController
    }

    // MARK: - Availability Check

    /// Checks if an ad is ready to show, loading one if needed
    func ensureAdReady() {
        if !isAdReady && !isLoading {
            loadRewardedAd()
        }
    }
}

// MARK: - FullScreenContentDelegate

extension AdManager: FullScreenContentDelegate {

    nonisolated func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        Task { @MainActor in
            print("Rewarded ad dismissed")
            self.rewardedAd = nil
            self.isAdReady = false
            // Preload next ad
            self.loadRewardedAd()
        }
    }

    nonisolated func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
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

    nonisolated func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
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
