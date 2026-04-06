//
//  EditProfileSheet.swift
//  Assistant
//
//  Created by Ramiro  on 2/9/26.
//
//  Profile editing sheet with avatar, name, DOB, and yearly goal
//
//
//
//  PURPOSE:
//    Profile editing form. Supports avatar change, date of birth,
//    yearly goal with preset suggestions, and display name.
//
//  ARCHITECTURE ROLE:
//    Form modal — presented from FamilyView or MeView.
//    Calls FamilyMemberViewModel.updateProfile().
//
//  DATA FLOW:
//    AuthViewModel → currentUser
//    FamilyMemberViewModel → updateProfile()
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
    @State private var dateOfBirth: Date = .now
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var avatarImage: UIImage?
    @State private var isLoading = false
    @State private var showDatePicker = false
    
    private var currentYear: String {
        Date.now.formatted(.dateTime.year())
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
                                Text("change_photo")
                                    .font(DS.Typography.bodySmall())
                                    .foregroundStyle(.accentPrimary)
                            }
                        }
                        Spacer()
                    }
                    .listRowBackground(Color.clear)
                }
                
                // Basic Info Section
                Section("basic_info") {
                    TextField("display_name", text: $displayName)
                    
                    Button {
                        showDatePicker.toggle()
                    } label: {
                        HStack {
                            Text("date_of_birth")
                                .foregroundStyle(.textPrimary)
                            Spacer()
                            Text(dateOfBirth.formattedDate)
                                .foregroundStyle(.textSecondary)
                        }
                    }
                    
                    if showDatePicker {
                        DatePicker(
                            "date_of_birth",
                            selection: $dateOfBirth,
                            in: ...Date.now,
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
                                        Text("yearly_goal_place_holder")
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
                    Text("yearly_goal")
                }
                
                // Goal Suggestions
                Section("goal_ideas") {
                    GoalSuggestionButton(text: String(localized: "goal_exercise")) {
                        goal = String(localized: "goal_exercise")
                    }
                    GoalSuggestionButton(text: String(localized: "goal_save_money")) {
                        goal = String(localized: "goal_save_money")
                    }
                    GoalSuggestionButton(text: String(localized: "goal_complete_tasks")) {
                        goal = String(localized: "goal_complete_tasks")
                    }
                    GoalSuggestionButton(text: String(localized: "goal_family_time")) {
                        goal = String(localized: "goal_family_time")
                    }
                }
            }
            .navigationTitle("edit_profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("save") {
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
                    .font(DS.Typography.bodySmall())
                    .foregroundStyle(.textPrimary)
                    .multilineTextAlignment(.leading)
                Spacer()
                Image(systemName: "plus.circle")
                    .foregroundStyle(.accentPrimary)
            }
        }
    }
}
