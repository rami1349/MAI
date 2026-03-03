//
//  SettingsView.swift
//  Assistant
//
//  Created by Ramiro  on 2/9/26.
//  App settings: account info, appearance, theme, language, sign-out, delete account
//

import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(LocalizationManager.self) var localization
    @Environment(ThemeManager.self) var themeManager
    @State private var showLogoutAlert = false
    @State private var showLanguagePicker = false
    @State private var showThemePicker = false
    @State private var showAppearancePicker = false
    @State private var showDeleteAccountSheet = false
    @Environment(SubscriptionManager.self) var store
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            settingsContent
                .scrollContentBackground(.hidden)
                .background(AdaptiveBackgroundView())
                .navigationTitle(L10n.settings)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(L10n.done) { dismiss() }
                    }
                }
                .alert(L10n.signOutConfirm, isPresented: $showLogoutAlert) {
                    Button(L10n.cancel, role: .cancel) {}
                    Button(L10n.signOut, role: .destructive) {
                        authViewModel.signOut()
                        dismiss()
                    }
                }
        }
        .sheet(isPresented: $showLanguagePicker) {
            LanguagePickerView()
                .presentationBackground(Color.themeSurfacePrimary)
        }
        .sheet(isPresented: $showThemePicker) {
            NavigationStack {
                ScrollView {
                    ThemePickerView()
                        .padding()
                }
                .scrollContentBackground(.hidden)
                .background(AdaptiveBackgroundView())
                .navigationTitle(L10n.chooseTheme)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(L10n.done) { showThemePicker = false }
                    }
                }
            }
            .presentationBackground(Color.themeSurfacePrimary)
        }
        .sheet(isPresented: $showAppearancePicker) {
            AppearancePickerView()
                .presentationBackground(Color.themeSurfacePrimary)
        }
        .sheet(isPresented: $showDeleteAccountSheet) {
            DeleteAccountSheet()
                .environment(authViewModel)
                .presentationBackground(Color.themeSurfacePrimary)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
                .environment(store)
                .presentationBackground(Color.themeSurfacePrimary)
        }
    }
    
    private var settingsContent: some View {
        List {
            Section(L10n.account) {
                if let user = authViewModel.currentUser {
                    HStack {
                        Text(L10n.email)
                        Spacer()
                        Text(user.email).foregroundStyle(Color.textSecondary)
                    }
                    .listRowBackground(Color.themeCardBackground)
                    HStack {
                        Text(L10n.role)
                        Spacer()
                        Text(user.role.rawValue.capitalized).foregroundStyle(Color.textSecondary)
                    }
                    .listRowBackground(Color.themeCardBackground)
                }
            }
            
            // MARK: - Subscription
            Section("Subscription") {
                Button {
                    if store.tier.isPremium {
                        // Already premium — show manage info
                    } else {
                        showPaywall = true
                    }
                } label: {
                    HStack {
                        Image(systemName: store.tier.isPremium ? "crown.fill" : "sparkles")
                            .foregroundStyle(store.tier.isPremium ? .yellow : Color.accentPrimary)
                            .frame(width: DS.IconContainer.sm)
                        Text("Plan")
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Text(store.tier.displayName)
                            .foregroundStyle(store.tier.isPremium ? .yellow : Color.textSecondary)
                            .fontWeight(store.tier.isPremium ? .semibold : .regular)
                        if !store.tier.isPremium {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(Color.textTertiary)
                        }
                    }
                }
                .listRowBackground(Color.themeCardBackground)
                
                // Credits balance
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.orange)
                        .frame(width: DS.IconContainer.sm)
                    Text("AI Credits")
                        .foregroundStyle(Color.textPrimary)
                    Spacer()
                    Text("\(store.aiCredits)")
                        .foregroundStyle(Color.textSecondary)
                        .fontWeight(.medium)
                }
                .listRowBackground(Color.themeCardBackground)
                
                if store.tier.isPremium {
                    Button {
                        // Open Apple subscription management
                        if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "gear")
                                .foregroundStyle(Color.accentPrimary)
                                .frame(width: DS.IconContainer.sm)
                            Text("Manage Subscription")
                                .foregroundStyle(Color.accentPrimary)
                        }
                    }
                    .listRowBackground(Color.themeCardBackground)
                }
                
                Button {
                    Task { await store.restorePurchases() }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(Color.accentPrimary)
                            .frame(width: DS.IconContainer.sm)
                        Text("Restore Purchases")
                            .foregroundStyle(Color.accentPrimary)
                    }
                }
                .listRowBackground(Color.themeCardBackground)
            }
            
            Section(L10n.appearance) {
                Button(action: { showAppearancePicker = true }) {
                    HStack {
                        Image(systemName: themeManager.appearanceMode.icon)
                            .foregroundStyle(Color.accentPrimary)
                            .frame(width: DS.IconContainer.sm)
                        Text(L10n.appearance)
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Text(themeManager.appearanceMode.displayName)
                            .foregroundStyle(Color.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                .listRowBackground(Color.themeCardBackground)
                
                Button(action: { showThemePicker = true }) {
                    HStack {
                        Image(systemName: "paintpalette.fill")
                            .foregroundStyle(Color.accentPrimary)
                            .frame(width: DS.IconContainer.sm)
                        Text(L10n.themeColor)
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        
                        // Show 3 preview colors
                        HStack(spacing: DS.Spacing.xs) {
                            ForEach(0..<3, id: \.self) { index in
                                Circle()
                                    .fill(themeManager.currentTheme.previewColors[index])
                                    .frame(width: DS.IconSize.xs, height: DS.IconSize.xs)
                            }
                        }
                        
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                .listRowBackground(Color.themeCardBackground)
            }
            
            Section(L10n.appSection) {
                Button(action: { showLanguagePicker = true }) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundStyle(Color.accentPrimary)
                            .frame(width: DS.IconContainer.sm)
                        Text(L10n.language)
                            .foregroundStyle(Color.textPrimary)
                        Spacer()
                        Text(localization.selectedLanguage == .system
                             ? "System (\(localization.currentLanguageShortName))"
                             : localization.currentLanguageShortName)
                            .foregroundStyle(Color.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(Color.textTertiary)
                    }
                }
                .listRowBackground(Color.themeCardBackground)
                
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(Color.accentPrimary)
                        .frame(width: DS.IconContainer.sm)
                    Text(L10n.version)
                    Spacer()
                    Text("1.0.0").foregroundStyle(Color.textSecondary)
                }
                .listRowBackground(Color.themeCardBackground)
            }
            
            Section {
                Button(role: .destructive, action: {
                    showLogoutAlert = true
                }) {
                    HStack {
                        Spacer()
                        Text(L10n.signOut)
                        Spacer()
                    }
                }
                .listRowBackground(Color.themeCardBackground)
            }
            
            Section {
                Button(role: .destructive, action: {
                    showDeleteAccountSheet = true
                }) {
                    HStack {
                        Image(systemName: "trash.fill")
                        Text(L10n.deleteAccount)
                    }
                }
                .listRowBackground(Color.themeCardBackground)
            } header: {
                Text(L10n.dangerZone)
            } footer: {
                Text(L10n.dangerZoneDescription)
                    .font(.caption)
            }
        }
    }
}

