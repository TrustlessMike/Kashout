//
//  OnboardingView.swift
//  Kashout
//
//  Sign up flow with state picker and odds disclosure
//

import SwiftUI

struct OnboardingView: View {

    // MARK: - State

    @StateObject private var authViewModel = AuthViewModel.shared
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var selectedState = ""
    @State private var isSignUp = true
    @State private var showOddsDisclosure = false
    @State private var acceptedTerms = false
    @State private var showError = false
    @State private var errorMessage = ""

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {

                    // Logo and Title
                    headerSection

                    // Auth Form
                    VStack(spacing: 20) {
                        if isSignUp {
                            signUpForm
                        } else {
                            signInForm
                        }
                    }
                    .padding(.horizontal)

                    // Toggle Sign Up / Sign In
                    toggleButton

                    Spacer(minLength: 40)
                }
                .padding(.top, 60)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .alert("Error", isPresented: $showError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
            .sheet(isPresented: $showOddsDisclosure) {
                OddsDisclosureSheet()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "gift.fill")
                .font(.system(size: 60))
                .foregroundStyle(.linearGradient(
                    colors: [.purple, .pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))

            Text("Kashout")
                .font(.system(size: 36, weight: .bold, design: .rounded))

            Text(isSignUp ? "Create your account" : "Welcome back!")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Sign Up Form

    private var signUpForm: some View {
        VStack(spacing: 16) {

            // Email
            CustomTextField(
                icon: "envelope.fill",
                placeholder: "Email",
                text: $email,
                keyboardType: .emailAddress
            )

            // Password
            CustomSecureField(
                icon: "lock.fill",
                placeholder: "Password (min 6 characters)",
                text: $password
            )

            // Confirm Password
            CustomSecureField(
                icon: "lock.fill",
                placeholder: "Confirm Password",
                text: $confirmPassword
            )

            // State Picker
            StatePicker(selectedState: $selectedState)

            // Terms and Odds Disclosure
            VStack(spacing: 12) {
                Toggle(isOn: $acceptedTerms) {
                    Text("I agree to the Terms of Service and Privacy Policy")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .toggleStyle(CheckboxToggleStyle())

                Button {
                    showOddsDisclosure = true
                } label: {
                    HStack {
                        Image(systemName: "info.circle")
                        Text("View Loot Box Odds")
                    }
                    .font(.footnote)
                    .foregroundColor(.blue)
                }
            }

            // Sign Up Button
            Button(action: performSignUp) {
                HStack {
                    if authViewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Create Account")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canSignUp ? Color.purple : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!canSignUp || authViewModel.isLoading)
        }
    }

    // MARK: - Sign In Form

    private var signInForm: some View {
        VStack(spacing: 16) {

            // Email
            CustomTextField(
                icon: "envelope.fill",
                placeholder: "Email",
                text: $email,
                keyboardType: .emailAddress
            )

            // Password
            CustomSecureField(
                icon: "lock.fill",
                placeholder: "Password",
                text: $password
            )

            // Forgot Password
            Button {
                performPasswordReset()
            } label: {
                Text("Forgot Password?")
                    .font(.footnote)
                    .foregroundColor(.blue)
            }
            .frame(maxWidth: .infinity, alignment: .trailing)

            // Sign In Button
            Button(action: performSignIn) {
                HStack {
                    if authViewModel.isLoading {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("Sign In")
                            .fontWeight(.semibold)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(canSignIn ? Color.purple : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!canSignIn || authViewModel.isLoading)
        }
    }

    // MARK: - Toggle Button

    private var toggleButton: some View {
        Button {
            withAnimation {
                isSignUp.toggle()
                clearForm()
            }
        } label: {
            HStack(spacing: 4) {
                Text(isSignUp ? "Already have an account?" : "Don't have an account?")
                    .foregroundColor(.secondary)
                Text(isSignUp ? "Sign In" : "Sign Up")
                    .fontWeight(.semibold)
                    .foregroundColor(.purple)
            }
            .font(.subheadline)
        }
    }

    // MARK: - Validation

    private var canSignUp: Bool {
        !email.isEmpty &&
        password.count >= 6 &&
        password == confirmPassword &&
        !selectedState.isEmpty &&
        acceptedTerms
    }

    private var canSignIn: Bool {
        !email.isEmpty && !password.isEmpty
    }

    // MARK: - Actions

    private func performSignUp() {
        Task {
            do {
                try await authViewModel.signUp(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password,
                    state: selectedState
                )
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func performSignIn() {
        Task {
            do {
                try await authViewModel.signIn(
                    email: email.trimmingCharacters(in: .whitespaces),
                    password: password
                )
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func performPasswordReset() {
        guard !email.isEmpty else {
            errorMessage = "Please enter your email address."
            showError = true
            return
        }

        Task {
            do {
                try await authViewModel.sendPasswordReset(email: email)
                errorMessage = "Password reset email sent!"
                showError = true
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }

    private func clearForm() {
        email = ""
        password = ""
        confirmPassword = ""
        selectedState = ""
        acceptedTerms = false
    }
}

// MARK: - Custom Text Field

struct CustomTextField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            TextField(placeholder, text: $text)
                .keyboardType(keyboardType)
                .autocapitalization(.none)
                .disableAutocorrection(true)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Custom Secure Field

struct CustomSecureField: View {
    let icon: String
    let placeholder: String
    @Binding var text: String
    @State private var showPassword = false

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(.secondary)
                .frame(width: 20)

            if showPassword {
                TextField(placeholder, text: $text)
                    .autocapitalization(.none)
                    .disableAutocorrection(true)
            } else {
                SecureField(placeholder, text: $text)
            }

            Button {
                showPassword.toggle()
            } label: {
                Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - State Picker

struct StatePicker: View {
    @Binding var selectedState: String

    var body: some View {
        Menu {
            ForEach(Constants.allowedStates, id: \.self) { stateCode in
                Button {
                    selectedState = stateCode
                } label: {
                    Text(Constants.stateNames[stateCode] ?? stateCode)
                }
            }
        } label: {
            HStack {
                Image(systemName: "mappin.circle.fill")
                    .foregroundColor(.secondary)
                    .frame(width: 20)

                Text(selectedState.isEmpty ? "Select Your State" : (Constants.stateNames[selectedState] ?? selectedState))
                    .foregroundColor(selectedState.isEmpty ? .secondary : .primary)

                Spacer()

                Image(systemName: "chevron.down")
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Checkbox Toggle Style

struct CheckboxToggleStyle: ToggleStyle {
    func makeBody(configuration: Configuration) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: configuration.isOn ? "checkmark.square.fill" : "square")
                .foregroundColor(configuration.isOn ? .purple : .secondary)
                .onTapGesture {
                    configuration.isOn.toggle()
                }

            configuration.label
        }
    }
}

// MARK: - Odds Disclosure Sheet

struct OddsDisclosureSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    Text("Loot Box Odds")
                        .font(.title2.bold())

                    Text("Each loot box has the following chances:")
                        .foregroundColor(.secondary)

                    VStack(spacing: 12) {
                        ForEach(LootBoxRarity.allCases, id: \.self) { rarity in
                            OddsRow(rarity: rarity)
                        }
                    }

                    Divider()

                    Text("Important Information")
                        .font(.headline)

                    Text("""
                    • These odds are identical for all users
                    • Odds do not change based on purchase history
                    • Pro subscribers receive the same odds
                    • Pro subscription only reduces cooldown times
                    • Points can be redeemed for real gift cards
                    """)
                    .font(.footnote)
                    .foregroundColor(.secondary)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Odds Disclosure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct OddsRow: View {
    let rarity: LootBoxRarity

    var body: some View {
        HStack {
            Circle()
                .fill(rarityColor)
                .frame(width: 12, height: 12)

            Text(rarity.displayName)
                .fontWeight(.medium)

            Spacer()

            Text("\(rarity.pointRange.lowerBound)-\(rarity.pointRange.upperBound) pts")
                .foregroundColor(.secondary)

            Text(rarity.probabilityFormatted)
                .fontWeight(.semibold)
                .foregroundColor(rarityColor)
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color(.systemBackground))
        .cornerRadius(8)
    }

    private var rarityColor: Color {
        switch rarity {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }
}

// MARK: - Preview

#Preview {
    OnboardingView()
}
