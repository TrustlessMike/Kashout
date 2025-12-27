//
//  SubscriptionView.swift
//  Kashout
//
//  Pro subscription upgrade ($4.99/mo)
//

import SwiftUI
import StoreKit

struct SubscriptionView: View {

    // MARK: - State

    @StateObject private var storeManager = StoreManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedProduct: Product?
    @State private var showError = false
    @State private var errorMessage = ""

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Header
                    headerSection

                    // Benefits
                    benefitsSection

                    // Subscription Options
                    subscriptionOptions

                    // Subscribe Button
                    subscribeButton

                    // Restore & Legal
                    footerSection

                    Spacer(minLength: 40)
                }
                .padding()
            }
            .background(
                LinearGradient(
                    colors: [Color(.systemBackground), Color.purple.opacity(0.1)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
            )
            .navigationTitle("Pro Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .overlay {
                if storeManager.isLoading {
                    loadingOverlay
                }
            }
        }
        .onAppear {
            // Select monthly by default
            selectedProduct = storeManager.monthlyProduct
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 16) {
            // Crown icon
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.yellow, .orange],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 100, height: 100)

                Image(systemName: "crown.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.white)
            }
            .shadow(color: .orange.opacity(0.4), radius: 15, y: 5)

            Text("Upgrade to Pro")
                .font(.title.bold())

            Text("Unlock premium features and maximize your earnings")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 20)
    }

    // MARK: - Benefits Section

    private var benefitsSection: some View {
        VStack(spacing: 16) {
            BenefitRow(
                icon: "bolt.fill",
                iconColor: .yellow,
                title: "2x Daily Bonus",
                subtitle: "Double your daily login rewards"
            )

            BenefitRow(
                icon: "timer",
                iconColor: .green,
                title: "Faster Cooldowns",
                subtitle: "\(Constants.proBoxCooldownMinutes) min vs \(Constants.freeBoxCooldownMinutes) min between opens"
            )

            BenefitRow(
                icon: "sparkles",
                iconColor: .purple,
                title: "Exclusive Badge",
                subtitle: "Show off your Pro status"
            )

            BenefitRow(
                icon: "bell.badge.fill",
                iconColor: .blue,
                title: "Priority Support",
                subtitle: "Get help faster when you need it"
            )
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    // MARK: - Subscription Options

    private var subscriptionOptions: some View {
        VStack(spacing: 12) {
            Text("Choose Your Plan")
                .font(.headline)

            // Monthly Option
            if let monthly = storeManager.monthlyProduct {
                SubscriptionOption(
                    product: monthly,
                    isSelected: selectedProduct?.id == monthly.id,
                    isBestValue: false
                ) {
                    selectedProduct = monthly
                }
            }

            // Yearly Option (if available)
            if let yearly = storeManager.yearlyProduct {
                SubscriptionOption(
                    product: yearly,
                    isSelected: selectedProduct?.id == yearly.id,
                    isBestValue: true
                ) {
                    selectedProduct = yearly
                }
            }

            // If no products loaded
            if storeManager.products.isEmpty && !storeManager.isLoading {
                VStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.title)
                        .foregroundColor(.orange)

                    Text("Unable to load subscription options")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Button("Retry") {
                        Task {
                            await storeManager.loadProducts()
                        }
                    }
                    .font(.subheadline.bold())
                    .foregroundColor(.purple)
                }
                .padding()
            }
        }
    }

    // MARK: - Subscribe Button

    private var subscribeButton: some View {
        Button {
            performPurchase()
        } label: {
            HStack {
                Text("Subscribe Now")
                    .fontWeight(.bold)

                if let product = selectedProduct {
                    Text("- \(product.displayPrice)")
                }
            }
            .font(.headline)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                LinearGradient(
                    colors: selectedProduct != nil ? [.purple, .pink] : [.gray, .gray],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
        }
        .disabled(selectedProduct == nil || storeManager.isLoading)
    }

    // MARK: - Footer Section

    private var footerSection: some View {
        VStack(spacing: 16) {
            // Restore Purchases
            Button {
                Task {
                    await storeManager.restorePurchases()
                }
            } label: {
                Text("Restore Purchases")
                    .font(.subheadline)
                    .foregroundColor(.purple)
            }

            // Legal Text
            VStack(spacing: 8) {
                Text("Subscription automatically renews unless canceled at least 24 hours before the end of the current period. You can manage and cancel your subscription in your App Store account settings.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 16) {
                    Link("Terms of Service", destination: URL(string: Constants.App.termsOfServiceURL)!)
                    Link("Privacy Policy", destination: URL(string: Constants.App.privacyPolicyURL)!)
                }
                .font(.caption2)
                .foregroundColor(.blue)
            }
        }
        .padding(.top, 8)
    }

    // MARK: - Loading Overlay

    private var loadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text("Processing...")
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding(40)
            .background(.ultraThinMaterial)
            .cornerRadius(20)
        }
    }

    // MARK: - Actions

    private func performPurchase() {
        guard let product = selectedProduct else { return }

        Task {
            let success = await storeManager.purchase(product)

            if success {
                dismiss()
            } else if let error = storeManager.lastError {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// MARK: - Benefit Row

struct BenefitRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.bold())

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        }
    }
}

// MARK: - Subscription Option

struct SubscriptionOption: View {
    let product: Product
    let isSelected: Bool
    let isBestValue: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(product.periodDescription ?? "Subscription")
                            .font(.headline)

                        if isBestValue {
                            Text("BEST VALUE")
                                .font(.caption2.bold())
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green)
                                .cornerRadius(4)
                        }
                    }

                    Text(product.displayPrice)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(isSelected ? .purple : .secondary)
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.purple : Color.gray.opacity(0.3), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    SubscriptionView()
}
