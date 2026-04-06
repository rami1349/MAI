// ============================================================================
// MainTabView.swift
//
// v3 NAVIGATION: Centralized via NavigationRouter
//
// WHAT CHANGED (v2 → v3):
//   - @State selectedTab → router.selectedTab
//   - 3 @State show* booleans → router.activeSheet (one enum)
//   - .sheet(isPresented:) × 3 → .sheet(item: router.activeSheet) × 1
//   - resetTrigger UUID hack → router.popToRoot()
//   - Deep link handling via .onOpenURL → router.navigate(to:)
//   - State restoration: tab persisted via @SceneStorage
//   - Sheets presented once here, not duplicated in child views
//
// ============================================================================

import SwiftUI

struct MainTabView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    @Environment(NotificationViewModel.self) var notificationVM
    @Environment(TourManager.self) var tourManager
    @Environment(NavigationRouter.self) var router
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // State restoration: persist selected tab across launches
    @SceneStorage("selectedTab") private var persistedTab: String = NavigationItem.home.rawValue
    
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    // MARK: - Body
    
    var body: some View {
        @Bindable var familyViewModel = familyViewModel
        @Bindable var router = router
        
        Group {
            if isRegularWidth {
                MainTabiPadContent()
            } else {
                MainTabiPhoneContent()
            }
        }
        .task {
            await loadInitialData()
        }
        // ── Deep Link Handler ────────────────────────────────────
        .onOpenURL { url in
            router.navigate(to: url)
        }
        // ── Deep Link Task Resolution ────────────────────────────
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkTask)) { notification in
            if let taskId = notification.userInfo?["taskId"] as? String,
               let task = familyViewModel.taskVM.task(byStableId: taskId)
                ?? familyViewModel.taskVM.allTasks.first(where: { $0.id == taskId }) {
                router.present(.taskDetail(task))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .deepLinkEvent)) { notification in
            if let eventId = notification.userInfo?["eventId"] as? String,
               let event = familyViewModel.calendarVM.events.first(where: { $0.id == eventId }) {
                router.present(.eventDetail(event))
            }
        }
        // ── Centralized Sheet Presentation ───────────────────────
        .sheet(item: $router.activeSheet) { sheet in
            sheetContent(for: sheet)
        }
        .globalErrorBanner(errorMessage: $familyViewModel.errorMessage)
        .offlineBanner()
        .withFeatureTour()
        // ── State Restoration ────────────────────────────────────
        .onAppear {
            tourManager.startIfNeeded()
            // Restore tab from previous session
            if let tab = NavigationItem(rawValue: persistedTab) {
                router.selectedTab = tab
            }
        }
        .onChange(of: router.selectedTab) { _, newTab in
            persistedTab = newTab.rawValue
        }
    }
    
    // MARK: - Centralized Sheet Content
    
    @ViewBuilder
    private func sheetContent(for sheet: AppSheet) -> some View {
        switch sheet {
        case .addTask(let groupId):
            AddTaskView(preSelectedGroupId: groupId)
                .presentationBackground(Color.themeSurfacePrimary)
        case .addEvent:
            AddEventView()
                .presentationBackground(Color.themeSurfacePrimary)
        case .addHabit:
            AddHabitView()
                .presentationBackground(Color.themeSurfacePrimary)
        case .createGroup:
            CreateTaskGroupView()
                .presentationBackground(Color.themeSurfacePrimary)
        case .taskDetail(let task):
            TaskDetailView(task: task)
        case .eventDetail(let event):
            EventDetailView(event: event)
        case .notifications:
            NotificationsView()
        case .rewardWallet:
            RewardWalletView()
        case .inviteCode:
            InviteCodeSheet()
        case .paywall:
            PaywallView()
        }
    }
    
    // MARK: - Data Loading
    
    private func loadInitialData() async {
        guard let user = authViewModel.currentUser,
              let familyId = user.familyId,
              let userId = user.id else { return }
        
        await familyViewModel.loadFamilyData(familyId: familyId, userId: userId)
        
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: .now))!
        // FIX: Use start of NEXT month as exclusive upper bound.
        // DateComponents(month: 1, day: -1) gave last-day-at-midnight, excluding
        // any event ON the last day because query is startDate < end.
        let endOfMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        await familyViewModel.loadCalendarEvents(from: startOfMonth, to: endOfMonth)
        await familyViewModel.loadHabitLogs(from: startOfMonth, to: endOfMonth)
    }
}
