//
//  AddHabitView.swift
//
//  CONSISTENCY FIX: Aligned with AddEventView/EditEventView pattern.
//
//  Changes:
//  - AdaptiveBackgroundView → Color.themeSurfacePrimary
//  - Color.backgroundCard → Color.themeCardBackground
//  - Color.backgroundSecondary → Color.themeCardBackground
//  - Raw .font(.caption/.headline/.title2) → DS.Typography tokens
//  - DS.Spacing.xxl → DS.Spacing.xl for section spacing
//  - Unstyled toolbar buttons → styled with DS.Typography
//  - .navigationTitle → custom .principal toolbar item
//

import SwiftUI
import UIKit

struct AddHabitView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(FamilyViewModel.self) var familyViewModel
    
    @State private var name = ""
    @State private var selectedIcon = "star.fill"
    @State private var selectedColor = "8B7EC8"
    @State private var isLoading = false
    @State private var showSuccess = false
    @State private var createError: String? = nil
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeSurfacePrimary
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: DS.Spacing.xl) {
                        previewSection
                        nameSection
                        iconSection
                        colorSection
                    }
                    .padding(.horizontal, DS.Spacing.screenH)
                    .padding(.top, DS.Spacing.md)
                    .constrainedWidth(.form)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                        .font(DS.Typography.body())
                        .foregroundStyle(.textSecondary)
                }
                ToolbarItem(placement: .principal) {
                    Text("new_habit")
                        .font(DS.Typography.subheading())
                        .foregroundStyle(.textPrimary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: createHabit) {
                        if isLoading {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Text("create")
                                .font(DS.Typography.label())
                                .fontWeight(.semibold)
                        }
                    }
                    .foregroundStyle(name.isEmpty ? .textTertiary : .accentPrimary)
                    .disabled(name.isEmpty || isLoading)
                }
            }
            .overlay {
                if showSuccess {
                    SuccessDismissOverlay(message: "habit_created") {
                        dismiss()
                    }
                }
            }
            .globalErrorBanner(errorMessage: $createError)
        }
    }
    
    // MARK: - Preview Section
    private var previewSection: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color(hex: selectedColor).opacity(0.2))
                    .frame(width: DS.IconSize.jumbo, height: DS.IconSize.jumbo)
                
                Image(systemName: selectedIcon)
                    .font(DS.Typography.heading())
                    .foregroundStyle(Color(hex: selectedColor))
            }
            
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(name.isEmpty ? "Habit Name" : name)
                    .font(DS.Typography.subheading())
                    .foregroundStyle(name.isEmpty ? .textTertiary : .textPrimary)
                Text("track_daily")
                    .font(DS.Typography.caption())
                    .foregroundStyle(.textSecondary)
            }
            
            Spacer()
            
            // Sample dots
            HStack(spacing: DS.Spacing.xs) {
                ForEach(0..<5, id: \.self) { i in
                    Circle()
                        .fill(Color(hex: selectedColor).opacity(i < 3 ? 1 : 0.15))
                        .frame(width: DS.IconSize.sm, height: DS.IconSize.sm)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .fill(Color.themeCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .stroke(Color.themeCardBorder, lineWidth: 0.5)
        )
    }
    
    // MARK: - Name Section
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            TextField("habit_place_holder", text: $name)
                .font(DS.Typography.body())
                .padding(DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .fill(Color.themeCardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(Color.themeCardBorder, lineWidth: 1)
                )
        }
    }
    
    // MARK: - Icon Section
    private var iconSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("icon")
                .font(DS.Typography.caption())
                .foregroundStyle(.textSecondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: DS.Spacing.md) {
                ForEach(HabitColors.icons, id: \.icon) { item in
                    Button {
                        selectedIcon = item.icon
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: DS.Radius.md)
                                .fill(selectedIcon == item.icon ?
                                      Color(hex: selectedColor).opacity(0.2) :
                                        Color.themeCardBackground)
                                .frame(width: DS.Control.large, height: DS.Control.large)
                            
                            Image(systemName: item.icon)
                                .foregroundStyle(selectedIcon == item.icon ?
                                                 Color(hex: selectedColor) :
                                        Color.textSecondary)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Color Section
    private var colorSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text("color")
                .font(DS.Typography.caption())
                .foregroundStyle(.textSecondary)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: DS.Spacing.md) {
                ForEach(HabitColors.colors, id: \.hex) { color in
                    Button {
                        selectedColor = color.hex
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(hex: color.hex))
                                .frame(width: DS.Control.standard, height: DS.Control.standard)
                            
                            if selectedColor == color.hex {
                                Circle()
                                    .stroke(Color.white, lineWidth: DS.Border.heavy)
                                    .frame(width: DS.IconContainer.md, height: DS.IconContainer.md)
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func createHabit() {
        isLoading = true
        createError = nil
        
        Task {
            await familyViewModel.createHabit(
                name: name,
                icon: selectedIcon,
                colorHex: selectedColor
            )
            isLoading = false
            
            if let error = familyViewModel.errorMessage {
                createError = error
                familyViewModel.errorMessage = nil
                DS.Haptics.error()
            } else {
                withAnimation {
                    showSuccess = true
                }
            }
        }
    }
}

#Preview {
    let familyVM = FamilyViewModel()
    AddHabitView()
        .environment(familyVM)
        .environment(familyVM.familyMemberVM)
        .environment(familyVM.taskVM)
        .environment(familyVM.calendarVM)
        .environment(familyVM.habitVM)
        .environment(familyVM.notificationVM)
}
