//
//  LootBoxTests.swift
//  KashoutTests
//
//  Reward-box odds and points logic
//

import XCTest
@testable import Kashout

final class LootBoxTests: XCTestCase {

    func testRarityWeightsSumToOneHundred() {
        XCTAssertEqual(LootBox.totalWeight, 100)
        XCTAssertEqual(LootBoxRarity.allCases.map(\.probability).reduce(0, +), 100)
    }

    func testRollBoundariesMapToDisclosedOdds() {
        // 1-50 common, 51-80 uncommon, 81-95 rare, 96-98 epic, 99-100 legendary
        XCTAssertEqual(LootBox.rarity(forRoll: 1), .common)
        XCTAssertEqual(LootBox.rarity(forRoll: 50), .common)
        XCTAssertEqual(LootBox.rarity(forRoll: 51), .uncommon)
        XCTAssertEqual(LootBox.rarity(forRoll: 80), .uncommon)
        XCTAssertEqual(LootBox.rarity(forRoll: 81), .rare)
        XCTAssertEqual(LootBox.rarity(forRoll: 95), .rare)
        XCTAssertEqual(LootBox.rarity(forRoll: 96), .epic)
        XCTAssertEqual(LootBox.rarity(forRoll: 98), .epic)
        XCTAssertEqual(LootBox.rarity(forRoll: 99), .legendary)
        XCTAssertEqual(LootBox.rarity(forRoll: 100), .legendary)
    }

    func testEachRollCountMatchesProbability() {
        var counts: [LootBoxRarity: Int] = [:]
        for roll in 1...LootBox.totalWeight {
            counts[LootBox.rarity(forRoll: roll), default: 0] += 1
        }
        for rarity in LootBoxRarity.allCases {
            XCTAssertEqual(counts[rarity], rarity.probability, "\(rarity)")
        }
    }

    func testPointRangesAreContiguousAndIncreasing() {
        let ranges = LootBoxRarity.allCases.map(\.pointRange)
        XCTAssertEqual(ranges.first?.lowerBound, 1)
        for (lower, upper) in zip(ranges, ranges.dropFirst()) {
            XCTAssertEqual(upper.lowerBound, lower.upperBound + 1)
        }
    }

    func testOpenedPointsStayInsideRarityRange() {
        var generator = SeededGenerator(seed: 42)
        for _ in 0..<5_000 {
            let result = LootBox.open(using: &generator)
            XCTAssertTrue(result.rarity.pointRange.contains(result.points), "\(result)")
        }
    }

    func testSeededOpensAreReproducible() {
        var first = SeededGenerator(seed: 7)
        var second = SeededGenerator(seed: 7)
        for _ in 0..<100 {
            let a = LootBox.open(using: &first)
            let b = LootBox.open(using: &second)
            XCTAssertEqual(a.rarity, b.rarity)
            XCTAssertEqual(a.points, b.points)
        }
    }

    func testSimulatedDistributionIsCloseToDisclosedOdds() {
        var generator = SeededGenerator(seed: 2026)
        let count = 20_000
        var counts: [LootBoxRarity: Int] = [:]
        for _ in 0..<count {
            counts[LootBox.open(using: &generator).rarity, default: 0] += 1
        }
        for rarity in LootBoxRarity.allCases {
            let observed = Double(counts[rarity, default: 0]) / Double(count) * 100
            XCTAssertEqual(observed, Double(rarity.probability), accuracy: 1.5, "\(rarity)")
        }
    }

    func testExpectedPointsPerBox() {
        // 0.50*25.5 + 0.30*100.5 + 0.15*325.5 + 0.03*750.5 + 0.02*3000.5
        XCTAssertEqual(LootBox.expectedPointsPerBox, 174.25, accuracy: 0.0001)
    }

    func testSpecialEffectsOnlyForRareAndAbove() {
        XCTAssertFalse(LootBoxResult.previewCommon.shouldShowSpecialEffects)
        XCTAssertFalse(LootBoxResult.previewUncommon.shouldShowSpecialEffects)
        XCTAssertTrue(LootBoxResult.previewRare.shouldShowSpecialEffects)
        XCTAssertTrue(LootBoxResult.previewEpic.shouldShowSpecialEffects)
        XCTAssertTrue(LootBoxResult.previewLegendary.shouldShowSpecialEffects)
        XCTAssertEqual(LootBoxResult.previewRare.pointsFormatted, "+300 points")
    }
}

// MARK: - Seeded Generator

/// SplitMix64, deterministic across runs
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
