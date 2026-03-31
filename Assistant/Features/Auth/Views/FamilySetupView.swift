//
//  FamilySetupView.swift
//
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
                        Text("\(AppStrings.localized("hi")) \(authViewModel.currentUser?.displayName ?? "")!")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundStyle(.textPrimary)
                        
                        Text("let_setup_family")
                            .font(.subheadline)
                            .foregroundStyle(.textSecondary)
                    }
                    
                    // Toggle
                    modeToggle
                    // Form
                    formSection
                    
                    // Error message
                    if let error = authViewModel.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.accentRed)
                            .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
                    }
                    
                    // Action Button
                    PrimaryButton(
                        title: isCreating ? "create_family" :"join_family",
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
                    Button("sign_out") {
                        authViewModel.signOut()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
                    
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
                Text("create_family")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(isCreating ? .textOnAccent : .textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, DS.Spacing.md)
                    .background(
                        isCreating ?
                        RoundedRectangle(cornerRadius: DS.Radius.button).fill(Color.accentPrimary) :
                            RoundedRectangle(cornerRadius: DS.Radius.button).fill(Color.clear)
                    )
            }
            
            Button(action: { isCreating = false }) {
                Text("join_family")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(!isCreating ? .textOnAccent : .textSecondary)
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
                        placeholder: "family_name",
                        text: $familyName,
                        icon: "house"
                    )
                }
                
                Text("create_family_message")
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                // Invite code with help
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    CustomTextField(
                        placeholder: "invite_code",
                        text: $inviteCode,
                        icon: "ticket"
                    )
                    .textInputAutocapitalization(.characters)
                }
                
                Text("enter_invite_code")
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
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
