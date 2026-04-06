//
//  MeView.swift
//
//  PURPOSE:
//    Unified personal + family hub. Shows profile, goal, wallet, activity
//    heatmap, habits, family members, and settings. Replaces the former
//    FamilyView — all family management features now live here.
//
//  ARCHITECTURE ROLE:
//    Tab root for the "Me" tab. Adapts layout: single-column on iPhone,
//    two-column on iPad (heatmap + profile left, wallet + actions right).
//
//  DATA FLOW:
//    AuthViewModel        → currentUser profile
//    FamilyMemberViewModel → members list, family banner
//    TaskViewModel        → user tasks for heatmap
//    HabitViewModel       → habit logs for heatmap
//    RewardViewModel      → balance, pending payouts
//

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

    // MARK: - State

    @State private var showEditProfile = false
    @State private var showRewardWallet = false
    @State private var showInviteCode = false
    @State private var showFamilyMembers = false
    @State private var showSettings = false
    @State private var showAddHabit = false
    @State private var selectedMember: FamilyUser?
    @State private var selectedBannerPhoto: PhotosPickerItem?
    @State private var isUploadingBanner = false
    @State private var heatmapMonth: Date = .now

    // MARK: - Computed

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

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

    private var pendingPayoutCount: Int {
        rewardVM.pendingWithdrawals
            .filter { $0.userId != currentUser?.id }
            .count
    }

    // MARK: - Body

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 0) {
                // Banner
                MeBannerSection(
                    family: familyMemberVM.family,
                    selectedPhoto: $selectedBannerPhoto,
                    isUploading: isUploadingBanner
                )

                // Content — adapts to device
                if isRegularWidth {
                    iPadLayout
                } else {
                    iPhoneLayout
                }
            }
        }
        .background(Color.themeSurfacePrimary.ignoresSafeArea())
        .navigationTitle("me_tab")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape.fill")
                        .foregroundStyle(.textPrimary)
                }
            }
        }
        // ── Sheets ───────────────────────────────────────────────
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
        .sheet(isPresented: $showFamilyMembers) {
            FamilyMembersListView()
                .presentationBackground(Color.themeSurfacePrimary)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
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

    // ═══════════════════════════════════════════════════════════════════
    // MARK: - iPhone Layout (single column)
    // ═══════════════════════════════════════════════════════════════════

    private var iPhoneLayout: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Profile
            if let user = currentUser {
                MeProfileSection(
                    user: user,
                    onEditProfile: { showEditProfile = true }
                )
            }

            // Goal
            if let user = currentUser {
                MeGoalSection(
                    goal: user.goal,
                    currentYear: currentYear,
                    onEditGoal: { showEditProfile = true }
                )
            }

            // Wallet
            if let user = currentUser {
                MeWalletSection(
                    balance: user.balance,
                    pendingPayoutCount: pendingPayoutCount,
                    canApprovePayouts: user.resolvedCapabilities.canApprovePayouts,
                    onViewHistory: { showRewardWallet = true }
                )
            }

            // Activity heatmap
            activityHeatmap

            // Habits
            MeHabitsSection(showAddHabit: $showAddHabit)

            // Family members
            MeFamilySection(
                members: familyMemberVM.familyMembers,
                canManageFamily: currentUser?.resolvedCapabilities.canManageFamily == true,
                onSelectMember: { selectedMember = $0 },
                onInvite: { showInviteCode = true }
            )

            // Settings (inline quick actions + sign out)
            MeSettingsSection()

            Spacer().frame(height: 60)
        }
        .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
        .padding(.top, DS.Spacing.md)
    }

    // ═══════════════════════════════════════════════════════════════════
    // MARK: - iPad Layout (two column)
    // ═══════════════════════════════════════════════════════════════════

    private var iPadLayout: some View {
        VStack(spacing: DS.Spacing.xl) {
            HStack(alignment: .top, spacing: DS.Spacing.xxl) {
                // Left: Profile + Heatmap + Habits
                VStack(spacing: DS.Spacing.lg) {
                    if let user = currentUser {
                        MeProfileSection(
                            user: user,
                            onEditProfile: { showEditProfile = true }
                        )
                    }

                    if let user = currentUser {
                        MeGoalSection(
                            goal: user.goal,
                            currentYear: currentYear,
                            onEditGoal: { showEditProfile = true }
                        )
                    }

                    activityHeatmap

                    MeHabitsSection(showAddHabit: $showAddHabit)
                }
                .frame(maxWidth: .infinity)

                // Right: Wallet + Family + Actions
                VStack(spacing: DS.Spacing.lg) {
                    if let user = currentUser {
                        MeWalletSection(
                            balance: user.balance,
                            pendingPayoutCount: pendingPayoutCount,
                            canApprovePayouts: user.resolvedCapabilities.canApprovePayouts,
                            onViewHistory: { showRewardWallet = true }
                        )
                    }

                    MeFamilySection(
                        members: familyMemberVM.familyMembers,
                        canManageFamily: currentUser?.resolvedCapabilities.canManageFamily == true,
                        onSelectMember: { selectedMember = $0 },
                        onInvite: { showInviteCode = true }
                    )
                }
                .frame(width: 360)
            }

            Spacer().frame(height: 60)
        }
        .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
        .padding(.top, DS.Spacing.md)
    }

    // ═══════════════════════════════════════════════════════════════════
    // MARK: - Shared Sections
    // ═══════════════════════════════════════════════════════════════════

    private var activityHeatmap: some View {
        MonthlyActivityHeatmap(
            tasks: userTasks,
            habitLogs: userHabitLogs,
            displayMonth: $heatmapMonth,
            onMonthChange: { newMonth in
                Task { await loadHabitLogsForMonth(newMonth) }
            }
        )
    }

    // MARK: - Data Helpers

    private func loadHabitLogsForMonth(_ month: Date) async {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        await familyViewModel.loadHabitLogs(from: startOfMonth, to: endOfMonth)
    }

    private func loadBannerPhoto(_ item: PhotosPickerItem?) {
        guard let item else { return }
        isUploadingBanner = true
        Task {
            defer {
                Task { @MainActor in
                    isUploadingBanner = false
                    selectedBannerPhoto = nil
                }
            }
            do {
                if let data = try await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    let resized = resizeImage(uiImage, maxWidth: 1200)
                    if let jpegData = resized.jpegData(compressionQuality: 0.8) {
                        await familyViewModel.updateFamilyBanner(imageData: jpegData)
                    }
                }
            } catch {
                Log.general.error("Banner upload failed: \(error.localizedDescription)")
            }
        }
    }

    private func resizeImage(_ image: UIImage, maxWidth: CGFloat) -> UIImage {
        let ratio = maxWidth / image.size.width
        guard ratio < 1 else { return image }
        let newSize = CGSize(width: maxWidth, height: image.size.height * ratio)
        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
