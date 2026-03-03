
//  CalendarFilters.swift
//  FamilyHub
//
//  Filter components for calendar member filtering
//

import SwiftUI

// MARK: - Member Filter Chip

struct MemberFilterChip: View {
    let name: String
    let isSelected: Bool
    let avatar: FamilyUser?
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let user = avatar {
                    AvatarView(user: user, size: 24)
                } else {
                    Image(systemName: "person.3.fill")
                        .font(DS.Typography.micro())
                        .foregroundStyle(isSelected ? .white : Color.textSecondary)
                }
                
                Text(name)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(isSelected ? .white : Color.textPrimary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Capsule().fill(isSelected ? Color.primary: Color.backgroundCard))
            .overlay(
                Capsule().stroke(isSelected ? Color.clear : Color.dividerColor, lineWidth: 1)
            )
        }
    }
}

// MARK: - Member Filter Sheet

struct MemberFilterSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    @Environment(TaskViewModel.self) var taskVM
    @Environment(CalendarViewModel.self) var calendarVM
    @Binding var selectedMemberIds: Set<String>
    
    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        selectedMemberIds.removeAll()
                    } label: {
                        HStack {
                            Image(systemName: "person.3.fill")
                                .foregroundStyle(.primary)
                                .frame(width: 32)
                            
                            Text(L10n.showAllMembers)
                                .foregroundStyle(Color.textPrimary)
                            
                            Spacer()
                            
                            if selectedMemberIds.isEmpty {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.primary)
                            }
                        }
                    }
                    .listRowBackground(Color.backgroundCard)
                }
                
                Section(L10n.filterByMember) {
                    ForEach(familyMemberVM.familyMembers) { member in
                        Button {
                            toggleMember(member)
                        } label: {
                            HStack(spacing: 12) {
                                AvatarView(user: member, size: 36)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.displayName)
                                        .foregroundStyle(Color.textPrimary)
                                    Text(member.isAdult ? L10n.adult : L10n.member)
                                        .font(.caption)
                                        .foregroundStyle(Color.textSecondary)
                                }
                                
                                Spacer()
                                
                                if let memberId = member.id, selectedMemberIds.contains(memberId) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.primary)
                                } else {
                                    Image(systemName: "circle")
                                        .foregroundStyle(Color.textTertiary)
                                }
                            }
                        }
                        .listRowBackground(Color.backgroundCard)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(AdaptiveBackgroundView())
            .navigationTitle(L10n.filterByMember)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
    
    private func toggleMember(_ member: FamilyUser) {
        guard let memberId = member.id else { return }
        if selectedMemberIds.contains(memberId) {
            selectedMemberIds.remove(memberId)
        } else {
            selectedMemberIds.insert(memberId)
        }
    }
}
