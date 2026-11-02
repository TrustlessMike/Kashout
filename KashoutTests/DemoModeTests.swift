//
//  DemoModeTests.swift
//  KashoutTests
//
//  Demo-mode detection and the in-memory backend driving the view models
//

import XCTest
@testable import Kashout

@MainActor
final class DemoModeTests: XCTestCase {

    // MARK: - Environment Detection

    func testDemoModeWithoutFirebaseConfig() {
        XCTAssertEqual(AppEnvironment.detect(hasFirebaseConfig: false, arguments: []), .demo)
        XCTAssertEqual(AppEnvironment.detect(hasFirebaseConfig: true, arguments: []), .firebase)
        XCTAssertEqual(
            AppEnvironment.detect(hasFirebaseConfig: true, arguments: [AppEnvironment.forceDemoArgument]),
            .demo
        )
    }

    func testTestHostRunsInDemoMode() {
        // The repository ships no GoogleService-Info.plist
        XCTAssertEqual(AppEnvironment.current, .demo)
        XCTAssertTrue(AuthViewModel.shared.isDemoMode)
        XCTAssertTrue(StoreManager.shared.isDemoMode)
        XCTAssertTrue(AdManager.shared.isDemoMode)
    }

    // MARK: - Auth

    func testStartsSignedOut() async {
        let auth = AuthViewModel(backend: DemoBackend())
        await settle()
        XCTAssertEqual(auth.authState, .unauthenticated)
    }

    func testDemoAccountSignIn() async throws {
        let auth = AuthViewModel(backend: DemoBackend())
        try await auth.signInDemoAccount()

        let user = try XCTUnwrap(auth.authState.user)
        XCTAssertEqual(user.email, Constants.Demo.accountEmail)
        XCTAssertEqual(user.points, Constants.Demo.startingPoints)
    }

    func testSignUpCreatesAuthenticatedUser() async throws {
        let backend = DemoBackend(seedDemoAccount: false)
        let auth = AuthViewModel(backend: backend)

        try await auth.signUp(email: "new@example.com", password: "secret1", state: "NY")
        await settle()

        let user = try XCTUnwrap(auth.authState.user)
        XCTAssertEqual(user.email, "new@example.com")
        XCTAssertEqual(user.points, 0)
        XCTAssertEqual(backend.users.count, 1)
    }

    func testSignUpRejectsRestrictedState() async {
        let auth = AuthViewModel(backend: DemoBackend())
        do {
            try await auth.signUp(email: "x@example.com", password: "secret1", state: "SC")
            XCTFail("Expected restricted state error")
        } catch AuthError.restrictedState(let name) {
            XCTAssertEqual(name, "South Carolina")
        } catch {
            XCTFail("Unexpected error \(error)")
        }
    }

    func testSignInChecksPassword() async throws {
        let backend = DemoBackend(seedDemoAccount: false)
        _ = try await backend.createAccount(email: "user@example.com", password: "right-password")
        try backend.signOut()

        do {
            _ = try await backend.signIn(email: "user@example.com", password: "wrong-password")
            XCTFail("Expected wrong password")
        } catch AuthError.wrongPassword {
            // expected
        }

        let uid = try await backend.signIn(email: "USER@example.com", password: "right-password")
        XCTAssertEqual(backend.currentUserID, uid)
    }

    func testSignOutReturnsToOnboarding() async throws {
        let auth = AuthViewModel(backend: DemoBackend())
        try await auth.signInDemoAccount()
        try auth.signOut()
        await settle()
        XCTAssertEqual(auth.authState, .unauthenticated)
    }

    // MARK: - Rewards

