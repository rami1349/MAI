//
//  ContentView.swift
//  FamilyHub
//
//  Main content view with streamlined onboarding:
//  Phase 1: Emotional slides (WelcomeSlidesView) - new users only
//  Phase 2: Authentication + Family Setup
//  Phase 3: Main App (FeatureTour triggers automatically on first launch)
//

import SwiftUI

struct ContentView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(LocalizationManager.self) var localization
    @Environment(ThemeManager.self) var themeManager
    @Environment(TourManager.self) var tourManager
    
    // Track if user has seen welcome slides (persisted locally)
    @AppStorage("hasSeenWelcomeSlides") private var hasSeenWelcomeSlides = false
    
    // Track if user chose sign-in vs sign-up from welcome slides
    @State private var isSigningIn = false
    
    var body: some View {
        Group {
            // Show splash while checking auth state
            if !authViewModel.authReady {
                SplashView()
            }
            // PHASE 1: Welcome slides (only for new users who haven't seen them)
            else if !hasSeenWelcomeSlides && !authViewModel.isAuthenticated {
                WelcomeSlidesView(
                    onGetStarted: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            hasSeenWelcomeSlides = true
                            isSigningIn = false
                        }
                    },
                    onSignIn: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            hasSeenWelcomeSlides = true
                            isSigningIn = true
                        }
                    }
                )
                .transition(.opacity)
            }
            // PHASE 2a: Authentication
            else if !authViewModel.isAuthenticated {
                AuthenticationView(initialMode: isSigningIn ? .signIn : .signUp)
                    .transition(.opacity)
            }
            // PHASE 2b: Family Setup
            else if !authViewModel.hasFamily {
                FamilySetupView()
                    .transition(.opacity)
            }
            // PHASE 3: Main App (FeatureTour triggers on first launch)
            else {
                MainTabView()
                    .transition(.opacity)
            }
        }
        .id(localization.currentLanguage)
        .animation(.easeInOut(duration: 0.3), value: authViewModel.isAuthenticated)
        .animation(.easeInOut(duration: 0.3), value: authViewModel.hasFamily)
        .animation(.easeInOut(duration: 0.3), value: hasSeenWelcomeSlides)
        .preferredColorScheme(themeManager.colorScheme)
    }
}

// MARK: - Splash View

struct SplashView: View {
    @State private var isAnimating = false
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.accentPrimary.opacity(0.1), Color.backgroundPrimary],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: DS.Spacing.xl) {
                Image("panda")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .scaleEffect(isAnimating ? 1.05 : 1.0)
                    .animation(
                        .easeInOut(duration: 1.2).repeatForever(autoreverses: true),
                        value: isAnimating
                    )
                
                ProgressView()
                    .tint(Color.accentPrimary)
                    .scaleEffect(1.2)
            }
        }
        .onAppear {
            isAnimating = true
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environment(AuthViewModel())
        .environment(ThemeManager.shared)
        .environment(LocalizationManager.shared)
        .environment(TourManager.shared)
}
