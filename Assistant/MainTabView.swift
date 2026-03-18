// MainTabView.swift
//
// ARCHITECTURE:
//   Thin shell that owns ONLY shared state (tab selection, shared sheets).
//   Delegates layout to child structs that own their own @State:
//     - MainTabiPhoneContent: owns showFABMenu
//     - MainTabiPadContent: owns sidebarExpanded, selectedGroup, folder state,
//       showAIChat, showSettings, showQuickAddMenu
//
// PERFORMANCE:
//   Previously, toggling showFABMenu (iPhone-only) forced SwiftUI to diff the
//   entire iPad sidebar + all 5 tab contents. Now, each layout's @State changes
//   only re-evaluate that layout's body — not the other platform's.


import SwiftUI
import os


// MARK: - Navigation Item Model

enum NavigationItem: String, CaseIterable, Identifiable, Sendable {
    case home
    case calendar
    case chat
    case tasks
    case family
    
    var id: String { rawValue }
    
    /// All 5 tabs for iPhone tab bar
    static var phoneTabs: [NavigationItem] { allCases }
    
    /// 4 tabs for iPad sidebar (chat uses floating button instead)
    static var sidebarTabs: [NavigationItem] { allCases.filter { $0 != .chat } }
    
    var title: String {
        switch self {
        case .home: return "Home"
        case .calendar: return "Calendar"
        case .chat: return "Chat"
        case .tasks: return "Tasks"
        case .family: return "Family"
        }
    }
    
    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .calendar: return "calendar"
        case .chat: return "samy"
        case .tasks: return "checkmark.circle.fill"
        case .family: return "person.2.fill"
        }
    }
    
    var selectedIcon: String {
        switch self {
        case .home: return "house.fill"
        case .calendar: return "calendar"
        case .chat: return "samy"
        case .tasks: return "checkmark.circle.fill"
        case .family: return "person.2.fill"
        }
    }
}

// MARK: - Tasks View Mode

enum TasksViewMode: Sendable {
    case tasks
    case habits
}

// MARK: - Main Tab View (Thin Shell)

struct MainTabView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    @Environment(NotificationViewModel.self) var notificationVM
    @Environment(TourManager.self) var tourManager
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    // SHARED STATE — Only state needed by BOTH layouts lives here.
    // Layout-specific state lives in the child structs.
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    
    /// Current tab selection — drives both iPhone TabView and iPad sidebar highlight
    @State private var selectedTab: NavigationItem = .home
    
    /// Incremented to reset child view state (e.g., scroll position)
    @State private var resetTrigger = UUID()
    
    /// Tasks vs Habits mode — passed to TasksView in both layouts
    @State private var tasksViewMode: TasksViewMode = .tasks
    
    // Shared sheet triggers (used by both iPhone FAB and iPad sidebar quick-add)
    @State private var showAddTask = false
    @State private var showAddHabit = false
    @State private var showAddEvent = false
    
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
                    tasksViewMode: $tasksViewMode,
                    showAddTask: $showAddTask,
                    showAddHabit: $showAddHabit,
                    showAddEvent: $showAddEvent
                )
            } else {
                MainTabiPhoneContent(
                    selectedTab: $selectedTab,
                    resetTrigger: resetTrigger,
                    tasksViewMode: $tasksViewMode,
                    showAddTask: $showAddTask,
                    showAddHabit: $showAddHabit,
                    showAddEvent: $showAddEvent
                )
            }
        }
        .task {
            await loadInitialData()
        }
        // ── Shared Sheets (triggered from both iPhone FAB and iPad sidebar) ──
        .sheet(isPresented: $showAddTask) {
            AddTaskView()
                .presentationBackground(Color.themeSurfacePrimary)
        }
        .sheet(isPresented: $showAddHabit) {
            AddHabitView()
                .presentationBackground(Color.themeSurfacePrimary)
        }
        .sheet(isPresented: $showAddEvent) {
            AddEventView()
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
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: Date()))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        await familyViewModel.loadCalendarEvents(from: startOfMonth, to: endOfMonth)
        await familyViewModel.loadHabitLogs(from: startOfMonth, to: endOfMonth)
    }
}

// MARK: - Previews

#Preview("iPad") {
    let familyVM = FamilyViewModel()
    MainTabView()
        .environment(AuthViewModel())
        .environment(familyVM)
        .environment(familyVM.familyMemberVM)
        .environment(familyVM.taskVM)
        .environment(familyVM.calendarVM)
        .environment(familyVM.habitVM)
        .environment(familyVM.notificationVM)
        .environment(familyVM.rewardVM)
        .environment(ThemeManager.shared)
        .environment(LocalizationManager.shared)
        .environment(TourManager.shared)
}

#Preview("iPhone") {
    let familyVM = FamilyViewModel()
    MainTabView()
        .environment(AuthViewModel())
        .environment(familyVM)
        .environment(familyVM.familyMemberVM)
        .environment(familyVM.taskVM)
        .environment(familyVM.calendarVM)
        .environment(familyVM.habitVM)
        .environment(familyVM.notificationVM)
        .environment(familyVM.rewardVM)
        .environment(ThemeManager.shared)
        .environment(LocalizationManager.shared)
        .environment(TourManager.shared)
}