// MARK: - Appearance Picker View
struct AppearancePickerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(ThemeManager.self) var themeManager
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(AppearanceMode.allCases) { mode in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            themeManager.appearanceMode = mode
                        }
                    }) {
                        HStack(spacing: DS.Spacing.lg) {
                            ZStack {
                                Circle()
                                    .fill(themeManager.appearanceMode == mode ? Color.accentPrimary.opacity(0.15) : Color.fill)
                                    .frame(width: DS.IconContainer.lg, height: DS.IconContainer.lg)
                                
                                Image(systemName: mode.icon)
                                    .font(.title3)
                                    .foregroundStyle(themeManager.appearanceMode == mode ? Color.accentPrimary : Color.textSecondary)
                            }
                            
                            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                Text(mode.displayName)
                                    .font(.body)
                                    .fontWeight(themeManager.appearanceMode == mode ? .semibold : .regular)
                                    .foregroundStyle(Color.textPrimary)
                                
                                Text(modeDescription(mode))
                                    .font(.caption)
                                    .foregroundStyle(Color.textSecondary)
                            }
                            
                            Spacer()
                            
                            if themeManager.appearanceMode == mode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(Color.accentPrimary)
                                    .font(.title3)
                            }
                        }
                        .padding(.vertical, DS.Spacing.sm)
                    }
                    .listRowBackground(Color.themeCardBackground)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AdaptiveBackgroundView())
            .navigationTitle(L10n.appearance)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.done) { dismiss() }
                }
            }
        }
    }
    
    private func modeDescription(_ mode: AppearanceMode) -> String {
        switch mode {
        case .system: return "Match device settings"
        case .light: return "Always use light mode"
        case .dark: return "Always use dark mode"
        }
    }
}


