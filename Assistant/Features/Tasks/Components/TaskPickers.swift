//
//  TaskPickers.swift
//  FamilyHub
//
//  Picker sheets for AddTaskView
//  Updated with MultiMemberPicker for multi-assignee support
//

import SwiftUI

// MARK: - Task Group Picker
struct TaskGroupPicker: View {
    @Environment(\.dismiss) var dismiss
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    @Binding var selectedGroupId: String?
    @State private var showCreateGroup = false
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: { selectedGroupId = nil; dismiss() }) {
                        HStack {
                            Text(L10n.noGroup)
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            if selectedGroupId == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentPrimary)
                            }
                        }
                    }
                    .listRowBackground(Color.backgroundCard)
                }
                
                Section(L10n.taskGroups) {
                    let myGroups = familyMemberVM.taskGroups.filter {
                        $0.createdBy == familyViewModel.currentUserId
                    }
                    ForEach(myGroups) { group in
                        Button(action: { selectedGroupId = group.id; dismiss() }) {
                            HStack(spacing: DS.Spacing.md) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: DS.Radius.md)
                                        .fill(Color(hex: group.color).opacity(0.15))
                                        .frame(width: DS.IconContainer.md, height: DS.IconContainer.md)
                                    
                                    Image(systemName: group.icon)
                                        .foregroundStyle(Color(hex: group.color))
                                }
                                
                                Text(group.name)
                                    .foregroundStyle(Color.textPrimary)
                                
                                Spacer()
                                
                                if selectedGroupId == group.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentPrimary)
                                }
                            }
                        }
                        .listRowBackground(Color.backgroundCard)
                    }
                }
                
                Section {
                    Button(action: { showCreateGroup = true }) {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundStyle(Color.accentPrimary)
                            Text(L10n.createGroup)
                                .foregroundStyle(Color.accentPrimary)
                        }
                    }
                    .listRowBackground(Color.backgroundCard)
                }
            }
            .scrollContentBackground(.hidden)
            .background(AdaptiveBackgroundView())
            .navigationTitle(L10n.selectGroup)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
            .sheet(isPresented: $showCreateGroup) {
                CreateTaskGroupView()
                    .presentationBackground(Color.backgroundPrimary)
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Multi-Member Picker (NEW)
/// Multi-select picker for assigning tasks to multiple family members
struct MultiMemberPicker: View {
    @Environment(\.dismiss) var dismiss
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    
    @Binding var selectedMemberIds: [String]
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        NavigationStack {
            List {
                // Header showing selection count
                if !selectedMemberIds.isEmpty {
                    Section {
                        HStack {
                            Text("\(selectedMemberIds.count) selected")
                                .font(DS.Typography.label())
                                .foregroundStyle(Color.textSecondary)
                            
                            Spacer()
                            
                            Button("Clear all") {
                                withAnimation(.easeOut(duration: 0.2)) {
                                    selectedMemberIds.removeAll()
                                }
                            }
                            .font(DS.Typography.label())
                            .foregroundStyle(Color.accentPrimary)
                        }
                    }
                    .listRowBackground(Color.backgroundCard)
                }
                
                Section(L10n.familyMembers) {
                    ForEach(familyMemberVM.familyMembers) { member in
                        MultiMemberPickerRow(
                            member: member,
                            isSelected: selectedMemberIds.contains(member.id ?? ""),
                            onToggle: {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    toggleMember(member.id ?? "")
                                }
                            }
                        )
                        .listRowBackground(
                            selectedMemberIds.contains(member.id ?? "")
                                ? Color.accentPrimary.opacity(0.08)
                                : Color.backgroundCard
                        )
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AdaptiveBackgroundView())
            .navigationTitle(L10n.assignTo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onDismiss?()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
    
    private func toggleMember(_ memberId: String) {
        if let index = selectedMemberIds.firstIndex(of: memberId) {
            selectedMemberIds.remove(at: index)
        } else {
            selectedMemberIds.append(memberId)
        }
    }
}

// MARK: - Multi-Member Picker Row

private struct MultiMemberPickerRow: View {
    let member: FamilyUser
    let isSelected: Bool
    let onToggle: () -> Void
    
    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: DS.Spacing.md) {
                // Checkbox indicator
                ZStack {
                    Circle()
                        .stroke(isSelected ? Color.accentPrimary : Color.textTertiary, lineWidth: 2)
                        .frame(width: DS.IconContainer.sm, height: DS.IconContainer.sm)
                    
                    if isSelected {
                        Circle()
                            .fill(Color.accentPrimary)
                            .frame(width: DS.IconContainer.sm - 4, height: DS.IconContainer.sm - 4)
                        
                        Image(systemName: "checkmark")
                            .font(.system(size: DS.IconSize.xs, weight: .bold)) // DT-exempt: icon sizing
                            .foregroundStyle(.white)
                    }
                }
                
                // Avatar
                AvatarView(user: member, size: DS.Avatar.md)
                
                // Name & role
                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                    Text(member.displayName)
                        .font(DS.Typography.label())
                        .foregroundStyle(Color.textPrimary)
                    Text(member.isAdult ? L10n.adult : L10n.member)
                        .font(.caption)
                        .foregroundStyle(Color.textSecondary)
                }
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Legacy Member Picker (Single Select)
/// Kept for backwards compatibility - use MultiMemberPicker for new features
struct MemberPicker: View {
    @Environment(\.dismiss) var dismiss
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    @Binding var selectedMemberId: String?
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button(action: { selectedMemberId = nil; dismiss() }) {
                        HStack {
                            Text(L10n.unassigned)
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                            if selectedMemberId == nil {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentPrimary)
                            }
                        }
                    }
                    .listRowBackground(Color.backgroundCard)
                }
                
                Section(L10n.familyMembers) {
                    ForEach(familyMemberVM.familyMembers) { member in
                        Button(action: { selectedMemberId = member.id; dismiss() }) {
                            HStack(spacing: DS.Spacing.md) {
                                AvatarView(user: member, size: DS.Avatar.md)
                                
                                VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                    Text(member.displayName)
                                        .foregroundStyle(Color.textPrimary)
                                    Text(member.isAdult ? L10n.adult : L10n.member)
                                        .font(.caption)
                                        .foregroundStyle(Color.textSecondary)
                                }
                                
                                Spacer()
                                
                                if selectedMemberId == member.id {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(Color.accentPrimary)
                                }
                            }
                        }
                        .listRowBackground(Color.backgroundCard)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AdaptiveBackgroundView())
            .navigationTitle(L10n.assignTo)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Create Task Group View
struct CreateTaskGroupView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    
    @State private var name = ""
    @State private var selectedIcon = "briefcase.fill"
    @State private var selectedColor = "7C3AED"
    @State private var isLoading = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: DS.Spacing.xxl) {
                    // Preview
                    ZStack {
                        RoundedRectangle(cornerRadius: DS.Radius.xl)
                            .fill(Color(hex: selectedColor).opacity(0.15))
                            .frame(width: DS.Avatar.xl, height: DS.Avatar.xl)
                        
                        Image(systemName: selectedIcon)
                            .font(.system(size: DS.IconSize.xl)) // DT-exempt: icon sizing
                            .foregroundStyle(Color(hex: selectedColor))
                    }
                    
                    // Name
                    TextField(L10n.groupName, text: $name)
                        .padding(DS.Spacing.lg)
                        .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(Color.backgroundCard))
                    
                    // Icons
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text(L10n.icon)
                            .font(.headline)
                            .foregroundStyle(Color.textPrimary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: DS.Spacing.md) {
                            ForEach(TaskGroupColors.icons, id: \.systemName) { icon in
                                Button(action: { selectedIcon = icon.systemName }) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius: DS.Radius.md)
                                            .fill(selectedIcon == icon.systemName ?
                                                  Color(hex: selectedColor).opacity(0.2) :
                                                  Color.surfaceColor)
                                            .frame(width: DS.Control.large, height: DS.Control.large)
                                        
                                        Image(systemName: icon.systemName)
                                            .foregroundStyle(selectedIcon == icon.systemName ?
                                                           Color(hex: selectedColor) :
                                                           Color.textSecondary)
                                    }
                                }
                            }
                        }
                    }
                    
                    // Colors
                    VStack(alignment: .leading, spacing: DS.Spacing.md) {
                        Text(L10n.color)
                            .font(.headline)
                            .foregroundStyle(Color.textPrimary)
                        
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: DS.Spacing.md) {
                            ForEach(TaskGroupColors.colors, id: \.hex) { color in
                                Button(action: { selectedColor = color.hex }) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: color.hex))
                                            .frame(width: DS.Control.standard, height: DS.Control.standard)
                                        
                                        if selectedColor == color.hex {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.white)
                                                .fontWeight(.bold)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(DS.Spacing.xl)
            }
            .scrollContentBackground(.hidden)
            .background(AdaptiveBackgroundView())
            .navigationTitle(L10n.newTaskGroup)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.create)  {
                        createGroup()
                    }
                    .disabled(name.isEmpty || isLoading)
                }
            }
        }
    }
    
    private func createGroup() {
        isLoading = true
        
        Task {
            await familyViewModel.createTaskGroup(
                name: name,
                icon: selectedIcon,
                color: selectedColor
            )
            dismiss()
        }
    }
}
