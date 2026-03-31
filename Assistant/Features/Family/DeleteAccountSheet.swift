//
//  DeleteAccountSheet.swift
//
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
                    .foregroundStyle(.accentRed)
                    .padding(.top, DS.Spacing.xl)
                
                // Title
                Text("delete_account")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.textPrimary)
                
                // Warning message
                VStack(spacing: DS.Spacing.md) {
                    Text("delete_account_permanent")
                        .font(.subheadline)
                        .foregroundStyle(.textSecondary)
                        .multilineTextAlignment(.center)
                    
                    Text("delete_account_removes")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.textPrimary)
                    
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        deleteWarningItem("Your profile and account")
                        deleteWarningItem("All your habits and habit history")
                        deleteWarningItem("All tasks you created")
                        deleteWarningItem("Calendar events you created")
                        deleteWarningItem("Your notifications")
                        deleteWarningItem("You will be removed from your family")
                    }
                    .padding(.horizontal)
                    
                    Text("tasks_unassigned_note")
                        .font(.caption)
                        .foregroundStyle(.textTertiary)
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
                    Button("cancel") {
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
            Text(AppStrings.typeToConfirm(requiredConfirmation))
                .font(.subheadline)
                .foregroundStyle(.textSecondary)
            
            TextField("type_delete_placeholder", text: $confirmText)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.allCharacters)
                .padding(.horizontal)
            
            if let error = authViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.accentRed)
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
                Text("delete_my_account")
                    .fontWeight(.semibold)
                    .foregroundStyle(.textOnAccent)
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
            Text("reenter_password")
                .font(.subheadline)
                .foregroundStyle(.textSecondary)
            
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
            
            if let error = authViewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.accentRed)
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
                    Text("confirm_and_delete")
                        .fontWeight(.semibold)
                }
                .foregroundStyle(.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.card)
                        .fill(password.count >= 6 ? Color.accentRed : Color.gray.opacity(0.5))
                )
            }
            .disabled(password.count < 6 || authViewModel.isLoading)
            .padding(.horizontal)
            
            Button("go_back") {
                step = .confirm
                password = ""
                authViewModel.errorMessage = nil
                authViewModel.needsReauthentication = false
            }
            .font(.subheadline)
            .foregroundStyle(.textSecondary)
        }
    }
    
    private var deletingStep: some View {
        VStack(spacing: DS.Spacing.lg) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.5)
            
            Text("deleting_account")
                .font(.subheadline)
                .foregroundStyle(.textSecondary)
        }
        .padding(.top, DS.Spacing.xl)
    }
    
    // MARK: - Helper Views
    
    private func deleteWarningItem(_ text: String) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.accentRed)
                .font(.caption)
            Text(text)
                .font(.caption)
                .foregroundStyle(.textSecondary)
        }
    }
}

#Preview {
    DeleteAccountSheet()
        .environment(AuthViewModel())
}
