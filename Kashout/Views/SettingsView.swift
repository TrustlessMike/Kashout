//
//  SettingsView.swift
//  Kashout
//
//  Account settings, legal, and sign out
//

import SwiftUI

struct SettingsView: View {

    // MARK: - State

    @StateObject private var authViewModel = AuthViewModel.shared
    @StateObject private var storeManager = StoreManager.shared
    @Environment(\.dismiss) private var dismiss

    @State private var showOddsDisclosure = false
    @State private var showDeleteConfirmation = false
    @State private var showSignOutConfirmation = false
    @State private var showSubscription = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            List {

                // Account Section
                accountSection

                // Subscription Section
                subscriptionSection

                // Legal Section
                legalSection

                // Support Section
                supportSection

                // Sign Out Section
                signOutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showOddsDisclosure) {
                OddsDisclosureSheet()
            }
            .sheet(isPresented: $showSubscription) {
                SubscriptionView()
            }
            .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    performSignOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $showDeleteConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    performDeleteAccount()
                }
            } message: {
                Text("This will permanently delete your account and all associated data. This action cannot be undone.")
            }
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        Section {
            // Email
            HStack {
                Label("Email", systemImage: "envelope.fill")
                Spacer()
                Text(authViewModel.authState.user?.email ?? "—")
                    .foregroundColor(.secondary)
            }

            // State
            HStack {
                Label("State", systemImage: "mappin.circle.fill")
                Spacer()
                if let stateCode = authViewModel.authState.user?.state,
                   let stateName = Constants.stateNames[stateCode] {
                    Text(stateName)
                        .foregroundColor(.secondary)
                }
            }

            // Member Since
            HStack {
                Label("Member Since", systemImage: "calendar")
                Spacer()
                if let date = authViewModel.authState.user?.createdAt {
                    Text(date.formatted(date: .abbreviated, time: .omitted))
                        .foregroundColor(.secondary)
                }
            }

            // Stats
            HStack {
                Label("Boxes Opened", systemImage: "gift.fill")
                Spacer()
                Text("\(authViewModel.authState.user?.totalBoxesOpened ?? 0)")
                    .foregroundColor(.secondary)
            }

            HStack {
                Label("Total Points Earned", systemImage: "star.fill")
                Spacer()
                Text("\(authViewModel.authState.user?.totalPointsEarned ?? 0)")
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Account")
        }
    }

    // MARK: - Subscription Section

    private var subscriptionSection: some View {
        Section {
            if storeManager.isProSubscriber {
                // Pro Status
                HStack {
                    Label {
                        Text("Pro Subscriber")
                    } icon: {
                        Image(systemName: "crown.fill")
                            .foregroundColor(.yellow)
                    }

                    Spacer()

                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }

                // Manage Subscription
                Button {
                    openSubscriptionManagement()
                } label: {
                    Label("Manage Subscription", systemImage: "creditcard.fill")
                }
            } else {
                // Upgrade Button
                Button {
                    showSubscription = true
                } label: {
                    HStack {
                        Label {
                            Text("Upgrade to Pro")
                        } icon: {
                            Image(systemName: "crown.fill")
                                .foregroundColor(.yellow)
                        }

                        Spacer()

                        Text(Constants.StoreKit.proMonthlyPrice + "/mo")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Restore
                Button {
                    Task {
                        await storeManager.restorePurchases()
                    }
                } label: {
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                }
            }
        } header: {
            Text("Subscription")
        }
    }

    // MARK: - Legal Section

    private var legalSection: some View {
        Section {
            // Odds Disclosure
            Button {
                showOddsDisclosure = true
            } label: {
                Label("Loot Box Odds", systemImage: "percent")
                    .foregroundColor(.primary)
            }

            // Terms of Service
            Link(destination: URL(string: Constants.App.termsOfServiceURL)!) {
                HStack {
                    Label("Terms of Service", systemImage: "doc.text.fill")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Privacy Policy
            Link(destination: URL(string: Constants.App.privacyPolicyURL)!) {
                HStack {
                    Label("Privacy Policy", systemImage: "hand.raised.fill")
                        .foregroundColor(.primary)
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        } header: {
            Text("Legal")
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {
        Section {
            // Contact Support
            Link(destination: URL(string: "mailto:\(Constants.App.supportEmail)")!) {
                HStack {
                    Label("Contact Support", systemImage: "envelope.fill")
                        .foregroundColor(.primary)
                    Spacer()
                    Text(Constants.App.supportEmail)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // App Version
            HStack {
                Label("Version", systemImage: "info.circle.fill")
                Spacer()
                Text(appVersion)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Support")
        }
    }

    // MARK: - Sign Out Section

    private var signOutSection: some View {
        Section {
            // Sign Out
            Button(role: .destructive) {
                showSignOutConfirmation = true
            } label: {
                Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
            }

            // Delete Account
            Button(role: .destructive) {
                showDeleteConfirmation = true
            } label: {
                Label("Delete Account", systemImage: "trash.fill")
            }
        }
    }

    // MARK: - Helpers

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    private func openSubscriptionManagement() {
        if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
            UIApplication.shared.open(url)
        }
    }

    private func performSignOut() {
        do {
            try authViewModel.signOut()
            dismiss()
        } catch {
            print("Sign out error: \(error)")
        }
    }

    private func performDeleteAccount() {
        Task {
            do {
                try await authViewModel.deleteAccount()
                dismiss()
            } catch {
                print("Delete account error: \(error)")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
}
