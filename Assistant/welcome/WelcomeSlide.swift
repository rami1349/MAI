//
//  WelcomeSlidesView.swift
//  FamilyHub
//
//  Premium emotional onboarding - Phase 1
//  Goal: Sell the outcome, not the features
//  Shows BEFORE authentication to build emotional buy-in
//

import SwiftUI

// MARK: - Welcome Slide Model

struct WelcomeSlide: Identifiable {
    let id = UUID()
    let headlineKey: String
    let subheadlineKey: String
    let icon: String
    let gradientColors: [Color]
    
    var headline: String { LocalizationManager.shared.string(headlineKey) }
    var subheadline: String { LocalizationManager.shared.string(subheadlineKey) }
}

// MARK: - Welcome Slides View

struct WelcomeSlidesView: View {
    let onGetStarted: () -> Void
    let onSignIn: () -> Void
    
    @State private var currentPage = 0
    @State private var dragOffset: CGFloat = 0
    
    private let slides: [WelcomeSlide] = [
        WelcomeSlide(
            headlineKey: "welcome_slide_1_headline",
            subheadlineKey: "welcome_slide_1_subheadline",
            icon: "samy",
            gradientColors: [Color(hex: "667EEA"), Color(hex: "764BA2")]
        ),
        WelcomeSlide(
            headlineKey: "welcome_slide_2_headline",
            subheadlineKey: "welcome_slide_2_subheadline",
            icon: "checklist",
            gradientColors: [Color(hex: "11998E"), Color(hex: "38EF7D")]
        ),
        WelcomeSlide(
            headlineKey: "welcome_slide_3_headline",
            subheadlineKey: "welcome_slide_3_subheadline",
            icon: "gift.fill",
            gradientColors: [Color(hex: "F2994A"), Color(hex: "F2C94C")]
        ),
        WelcomeSlide(
            headlineKey: "welcome_slide_4_headline",
            subheadlineKey: "welcome_slide_4_subheadline",
            icon: "house.fill",
            gradientColors: [Color(hex: "EC6EAD"), Color(hex: "3494E6")]
        )
    ]
    
    var body: some View {
        ZStack {
            // Animated gradient background
            LinearGradient(
                colors: slides[currentPage].gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            .animation(.easeInOut(duration: 0.5), value: currentPage)
            
            // Decorative circles
            decorativeBackground
            
            VStack(spacing: 0) {
                // Slide content
                TabView(selection: $currentPage) {
                    ForEach(Array(slides.enumerated()), id: \.element.id) { index, slide in
                        slideContent(slide)
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Bottom section
                bottomSection
            }
            .constrainedWidth(.form)
        }
    }
    
    // MARK: - Slide Content
    
    private func slideContent(_ slide: WelcomeSlide) -> some View {
        VStack(spacing: DS.Spacing.xxxl) {
            Spacer()
            
            // Icon with glow
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 160, height: 160)
                    .blur(radius: 20)
                
                Circle()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 120, height: 120)
                
                Image(systemName: slide.icon)
                    .font(.system(size: 48, weight: .semibold))
                    .foregroundColor(.white)
            }
            .scaleEffect(currentPage == slides.firstIndex(where: { $0.id == slide.id }) ? 1.0 : 0.8)
            .animation(.spring(response: 0.5, dampingFraction: 0.7), value: currentPage)
            
            Spacer()
            
            // Text content
            VStack(spacing: DS.Spacing.md) {
                Text(slide.headline)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                
                Text(slide.subheadline)
                    .font(.title3)
                    .foregroundColor(.white.opacity(0.85))
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, DS.Spacing.xxl)
            
            Spacer()
            Spacer()
        }
    }
    
    // MARK: - Decorative Background
    
    private var decorativeBackground: some View {
        GeometryReader { geo in
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: geo.size.width * 0.8)
                    .offset(x: geo.size.width * 0.4, y: -geo.size.height * 0.2)
                
                Circle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: geo.size.width * 0.6)
                    .offset(x: -geo.size.width * 0.3, y: geo.size.height * 0.35)
                
                Circle()
                    .fill(Color.white.opacity(0.1))
                    .frame(width: 100)
                    .offset(x: geo.size.width * 0.3, y: geo.size.height * 0.15)
            }
        }
        .ignoresSafeArea()
    }
    
    // MARK: - Bottom Section
    
    private var bottomSection: some View {
        VStack(spacing: DS.Spacing.xl) {
            // Page indicators
            HStack(spacing: DS.Spacing.sm) {
                ForEach(0..<slides.count, id: \.self) { index in
                    Capsule()
                        .fill(Color.white.opacity(currentPage == index ? 1.0 : 0.4))
                        .frame(
                            width: currentPage == index ? 24 : 8,
                            height: 8
                        )
                        .animation(.spring(response: 0.3), value: currentPage)
                }
            }
            
            // Buttons (only on last slide)
            if currentPage == slides.count - 1 {
                VStack(spacing: DS.Spacing.md) {
                    // Get Started button
                    Button(action: {
                        DS.Haptics.medium()
                        onGetStarted()
                    }) {
                        Text(L10n.getStarted)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(slides[currentPage].gradientColors[0])
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DS.Spacing.lg)
                            .background(
                                RoundedRectangle(cornerRadius: DS.Radius.xl)
                                    .fill(Color.white)
                            )
                            .shadow(color: Color.black.opacity(0.1), radius: 10, y: 5)
                    }
                    
                    // Sign In link
                    Button(action: {
                        DS.Haptics.light()
                        onSignIn()
                    }) {
                        Text(L10n.alreadyHaveAccount)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.9))
                    }
                }
                .padding(.horizontal, DS.Spacing.xxl)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            } else {
                // Swipe hint
                HStack(spacing: DS.Spacing.xs) {
                    Text(L10n.swipeToContinue)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(.top, DS.Spacing.md)
            }
        }
        .padding(.bottom, DS.Spacing.jumbo)
        .animation(.spring(response: 0.4), value: currentPage)
    }
}

// MARK: - Preview

#Preview("Welcome Slides") {
    WelcomeSlidesView(
        onGetStarted: {},
        onSignIn: {}
    )
}