// MARK: - Theme Picker View
struct ThemePickerView: View {
    @Environment(ThemeManager.self) var themeManager
    
    let columns = [
        GridItem(.flexible()),
        GridItem(.flexible())
    ]
    
    var body: some View {
        LazyVGrid(columns: columns, spacing: DS.Spacing.lg) {
            ForEach(AppTheme.allCases) { theme in
                ThemeCard(
                    theme: theme,
                    isSelected: themeManager.currentTheme == theme,
                    onSelect: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            themeManager.currentTheme = theme
                        }
                    }
                )
            }
        }
    }
}

// MARK: - Theme Card (Updated for 4-color system)
struct ThemeCard: View {
    let theme: AppTheme
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: DS.Spacing.md) {
                // Color preview - gradient background with 4 color circles
                ZStack {
                    // Background using theme surface and card colors
                    RoundedRectangle(cornerRadius: DS.Radius.xl)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(hex: theme.palette.surface),
                                    Color(hex: theme.palette.card)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(height: 100)
                    
                    // 4 color circles (Primary, Accent, Surface, Card)
                    HStack(spacing: DS.Spacing.sm) {
                        ForEach(0..<4, id: \.self) { index in
                            Circle()
                                .fill(theme.previewColors[index])
                                .frame(width: DS.IconContainer.sm, height: DS.IconContainer.sm)
                                .elevation2()
                        }
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.xl)
                        .stroke(isSelected ? Color(hex: theme.palette.primary) : Color.clear, lineWidth: DS.Border.heavy)
                )
                
                // Theme name
                HStack {
                    Text(theme.displayName)
                        .font(DS.Typography.body())
                        .fontWeight(isSelected ? .semibold : .regular)
                        .foregroundStyle(isSelected ? Color(hex: theme.palette.primary) : Color.textPrimary)
                    
                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(DS.Typography.bodySmall())
                            .foregroundStyle(Color(hex: theme.palette.primary))
                    }
                }
            }
            .padding(DS.Spacing.md)
            .background(RoundedRectangle(cornerRadius: DS.Radius.xxl).fill(Color.themeCardBackground))
            .shadow(color: isSelected ? Color(hex: theme.palette.primary).opacity(0.3) : Color.black.opacity(0.05), radius: isSelected ? 8 : 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Language Picker View
struct LanguagePickerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(LocalizationManager.self) var localization
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(AppLanguage.allCases) { language in
                        Button(action: {
                            localization.setLanguage(language)
                            dismiss()
                        }) {
                            HStack {
                                Text(language.displayName)
                                    .foregroundStyle(Color.textPrimary)
                                
                                Spacer()
                                
                                if localization.selectedLanguage == language {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentPrimary)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .listRowBackground(Color.themeCardBackground)
                    }
                }//intead of footer, use a help inline incone to show this text
                footer: {
                    Text(L10n.languageDescription)
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AdaptiveBackgroundView())
            .navigationTitle(L10n.language)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(L10n.done) { dismiss() }
                }
            }
        }
    }
}
