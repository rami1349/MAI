//
//  SettingsView.swift
//  Assistant
//
//  PURPOSE:
//    Central hub for user preferences and account management.
//    Surfaces account info, subscription tier, AI credit balance,
//    appearance / theme / language pickers, legal documents, and
//    destructive actions (sign-out, delete account).
//
//  ARCHITECTURE ROLE:
//    Leaf modal — presented from MeView or navigation sidebar.
//    Reads SubscriptionManager, AuthViewModel, ThemeManager, and
//    AppLanguage from the SwiftUI environment. Owns no domain logic;
//    delegates every action to the appropriate environment object.
//
//  DATA FLOW:
//    SubscriptionManager  → tier, aiCredits, restorePurchases()
//    AuthViewModel        → currentUser, signOut()
//    ThemeManager         → currentTheme, appearanceMode
//    AppLanguage          → selectedLanguage, setLanguage()
//
//  APP STORE REQUIREMENTS:
//    ✅  Restore Purchases button in Subscription section
//    ✅  Manage Subscription deep-link to Apple settings
//    ✅  Privacy Policy, Terms of Service, Parental Consent links
//

import SwiftUI

// MARK: - Settings View
struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(AppLanguage.self) var appLanguage
    @Environment(ThemeManager.self) var themeManager
    @State private var showLogoutAlert = false
    @State private var showLanguagePicker = false
    @State private var showThemePicker = false
    @State private var showAppearancePicker = false
    @State private var showDeleteAccountSheet = false
    @Environment(SubscriptionManager.self) var store
    @State private var showPaywall = false
    @State private var selectedLegalDocument: LegalDocument?

    var body: some View {
        NavigationStack {
            settingsContent
                .scrollContentBackground(.hidden)
                .background(AdaptiveBackgroundView())
                .navigationTitle("settings")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("done") { dismiss() }
                    }
                }
                .alert("sign_out_confirm", isPresented: $showLogoutAlert) {
                    Button("cancel", role: .cancel) {}
                    Button("sign_out", role: .destructive) {
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
                .navigationTitle("choose_theme")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("done") { showThemePicker = false }
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
        .sheet(item: $selectedLegalDocument) { doc in
            LegalView(document: doc)
                .presentationBackground(Color.themeSurfacePrimary)
        }
    }
    
    private var settingsContent: some View {
        List {
            Section("account") {
                if let user = authViewModel.currentUser {
                    HStack {
                        Text("email")
                        Spacer()
                        Text(user.email).foregroundStyle(.textSecondary)
                    }
                    .listRowBackground(Color.themeCardBackground)
                    HStack {
                        Text("role")
                        Spacer()
                        Text(user.resolvedPreset.displayName).foregroundStyle(.textSecondary)
                    }
                    .listRowBackground(Color.themeCardBackground)
                }
            }
            
            // MARK: - Subscription
            Section("subscription") {
                Button {
                    if store.tier.isPremium {
                        // Already premium — show manage info
                    } else {
                        showPaywall = true
                    }
                } label: {
                    HStack {
                        Image(systemName: store.tier.isPremium ? "crown.fill" : "sparkles")
                            .foregroundStyle(store.tier.isPremium ? .yellow : .accentPrimary)
                            .frame(width: DS.IconContainer.sm)
                        Text("plan")
                            .foregroundStyle(.textPrimary)
                        Spacer()
                        Text(store.tier.displayName)
                            .foregroundStyle(store.tier.isPremium ? .yellow : .textSecondary)
                            .fontWeight(store.tier.isPremium ? .semibold : .regular)
                        if !store.tier.isPremium {
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.textTertiary)
                        }
                    }
                }
                .listRowBackground(Color.themeCardBackground)
                
                // Credits balance
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundStyle(.statusWarning)
                        .frame(width: DS.IconContainer.sm)
                    Text("ai_credits")
                        .foregroundStyle(.textPrimary)
                    Spacer()
                    Text("\(store.aiCredits)")
                        .foregroundStyle(.textSecondary)
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
                                .foregroundStyle(.accentPrimary)
                                .frame(width: DS.IconContainer.sm)
                            Text("manage_subscription")
                                .foregroundStyle(.accentPrimary)
                        }
                    }
                    .listRowBackground(Color.themeCardBackground)
                }
                
                Button {
                    Task { await store.restorePurchases() }
                } label: {
                    HStack {
                        Image(systemName: "arrow.clockwise")
                            .foregroundStyle(.accentPrimary)
                            .frame(width: DS.IconContainer.sm)
                        Text("restore_purchases")
                            .foregroundStyle(.accentPrimary)
                    }
                }
                .listRowBackground(Color.themeCardBackground)
            }
            
            Section("appearance") {
                Button(action: { showAppearancePicker = true }) {
                    HStack {
                        Image(systemName: themeManager.appearanceMode.icon)
                            .foregroundStyle(.accentPrimary)
                            .frame(width: DS.IconContainer.sm)
                        Text("appearance")
                            .foregroundStyle(.textPrimary)
                        Spacer()
                        Text(themeManager.appearanceMode.displayName)
                            .foregroundStyle(.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.textTertiary)
                    }
                }
                .listRowBackground(Color.themeCardBackground)
                
                Button(action: { showThemePicker = true }) {
                    HStack {
                        Image(systemName: "paintpalette.fill")
                            .foregroundStyle(.accentPrimary)
                            .frame(width: DS.IconContainer.sm)
                        Text("theme_color")
                            .foregroundStyle(.textPrimary)
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
                            .foregroundStyle(.textTertiary)
                    }
                }
                .listRowBackground(Color.themeCardBackground)
            }
            
            Section("app_section") {
                Button(action: { showLanguagePicker = true }) {
                    HStack {
                        Image(systemName: "globe")
                            .foregroundStyle(.accentPrimary)
                            .frame(width: DS.IconContainer.sm)
                        Text("language")
                            .foregroundStyle(.textPrimary)
                        Spacer()
                        Text(appLanguage.selectedLanguage == .system
                             ? "System (\(LanguageCode(rawValue: appLanguage.resolvedLanguageCode)?.displayName ?? "English"))"
                             : appLanguage.selectedLanguage.displayName)
                            .foregroundStyle(.textSecondary)
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.textTertiary)
                    }
                }
                .listRowBackground(Color.themeCardBackground)
                
                HStack {
                    Image(systemName: "info.circle")
                        .foregroundStyle(.accentPrimary)
                        .frame(width: DS.IconContainer.sm)
                    Text("version")
                    Spacer()
                    Text("1.0.0").foregroundStyle(.textSecondary)
                }
                .listRowBackground(Color.themeCardBackground)
            }
            
            // MARK: - Legal
            Section("legal") {
                ForEach(LegalDocument.allCases) { doc in
                    Button {
                        selectedLegalDocument = doc
                    } label: {
                        HStack {
                            Image(systemName: doc.icon)
                                .foregroundStyle(.accentPrimary)
                                .frame(width: DS.IconContainer.sm)
                            Text(doc.titleKey)
                                .foregroundStyle(.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.textTertiary)
                        }
                    }
                    .listRowBackground(Color.themeCardBackground)
                }
            }
            
            Section {
                Button(role: .destructive, action: {
                    showLogoutAlert = true
                }) {
                    HStack {
                        Spacer()
                        Text("sign_out")
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
                        Text("delete_account")
                    }
                }
                .listRowBackground(Color.themeCardBackground)
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
                                    .foregroundStyle(themeManager.appearanceMode == mode ? .accentPrimary : .textSecondary)
                            }
                            
                            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                Text(mode.displayName)
                                    .font(.body)
                                    .fontWeight(themeManager.appearanceMode == mode ? .semibold : .regular)
                                    .foregroundStyle(.textPrimary)
                                
                                Text(modeDescription(mode))
                                    .font(.caption)
                                    .foregroundStyle(.textSecondary)
                            }
                            
                            Spacer()
                            
                            if themeManager.appearanceMode == mode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.accentPrimary)
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
            .navigationTitle("appearance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done") { dismiss() }
                }
            }
        }
    }
    
    private func modeDescription(_ mode: AppearanceMode) -> String {
        switch mode {
        case .system: return String(localized: "appearance_match_device")
        case .light: return String(localized: "appearance_always_light")
        case .dark: return String(localized: "appearance_always_dark")
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
                        .foregroundStyle(isSelected ? Color(hex: theme.palette.primary) : .textPrimary)
                    
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
    @Environment(AppLanguage.self) var appLanguage
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(LanguageCode.allCases) { language in
                        Button(action: {
                            appLanguage.setLanguage(language)
                            dismiss()
                        }) {
                            HStack {
                                Text(language.displayName)
                                    .foregroundStyle(.textPrimary)
                                
                                Spacer()
                                
                                if appLanguage.selectedLanguage == language {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.accentPrimary)
                                        .fontWeight(.semibold)
                                }
                            }
                        }
                        .listRowBackground(Color.themeCardBackground)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AdaptiveBackgroundView())
            .navigationTitle("language")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done") { dismiss() }
                }
            }
        }
    }
}
