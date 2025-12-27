//
//  HomeView.swift
//  Kashout
//
//  Main screen with loot box opening button
//

import SwiftUI

struct HomeView: View {

    // MARK: - State

    @StateObject private var viewModel = LootBoxViewModel()
    @StateObject private var storeManager = StoreManager.shared
    @StateObject private var adManager = AdManager.shared

    @State private var showReveal = false
    @State private var showRewards = false
    @State private var showSubscription = false
    @State private var showSettings = false
    @State private var cooldownTimer: Timer?
    @State private var cooldownDisplay = "00:00"

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color(.systemBackground), Color.purple.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // Points Display
                        pointsCard

                        // Daily Bonus
                        if viewModel.canClaimDailyBonus {
                            dailyBonusCard
                        }

                        // Loot Box Button
                        lootBoxSection

                        // Watch Ad Button
                        if viewModel.canWatchAd {
                            watchAdCard
                        }

                        // Pro Upgrade Banner
                        if !storeManager.isProSubscriber {
                            proUpgradeBanner
                        }

                        Spacer(minLength: 100)
                    }
                    .padding()
                }
            }
            .navigationTitle("Kashout")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showRewards = true
                    } label: {
                        Image(systemName: "gift.fill")
                            .foregroundColor(.purple)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .sheet(isPresented: $showRewards) {
                RewardsView(viewModel: viewModel)
            }
            .sheet(isPresented: $showSubscription) {
                SubscriptionView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $showReveal) {
                if let result = viewModel.currentResult {
                    LootBoxRevealView(result: result) {
                        showReveal = false
                        viewModel.clearResult()
                    }
                }
            }
            .onAppear {
                startCooldownTimer()
                adManager.ensureAdReady()
            }
            .onDisappear {
                stopCooldownTimer()
            }
            .onChange(of: viewModel.currentResult) { _, newResult in
                if newResult != nil {
                    showReveal = true
                }
            }
        }
        .preloadAds()
    }

    // MARK: - Points Card

    private var pointsCard: some View {
        VStack(spacing: 8) {
            Text("Your Points")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("\(viewModel.points)")
                .font(.system(size: 48, weight: .bold, design: .rounded))
                .foregroundStyle(.linearGradient(
                    colors: [.purple, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                ))

            if let tier = viewModel.user?.highestAvailableTier {
                Text("Ready to redeem \(tier.displayName)!")
                    .font(.caption)
                    .foregroundColor(.green)
            } else {
                let needed = Constants.minimumRedemptionPoints - viewModel.points
                Text("\(needed) more points to redeem")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.05), radius: 10, y: 5)
    }

    // MARK: - Daily Bonus Card

    private var dailyBonusCard: some View {
        Button {
            Task {
                await viewModel.claimDailyBonus()
            }
        } label: {
            HStack {
                Image(systemName: "calendar.badge.plus")
                    .font(.title2)
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Daily Bonus")
                        .font(.headline)
                        .foregroundColor(.primary)

                    let bonus = storeManager.isProSubscriber ?
                        Int(Double(Constants.dailyBonusPoints) * Constants.proBonusMultiplier) :
                        Constants.dailyBonusPoints
                    Text("+\(bonus) points")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text("Claim")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .cornerRadius(20)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Loot Box Section

    private var lootBoxSection: some View {
        VStack(spacing: 16) {

            // Loot Box Button
            Button {
                Task {
                    await viewModel.openLootBox()
                }
            } label: {
                ZStack {
                    // Outer glow
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.purple.opacity(0.3), .clear],
                                center: .center,
                                startRadius: 60,
                                endRadius: 120
                            )
                        )
                        .frame(width: 240, height: 240)

                    // Box container
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: viewModel.canOpenBox ?
                                    [.purple, .pink] :
                                    [.gray, .gray.opacity(0.8)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 160, height: 160)
                        .shadow(color: .purple.opacity(0.4), radius: 20, y: 10)

                    // Icon
                    VStack(spacing: 8) {
                        Image(systemName: viewModel.canOpenBox ? "gift.fill" : "lock.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.white)

                        if viewModel.canOpenBox {
                            Text("TAP TO OPEN")
                                .font(.caption.bold())
                                .foregroundColor(.white.opacity(0.9))
                        }
                    }
                }
            }
            .disabled(!viewModel.canOpenBox || viewModel.isOpening)
            .scaleEffect(viewModel.isOpening ? 0.95 : 1.0)
            .animation(.spring(response: 0.3), value: viewModel.isOpening)

            // Cooldown Timer
            if !viewModel.canOpenBox {
                VStack(spacing: 4) {
                    Text("Next box in")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(cooldownDisplay)
                        .font(.title2.monospacedDigit().bold())
                        .foregroundColor(.purple)
                }
            }

            // Pro subscriber badge
            if storeManager.isProSubscriber {
                HStack(spacing: 4) {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                    Text("Pro: \(Constants.proBoxCooldownMinutes) min cooldown")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.vertical, 20)
    }

    // MARK: - Watch Ad Card

    private var watchAdCard: some View {
        Button {
            watchAd()
        } label: {
            HStack {
                Image(systemName: "play.rectangle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Watch Ad")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("+\(Constants.AdMob.rewardedAdPoints) points • \(viewModel.remainingAds) left today")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if adManager.isAdReady {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else if adManager.isLoading {
                    ProgressView()
                } else {
                    Image(systemName: "arrow.clockwise.circle")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
        .disabled(!adManager.isAdReady)
    }

    // MARK: - Pro Upgrade Banner

    private var proUpgradeBanner: some View {
        Button {
            showSubscription = true
        } label: {
            HStack {
                Image(systemName: "crown.fill")
                    .font(.title2)
                    .foregroundColor(.yellow)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Upgrade to Pro")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text("2x daily bonus • Faster cooldowns")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Text(Constants.StoreKit.proMonthlyPrice + "/mo")
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(16)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        LinearGradient(
                            colors: [.purple.opacity(0.5), .pink.opacity(0.5)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 1
                    )
            )
        }
    }

    // MARK: - Actions

    private func watchAd() {
        adManager.showRewardedAd { result in
            Task {
                switch result {
                case .success(let points):
                    await viewModel.recordRewardedAd(points: points)
                case .failure(let error):
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Timer

    private func startCooldownTimer() {
        updateCooldownDisplay()
        cooldownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            updateCooldownDisplay()
        }
    }

    private func stopCooldownTimer() {
        cooldownTimer?.invalidate()
        cooldownTimer = nil
    }

    private func updateCooldownDisplay() {
        cooldownDisplay = viewModel.cooldownFormatted
    }
}

// MARK: - Preview

#Preview {
    HomeView()
}
