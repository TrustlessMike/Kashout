//
//  LootBoxRevealView.swift
//  Kashout
//
//  Animated loot box reveal with confetti
//

import SwiftUI

struct LootBoxRevealView: View {

    // MARK: - Properties

    let result: LootBoxResult
    let onDismiss: () -> Void

    // MARK: - State

    @State private var phase: RevealPhase = .initial
    @State private var showConfetti = false
    @State private var boxRotation: Double = 0
    @State private var boxScale: CGFloat = 0.5
    @State private var glowOpacity: Double = 0
    @State private var pointsOffset: CGFloat = 50
    @State private var pointsOpacity: Double = 0

    // MARK: - Body

    var body: some View {
        ZStack {
            // Background
            backgroundColor
                .ignoresSafeArea()
                .animation(.easeOut(duration: 0.5), value: phase)

            // Confetti layer
            if showConfetti && result.shouldShowSpecialEffects {
                ConfettiView()
                    .ignoresSafeArea()
            }

            // Main content
            VStack(spacing: 40) {
                Spacer()

                // Loot Box / Reveal
                ZStack {
                    // Glow effect
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [rarityColor.opacity(0.6), .clear],
                                center: .center,
                                startRadius: 0,
                                endRadius: 150
                            )
                        )
                        .frame(width: 300, height: 300)
                        .opacity(glowOpacity)

                    // Box or Result
                    if phase == .initial || phase == .shaking {
                        boxView
                    } else {
                        resultView
                    }
                }

                // Points and message
                if phase == .revealed {
                    VStack(spacing: 16) {
                        Text(result.celebrationMessage)
                            .font(.title.bold())
                            .foregroundColor(.white)

                        Text(result.pointsFormatted)
                            .font(.system(size: 48, weight: .heavy, design: .rounded))
                            .foregroundColor(.white)

                        Text(result.rarity.displayName.uppercased())
                            .font(.caption.bold())
                            .tracking(4)
                            .foregroundColor(rarityColor)
                    }
                    .offset(y: pointsOffset)
                    .opacity(pointsOpacity)
                }

                Spacer()

                // Tap to continue
                if phase == .revealed {
                    Button {
                        onDismiss()
                    } label: {
                        Text("Tap to Continue")
                            .font(.headline)
                            .foregroundColor(.white.opacity(0.8))
                            .padding()
                            .frame(maxWidth: .infinity)
                    }
                    .padding(.bottom, 40)
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            startRevealAnimation()
        }
        .onTapGesture {
            if phase == .revealed {
                onDismiss()
            }
        }
    }

    // MARK: - Subviews

