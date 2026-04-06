//  LegalView.swift
//  Assistant
//
//  PURPOSE:
//    Hosts the three legal documents required for App Store publication:
//    Privacy Policy, Terms of Service, and Parental Consent disclosure.
//    All content renders in-app via native ScrollView — no external browser.
//
//  ARCHITECTURE ROLE:
//    Leaf view — presented modally from SettingsView, PaywallView,
//    AuthenticationView, and FamilySetupView. Has no dependencies
//    on any ViewModel; purely static content.
//
//  DATA FLOW:
//    None. Receives a LegalDocument enum case and renders the matching
//    localized content. Dismiss via toolbar close button.
//
//  APP STORE REQUIREMENTS MET:
//    ✅  Privacy Policy (App Store Review Guideline 5.1.1)
//    ✅  Terms of Service / EULA (Guideline 3.1.2)
//    ✅  Parental / Guardian Consent (COPPA / Guideline 1.3)
//    ✅  Links accessible BEFORE sign-up and in Settings
//

import SwiftUI

// MARK: - Legal Document Type

enum LegalDocument: String, Identifiable, CaseIterable {
    case privacyPolicy
    case termsOfService
    case parentalConsent
    
    var id: String { rawValue }
    
    var titleKey: String {
        switch self {
        case .privacyPolicy:   return "privacy_policy"
        case .termsOfService:  return "terms_of_service"
        case .parentalConsent: return "parental_consent"
        }
    }
    
    var icon: String {
        switch self {
        case .privacyPolicy:   return "hand.raised.fill"
        case .termsOfService:  return "doc.text.fill"
        case .parentalConsent: return "figure.and.child.holdinghands"
        }
    }
}

// MARK: - Legal View

struct LegalView: View {
    let document: LegalDocument
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: DS.Spacing.xl) {
                    headerSection
                    contentSection
                    footerSection
                }
                .padding(.horizontal, DS.Spacing.lg)
                .padding(.bottom, DS.Spacing.xxl)
            }
            .scrollContentBackground(.hidden)
            .background(AdaptiveBackgroundView())
            .navigationTitle(document.titleKey)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Header
    
    private var headerSection: some View {
        VStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.accentPrimary.opacity(0.12))
                    .frame(width: 56, height: 56)
                Image(systemName: document.icon)
                    .font(.title2)
                    .foregroundStyle(.accentPrimary)
            }
            .padding(.top, DS.Spacing.lg)
            
            Text("last_updated_date")
                .font(DS.Typography.caption())
                .foregroundStyle(.textTertiary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var contentSection: some View {
        switch document {
        case .privacyPolicy:
            privacyPolicyContent
        case .termsOfService:
            termsOfServiceContent
        case .parentalConsent:
            parentalConsentContent
        }
    }
    
    // MARK: - Footer
    
    private var footerSection: some View {
        VStack(spacing: DS.Spacing.md) {
            Divider()
            Text("legal_contact_email")
                .font(DS.Typography.caption())
                .foregroundStyle(.textTertiary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, DS.Spacing.lg)
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Privacy Policy Content
    // ═══════════════════════════════════════════════════════════════════
    
    private var privacyPolicyContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            legalSection(
                title: "pp_data_we_collect",
                body: "pp_data_we_collect_body"
            )
            legalSection(
                title: "pp_how_we_use_data",
                body: "pp_how_we_use_data_body"
            )
            legalSection(
                title: "pp_third_party_services",
                body: "pp_third_party_services_body"
            )
            legalSection(
                title: "pp_data_storage",
                body: "pp_data_storage_body"
            )
            legalSection(
                title: "pp_childrens_privacy",
                body: "pp_childrens_privacy_body"
            )
            legalSection(
                title: "pp_your_rights",
                body: "pp_your_rights_body"
            )
            legalSection(
                title: "pp_changes_to_policy",
                body: "pp_changes_to_policy_body"
            )
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Terms of Service Content
    // ═══════════════════════════════════════════════════════════════════
    
    private var termsOfServiceContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            legalSection(
                title: "tos_acceptance",
                body: "tos_acceptance_body"
            )
            legalSection(
                title: "tos_subscriptions",
                body: "tos_subscriptions_body"
            )
            legalSection(
                title: "tos_credits",
                body: "tos_credits_body"
            )
            legalSection(
                title: "tos_ai_disclaimer",
                body: "tos_ai_disclaimer_body"
            )
            legalSection(
                title: "tos_user_conduct",
                body: "tos_user_conduct_body"
            )
            legalSection(
                title: "tos_termination",
                body: "tos_termination_body"
            )
            legalSection(
                title: "tos_limitation_of_liability",
                body: "tos_limitation_of_liability_body"
            )
        }
    }
    
    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Parental Consent Content
    // ═══════════════════════════════════════════════════════════════════
    
    private var parentalConsentContent: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.xl) {
            legalSection(
                title: "pc_family_app_notice",
                body: "pc_family_app_notice_body"
            )
            legalSection(
                title: "pc_minor_accounts",
                body: "pc_minor_accounts_body"
            )
            legalSection(
                title: "pc_parent_controls",
                body: "pc_parent_controls_body"
            )
            legalSection(
                title: "pc_ai_features",
                body: "pc_ai_features_body"
            )
            legalSection(
                title: "pc_data_for_minors",
                body: "pc_data_for_minors_body"
            )
            legalSection(
                title: "pc_contact_us",
                body: "pc_contact_us_body"
            )
        }
    }
    
    // MARK: - Reusable Section Builder
    
    private func legalSection(title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(LocalizedStringKey(title))
                .font(DS.Typography.subheading())
                .foregroundStyle(.textPrimary)
            Text(LocalizedStringKey(body))
                .font(DS.Typography.body())
                .foregroundStyle(.textSecondary)
                .lineSpacing(4)
        }
    }
}
