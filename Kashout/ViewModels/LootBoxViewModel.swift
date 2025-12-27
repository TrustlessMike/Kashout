//
//  LootBoxViewModel.swift
//  Kashout
//
//  Points management, daily bonus, and redemption logic
//

import Foundation
import FirebaseFirestore

// MARK: - Loot Box View Model

@MainActor
class LootBoxViewModel: ObservableObject {

    // MARK: - Published Properties

    @Published var currentResult: LootBoxResult?
    @Published var isOpening = false
    @Published var isProcessingRedemption = false
    @Published var redemptionHistory: [Redemption] = []
    @Published var errorMessage: String?
    @Published var successMessage: String?

    // MARK: - Private Properties

    private let db = Firestore.firestore()
    private let authViewModel: AuthViewModel

    // MARK: - Computed Properties

    var user: User? {
        authViewModel.authState.user
    }

    var points: Int {
        user?.points ?? 0
    }

    var canOpenBox: Bool {
        user?.canOpenLootBox ?? false
    }

    var cooldownRemaining: TimeInterval {
        user?.lootBoxCooldownRemaining ?? 0
    }

    var cooldownFormatted: String {
        let minutes = Int(cooldownRemaining) / 60
        let seconds = Int(cooldownRemaining) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var canClaimDailyBonus: Bool {
        user?.canClaimDailyBonus ?? false
    }

    var canWatchAd: Bool {
        user?.canWatchRewardedAd ?? false
    }

    var remainingAds: Int {
        user?.remainingRewardedAds ?? 0
    }

    var availableTiers: [Constants.RedemptionTier] {
        user?.availableRedemptionTiers ?? []
    }

    // MARK: - Initialization

    init(authViewModel: AuthViewModel = .shared) {
        self.authViewModel = authViewModel
    }

    // MARK: - Open Loot Box

    /// Opens a loot box and awards points
    func openLootBox() async {
        guard var user = user, canOpenBox else {
            errorMessage = "Please wait for the cooldown to finish."
            return
        }

        isOpening = true
        errorMessage = nil

        // Generate result
        let result = LootBox.open()
        currentResult = result

        // Update user stats
        user.points += result.points
        user.totalPointsEarned += result.points
        user.totalBoxesOpened += 1
        user.lastLootBoxOpen = Date()

        do {
            // Save to Firestore
            try await saveUser(user)

            // Record history
            let historyEntry = LootBoxHistoryEntry(
                userId: user.id ?? "",
                pointsAwarded: result.points,
                rarity: result.rarity,
                wasProSubscriber: user.isPro
            )
            try await saveHistoryEntry(historyEntry)

            isOpening = false

        } catch {
            isOpening = false
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    /// Clears the current result (after animation completes)
    func clearResult() {
        currentResult = nil
    }

    // MARK: - Daily Bonus

    /// Claims the daily login bonus
    func claimDailyBonus() async {
        guard var user = user, canClaimDailyBonus else {
            errorMessage = "Daily bonus already claimed."
            return
        }

        let basePoints = Constants.dailyBonusPoints
        let bonusPoints = user.isPro ? Int(Double(basePoints) * Constants.proBonusMultiplier) : basePoints

        user.points += bonusPoints
        user.totalPointsEarned += bonusPoints
        user.lastDailyBonus = Date()

        do {
            try await saveUser(user)
            successMessage = "+\(bonusPoints) daily bonus!"
        } catch {
            errorMessage = "Failed to claim bonus: \(error.localizedDescription)"
        }
    }

    // MARK: - Rewarded Ads

    /// Records watching a rewarded ad and awards points
    func recordRewardedAd(points: Int) async {
        guard var user = user else { return }

        // Reset counter if new day
        if let lastAdDate = user.lastAdWatchDate,
           !Calendar.current.isDateInToday(lastAdDate) {
            user.rewardedAdsWatchedToday = 0
        }

        user.points += points
        user.totalPointsEarned += points
        user.rewardedAdsWatchedToday += 1
        user.lastAdWatchDate = Date()

        do {
            try await saveUser(user)
            successMessage = "+\(points) points from ad!"
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
        }
    }

    // MARK: - Redemption

    /// Redeems points for a gift card
    func redeemPoints(tier: Constants.RedemptionTier, giftCardType: Redemption.GiftCardType) async {
        guard var user = user else { return }
        guard user.points >= tier.rawValue else {
            errorMessage = "Not enough points."
            return
        }

        isProcessingRedemption = true
        errorMessage = nil

        // Create redemption record
        let redemption = Redemption(
            userId: user.id ?? "",
            pointsRedeemed: tier.rawValue,
            dollarValue: tier.dollarValue,
            giftCardType: giftCardType,
            status: .pending,
            createdAt: Date()
        )

        // Deduct points
        user.points -= tier.rawValue

        do {
            // Save user with deducted points
            try await saveUser(user)

            // Save redemption request
            try db.collection(Constants.Firebase.redemptionsCollection)
                .addDocument(from: redemption)

            successMessage = "Redemption submitted! You'll receive your \(giftCardType.rawValue) gift card within 24-48 hours."
            isProcessingRedemption = false

            // Refresh redemption history
            await fetchRedemptionHistory()

        } catch {
            // Restore points on failure
            user.points += tier.rawValue
            try? await saveUser(user)

            errorMessage = "Redemption failed: \(error.localizedDescription)"
            isProcessingRedemption = false
        }
    }

    /// Fetches user's redemption history
    func fetchRedemptionHistory() async {
        guard let userId = user?.id else { return }

        do {
            let snapshot = try await db.collection(Constants.Firebase.redemptionsCollection)
                .whereField("userId", isEqualTo: userId)
                .order(by: "createdAt", descending: true)
                .limit(to: 50)
                .getDocuments()

            redemptionHistory = snapshot.documents.compactMap {
                try? $0.data(as: Redemption.self)
            }
        } catch {
            print("Failed to fetch redemption history: \(error)")
        }
    }

    // MARK: - Pro Subscription

    /// Updates user's Pro status
    func updateProStatus(isPro: Bool) async {
        guard var user = user else { return }

        user.isPro = isPro

        do {
            try await saveUser(user)
        } catch {
            errorMessage = "Failed to update subscription status."
        }
    }

    // MARK: - Private Helpers

    private func saveUser(_ user: User) async throws {
        guard let uid = user.id else { return }

        try db.collection(Constants.Firebase.usersCollection)
            .document(uid)
            .setData(from: user, merge: true)

        // Refresh auth state
        await authViewModel.refreshUser()
    }

    private func saveHistoryEntry(_ entry: LootBoxHistoryEntry) async throws {
        try db.collection(Constants.Firebase.lootBoxHistoryCollection)
            .addDocument(from: entry)
    }

    // MARK: - Clear Messages

    func clearError() {
        errorMessage = nil
    }

    func clearSuccess() {
        successMessage = nil
    }
}

// MARK: - Preview Helper

#if DEBUG
extension LootBoxViewModel {
    static var preview: LootBoxViewModel {
        LootBoxViewModel()
    }
}
#endif
