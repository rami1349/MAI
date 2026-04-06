//
//  FamilyMembersListView.swift
//  Assistant
//
//  Created by Ramiro  on 2/9/26.
//  List of all family members with task stats and navigation to member detail
//

import SwiftUI

// MARK: - Family Members List View
struct FamilyMembersListView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyViewModel.self) var familyViewModel

    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    @Environment(TaskViewModel.self) var taskVM
    @State private var selectedMember: FamilyUser?
    
    private var otherMembers: [FamilyUser] {
        familyMemberVM.familyMembers.filter { $0.id != authViewModel.currentUser?.id }
    }
    
    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.lg) {
                    VStack(spacing: DS.Spacing.sm) {
                        Image(systemName: "person.3.fill")
                            .font(.system(size: DS.IconSize.xxl)) // DT-exempt: decorative icon
                            .foregroundStyle(.accentPrimary)
                        
                        Text(AppStrings.xMembers(familyMemberVM.familyMembers.count))
                            .font(.headline)
                            .foregroundStyle(.textPrimary)
                        
                        Text(familyMemberVM.family?.name ?? String(localized: "my_family"))
                            .font(.subheadline)
                            .foregroundStyle(.textSecondary)
                    }
                    .padding(.top, DS.Spacing.xl)
                    .padding(.bottom, DS.Spacing.sm)
                    
                    if otherMembers.isEmpty {
                        VStack(spacing: DS.Spacing.md) {
                            Image(systemName: "person.badge.plus")
                                .font(.largeTitle)
                                .foregroundStyle(.textTertiary)
                            Text("no_other_members")
                                .font(.subheadline)
                                .foregroundStyle(.textSecondary)
                            Text("invite_family_member")
                                .font(.caption)
                                .foregroundStyle(.textTertiary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.jumbo)
                    } else {
                        ForEach(otherMembers) { member in
                            FamilyMemberCard(member: member) {
                                selectedMember = member
                            }
                        }
                    }
                    
                    Spacer().frame(height: DS.Control.large)
                }
                .padding(DS.Layout.adaptiveScreenPadding)
                .constrainedWidth(.card)
            }
            .background(AdaptiveBackgroundView())
            .navigationTitle("family_members")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("done") { dismiss() }
                }
            }
            .sheet(item: $selectedMember) { member in
                MemberDetailView(member: member)
            }
        }
    }
}

// MARK: - Family Member Card
struct FamilyMemberCard: View {
    @Environment(FamilyViewModel.self) var familyViewModel

    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    @Environment(TaskViewModel.self) var taskVM
    let member: FamilyUser
    let onTap: () -> Void
    
    private var memberTasks: [FamilyTask] {
        taskVM.allTasks.filter { task in
            task.assignedTo == member.id || (task.assignedTo == nil && task.assignedBy == member.id)
        }
    }
    
    private var completedCount: Int {
        memberTasks.filter { $0.status == .completed }.count
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DS.Spacing.lg) {
                HStack(spacing: DS.Spacing.md) {
                    AvatarView(user: member, size: DS.Avatar.lg)
                    
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(member.displayName)
                            .font(.headline)
                            .foregroundStyle(.textPrimary)
                        
                        HStack(spacing: DS.Spacing.sm) {
                            CapabilityBadge(preset: member.resolvedPreset)
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.textTertiary)
                }
                
                HStack(spacing: 0) {
                    VStack(spacing: DS.Spacing.xxs) {
                        Text("\(memberTasks.count)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("tasks")
                            .font(.caption2)
                            .foregroundStyle(.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider().frame(height: DS.Spacing.xxl)
                    
                    VStack(spacing: DS.Spacing.xxs) {
                        Text("\(completedCount)")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.accentGreen)
                        Text("done")
                            .font(.caption2)
                            .foregroundStyle(.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Divider().frame(height: DS.Spacing.xxl)
                    
                    VStack(spacing: DS.Spacing.xxs) {
                        Text(member.balance.currencyString)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.accentOrange)
                        Text("balance")
                            .font(.caption2)
                            .foregroundStyle(.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.top, DS.Spacing.xs)
            }
            .padding(DS.Spacing.lg)
            .background(RoundedRectangle(cornerRadius: DS.Radius.xxl).fill(Color.themeCardBackground))
            .elevation1()
        }
        .buttonStyle(.plain)
    }
}
