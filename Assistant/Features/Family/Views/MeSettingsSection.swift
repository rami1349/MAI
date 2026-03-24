// ============================================================================
// MeSettingsSection.swift
//
// ME TAB section 8: Settings
//
// No longer a toolbar gear button. Settings are inline at the bottom
// of the Me scroll. Shows quick actions (theme, language, sign out)
// and a "All Settings" button for the full SettingsView.
//
// ============================================================================

import SwiftUI

struct MeSettingsSection: View {
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(ThemeManager.self) var themeManager

    @State private var showFullSettings = false
    @State private var showSignOutConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Section header
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "gearshape.fill")
                    .font(DS.Typography.label())
                    .foregroundStyle(.textSecondary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle().fill(Color.textSecondary.opacity(0.1))
                    )

                Text("settings")
                    .font(DS.Typography.subheading())
                    .foregroundStyle(.textPrimary)

                Spacer()
            }

            // Quick settings rows
            VStack(spacing: 0) {
                // Theme
                settingsRow(
                    icon: "paintbrush.fill",
                    iconColor: .accentPrimary,
                    title: "theme_color",
                    value: themeManager.currentTheme.displayName
                ) {
                    showFullSettings = true
                }

                Divider().padding(.leading, 48)

                // Language
                settingsRow(
                    icon: "globe",
                    iconColor: .accentTertiary,
                    title: "language",
                    value: AppLanguage.shared.displayName
                ) {
                    showFullSettings = true
                }

                Divider().padding(.leading, 48)

                // Subscription / Plan
                if let user = authViewModel.currentUser {
                    settingsRow(
                        icon: "crown.fill",
                        iconColor: .accentOrange,
                        title: "plan",
                        value: user.isPremium
                            ? AppStrings.localized("premium")
                            : AppStrings.localized("free")
                    ) {
                        showFullSettings = true
                    }

                    Divider().padding(.leading, 48)
                }

                // All Settings
                settingsRow(
                    icon: "slider.horizontal.3",
                    iconColor: .textSecondary,
                    title: "all_settings",
                    value: nil
                ) {
                    showFullSettings = true
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(Color.themeSurfacePrimary)
            )

            // Sign Out
            Button(action: { showSignOutConfirm = true }) {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(DS.Typography.body())
                    Text("sign_out")
                        .font(DS.Typography.label())
                }
                .foregroundStyle(.statusError)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .fill(Color.statusError.opacity(0.08))
                )
            }
            .buttonStyle(.plain)
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xxl)
                .fill(Color.themeCardBackground)
        )
        .elevation1()
        .sheet(isPresented: $showFullSettings) {
            SettingsView()
                .presentationBackground(Color.themeSurfacePrimary)
        }
        .alert("sign_out_confirm", isPresented: $showSignOutConfirm) {
            Button("sign_out", role: .destructive) {
                authViewModel.signOut()
            }
            Button("cancel", role: .cancel) {}
        }
    }

    // MARK: - Settings Row

    private func settingsRow(
        icon: String,
        iconColor: Color,
        title: LocalizedStringKey,
        value: String?,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(DS.Typography.body())
                    .foregroundStyle(iconColor)
                    .frame(width: 28)

                Text(title)
                    .font(DS.Typography.body())
                    .foregroundStyle(.textPrimary)

                Spacer()

                if let value {
                    Text(value)
                        .font(DS.Typography.bodySmall())
                        .foregroundStyle(.textTertiary)
                }

                Image(systemName: "chevron.right")
                    .font(DS.Typography.caption())
                    .foregroundStyle(.textTertiary)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.md)
        }
        .buttonStyle(.plain)
    }
}
