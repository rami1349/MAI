//
//  DeleteAccountSheet.swift
//  FamilyHub
//
//  Sheet for confirming account deletion with reauthentication support
//

import SwiftUI

struct DeleteAccountSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AuthViewModel.self) var authViewModel
    
    @State private var password = ""
    @State private var confirmText = ""
    @State private var step: DeleteStep = .confirm
    
    enum DeleteStep {
        case confirm
        case reauthenticate
        case deleting
    }
    
    private let requiredConfirmation = "DELETE"
    
    var body: some View {
        NavigationStack {
            VStack(spacing: DS.Spacing.xxl) {
                // Warning icon
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: DS.IconSize.xxxl)) // DT-exempt: icon sizing
                    .foregroundStyle(Color.accentRed)
                    .padding(.top, DS.Spacing.xl)
                
                // Title
                Text(L10n.deleteAccount)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(Color.textPrimary)
                
                // Warning message
                VStack(spacing: DS.Spacing.md) {
                    Text(L10n.deleteAccountPermanent)
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Text(L10n.deleteAccountRemoves)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(Color.textPrimary)
                    
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        deleteWarningItem("Your profile and account")
                        deleteWarningItem("All your habits and habit history")
                        deleteWarningItem("All tasks you created")
                        deleteWarningItem("Calendar events you created")
                        deleteWarningItem("Your notifications")
                        deleteWarningItem("You will be removed from your family")
                    }
                    .padding(.horizontal)
                    
                    Text(L10n.tasksUnassignedNote)
                        .font(.caption)
                        .foregroundStyle(Color.textTertiary)
                        .italic()
                }
                .padding(.horizontal)
                
                // Content based on step
                switch step {
                case .confirm:
                    confirmationStep
                case .reauthenticate:
                    reauthenticationStep
                case .deleting:
                    deletingStep
                }
                
                Spacer()
            }
            .padding()
            .constrainedWidth(.form)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(L10n.cancel) {
                        dismiss()
                    }
                    .disabled(step == .deleting)
                }
            }
            .onChange(of: authViewModel.needsReauthentication) { _, needsReauth in
                if needsReauth {
                    step = .reauthenticate
                }
            }
            // Note: No need to watch isAuthenticated for dismissal.
            // When the account is deleted, the auth state listener sets isAuthenticated = false,
            // which causes ContentView to show AuthenticationView instead of MainTabView.
            // This naturally removes the sheet from the view hierarchy.
        }
    }
    
    // MARK: - Step Views
    
    private var confirmationStep: some View {
        VStack(spacing: DS.Spacing.lg) {
            Text(L10n.typeToConfirm(requiredConfirmation))
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
            
            TextField(L10n.typeDeletePlaceholder, text: $confirmText)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.allCharacters)
                .padding(.horizontal)
            
            if let error = authViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.accentRed)
                    .padding(.horizontal)
            }
            
            Button(action: {
                step = .deleting
                Task {
                    await authViewModel.deleteAccount()
                    // If we need reauth, step will change via onChange
                    // If successful, isAuthenticated will become false
                    if authViewModel.isAuthenticated && !authViewModel.needsReauthentication {
                        step = .confirm
                    }
                }
            }) {
                Text(L10n.deleteMyAccount)
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.card)
                            .fill(confirmText == requiredConfirmation ? Color.accentRed : Color.gray.opacity(0.5))
                    )
            }
            .disabled(confirmText != requiredConfirmation)
            .padding(.horizontal)
        }
    }
    
    private var reauthenticationStep: some View {
        VStack(spacing: DS.Spacing.lg) {
            Text(L10n.reenterPassword)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
            
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            
            if let error = authViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(Color.accentRed)
                    .padding(.horizontal)
            }
            
            Button(action: {
                Task {
                    let email = authViewModel.currentUser?.email ?? ""
                    let success = await authViewModel.reauthenticate(email: email, password: password)
                    if success {
                        // Try deleting again
                        step = .deleting
                        await authViewModel.deleteAccount()
                    }
                }
            }) {
                HStack {
                    if authViewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    }
                    Text(L10n.confirmAndDelete)
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.card)
                        .fill(password.count >= 6 ? Color.accentRed : Color.gray.opacity(0.5))
                )
            }
            .disabled(password.count < 6 || authViewModel.isLoading)
            .padding(.horizontal)
            
            Button(L10n.goBack) {
                step = .confirm
                password = ""
                authViewModel.errorMessage = nil
                authViewModel.needsReauthentication = false
            }
            .font(.subheadline)
            .foregroundStyle(Color.textSecondary)
        }
    }
    
    private var deletingStep: some View {
        VStack(spacing: DS.Spacing.lg) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            
            Text(L10n.deletingAccount)
                .font(.subheadline)
                .foregroundStyle(Color.textSecondary)
        }
        .padding(.top, DS.Spacing.xl)
    }
    
    // MARK: - Helper Views
    
    private func deleteWarningItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(Color.accentRed)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundStyle(Color.textSecondary)
        }
    }
}

#Preview {
    DeleteAccountSheet()
        .environment(AuthViewModel())
}
