//
//  UserRulesTests.swift
//  KashoutTests
//
//  Cooldowns, daily limits and redemption tiers on the User model
//

import XCTest
@testable import Kashout

final class UserRulesTests: XCTestCase {

    private func makeUser(points: Int = 0, isPro: Bool = false) -> User {
        User(id: "test-user", email: "test@example.com", state: "CA", points: points, isPro: isPro)
    }

    func testNewUserCanOpenBoxAndClaimBonus() {
        let user = makeUser()
        XCTAssertTrue(user.canOpenLootBox)
        XCTAssertTrue(user.canClaimDailyBonus)
        XCTAssertEqual(user.lootBoxCooldownRemaining, 0)
    }

    func testFreeCooldownIsThirtyMinutes() {
        var user = makeUser()
        user.lastLootBoxOpen = Date().addingTimeInterval(-20 * 60)
        XCTAssertFalse(user.canOpenLootBox)
        XCTAssertEqual(user.lootBoxCooldownRemaining, 10 * 60, accuracy: 5)

        user.lastLootBoxOpen = Date().addingTimeInterval(-31 * 60)
        XCTAssertTrue(user.canOpenLootBox)
    }

    func testProCooldownIsFifteenMinutes() {
        var user = makeUser(isPro: true)
        user.lastLootBoxOpen = Date().addingTimeInterval(-16 * 60)
        XCTAssertTrue(user.canOpenLootBox)

        user.lastLootBoxOpen = Date().addingTimeInterval(-10 * 60)
        XCTAssertFalse(user.canOpenLootBox)
    }

    func testDailyBonusCooldown() {
        var user = makeUser()
        user.lastDailyBonus = Date().addingTimeInterval(-23 * 3600)
        XCTAssertFalse(user.canClaimDailyBonus)

        user.lastDailyBonus = Date().addingTimeInterval(-25 * 3600)
        XCTAssertTrue(user.canClaimDailyBonus)
    }

    func testRewardedAdDailyLimitResetsOnNewDay() {
        var user = makeUser()
        user.rewardedAdsWatchedToday = Constants.AdMob.maxDailyRewardedAds
        user.lastAdWatchDate = Date()
        XCTAssertFalse(user.canWatchRewardedAd)
        XCTAssertEqual(user.remainingRewardedAds, 0)

        user.lastAdWatchDate = Calendar.current.date(byAdding: .day, value: -1, to: Date())
        XCTAssertTrue(user.canWatchRewardedAd)
        XCTAssertEqual(user.remainingRewardedAds, Constants.AdMob.maxDailyRewardedAds)
    }

    func testRedemptionTiers() {
        XCTAssertTrue(makeUser(points: 9_999).availableRedemptionTiers.isEmpty)
        XCTAssertNil(makeUser(points: 9_999).highestAvailableTier)
        XCTAssertEqual(makeUser(points: 10_000).availableRedemptionTiers, [.five])
        XCTAssertEqual(makeUser(points: 20_000).highestAvailableTier, .ten)
        XCTAssertEqual(makeUser(points: 75_000).highestAvailableTier, .twentyFive)
        XCTAssertEqual(Constants.RedemptionTier.twentyFive.displayName, "$25 Gift Card")
    }

    func testRestrictedStatesAreBlockedAndNotOffered() {
        XCTAssertTrue(User(email: "a@example.com", state: "TN").isInRestrictedState)
        XCTAssertFalse(User(email: "a@example.com", state: "CA").isInRestrictedState)
        XCTAssertTrue(Constants.restrictedStates.isDisjoint(with: Constants.allowedStates))
        XCTAssertFalse(Constants.restrictedStates.contains(Constants.Demo.accountState))
    }
}
