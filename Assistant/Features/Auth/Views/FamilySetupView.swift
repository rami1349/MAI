//
//  FamilySetupView.swift
//  FamilyHub
//
//  Create or join family flow after registration - with inline help
//

import SwiftUI

struct FamilySetupView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @State private var familyName = ""
    @State private var inviteCode = ""
    @State private var isCreating = true
    
    var body: some View {
        ZStack {
            LinearGradient.backgroundGradient
                .ignoresSafeArea()
            
            ScrollView {
                VStack(spacing: DS.Spacing.xxxl) {
                    Spacer().frame(height: DS.Spacing.jumbo)
                    
                    // Icon
                    Image("collaboration")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 300, height: 300)
                    
                    // Title
                    VStack(spacing: DS.Spacing.sm) {
                        Text("\(L10n.hi) \(authViewModel.currentUser?.displayName ?? "")!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(Color.textPrimary)
                        
                        Text(L10n.letSetupFamily)
                            .font(.subheadline)
                            .foregroundStyle(Color.textSecondary)
                    }
                    
                    // Toggle
                    modeToggle
                    
                    // Form
                    formSection
                    
                    // Error message
                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(Color.accentRed)
                            .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
                    }
                    
                    // Action Button
                    PrimaryButton(
                        title: isCreating ? L10n.createFamily : L10n.joinFamily,
                        isLoading: authViewModel.isLoading,
                        isDisabled: isCreating ? familyName.isEmpty : inviteCode.count != 6
                    ) {
                        Task {
                            if isCreating {
                                await authViewModel.createFamily(name: familyName)
                            } else {
                                await authViewModel.joinFamily(inviteCode: inviteCode.uppercased())
                            }
                        }
                    }
                    .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
                    
                    // Sign out option
                    Button(L10n.signOut) {
                        authViewModel.signOut()
                    }
                    .font(.subheadline)
                    .foregroundStyle(Color.textSecondary)
                    
                    Spacer()
                }
                .constrainedWidth(.form)
            }
        }
    }
    
    // MARK: - Mode Toggle
    private var modeToggle: some View {
        HStack(spacing: 0) {
            Button(action: { isCreating = true }) {
                Text(L10n.createFamily)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isCreating ? .white : Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(
                        isCreating ?
                        RoundedRectangle(cornerRadius: DS.Radius.button).fill(Color.accentPrimary) :
                            RoundedRectangle(cornerRadius: DS.Radius.button).fill(Color.clear)
                    )
            }
            
            Button(action: { isCreating = false }) {
                Text(L10n.joinFamily)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(!isCreating ? .white : Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(
                        !isCreating ?
                        RoundedRectangle(cornerRadius: DS.Radius.button).fill(Color.accentPrimary) :
                            RoundedRectangle(cornerRadius: DS.Radius.button).fill(Color.clear)
                    )
            }
        }
        .padding(DS.Spacing.xs)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .fill(Color.backgroundSecondary)
        )
        .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
    }
    
    // MARK: - Form Section
    private var formSection: some View {
        VStack(spacing: DS.Spacing.lg) {
            if isCreating {
                // Family name with help
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    CustomTextField(
                        placeholder: L10n.familyName,
                        text: $familyName,
                        icon: "house"
                    )
                }
                
                Text(L10n.createFamilyMessage)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                // Invite code with help
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    CustomTextField(
                        placeholder: L10n.inviteCode,
                        text: $inviteCode,
                        icon: "ticket"
                    )
                    .textInputAutocapitalization(.characters)
                }
                
                Text(L10n.enterInviteCode)
                    .font(.caption)
                    .foregroundStyle(Color.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
    }
}

#Preview {
    FamilySetupView()
        .environment(AuthViewModel())
}
