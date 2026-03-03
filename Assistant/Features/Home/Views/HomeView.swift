//
//  HomeView.swift
//  FamilyHub
//
//  LUXURY CALM REDESIGN
//  - Clean, minimal header with soft notification badge
//  - Premium typography throughout
//  - Elegant greeting and date display
//  - Refined spacing using 8pt grid
//
//  PERFORMANCE: Snapshot provider pattern
//  - ViewModels passed as parameters (not @Environment)
//  - Minimizes cascade re-renders
//  - Only 2 @Environment kept
//

import SwiftUI
import EventKit

struct HomeView: View {
    // MARK: - Essential EnvironmentObjects (kept to 2)
    @Environment(ThemeManager.self) var themeManager
    @Environment(TourManager.self) var tourManager
    
    // MARK: - Parameters (snapshot provider pattern)
    let resetTrigger: UUID
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
    
    // MARK: - Navigation State
    
    @State var showNotifications = false
    @State var showTodayTasks = false
    @State var showTaskGroup: TaskGroup? = nil
    @State var selectedTask: FamilyTask? = nil
    
    // MARK: - Add Sheets (for inline empty-state CTAs)
    
    @State var showAddTask = false
    @State var showAddHabit = false
    @State var showAddEvent = false
    
    // MARK: - EventKit
    
    var eventKitService = EventKitCalendarService.shared
    
    // MARK: - Derived State Cache
    
    @State var derived = HomeDerivedState()
    
    @State var cachedUpcomingEvents: [UpcomingEvent] = []
    
    // MARK: - Rebuild Debounce
    /// Coalesces rapid-fire @Observable change notifications
    /// into a single rebuild pass after 150ms of quiet.
    @State private var rebuildTask: Task<Void, Never>?
    @State private var pendingEventRecompute = false
    
    // MARK: - Computed Properties
    
    var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    // myPendingVerificationTasks → moved to derived.myPendingVerificationTasks
    // myVisibleGroups → moved to derived.myVisibleGroups
    
    // MARK: - Shared Inline CTAs (used by both iPhone and iPad layouts)
    
    var addTaskCTA: some View {
        HomeInlineCTA(
            icon: "checkmark.circle",
            iconColor: Color.accentPrimary,
            title: "Create Your First Task",
            subtitle: "Organize to-dos and chores for the whole family.",
            buttonLabel: "Add Task",
            action: { showAddTask = true }
        )
        .tourTarget("home.addTask")
    }
    
    var addHabitCTA: some View {
        HomeInlineCTA(
            icon: "flame",
            iconColor: Color.accentGreen,
            title: "Start Tracking Habits",
            subtitle: "Build daily routines like reading, exercise, or chores.",
            buttonLabel: "Add Habit",
            action: { showAddHabit = true }
        )
        .tourTarget("home.addHabit")
    }
    
    var addEventCTA: some View {
        HomeInlineCTA(
            icon: "calendar.badge.plus",
            iconColor: Color.accentOrange,
            title: "Add a Family Event",
            subtitle: "Birthdays, appointments, and activities in one place.",
            buttonLabel: "Add Event",
            action: { showAddEvent = true }
        )
        .tourTarget("home.addEvent")
    }
    
    // MARK: - Static Formatters
    
    static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            Color.themeSurfacePrimary
                .ignoresSafeArea()
            
            if familyVM.isLoading {
                VStack(spacing: DS.Spacing.md) {
                    ProgressView()
                    Text(L10n.loading)
                        .font(DS.Typography.bodySmall())
                        .foregroundStyle(.textSecondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if isRegularWidth {
                    iPadLayout
                } else {
                    iPhoneLayout
                }
            }
        }
        .navigationDestination(isPresented: $showTodayTasks) {
            TodayTasksView()
        }
        .navigationDestination(item: $showTaskGroup) { group in
            TaskGroupDetailView(taskGroup: group)
        }
        .sheet(isPresented: $showNotifications) {
            NotificationsView()
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task)
        }
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
        .onChange(of: resetTrigger) { _, _ in
            showTodayTasks = false
            showTaskGroup = nil
            selectedTask = nil
        }
        .onReceive(NotificationCenter.default.publisher(for: .dismissTaskSheets)) { _ in
            selectedTask = nil
        }
        .task {
            await loadData()
        }
        // PERF: Debounced rebuild — @Observable tracks per-property access
        // (isLoading, errorMessage, selectedDate, etc.), not just data arrays.
        // A single Firestore snapshot fires isLoading=true → data → isLoading=false = 3 events.
        // With 3 VMs that's up to 9 rebuilds per snapshot. Debounce coalesces to 1.
        .onReceive(taskVM.objectWillChange) { _ in
            scheduleRebuild()
        }
        .onReceive(familyMemberVM.objectWillChange) { _ in
            scheduleRebuild(recomputeEvents: true)
        }
        .onReceive(calendarVM.objectWillChange) { _ in
            scheduleRebuild(recomputeEvents: true)
        }
        .onChange(of: eventKitService.events.count) { _, _ in scheduleRebuild(recomputeEvents: true) }
        .onChange(of: eventKitService.holidayEvents.count) { _, _ in scheduleRebuild(recomputeEvents: true) }
    }
    
    // MARK: - Shared Components
    
    var headerSection: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Date (small, muted) - on top
                Text(Self.fullDateFormatter.string(from: Date()))
                    .font(DS.Typography.caption())
                    .foregroundStyle(.textTertiary)
                
                // Large greeting with name
                Text("\(greetingText), \(authVM.currentUser?.displayName ?? "")!")
                    .font(DS.Typography.displayMedium())
                    .foregroundStyle(.textPrimary)
            }
            
            Spacer()
            
            // Notification button
            Button(action: { showNotifications = true }) {
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
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return L10n.goodMorning
        case 12..<17: return L10n.goodAfternoon
        default: return L10n.goodEvening
        }
    }
    
    // MARK: - Data Methods
    
    /// Debounced rebuild: cancels pending work, waits 150ms, then executes once.
    /// Accumulates the `recomputeEvents` flag across coalesced calls so event
    /// recomputation isn't lost when a non-event call arrives first.
    ///
    /// Before: 9 rebuilds per Firestore snapshot (3 VMs × isLoading + data + isLoading)
    /// After:  1 rebuild per snapshot, 150ms after the last mutation
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
        let today = Date()
        let startOfWeek = today.startOfWeek
        let endOfWeek = Calendar.current.date(byAdding: .day, value: 6, to: startOfWeek) ?? today
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
            isAdult: authVM.currentUser?.isAdult == true,
            members: familyMemberVM.familyMembers,
            groups: familyMemberVM.taskGroups,
            upcomingEvents: cachedUpcomingEvents
        )
    }
    
    func recomputeUpcomingEvents() {
        cachedUpcomingEvents = UpcomingEventsBuilder.buildEvents(
            familyMembers: familyMemberVM.familyMembers,
            eventKitHolidays: eventKitService.holidayEvents,
            eventKitEvents: eventKitService.events,
            firestoreEvents: calendarVM.events,
            month: Date(),
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
            resetTrigger: UUID(),
            authVM: authVM,
            familyVM: familyVM,
            taskVM: familyVM.taskVM,
            habitVM: familyVM.habitVM,
            notificationVM: familyVM.notificationVM
        )
    }
    .environment(ThemeManager.shared)
    .environment(TourManager.shared)
}
