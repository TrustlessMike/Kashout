//
//  Constants.swift
//  Kashout
//
//  Loot box app configuration constants
//

import Foundation

enum Constants {

    // MARK: - Points & Redemption

    /// Minimum points required for gift card redemption
    static let minimumRedemptionPoints = 10_000

    /// Points thresholds for different gift card values
    enum RedemptionTier: Int, CaseIterable {
        case five = 10_000      // $5 gift card
        case ten = 20_000       // $10 gift card
        case twentyFive = 50_000 // $25 gift card

        var dollarValue: Int {
            switch self {
            case .five: return 5
            case .ten: return 10
            case .twentyFive: return 25
            }
        }

        var displayName: String {
            "$\(dollarValue) Gift Card"
        }
    }

    // MARK: - Daily Bonus

    /// Base points for daily login bonus
    static let dailyBonusPoints = 100

    /// Bonus multiplier for Pro subscribers
    static let proBonusMultiplier = 2.0

    /// Hours between daily bonuses
    static let dailyBonusCooldownHours = 24

    // MARK: - Loot Box Cooldowns

    /// Minutes between free loot box opens
    static let freeBoxCooldownMinutes = 30

    /// Pro subscribers: minutes between free opens
    static let proBoxCooldownMinutes = 15

    // MARK: - Restricted States

    /// US states where loot box mechanics are restricted
    /// These states have laws regulating randomized reward systems
    static let restrictedStates: Set<String> = [
        "AR",  // Arkansas
        "LA",  // Louisiana
        "MT",  // Montana
        "SC",  // South Carolina
        "SD",  // South Dakota
        "TN"   // Tennessee
    ]

    /// Full state names for display
    static let stateNames: [String: String] = [
        "AL": "Alabama", "AK": "Alaska", "AZ": "Arizona", "AR": "Arkansas",
        "CA": "California", "CO": "Colorado", "CT": "Connecticut", "DE": "Delaware",
        "FL": "Florida", "GA": "Georgia", "HI": "Hawaii", "ID": "Idaho",
        "IL": "Illinois", "IN": "Indiana", "IA": "Iowa", "KS": "Kansas",
        "KY": "Kentucky", "LA": "Louisiana", "ME": "Maine", "MD": "Maryland",
        "MA": "Massachusetts", "MI": "Michigan", "MN": "Minnesota", "MS": "Mississippi",
        "MO": "Missouri", "MT": "Montana", "NE": "Nebraska", "NV": "Nevada",
        "NH": "New Hampshire", "NJ": "New Jersey", "NM": "New Mexico", "NY": "New York",
        "NC": "North Carolina", "ND": "North Dakota", "OH": "Ohio", "OK": "Oklahoma",
        "OR": "Oregon", "PA": "Pennsylvania", "RI": "Rhode Island", "SC": "South Carolina",
        "SD": "South Dakota", "TN": "Tennessee", "TX": "Texas", "UT": "Utah",
        "VT": "Vermont", "VA": "Virginia", "WA": "Washington", "WV": "West Virginia",
        "WI": "Wisconsin", "WY": "Wyoming", "DC": "District of Columbia"
    ]

    /// Allowed states (non-restricted)
    static var allowedStates: [String] {
        stateNames.keys.filter { !restrictedStates.contains($0) }.sorted()
    }

    // MARK: - AdMob Configuration

    enum AdMob {
        /// Test ad unit ID for rewarded videos (use in development)
        static let testRewardedAdUnitID = "ca-app-pub-3940256099942544/1712485313"

        /// Production ad unit ID - REPLACE WITH YOUR ACTUAL AD UNIT ID
        static let productionRewardedAdUnitID = "ca-app-pub-XXXXXXXXXXXXXXXX/XXXXXXXXXX"

        /// Points awarded for watching a rewarded ad
        static let rewardedAdPoints = 50

        /// Maximum rewarded ads per day
        static let maxDailyRewardedAds = 10

        /// Current ad unit ID based on build configuration
        static var rewardedAdUnitID: String {
            #if DEBUG
            return testRewardedAdUnitID
            #else
            return productionRewardedAdUnitID
            #endif
        }
    }

    // MARK: - StoreKit / Subscriptions

    enum StoreKit {
        /// Product ID for monthly Pro subscription
        static let proMonthlyProductID = "com.kashout.pro.monthly"

        /// Product ID for yearly Pro subscription (optional)
        static let proYearlyProductID = "com.kashout.pro.yearly"

        /// Monthly subscription price
        static let proMonthlyPrice = "$4.99"

        /// Yearly subscription price (optional)
        static let proYearlyPrice = "$39.99"
    }

    // MARK: - Firebase Collections

    enum Firebase {
        static let usersCollection = "users"
        static let redemptionsCollection = "redemptions"
        static let lootBoxHistoryCollection = "lootBoxHistory"
    }

    // MARK: - App Info

    enum App {
        static let name = "Kashout"
        static let supportEmail = "support@kashout.app"
        static let privacyPolicyURL = "https://kashout.app/privacy"
        static let termsOfServiceURL = "https://kashout.app/terms"
    }

    // MARK: - Odds Disclosure

    /// Legal disclosure text for loot box odds (required by App Store)
    static let oddsDisclosure = """
    LOOT BOX ODDS DISCLOSURE

    Common Reward (1-50 points): 50% chance
    Uncommon Reward (51-150 points): 30% chance
    Rare Reward (151-500 points): 15% chance
    Epic Reward (501-1000 points): 3% chance
    Legendary Reward (1001-5000 points): 2% chance

    These odds are the same for all users and do not change based on purchase history or account status. Pro subscribers receive the same odds but with reduced cooldown times between opens.
    """
}
