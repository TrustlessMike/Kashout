//
//  DemoModeViews.swift
//  Kashout
//
//  Demo mode banner and simulated rewarded ad
//

import SwiftUI

// MARK: - Demo Mode Banner

struct DemoModeBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "testtube.2")
            Text("Demo mode: local data only, no real rewards")
        }
        .font(.caption.bold())
        .foregroundColor(.orange)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.orange.opacity(0.12))
        .cornerRadius(20)
        .accessibilityIdentifier("demoModeBanner")
    }
}

// MARK: - Demo Rewarded Ad

/// Stand-in for a rewarded video in demo mode. No ad network is contacted.
struct DemoRewardedAdView: View {
    let onFinish: (_ rewardEarned: Bool) -> Void

    @State private var secondsRemaining = Constants.Demo.simulatedAdSeconds

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 24) {
                HStack {
                    Spacer()

                    Button {
                        onFinish(false)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text("Simulated Rewarded Ad")
                    .font(.title2.bold())
                    .foregroundColor(.white)

                Text("Demo mode does not load real ads.")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.7))

                Spacer()

                if secondsRemaining > 0 {
                    Text("Reward unlocks in \(secondsRemaining)s")
                        .font(.headline.monospacedDigit())
                        .foregroundColor(.white.opacity(0.8))
                        .padding()
                } else {
                    Button {
                        onFinish(true)
                    } label: {
                        Text("Claim +\(Constants.AdMob.rewardedAdPoints) points")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(32)
        }
        .task {
            while secondsRemaining > 0 {
                guard (try? await Task.sleep(for: .seconds(1))) != nil else { return }
                secondsRemaining -= 1
            }
        }
    }
}

// MARK: - Preview

#Preview("Banner") {
    DemoModeBanner()
}

#Preview("Ad") {
    DemoRewardedAdView { _ in }
}
