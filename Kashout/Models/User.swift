//
//  User.swift
//  Kashout
//
//  User account and redemption data models
//

import Foundation
import FirebaseFirestore

// MARK: - User Model

struct User: Codable, Identifiable {
    @DocumentID var id: String?
    var email: String
    var state: String
    var points: Int
    var isPro: Bool
    var createdAt: Date
    var lastDailyBonus: Date?
    var lastLootBoxOpen: Date?
    var totalBoxesOpened: Int
    var totalPointsEarned: Int
    var rewardedAdsWatchedToday: Int
    var lastAdWatchDate: Date?

    init(
        id: String? = nil,
        email: String,
        state: String,
        points: Int = 0,
        isPro: Bool = false,
        createdAt: Date = Date(),
        lastDailyBonus: Date? = nil,
        lastLootBoxOpen: Date? = nil,
        totalBoxesOpened: Int = 0,
        totalPointsEarned: Int = 0,
        rewardedAdsWatchedToday: Int = 0,
        lastAdWatchDate: Date? = nil
    ) {
        self.id = id
        self.email = email
        self.state = state
        self.points = points
        self.isPro = isPro
        self.createdAt = createdAt
        self.lastDailyBonus = lastDailyBonus
        self.lastLootBoxOpen = lastLootBoxOpen
        self.totalBoxesOpened = totalBoxesOpened
        self.totalPointsEarned = totalPointsEarned
        self.rewardedAdsWatchedToday = rewardedAdsWatchedToday
        self.lastAdWatchDate = lastAdWatchDate
    }

    /// Check if user is in a restricted state
    var isInRestrictedState: Bool {
        Constants.restrictedStates.contains(state)
    }

    /// Check if daily bonus is available
    var canClaimDailyBonus: Bool {
        guard let lastBonus = lastDailyBonus else { return true }
        let hoursSinceLastBonus = Date().timeIntervalSince(lastBonus) / 3600
        return hoursSinceLastBonus >= Double(Constants.dailyBonusCooldownHours)
    }

    /// Check if user can open a loot box (cooldown elapsed)
    var canOpenLootBox: Bool {
        guard let lastOpen = lastLootBoxOpen else { return true }
        let minutesSinceLastOpen = Date().timeIntervalSince(lastOpen) / 60
        let cooldown = isPro ? Constants.proBoxCooldownMinutes : Constants.freeBoxCooldownMinutes
        return minutesSinceLastOpen >= Double(cooldown)
    }

    /// Time remaining until next loot box (in seconds)
    var lootBoxCooldownRemaining: TimeInterval {
        guard let lastOpen = lastLootBoxOpen else { return 0 }
        let cooldownMinutes = isPro ? Constants.proBoxCooldownMinutes : Constants.freeBoxCooldownMinutes
        let cooldownSeconds = Double(cooldownMinutes * 60)
        let elapsed = Date().timeIntervalSince(lastOpen)
        return max(0, cooldownSeconds - elapsed)
    }

    /// Check if user can watch another rewarded ad today
    var canWatchRewardedAd: Bool {
        // Reset counter if it's a new day
        if let lastAdDate = lastAdWatchDate, !Calendar.current.isDateInToday(lastAdDate) {
            return true
        }
        return rewardedAdsWatchedToday < Constants.AdMob.maxDailyRewardedAds
    }

    /// Remaining rewarded ads for today
    var remainingRewardedAds: Int {
        if let lastAdDate = lastAdWatchDate, !Calendar.current.isDateInToday(lastAdDate) {
            return Constants.AdMob.maxDailyRewardedAds
        }
        return max(0, Constants.AdMob.maxDailyRewardedAds - rewardedAdsWatchedToday)
    }

    /// Available redemption tiers based on current points
    var availableRedemptionTiers: [Constants.RedemptionTier] {
        Constants.RedemptionTier.allCases.filter { points >= $0.rawValue }
    }

    /// Highest available redemption tier
    var highestAvailableTier: Constants.RedemptionTier? {
        availableRedemptionTiers.max(by: { $0.rawValue < $1.rawValue })
    }
}

// MARK: - Redemption Model

struct Redemption: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var pointsRedeemed: Int
    var dollarValue: Int
    var giftCardType: GiftCardType
    var status: RedemptionStatus
    var createdAt: Date
    var processedAt: Date?
    var giftCardCode: String?

    enum GiftCardType: String, Codable, CaseIterable {
        case amazon = "Amazon"
        case apple = "Apple"
        case google = "Google Play"
        case visa = "Visa"
        case starbucks = "Starbucks"
        case target = "Target"
        case walmart = "Walmart"

        var iconName: String {
            switch self {
            case .amazon: return "cart.fill"
            case .apple: return "apple.logo"
            case .google: return "play.rectangle.fill"
            case .visa: return "creditcard.fill"
            case .starbucks: return "cup.and.saucer.fill"
            case .target: return "target"
            case .walmart: return "building.2.fill"
            }
        }
    }

    enum RedemptionStatus: String, Codable {
        case pending = "pending"
        case processing = "processing"
        case completed = "completed"
        case failed = "failed"

        var displayText: String {
            switch self {
            case .pending: return "Pending"
            case .processing: return "Processing"
            case .completed: return "Completed"
            case .failed: return "Failed"
            }
        }

        var color: String {
            switch self {
            case .pending: return "orange"
            case .processing: return "blue"
            case .completed: return "green"
            case .failed: return "red"
            }
        }
    }
}

// MARK: - Loot Box History Entry

struct LootBoxHistoryEntry: Codable, Identifiable {
    @DocumentID var id: String?
    var userId: String
    var pointsAwarded: Int
    var rarity: LootBoxRarity
    var openedAt: Date
    var wasProSubscriber: Bool

    init(
        id: String? = nil,
        userId: String,
        pointsAwarded: Int,
        rarity: LootBoxRarity,
        openedAt: Date = Date(),
        wasProSubscriber: Bool = false
    ) {
        self.id = id
        self.userId = userId
        self.pointsAwarded = pointsAwarded
        self.rarity = rarity
        self.openedAt = openedAt
        self.wasProSubscriber = wasProSubscriber
    }
}

// MARK: - Supporting Types

enum LootBoxRarity: String, Codable {
    case common
    case uncommon
    case rare
    case epic
    case legendary

    var displayName: String {
        rawValue.capitalized
    }

    var color: String {
        switch self {
        case .common: return "gray"
        case .uncommon: return "green"
        case .rare: return "blue"
        case .epic: return "purple"
        case .legendary: return "orange"
        }
    }

    var pointRange: ClosedRange<Int> {
        switch self {
        case .common: return 1...50
        case .uncommon: return 51...150
        case .rare: return 151...500
        case .epic: return 501...1000
        case .legendary: return 1001...5000
        }
    }
}
