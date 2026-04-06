//
//  HomeView.swift
//  PURPOSE:
//    Root container for the Home tab. Selects between iPhone and iPad
//    layouts and injects shared state (greeting, progress, derived data).
//
//  ARCHITECTURE ROLE:
//    Coordinator view — owns no data, delegates to HomeIphone/HomeIpad.
//    Reads AuthViewModel and FamilyViewModel from environment.
//
//  DATA FLOW:
//    AuthViewModel.currentUser → greeting
//    FamilyViewModel child VMs → tasks, events, habits
//    HomeDerivedState → computed sections for layout
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
    
    /// Fingerprint combining data source identity + content.
    /// Hashes task statuses so status changes (todo → completed) trigger rebuild.
    private var dataFingerprint: Int {
        var hasher = Hasher()
        hasher.combine(taskVM.isLoading)
        hasher.combine(habitVM.habits.count)
        hasher.combine(familyMemberVM.familyMembers.count)
        hasher.combine(familyMemberVM.taskGroups.count)
        hasher.combine(calendarVM.events.count)
        hasher.combine(eventKitService.events.count)
        hasher.combine(eventKitService.holidayEvents.count)
        hasher.combine(Calendar.current.component(.day, from: calendarVM.selectedDate))
        // FIX: Include task identity + status so status changes trigger rebuild.
        // Previously only hashed .count — a task completing didn't change the count.
        for task in taskVM.allTasks {
            hasher.combine(task.id)
            hasher.combine(task.status)
        }
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
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        // FIX: Load 90 days of habit logs so streak calculation can walk back
        // beyond the current week. Previously loaded only startOfWeek..endOfWeek
        // which capped visible streaks at 7 days.
        let streakLookback = calendar.date(byAdding: .day, value: -90, to: today) ?? today
        
        async let habitLogs: () = familyVM.loadHabitLogs(from: streakLookback, to: today)
        async let eventKit: () = eventKitService.loadEvents()
        async let calendarEvents: () = familyVM.loadCalendarEvents(from: startOfMonth, to: startOfNextMonth)
        
        _ = await (habitLogs, eventKit, calendarEvents)
        
        recomputeUpcomingEvents()
        rebuildDerived()
    }
    
    func refreshData() async {
        DS.Haptics.light()
        
        // FIX: Previous implementation called familyVM.loadFamilyData() which has a
        // `guard currentFamilyId != familyId` early return — making pull-to-refresh
        // a no-op since the family never changes. Now reload task and event data directly.
        let today = Date.now
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: today))!
        let startOfNextMonth = calendar.date(byAdding: .month, value: 1, to: startOfMonth)!
        
        if let familyId = authVM.currentUser?.familyId {
            await taskVM.loadTasks(familyId: familyId)
        }
        await familyVM.loadCalendarEvents(from: startOfMonth, to: startOfNextMonth)
        await eventKitService.refreshEvents()
        
        recomputeUpcomingEvents()
        rebuildDerived()
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
                // FIX: Use completedAt for weekly earnings, not dueDate.
                // An overdue task completed this week should count.
                (task.completedAt ?? task.dueDate) >= startOfWeek
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
