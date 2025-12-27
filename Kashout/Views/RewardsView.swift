//
//  RewardsView.swift
//  Kashout
//
//  Gift card redemption interface
//

import SwiftUI

struct RewardsView: View {

    // MARK: - Properties

    @ObservedObject var viewModel: LootBoxViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - State

    @State private var selectedTier: Constants.RedemptionTier?
    @State private var selectedGiftCard: Redemption.GiftCardType?
    @State private var showConfirmation = false
    @State private var showHistory = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Points Balance
                    pointsBalanceCard

                    // Redemption Tiers
                    tiersSection

                    // Gift Card Selection (if tier selected)
                    if selectedTier != nil {
                        giftCardSelection
                    }

                    // Redemption History
                    historySection

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Rewards")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Confirm Redemption", isPresented: $showConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Redeem") {
                    performRedemption()
                }
            } message: {
                if let tier = selectedTier, let card = selectedGiftCard {
                    Text("Redeem \(tier.rawValue.formatted()) points for a \(tier.displayName) from \(card.rawValue)?")
                }
            }
            .overlay {
                if viewModel.isProcessingRedemption {
                    processingOverlay
                }
            }
        }
        .onAppear {
            Task {
                await viewModel.fetchRedemptionHistory()
            }
        }
    }

    // MARK: - Points Balance Card

    private var pointsBalanceCard: some View {
        VStack(spacing: 8) {
            Text("Available Points")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Text("\(viewModel.points)")
                .font(.system(size: 42, weight: .bold, design: .rounded))
                .foregroundStyle(.linearGradient(
                    colors: [.purple, .pink],
                    startPoint: .leading,
                    endPoint: .trailing
                ))

            if viewModel.points < Constants.minimumRedemptionPoints {
                let needed = Constants.minimumRedemptionPoints - viewModel.points
                Text("\(needed) more points needed for redemption")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Tiers Section

    private var tiersSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Amount")
                .font(.headline)
                .foregroundColor(.primary)

            ForEach(Constants.RedemptionTier.allCases, id: \.rawValue) { tier in
                TierCard(
                    tier: tier,
                    isSelected: selectedTier == tier,
                    isAvailable: viewModel.points >= tier.rawValue,
                    onSelect: {
                        withAnimation {
                            if selectedTier == tier {
                                selectedTier = nil
                                selectedGiftCard = nil
                            } else {
                                selectedTier = tier
                                selectedGiftCard = nil
                            }
                        }
                    }
                )
            }
        }
    }

    // MARK: - Gift Card Selection

    private var giftCardSelection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select Gift Card")
                .font(.headline)
                .foregroundColor(.primary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(Redemption.GiftCardType.allCases, id: \.self) { type in
                    GiftCardButton(
                        type: type,
                        isSelected: selectedGiftCard == type,
                        onSelect: {
                            withAnimation {
                                selectedGiftCard = type
                            }
                        }
                    )
                }
            }

            // Redeem Button
            if selectedGiftCard != nil {
                Button {
                    showConfirmation = true
                } label: {
                    Text("Redeem Now")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            LinearGradient(
                                colors: [.purple, .pink],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(12)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    // MARK: - History Section

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Redemption History")
                    .font(.headline)

                Spacer()

                if !viewModel.redemptionHistory.isEmpty {
                    Text("\(viewModel.redemptionHistory.count) redemptions")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if viewModel.redemptionHistory.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "gift")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)

                    Text("No redemptions yet")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                ForEach(viewModel.redemptionHistory.prefix(5)) { redemption in
                    RedemptionRow(redemption: redemption)
                }

                if viewModel.redemptionHistory.count > 5 {
                    Button {
                        showHistory = true
                    } label: {
                        Text("View All")
                            .font(.subheadline)
                            .foregroundColor(.purple)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Processing Overlay

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("Processing Redemption...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
    }

    // MARK: - Actions

    private func performRedemption() {
        guard let tier = selectedTier, let card = selectedGiftCard else { return }

        Task {
            await viewModel.redeemPoints(tier: tier, giftCardType: card)
            selectedTier = nil
            selectedGiftCard = nil
        }
    }
}

// MARK: - Tier Card

struct TierCard: View {
    let tier: Constants.RedemptionTier
    let isSelected: Bool
    let isAvailable: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tier.displayName)
                        .font(.headline)
                        .foregroundColor(isAvailable ? .primary : .secondary)

                    Text("\(tier.rawValue.formatted()) points")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if isAvailable {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.title2)
                        .foregroundColor(isSelected ? .purple : .secondary)
                } else {
                    Image(systemName: "lock.fill")
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.purple : Color.clear, lineWidth: 2)
                    )
            )
        }
        .disabled(!isAvailable)
    }
}

// MARK: - Gift Card Button

struct GiftCardButton: View {
    let type: Redemption.GiftCardType
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                Image(systemName: type.iconName)
                    .font(.title)
                    .foregroundColor(isSelected ? .purple : .secondary)

                Text(type.rawValue)
                    .font(.caption)
                    .foregroundColor(.primary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.purple : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
    }
}

// MARK: - Redemption Row

struct RedemptionRow: View {
    let redemption: Redemption

    var body: some View {
        HStack {
            Image(systemName: redemption.giftCardType.iconName)
                .font(.title3)
                .foregroundColor(.purple)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(redemption.giftCardType.rawValue) - $\(redemption.dollarValue)")
                    .font(.subheadline.bold())

                Text(redemption.createdAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            StatusBadge(status: redemption.status)
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Status Badge

struct StatusBadge: View {
    let status: Redemption.RedemptionStatus

    var body: some View {
        Text(status.displayText)
            .font(.caption.bold())
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor)
            .cornerRadius(8)
    }

    private var statusColor: Color {
        switch status {
        case .pending: return .orange
        case .processing: return .blue
        case .completed: return .green
        case .failed: return .red
        }
    }
}

// MARK: - Preview

#Preview {
    RewardsView(viewModel: LootBoxViewModel())
}
