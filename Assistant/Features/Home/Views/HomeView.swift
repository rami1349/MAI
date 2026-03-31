//
//  HomeView.swift
//
//  v3: NAVIGATION VIA ROUTER
//
//  WHAT CHANGED (v2 → v3):
//    - resetTrigger parameter: REMOVED
//    - 7 navigation @State vars: REMOVED
//      (showNotifications, showTodayTasks, showTaskGroup, selectedTask,
//       showAddTask, showAddHabit, showAddEvent)
//    - applyNavigationDestinations/applySheets: REMOVED
//      (destinations now declared at NavigationStack level in MainTab*Content)
//      (sheets now centralized in MainTabView)
//    - .onReceive(.dismissTaskSheets): REMOVED (router.dismissSheet())
//    - .onChange(of: resetTrigger): REMOVED (router.popToRoot())
//    - All data logic, derived state, fingerprint, etc: UNCHANGED
//

import SwiftUI
import EventKit

struct HomeView: View {
    // MARK: - Essential Environments
    @Environment(ThemeManager.self) var themeManager
    @Environment(TourManager.self) var tourManager
    @Environment(NavigationRouter.self) var router
    
    // MARK: - Parameters (snapshot provider pattern)
    let authVM: AuthViewModel
    let familyVM: FamilyViewModel
    let taskVM: TaskViewModel
    let habitVM: HabitViewModel
    let notificationVM: NotificationViewModel
    
    // MARK: - Environment
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    @Environment(\.adaptiveLayout) var layout
    
    // MARK: - Convenience Accessors
    var familyMemberVM: FamilyMemberViewModel { familyVM.familyMemberVM }
    var calendarVM: CalendarViewModel { familyVM.calendarVM }
    
    // MARK: - EventKit
    
    var eventKitService = EventKitCalendarService.shared
    
    // MARK: - Derived State Cache
    
    @State var derived = HomeDerivedState()
    
    @State var cachedUpcomingEvents: [UpcomingEvent] = []
    
    // MARK: - Rebuild Debounce
    //
    // P-2 FIX: Replaced 9 separate .onChange handlers with a single fingerprint.
    // P-3 FIX: Single Task handle reused instead of allocating new Tasks per trigger.
    @State private var rebuildTask: Task<Void, Never>?
    @State private var pendingEventRecompute = false
    
    /// Cheap fingerprint combining all data source counts + identity.
    private var dataFingerprint: Int {
        var hasher = Hasher()
        hasher.combine(taskVM.allTasks.count)
        hasher.combine(taskVM.isLoading)
        hasher.combine(habitVM.habits.count)
        hasher.combine(familyMemberVM.familyMembers.count)
        hasher.combine(familyMemberVM.taskGroups.count)
        hasher.combine(calendarVM.events.count)
        hasher.combine(eventKitService.events.count)
        hasher.combine(eventKitService.holidayEvents.count)
        hasher.combine(Calendar.current.component(.day, from: calendarVM.selectedDate))
        return hasher.finalize()
    }
    
    // MARK: - Computed Properties
    
    var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    // MARK: - Shared Inline CTAs (used by both iPhone and iPad layouts)
    
    var addTaskCTA: some View {
        HomeInlineCTA(
            icon: "checkmark.circle",
            iconColor: Color.accentPrimary,
            title: "create_your_first_task",
            subtitle: "create_your_first_task_subtitle",
            buttonLabel: "add_task",
            action: { router.present(.addTask()) }
        )
        .tourTarget("home.addTask")
    }
    
    var addHabitCTA: some View {
        HomeInlineCTA(
            icon: "flame",
            iconColor: Color.accentGreen,
            title: "start_tracking_habits",
            subtitle: "start_tracking_habits_subtitle",
            buttonLabel: "add_habit",
            action: { router.present(.addHabit) }
        )
        .tourTarget("home.addHabit")
    }
    
    var addEventCTA: some View {
        HomeInlineCTA(
            icon: "calendar.badge.plus",
            iconColor: Color.accentOrange,
            title: "add_family_event",
            subtitle: "add_family_event_subtitle",
            buttonLabel: "add_event",
            action: { router.present(.addEvent) }
        )
        .tourTarget("home.addEvent")
    }
    
    // MARK: - Body
    
    var body: some View {
        mainContent
            .searchable(
                text: Binding(
                    get: { derived.searchText },
                    set: { derived.searchText = $0 }
                ),
                placement: .navigationBarDrawer(displayMode: .automatic),
                prompt: "search_tasks_events"
            )
            .task { await loadData() }
            .onChange(of: dataFingerprint) { _, _ in
                scheduleRebuild(recomputeEvents: true)
            }
    }
    
    // MARK: - Main Content (extracted to reduce body complexity)
    
    @ViewBuilder
    private var mainContent: some View {
        ZStack {
            Color.themeSurfacePrimary
                .ignoresSafeArea()
            
            if familyVM.isLoading {
                loadingView
            } else {
                layoutContent
            }
        }
    }
    