    private var boxView: some View {
        Image(systemName: "gift.fill")
            .font(.system(size: 100))
            .foregroundStyle(
                LinearGradient(
                    colors: [.purple, .pink],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .scaleEffect(boxScale)
            .rotationEffect(.degrees(boxRotation))
            .shadow(color: .purple.opacity(0.5), radius: 20)
    }

    private var resultView: some View {
        ZStack {
            // Rarity circle
            Circle()
                .fill(rarityColor.opacity(0.2))
                .frame(width: 160, height: 160)

            Circle()
                .stroke(rarityColor, lineWidth: 4)
                .frame(width: 160, height: 160)

            // Star icon
            Image(systemName: rarityIcon)
                .font(.system(size: 60))
                .foregroundColor(rarityColor)
        }
        .scaleEffect(boxScale)
        .transition(.scale.combined(with: .opacity))
    }

    // MARK: - Colors

    private var backgroundColor: Color {
        switch phase {
        case .initial, .shaking:
            return Color.black.opacity(0.9)
        case .revealing, .revealed:
            return backgroundColorForRarity
        }
    }

    private var backgroundColorForRarity: Color {
        switch result.rarity {
        case .common:
            return Color(red: 0.2, green: 0.2, blue: 0.25)
        case .uncommon:
            return Color(red: 0.1, green: 0.25, blue: 0.15)
        case .rare:
            return Color(red: 0.1, green: 0.15, blue: 0.3)
        case .epic:
            return Color(red: 0.2, green: 0.1, blue: 0.3)
        case .legendary:
            return Color(red: 0.3, green: 0.15, blue: 0.05)
        }
    }

    private var rarityColor: Color {
        switch result.rarity {
        case .common: return .gray
        case .uncommon: return .green
        case .rare: return .blue
        case .epic: return .purple
        case .legendary: return .orange
        }
    }

    private var rarityIcon: String {
        switch result.rarity {
        case .common: return "circle.fill"
        case .uncommon: return "star.fill"
        case .rare: return "star.circle.fill"
        case .epic: return "sparkles"
        case .legendary: return "crown.fill"
        }
    }

    // MARK: - Animation

    private func startRevealAnimation() {
        // Phase 1: Box appears
        withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
            boxScale = 1.0
        }

        // Phase 2: Shaking
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            phase = .shaking
            shakeBox()
        }

        // Phase 3: Reveal
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                phase = .revealing
                boxScale = 1.2
            }
        }

        // Phase 4: Show result
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.7) {
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                phase = .revealed
                boxScale = 1.0
                glowOpacity = 1.0
            }

            // Show confetti for rare+ results
            if result.shouldShowSpecialEffects {
                showConfetti = true
            }

            // Animate points
            withAnimation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2)) {
                pointsOffset = 0
                pointsOpacity = 1
            }
        }
    }

    private func shakeBox() {
        let shakeCount = 6
        let shakeDuration = 0.1

        for i in 0..<shakeCount {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * shakeDuration) {
                withAnimation(.easeInOut(duration: shakeDuration)) {
                    boxRotation = i % 2 == 0 ? 10 : -10
                }
            }
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + Double(shakeCount) * shakeDuration) {
            withAnimation(.easeOut(duration: 0.1)) {
                boxRotation = 0
            }
        }
    }
}

// MARK: - Reveal Phase

enum RevealPhase {
    case initial
    case shaking
    case revealing
    case revealed
}

// MARK: - Confetti View

struct ConfettiView: View {
    @State private var particles: [ConfettiParticle] = []

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let now = timeline.date.timeIntervalSinceReferenceDate

                for particle in particles {
                    let age = now - particle.createdAt
                    guard age < 3 else { continue }

                    let progress = age / 3
                    let x = particle.startX + particle.velocityX * age
                    let y = particle.startY + particle.velocityY * age + 200 * age * age
                    let opacity = 1 - progress

                    guard y < size.height + 50 else { continue }

                    let rotation = Angle(degrees: particle.rotation + particle.rotationSpeed * age)

                    context.opacity = opacity
                    context.translateBy(x: x, y: y)
                    context.rotate(by: rotation)

                    let rect = CGRect(x: -5, y: -8, width: 10, height: 16)
                    context.fill(
                        Path(roundedRect: rect, cornerRadius: 2),
                        with: .color(particle.color)
                    )

                    context.rotate(by: -rotation)
                    context.translateBy(x: -x, y: -y)
                }
            }
        }
        .onAppear {
            createParticles()
        }
    }

    private func createParticles() {
        let colors: [Color] = [.yellow, .orange, .pink, .purple, .blue, .green, .red]
        let now = Date().timeIntervalSinceReferenceDate

        for _ in 0..<50 {
            let particle = ConfettiParticle(
                startX: CGFloat.random(in: 100...300),
                startY: CGFloat.random(in: -50...50),
                velocityX: CGFloat.random(in: -100...100),
                velocityY: CGFloat.random(in: -300 ... -100),
                rotation: Double.random(in: 0...360),
                rotationSpeed: Double.random(in: -180...180),
                color: colors.randomElement()!,
                createdAt: now
            )
            particles.append(particle)
        }
    }
}

struct ConfettiParticle {
    let startX: CGFloat
    let startY: CGFloat
    let velocityX: CGFloat
    let velocityY: CGFloat
    let rotation: Double
    let rotationSpeed: Double
    let color: Color
    let createdAt: TimeInterval
}

// MARK: - Preview

#Preview("Legendary") {
    LootBoxRevealView(
        result: .previewLegendary,
        onDismiss: { }
    )
}

#Preview("Common") {
    LootBoxRevealView(
        result: .previewCommon,
        onDismiss: { }
    )
}
