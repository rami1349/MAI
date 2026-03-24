// ============================================================================
// MainTabView.swift
//
// v2 NAVIGATION: Home · Calendar · ✨ MAI ✨ · Tasks · Me
//
// ARCHITECTURE:
//   Thin shell that owns ONLY shared state (tab selection, context sheets).
//   Delegates layout to child structs:
//     - MainTabiPhoneContent: custom tab bar with MAI center, nav bar "+"
//     - MainTabiPadContent: 3-item sidebar, Me bottom, MAI floating button
//
// WHAT CHANGED (v1 → v2):
//   - NavigationItem: .chat → .mai, .family → .me
//   - TasksViewMode enum: REMOVED (Tasks tab is pure tasks, no habits toggle)
//   - FAB state (showFABMenu): REMOVED (replaced by context "+" in nav bar)
//   - showAddHabit: kept (triggered from Home slot 4 empty CTA only)
//
// ============================================================================

import SwiftUI

// MARK: - Navigation Item Model

enum NavigationItem: String, CaseIterable, Identifiable, Sendable {
    case home
    case calendar
    case mai
    case tasks
    case me

    var id: String { rawValue }

    /// All 5 tabs for iPhone tab bar
    static var phoneTabs: [NavigationItem] { allCases }

    /// 3 tabs for iPad sidebar (MAI uses floating button, Me is sidebar bottom)
    static var sidebarTabs: [NavigationItem] { [.home, .calendar, .tasks] }

    /// Localization key for the tab title (matches xcstrings)
    var localizationKey: String {
        switch self {
        case .home:     "home"
        case .calendar: "calendar"
        case .mai:      "mai"
        case .tasks:    "tasks"
        case .me:       "me_tab"
        }
    }

    /// Resolved title string for code contexts.
    var title: String {
        AppStrings.localized(.init(localizationKey))
    }

    var icon: String {
        switch self {
        case .home:     "house.fill"
        case .calendar: "calendar"
        case .mai:      "sparkles"
        case .tasks:    "checkmark.circle"
        case .me:       "person.circle"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home:     "house.fill"
        case .calendar: "calendar"
        case .mai:      "sparkles"
        case .tasks:    "checkmark.circle.fill"
        case .me:       "person.circle.fill"
        }
    }
}

// MARK: - Main Tab View (Thin Shell)

struct MainTabView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    @Environment(NotificationViewModel.self) var notificationVM
    @Environment(TourManager.self) var tourManager

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // SHARED STATE — Only state needed by BOTH layouts lives here.
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    /// Current tab selection
    @State private var selectedTab: NavigationItem = .home

    /// Incremented to reset child view state
    @State private var resetTrigger = UUID()

    // Context-aware "+" sheets (triggered from nav bar buttons per tab)
    @State private var showAddTask = false
    @State private var showAddEvent = false
    @State private var showAddHabit = false  // Home slot 4 empty CTA only

    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }

    // MARK: - Body

    var body: some View {
        @Bindable var familyViewModel = familyViewModel
        Group {
            if isRegularWidth {
                MainTabiPadContent(
                    selectedTab: $selectedTab,
                    resetTrigger: resetTrigger,
                    showAddTask: $showAddTask,
                    showAddEvent: $showAddEvent,
                    showAddHabit: $showAddHabit
                )
            } else {
                MainTabiPhoneContent(
                    selectedTab: $selectedTab,
                    resetTrigger: resetTrigger,
                    showAddTask: $showAddTask,
                    showAddEvent: $showAddEvent,
                    showAddHabit: $showAddHabit
                )
            }
        }
        .task {
            await loadInitialData()
        }
        // ── Context Sheets ──────────────────────────────────────────
        .sheet(isPresented: $showAddTask) {
            AddTaskView()
                .presentationBackground(Color.themeSurfacePrimary)
        }
        .sheet(isPresented: $showAddEvent) {
            AddEventView()
                .presentationBackground(Color.themeSurfacePrimary)
        }
        .sheet(isPresented: $showAddHabit) {
            AddHabitView()
                .presentationBackground(Color.themeSurfacePrimary)
        }
        .globalErrorBanner(errorMessage: $familyViewModel.errorMessage)
        .offlineBanner()
        .withFeatureTour()
        .onAppear {
            tourManager.startIfNeeded()
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
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        await familyViewModel.loadCalendarEvents(from: startOfMonth, to: endOfMonth)
        await familyViewModel.loadHabitLogs(from: startOfMonth, to: endOfMonth)
    }
}