    private var loadingView: some View {
        VStack(spacing: DS.Spacing.md) {
            ProgressView()
            Text("loading")
                .font(DS.Typography.bodySmall())
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private var layoutContent: some View {
        if isRegularWidth {
            iPadLayout
        } else {
            iPhoneLayout
        }
    }
    
    // MARK: - Shared Components
    
    var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Date (small, muted) - on top
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                    .font(DS.Typography.caption())
                    .foregroundStyle(.textTertiary)
                
                // Large greeting with name
                Text("\(greetingText), \(authVM.currentUser?.displayName ?? "")!")
                    .font(DS.Typography.displayMedium())
                    .foregroundStyle(.textPrimary)
            }
            
            Spacer()
            
            // Notification button → router
            Button(action: { router.present(.notifications) }) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                        .font(DS.Typography.heading())
                        .foregroundStyle(.textPrimary)
                        .frame(width: 44, height: 44)
                        .background(
                            Circle()
                                .fill(Color.themeCardBackground)
                                .elevation1()
                        )
                    
                    if notificationVM.unreadCount > 0 {
                        Circle()
                            .fill(Color.accentPrimary)
                            .frame(width: 10, height: 10)
                            .offset(x: 2, y: 2)
                    }
                }
            }
        }
        .padding(.horizontal, isRegularWidth ? 0 : DS.Spacing.screenH)
    }
    
    var greetingText: String {
        let hour = Calendar.current.component(.hour, from: .now)
        switch hour {
        case 0..<12: return "good_morning"
        case 12..<17: return "good_afternoon"
        default: return "good_evening"
        }
    }
    
    // MARK: - Data Methods
    
    /// Debounced rebuild: cancels pending work, waits 150ms, then executes once.
    func scheduleRebuild(recomputeEvents: Bool = false) {
        if recomputeEvents { pendingEventRecompute = true }
        rebuildTask?.cancel()
        rebuildTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.15))
            guard !Task.isCancelled else { return }
            if pendingEventRecompute {
                recomputeUpcomingEvents()
                pendingEventRecompute = false
            }
            rebuildDerived()
        }
    }
    
    func loadData() async {
        let today = Date.now
        let startOfWeek = today.startOfWeek
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 6, to: startOfWeek) ?? .now
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        async let habitLogs: () = familyVM.loadHabitLogs(from: startOfWeek, to: endOfWeek)
        async let eventKit: () = eventKitService.loadEvents()
        async let calendarEvents: () = familyVM.loadCalendarEvents(from: startOfMonth, to: startOfNextMonth)
        
        _ = await (habitLogs, eventKit, calendarEvents)
        
        recomputeUpcomingEvents()
        rebuildDerived()
    }
    
    func refreshData() async {
        DS.Haptics.light()
        if let familyId = authVM.currentUser?.familyId,
           let userId = authVM.currentUser?.id {
            await familyVM.loadFamilyData(familyId: familyId, userId: userId)
        }
        await eventKitService.refreshEvents()
    }
    
    func rebuildDerived() {
        derived.rebuild(
            allTasks: taskVM.activeTasks,
            userId: authVM.currentUser?.id ?? "",
            capabilities: authVM.currentUser?.resolvedCapabilities
                ?? CapabilityPreset.standard.capabilities(),
            members: familyMemberVM.familyMembers,
            groups: familyMemberVM.taskGroups,
            upcomingEvents: cachedUpcomingEvents,
            habitStreakDays: computeHabitStreak(),
            weeklyEarnings: computeWeeklyEarnings()
        )
    }
    
    /// Compute the current user's longest active habit streak (consecutive days including today).
    private func computeHabitStreak() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let logs = habitVM.habitLogs
        
        guard !logs.isEmpty else { return 0 }
        
        var longestStreak = 0
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"
        
        for (_, dates) in logs {
            let todayStr = dateFormatter.string(from: today)
            guard dates.contains(todayStr) else { continue }
            
            var streak = 1
            var checkDate = today
            while true {
                guard let prev = calendar.date(byAdding: .day, value: -1, to: checkDate) else { break }
                let prevStr = dateFormatter.string(from: prev)
                if dates.contains(prevStr) {
                    streak += 1
                    checkDate = prev
                } else {
                    break
                }
            }
            longestStreak = max(longestStreak, streak)
        }
        return longestStreak
    }
    
    /// Compute reward earnings this week for the current user.
    private func computeWeeklyEarnings() -> Double {
        let calendar = Calendar.current
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        let userId = authVM.currentUser?.id ?? ""
        
        return taskVM.allTasks
            .filter { task in
                task.status == .completed &&
                task.isAssigned(to: userId) &&
                task.hasReward &&
                task.dueDate >= startOfWeek
            }
            .compactMap { $0.rewardAmount }
            .reduce(0, +)
    }
    
    func recomputeUpcomingEvents() {
        cachedUpcomingEvents = UpcomingEventsBuilder.buildEvents(
            familyMembers: familyMemberVM.familyMembers,
            eventKitHolidays: eventKitService.holidayEvents,
            eventKitEvents: eventKitService.events,
            firestoreEvents: calendarVM.events,
            month: .now,
            maxDays: 60,
            includeEventKitRegularEvents: false
        )
    }
    
    func deleteUpcomingEvent(_ event: UpcomingEvent) {
        switch event.source {
        case .firestore(let eventId):
            if let calendarEvent = calendarVM.events.first(where: { $0.id == eventId }) {
                Task { await familyVM.deleteEvent(calendarEvent) }
            }
        case .birthday, .eventKit, .holiday:
            break
        }
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentPrimary.opacity(0.15), lineWidth: 3)
            
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(Color.accentPrimary, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            Text("\(Int(progress * 100))%")
                .font(DS.Typography.micro())
                .foregroundStyle(.textSecondary)
        }
    }
}

// MARK: - Previews

#Preview("iPhone") {
    let authVM = AuthViewModel()
    let familyVM = FamilyViewModel()
    return NavigationStack {
        HomeView(
            authVM: authVM,
            familyVM: familyVM,
            taskVM: familyVM.taskVM,
            habitVM: familyVM.habitVM,
            notificationVM: familyVM.notificationVM
        )
    }
    .environment(ThemeManager.shared)
    .environment(TourManager.shared)
    .environment(NavigationRouter())
}
