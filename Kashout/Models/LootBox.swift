//
//  LootBox.swift
//  Kashout
//
//  Loot box with weighted random points distribution
//  50% common, 30% uncommon, 15% rare, 3% epic, 2% legendary
//

import Foundation

// MARK: - Loot Box Model

struct LootBox {

    // MARK: - Weighted Rarity Distribution

    /// Rarity weights (must sum to 100)
    /// Common: 50%, Uncommon: 30%, Rare: 15%, Epic: 3%, Legendary: 2%
    private static let rarityWeights: [(rarity: LootBoxRarity, weight: Int)] = [
        (.common, 50),
        (.uncommon, 30),
        (.rare, 15),
        (.epic, 3),
        (.legendary, 2)
    ]

    // MARK: - Open Loot Box

    /// Opens a loot box and returns the result with weighted random rarity
    /// - Returns: A LootBoxResult containing the rarity and points awarded
    static func open() -> LootBoxResult {
        let rarity = rollRarity()
        let points = rollPoints(for: rarity)

        return LootBoxResult(
            rarity: rarity,
            points: points,
            openedAt: Date()
        )
    }

    /// Rolls for rarity using weighted random selection
    private static func rollRarity() -> LootBoxRarity {
        let totalWeight = rarityWeights.reduce(0) { $0 + $1.weight }
        let roll = Int.random(in: 1...totalWeight)

        var cumulative = 0
        for (rarity, weight) in rarityWeights {
            cumulative += weight
            if roll <= cumulative {
                return rarity
            }
        }

        // Fallback (should never reach here)
        return .common
    }

    /// Rolls for points within the rarity's point range
    private static func rollPoints(for rarity: LootBoxRarity) -> Int {
        let range = rarity.pointRange
        return Int.random(in: range)
    }

    // MARK: - Simulation (for testing/display)

    /// Simulates multiple loot box opens for testing odds
    /// - Parameter count: Number of boxes to simulate
    /// - Returns: Dictionary of rarity counts
    static func simulateOpens(count: Int) -> [LootBoxRarity: Int] {
        var results: [LootBoxRarity: Int] = [:]

        for rarity in LootBoxRarity.allCases {
            results[rarity] = 0
        }

        for _ in 0..<count {
            let result = open()
            results[result.rarity, default: 0] += 1
        }

        return results
    }

    /// Calculates expected value of points per loot box
    static var expectedPointsPerBox: Double {
        var expected = 0.0

        for (rarity, weight) in rarityWeights {
            let probability = Double(weight) / 100.0
            let range = rarity.pointRange
            let averagePoints = Double(range.lowerBound + range.upperBound) / 2.0
            expected += probability * averagePoints
        }

        return expected
    }
}

// MARK: - Loot Box Result

struct LootBoxResult {
    let rarity: LootBoxRarity
    let points: Int
    let openedAt: Date

    /// Formatted points string
    var pointsFormatted: String {
        "+\(points) points"
    }

    /// Message to display based on rarity
    var celebrationMessage: String {
        switch rarity {
        case .common:
            return "Nice!"
        case .uncommon:
            return "Good find!"
        case .rare:
            return "Awesome!"
        case .epic:
            return "EPIC WIN!"
        case .legendary:
            return "LEGENDARY!"
        }
    }

    /// Whether this result deserves special celebration effects
    var shouldShowSpecialEffects: Bool {
        switch rarity {
        case .common, .uncommon:
            return false
        case .rare, .epic, .legendary:
            return true
        }
    }

    /// Duration of celebration animation in seconds
    var celebrationDuration: Double {
        switch rarity {
        case .common: return 1.5
        case .uncommon: return 2.0
        case .rare: return 2.5
        case .epic: return 3.0
        case .legendary: return 4.0
        }
    }
}

// MARK: - LootBoxRarity Extension for CaseIterable

extension LootBoxRarity: CaseIterable {

    /// Probability of rolling this rarity (as percentage)
    var probability: Int {
        switch self {
        case .common: return 50
        case .uncommon: return 30
        case .rare: return 15
        case .epic: return 3
        case .legendary: return 2
        }
    }

    /// Probability as formatted string
    var probabilityFormatted: String {
        "\(probability)%"
    }

    /// Average points for this rarity
    var averagePoints: Int {
        let range = pointRange
        return (range.lowerBound + range.upperBound) / 2
    }

    /// Description for odds disclosure
    var oddsDescription: String {
        "\(displayName) (\(pointRange.lowerBound)-\(pointRange.upperBound) points): \(probabilityFormatted)"
    }
}

// MARK: - Preview Helper

#if DEBUG
extension LootBoxResult {
    static let previewCommon = LootBoxResult(rarity: .common, points: 25, openedAt: Date())
    static let previewUncommon = LootBoxResult(rarity: .uncommon, points: 100, openedAt: Date())
    static let previewRare = LootBoxResult(rarity: .rare, points: 300, openedAt: Date())
    static let previewEpic = LootBoxResult(rarity: .epic, points: 750, openedAt: Date())
    static let previewLegendary = LootBoxResult(rarity: .legendary, points: 3000, openedAt: Date())
}
#endif
