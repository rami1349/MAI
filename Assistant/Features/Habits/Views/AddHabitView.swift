//
//  AddHabitView.swift
//  F

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
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    previewSection
                    nameSection
                    iconSection
                    colorSection
                }
                .padding(DS.Layout.adaptiveScreenPadding)
                .constrainedWidth(.form)
            }
            .scrollContentBackground(.hidden)
            .background(AdaptiveBackgroundView())
            .navigationTitle(L10n.newHabit)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.create) {
                        createHabit()
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
            .overlay {
                if showSuccess {
                    SuccessDismissOverlay(message: "Habit Created!") {
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
                    .font(.title2)
                    .foregroundStyle(Color(hex: selectedColor))
            }
            
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(name.isEmpty ? "Habit Name" : name)
                    .font(.headline)
                    .foregroundStyle(name.isEmpty ? .textTertiary : .textPrimary)
                Text(L10n.trackDaily)
                    .font(.caption)
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
        .background(RoundedRectangle(cornerRadius: DS.Radius.xl).fill(Color.backgroundCard))
    }
    
    // MARK: - Name Section
    private var nameSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            TextField(L10n.habitPlaceholder, text: $name)
                .padding(DS.Spacing.lg)
                .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(Color.backgroundCard))
        }
    }
    
    // MARK: - Icon Section
    private var iconSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(L10n.icon)
                .font(.caption)
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
                                        Color.backgroundSecondary)
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
            Text(L10n.color)
                .font(.caption)
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
