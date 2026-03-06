//
//  EditProfileSheet.swift
//  Assistant
//
//  Created by Ramiro  on 2/9/26.
//
//  Profile editing sheet with avatar, name, DOB, and yearly goal
//

import SwiftUI
import PhotosUI

// MARK: - Edit Profile Sheet
struct EditProfileSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyViewModel.self) var familyViewModel
    
    @State private var displayName: String = ""
    @State private var goal: String = ""
    @State private var dateOfBirth: Date = Date()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var isLoading = false
    @State private var showDatePicker = false
    
    private var currentYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
    }
    
    var body: some View {
        NavigationStack {
            Form {
                // Avatar Section
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: DS.Spacing.md) {
                            if let avatarImage = avatarImage {
                                Image(uiImage: avatarImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: DS.Avatar.xl, height: DS.Avatar.xl)
                                    .clipShape(Circle())
                            } else if let user = authViewModel.currentUser {
                                AvatarView(user: user, size: DS.Avatar.xl)
                            }
                            
                            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                                Text(L10n.changePhoto)
                                    .font(.subheadline)
                                    .foregroundStyle(.accentPrimary)
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                
                // Basic Info Section
                Section(L10n.basicInfo) {
                    TextField(L10n.displayName, text: $displayName)
                    
                    Button {
                        showDatePicker.toggle()
                    } label: {
                        HStack {
                            Text(L10n.dateOfBirth)
                                .foregroundStyle(.textPrimary)
                            Spacer()
                            Text(dateOfBirth.formattedDate)
                                .foregroundStyle(.textSecondary)
                        }
                    }
                    
                    if showDatePicker {
                        DatePicker(
                            "Date of Birth",
                            selection: $dateOfBirth,
                            in: ...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.wheel)
                        .labelsHidden()
                    }
                }
                
                // Goal Section
                Section {
                    VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                        TextEditor(text: $goal)
                            .frame(minHeight: 50)
                            .overlay(
                                Group {
                                    if goal.isEmpty {
                                        Text(L10n.yearlyGoalPlaceholder)
                                            .foregroundStyle(.textTertiary)
                                            .padding(.top, DS.Spacing.sm)
                                            .padding(.leading, DS.Spacing.xs)
                                            .allowsHitTesting(false)
                                    }
                                },
                                alignment: .topLeading
                            )
                    }
                } header: {
                    Text(L10n.yearlyGoal)
                } footer: {
                    Text(L10n.yearlyGoalDescription)
                }
                
                // Goal Suggestions
                Section(L10n.goalIdeas) {
                    GoalSuggestionButton(text: "Exercise regularly and stay healthy") {
                        goal = "Exercise regularly and stay healthy"
                    }
                    GoalSuggestionButton(text: "Save money and be financially responsible") {
                        goal = "Save money and be financially responsible"
                    }
                    GoalSuggestionButton(text: "Complete all my assigned tasks on time") {
                        goal = "Complete all my assigned tasks on time"
                    }
                    GoalSuggestionButton(text: "Spend more quality time with family") {
                        goal = "Spend more quality time with family"
                    }
                }
            }
            .navigationTitle(L10n.editProfile)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.save) {
                        saveProfile()
                    }
                    .disabled(isLoading || displayName.isEmpty)
                }
            }
            .onAppear {
                loadCurrentUser()
            }
            .onChange(of: selectedPhoto) { _, newValue in
                loadSelectedPhoto(newValue)
            }
        }
    }
    
    private func loadCurrentUser() {
        guard let user = authViewModel.currentUser else { return }
        displayName = user.displayName
        dateOfBirth = user.dateOfBirth
        goal = user.goal ?? ""
    }
    
    private func loadSelectedPhoto(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    avatarImage = image
                }
            }
        }
    }
    
    private func saveProfile() {
        guard let userId = authViewModel.currentUser?.id else { return }
        isLoading = true
        
        Task {
            var avatarData: Data? = nil
            if let image = avatarImage {
                avatarData = image.jpegData(compressionQuality: 0.7)
            }
            
            await familyViewModel.updateUserProfile(
                userId: userId,
                displayName: displayName,
                dateOfBirth: dateOfBirth,
                goal: goal.isEmpty ? nil : goal,
                avatarData: avatarData
            )
            
            // Update auth view model's current user
            if var updatedUser = authViewModel.currentUser {
                updatedUser.displayName = displayName
                updatedUser.dateOfBirth = dateOfBirth
                updatedUser.goal = goal.isEmpty ? nil : goal
                await authViewModel.refreshCurrentUser()
            }
            
            isLoading = false
            dismiss()
        }
    }
}

// MARK: - Goal Suggestion Button
struct GoalSuggestionButton: View {
    let text: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                    .font(.subheadline)
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "plus.circle")
                    .foregroundStyle(.accentPrimary)
            }
        }
    }
}
