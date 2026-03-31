// MeView.swift
//
// ME TAB: Personal Hub
// │ 1. Family Banner (hero image)
// │ 2. My Profile (avatar, name, preset badge)
// │ 3. My Goal (year goal card)
// │ 4. My Wallet (inline balance + actions)
// │ 5. My Activity (heatmap)
// │ 6. My Habits (week/month/year analytics)
// │ 7. My Family (inline member list + invite)
// │ 8. Settings (inline at bottom)


import SwiftUI
import PhotosUI

struct MeView: View {

    // MARK: - Environment

    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    @Environment(TaskViewModel.self) var taskVM
    @Environment(HabitViewModel.self) var habitVM
    @Environment(RewardViewModel.self) var rewardVM
    @Environment(ThemeManager.self) var themeManager

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    // MARK: - State

    @State private var showEditProfile = false
    @State private var showRewardWallet = false
    @State private var showInviteCode = false
    @State private var selectedMember: FamilyUser?
    @State private var showAddHabit = false
    @State private var selectedBannerPhoto: PhotosPickerItem?
    @State private var isUploadingBanner = false
    @State private var heatmapMonth: Date = .now

    // MARK: - Derived

    private var currentUser: FamilyUser? {
        authViewModel.currentUser
    }

    private var userTasks: [FamilyTask] {
        guard let userId = currentUser?.id else { return [] }
        return taskVM.allTasks.filter { task in
            task.assignedTo == userId || (task.assignedTo == nil && task.assignedBy == userId)
        }
    }

    private var userHabitLogs: [String: Set<String>] {
        habitVM.habitLogs
    }

    private var currentYear: String {
        Date.now.formatted(.dateTime.year())
    }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {

                // ── 1. Family Banner ─────────────────────────
                MeBannerSection(
                    family: familyMemberVM.family,
                    selectedPhoto: $selectedBannerPhoto,
                    isUploading: isUploadingBanner
                )

                VStack(spacing: DS.Spacing.lg) {

                    // ── 2. My Profile ────────────────────────
                    if let user = currentUser {
                        MeProfileSection(
                            user: user,
                            onEditProfile: { showEditProfile = true }
                        )
                    }

                    // ── 3. My Goal ───────────────────────────
                    if let user = currentUser {
                        MeGoalSection(
                            goal: user.goal,
                            currentYear: currentYear,
                            onEditGoal: { showEditProfile = true }
                        )
                    }

                    // ── 4. My Wallet ─────────────────────────
                    if let user = currentUser {
                        MeWalletSection(
                            balance: user.balance,
                            pendingPayoutCount: pendingPayoutCount,
                            canApprovePayouts: user.resolvedCapabilities.canApprovePayouts,
                            onViewHistory: { showRewardWallet = true }
                        )
                    }

                    // ── 5. My Activity ───────────────────────
                    MonthlyActivityHeatmap(
                        tasks: userTasks,
                        habitLogs: userHabitLogs,
                        displayMonth: $heatmapMonth,
                        onMonthChange: { newMonth in
                            Task { await loadHabitLogsForMonth(newMonth) }
                        }
                    )

                    // ── 6. My Habits ─────────────────────────
                    MeHabitsSection(showAddHabit: $showAddHabit)

                    // ── 7. My Family ─────────────────────────
                    MeFamilySection(
                        members: familyMemberVM.familyMembers,
                        canManageFamily: currentUser?.resolvedCapabilities.canManageFamily == true,
                        onSelectMember: { selectedMember = $0 },
                        onInvite: { showInviteCode = true }
                    )

                    // ── 8. Settings ──────────────────────────
                    MeSettingsSection()

                    Spacer().frame(height: 60)
                }
                .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
                .padding(.top, DS.Spacing.md)
            }
        }
        .background(Color.themeSurfacePrimary.ignoresSafeArea())
        .navigationTitle("me_tab")
        .navigationBarTitleDisplayMode(.inline)
        // ── Sheets ──────────────────────────────────────────
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet()
                .presentationBackground(Color.themeSurfacePrimary)
        }
        .sheet(isPresented: $showRewardWallet) {
            RewardWalletView()
                .presentationBackground(Color.themeSurfacePrimary)
        }
        .sheet(isPresented: $showInviteCode) {
            InviteCodeSheet()
                .presentationBackground(Color.themeSurfacePrimary)
        }
        .sheet(item: $selectedMember) { member in
            MemberDetailView(member: member)
                .presentationBackground(Color.themeSurfacePrimary)
        }
        .sheet(isPresented: $showAddHabit) {
            AddHabitView()
                .presentationBackground(Color.themeSurfacePrimary)
        }
        .onChange(of: selectedBannerPhoto) { _, newItem in
            loadBannerPhoto(newItem)
        }
        .task {
            await loadHabitLogsForMonth(heatmapMonth)
        }
    }

    // MARK: - Data

    private var pendingPayoutCount: Int {
        rewardVM.pendingWithdrawals
            .filter { $0.userId != currentUser?.id }
            .count
    }

    private func loadHabitLogsForMonth(_ month: Date) async {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        await familyViewModel.loadHabitLogs(from: startOfMonth, to: endOfMonth)
    }

    private func loadBannerPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isUploadingBanner = true
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                await familyMemberVM.updateFamilyBanner(imageData: data)
            }
            isUploadingBanner = false
        }
    }
}