    func testOpeningBoxAwardsPointsAndStartsCooldown() async throws {
        let backend = DemoBackend()
        let auth = AuthViewModel(backend: backend)
        try await auth.signInDemoAccount()
        let viewModel = LootBoxViewModel(authViewModel: auth)
        let startingPoints = viewModel.points

        XCTAssertTrue(viewModel.canOpenBox)
        await viewModel.openLootBox()

        let result = try XCTUnwrap(viewModel.currentResult)
        XCTAssertEqual(viewModel.points, startingPoints + result.points)
        XCTAssertEqual(viewModel.user?.totalBoxesOpened, 1)
        XCTAssertFalse(viewModel.canOpenBox)
        XCTAssertEqual(backend.historyEntries.count, 1)
        XCTAssertEqual(backend.historyEntries.first?.pointsAwarded, result.points)

        // Second open is blocked by the cooldown
        await viewModel.openLootBox()
        XCTAssertEqual(viewModel.user?.totalBoxesOpened, 1)
        XCTAssertNotNil(viewModel.errorMessage)
    }

    func testDailyBonusIsDoubledForPro() async throws {
        let auth = AuthViewModel(backend: DemoBackend())
        try await auth.signInDemoAccount()
        let viewModel = LootBoxViewModel(authViewModel: auth)
        let startingPoints = viewModel.points

        await viewModel.updateProStatus(isPro: true)
        await viewModel.claimDailyBonus()

        XCTAssertEqual(viewModel.points, startingPoints + Constants.dailyBonusPoints * 2)
        XCTAssertFalse(viewModel.canClaimDailyBonus)
    }

    func testRewardedAdIsCounted() async throws {
        let auth = AuthViewModel(backend: DemoBackend())
        try await auth.signInDemoAccount()
        let viewModel = LootBoxViewModel(authViewModel: auth)
        let startingPoints = viewModel.points

        await viewModel.recordRewardedAd(points: Constants.AdMob.rewardedAdPoints)

        XCTAssertEqual(viewModel.points, startingPoints + Constants.AdMob.rewardedAdPoints)
        XCTAssertEqual(viewModel.remainingAds, Constants.AdMob.maxDailyRewardedAds - 1)
    }

    func testRedemptionDeductsPointsAndIsMarkedAsDemo() async throws {
        let backend = DemoBackend()
        let auth = AuthViewModel(backend: backend)
        try await auth.signInDemoAccount()
        let viewModel = LootBoxViewModel(authViewModel: auth)

        await viewModel.redeemPoints(tier: .five, giftCardType: .amazon)

        XCTAssertEqual(viewModel.points, Constants.Demo.startingPoints - Constants.RedemptionTier.five.rawValue)
        XCTAssertEqual(viewModel.redemptionHistory.count, 1)
        XCTAssertEqual(viewModel.redemptionHistory.first?.status, .pending)
        XCTAssertNotNil(viewModel.redemptionHistory.first?.id)
        XCTAssertTrue(viewModel.successMessage?.contains("demo mode") ?? false)

        // Not enough points left for another $5 card
        await viewModel.redeemPoints(tier: .five, giftCardType: .amazon)
        XCTAssertEqual(viewModel.errorMessage, "Not enough points.")
        XCTAssertEqual(backend.redemptions.count, 1)
    }

    // MARK: - Subscriptions and Ads

    func testDemoSubscriptionUnlocksProLocally() async {
        let store = StoreManager(environment: .demo)
        XCTAssertEqual(store.plans.map(\.id), [
            Constants.StoreKit.proMonthlyProductID,
            Constants.StoreKit.proYearlyProductID
        ])
        XCTAssertFalse(store.isProSubscriber)

        let success = await store.purchase(planID: Constants.StoreKit.proMonthlyProductID)

        XCTAssertTrue(success)
        XCTAssertTrue(store.isProSubscriber)
    }

    func testDemoAdsAreAlwaysReady() {
        let ads = AdManager(environment: .demo)
        ads.configure()
        XCTAssertTrue(ads.isAdReady)
        XCTAssertFalse(ads.isLoading)
    }

    func testDebugBuildsUseGoogleTestAdUnit() {
        // Google's published sample rewarded ad unit
        XCTAssertEqual(Constants.AdMob.rewardedAdUnitID, "ca-app-pub-3940256099942544/1712485313")
    }

    // MARK: - Helpers

    /// Lets queued main-actor tasks (auth listener callbacks) run
    private func settle() async {
        for _ in 0..<5 {
            await Task.yield()
        }
    }
}
