//
//  CalendarView.swift
//
//  PURPOSE:
//    Full calendar tab with month grid, week strip, and agenda views.
//    Supports member filtering, event creation, and date navigation.
//
//  ARCHITECTURE ROLE:
//    Tab root — owns date selection state and switches between
//    month grid overlay and day agenda views.
//
//  DATA FLOW:
//    CalendarViewModel → events by date range
//    TaskViewModel → tasks by date for combined agenda
//

import SwiftUI

struct CalendarView: View {
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    @Environment(TaskViewModel.self) var taskVM
    @Environment(CalendarViewModel.self) var calendarVM
    @Environment(AuthViewModel.self) var authViewModel
    private var eventKitService: EventKitCalendarService { .shared }
    
    // MARK: - Environment
    
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    // MARK: - State
    
    @State private var selectedDay = Date.now
    @State private var currentWeekStart = Date.now.startOfWeek
    @State private var showMonthGrid = false
    @State private var monthGridMonth = Date.now
    @State private var showMemberFilter = false
    @State private var selectedMemberIds: Set<String> = []
    @State private var selectedTask: FamilyTask? = nil
    @State private var showAddEvent = false
    
    // MARK: - Cache
    
    @State private var cache = AgendaDataCache()
    
    // MARK: - Computed Properties
    
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    private let calendar = Calendar.current
    
    private var weekDays: [Date] {
        (0..<7).map { currentWeekStart.addingDays($0) }
    }
    
    private var headerMonthLabel: String {
        SharedFormatters.monthYear.string(from: currentWeekStart)
    }
    
    private var currentAgenda: DayAgenda {
        cache.agenda(for: selectedDay)
    }
    
    private var weekItemCounts: [String: Int] {
        cache.itemCounts(for: weekDays)
    }
    
    // MARK: - Fingerprints
    
    private var eventsFingerprint: Int {
        var hasher = Hasher()
        for e in calendarVM.events {
            hasher.combine(e.id)
            hasher.combine(e.startDate)
            hasher.combine(e.title)
        }
        return hasher.finalize()
    }
    
    private var tasksFingerprint: Int {
        var hasher = Hasher()
        for t in taskVM.activeTasks { hasher.combine(t.id); hasher.combine(t.dueDate); hasher.combine(t.status) }
        return hasher.finalize()
    }
    
    // MARK: - Body
    
    var body: some View {
        Group {
            if isRegularWidth {
                iPadLayout
            } else {
                iPhoneLayout
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await initialLoad()
        }
        .onChange(of: eventsFingerprint) { _, _ in rebuildCache() }
        .onChange(of: tasksFingerprint) { _, _ in rebuildCache() }
        .onChange(of: selectedMemberIds) { _, _ in rebuildCache() }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task)
                .presentationBackground(Color.themeSurfacePrimary)
        }
        .sheet(isPresented: $showMemberFilter) {
            memberFilterSheet
        }
        .sheet(isPresented: $showAddEvent) {
            AddEventView()
                .presentationBackground(Color.themeSurfacePrimary)
        }
    }
    
    // MARK: - iPhone Layout
    
    private var iPhoneLayout: some View {
        ZStack(alignment: .top) {
            // Main background
            Color.themeSurfacePrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Clean header
                calendarHeader
                
                // Content scroll
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.Spacing.lg) {
                        // Week strip
                        weekStripSection
                        
                        // Agenda content
                        AgendaDayView(
                            selectedDay: selectedDay,
                            agenda: currentAgenda,
                            familyMembers: familyMemberVM.familyMembers,
                            onSelectTask: { selectedTask = $0 },
                            onDeleteEvent: { event in
                                Task { await familyViewModel.deleteEvent(event) }
                            }
                        )
                        .padding(.horizontal, DS.Spacing.screenH)
                        
                        Spacer(minLength: 120)
                    }
                    .padding(.top, DS.Spacing.md)
                }
            }
            
            // Month grid overlay
            if showMonthGrid {
                monthGridOverlay
            }
        }
    }
    
    // MARK: - Calendar Header
    
    private var calendarHeader: some View {
        HStack(spacing: DS.Spacing.md) {
            // Month title button
            Button(action: {
                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                    showMonthGrid.toggle()
                    if showMonthGrid {
                        monthGridMonth = selectedDay.startOfMonth
                    }
                }
            }) {
                HStack(spacing: DS.Spacing.sm) {
                    Text(headerMonthLabel)
                        .font(DS.Typography.heading())
                        .foregroundStyle(.textPrimary)
                    
                    Image(systemName: showMonthGrid ? "chevron.up" : "chevron.down")
                        .font(DS.Typography.captionMedium())
                        .foregroundStyle(.accentPrimary)
                }
            }
            
            Spacer()
            
            // Today button
            if !selectedDay.isToday {
                Button(action: jumpToToday) {
                    Text("today")
                        .font(DS.Typography.captionMedium())
                        .foregroundStyle(.accentPrimary)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(
                            Capsule()
                                .fill(Color.accentPrimary.opacity(0.1))
                        )
                }
            }
            
            // Filter button
            Button(action: { showMemberFilter = true }) {
                Image(systemName: selectedMemberIds.isEmpty ? "person.2" : "person.2.fill")
                    .font(DS.Typography.body())
                    .foregroundStyle(selectedMemberIds.isEmpty ? .textSecondary : .accentPrimary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.themeCardBackground)
                            .elevation1()
                    )
            }
            
            // Add event button
            Button(action: { showAddEvent = true }) {
                Image(systemName: "plus")
                    .font(DS.Typography.body())
                    .foregroundStyle(.accentPrimary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.themeCardBackground)
                            .elevation1()
                    )
            }
        }
        .padding(.horizontal, DS.Spacing.screenH)
        .padding(.vertical, DS.Spacing.md)
    }
    
    // MARK: - iPad Layout (Side-by-Side)
    
    private var iPadLayout: some View {
        HStack(spacing: 0) {
            // Left: Month Calendar Sidebar
            VStack(spacing: 0) {
                iPadMonthHeader
                
                Rectangle()
                    .fill(Color.separator)
                    .frame(height: 0.5)
                
                iPadMonthGrid
                    .padding(.horizontal, DS.Spacing.lg)
                    .padding(.top, DS.Spacing.lg)
                
                Spacer()
            }
            .frame(width: 320)
            .background(Color.themeSurfacePrimary)
            
            Rectangle()
                .fill(Color.separator)
                .frame(width: 0.5)
            
            // Right: Day Agenda
            VStack(spacing: 0) {
                iPadDayHeader
                
                Rectangle()
                    .fill(Color.separator)
                    .frame(height: 0.5)
                
                ScrollView(showsIndicators: false) {
                    AgendaDayView(
                        selectedDay: selectedDay,
                        agenda: currentAgenda,
                        familyMembers: familyMemberVM.familyMembers,
                        onSelectTask: { selectedTask = $0 },
                        onDeleteEvent: { event in
                            Task { await familyViewModel.deleteEvent(event) }
                        }
                    )
                    .padding(DS.Spacing.xl)
                    
                    Spacer(minLength: DS.Spacing.jumbo)
                }
            }
            .frame(maxWidth: .infinity)
            .background(Color.themeSurfacePrimary)
        }
    }
    
    // MARK: - iPad Components
    
    private var iPadMonthHeader: some View {
        HStack {
            Button {
                withAnimation { monthGridMonth = monthGridMonth.adding(months: -1) }
                loadMonthData()
            } label: {
                Image(systemName: "chevron.left")
                    .font(DS.Typography.label())
                    .foregroundStyle(.textSecondary)
                    .frame(width: 36, height: 36)
            }
            
            Spacer()
            
            Text(SharedFormatters.monthYear.string(from: monthGridMonth))
                .font(DS.Typography.subheading())
                .foregroundStyle(.textPrimary)
            
            Spacer()
            
            Button {
                withAnimation { monthGridMonth = monthGridMonth.adding(months: 1) }
                loadMonthData()
            } label: {
                Image(systemName: "chevron.right")
                    .font(DS.Typography.label())
                    .foregroundStyle(.textSecondary)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.md)
    }
    
    private var iPadMonthGrid: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Day names header
            HStack(spacing: 0) {
                ForEach(Array(AppStrings.dayNames.dropFirst().enumerated()), id: \.offset) { _, day in
                    Text(day)
                        .font(DS.Typography.micro())
                        .fontWeight(.medium)
                        .foregroundStyle(.textTertiary)
                        .frame(maxWidth: .infinity)
                }
            }
            
            // Calendar grid
            let days = calendarDays(for: monthGridMonth)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DS.Spacing.xs), count: 7), spacing: DS.Spacing.xs) {
                // FIX: Use \.offset as ID instead of \.self — padding days are nil,
                // and multiple nils as \.self IDs causes "ID nil occurs multiple times" warning.
                // Same pattern used in MonthGridOverlay.swift line 107.
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    iPadDayCell(date: date)
                }
            }
        }
    }
    
    private func iPadDayCell(date: Date?) -> some View {
        Group {
            if let date = date {
                let isSelected = calendar.isDate(date, inSameDayAs: selectedDay)
                let isToday = calendar.isDateInToday(date)
                let itemCount = cache.agenda(for: date).totalCount
                
                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        selectedDay = date
                        currentWeekStart = date.startOfWeek
                    }
                } label: {
                    VStack(spacing: DS.Spacing.xxs) {
                        Text("\(calendar.component(.day, from: date))")
                            .font(DS.Typography.bodySmall())
                            .fontWeight(isToday ? .semibold : .regular)
                            .foregroundStyle(isSelected ? .textOnAccent : (isToday ? .accentPrimary : .textPrimary))
                        
                        if itemCount > 0 {
                            Circle()
                                .fill(isSelected ? Color.white.opacity(0.8) : Color.accentPrimary)
                                .frame(width: 4, height: 4)
                        } else {
                            Spacer().frame(height: 4)
                        }
                    }
                    .frame(width: 36, height: 40)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .fill(isSelected ? Color.accentPrimary : Color.clear)
                    )
                }
                .buttonStyle(.plain)
            } else {
                Color.clear
                    .frame(width: 36, height: 40)
            }
        }
    }
    
    private var iPadDayHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(selectedDay.formatted(.dateTime.weekday(.wide)))
                    .font(DS.Typography.caption())
                    .foregroundStyle(.textSecondary)
                
                Text(selectedDay.formatted(.dateTime.month().day()))
                    .font(DS.Typography.heading())
                    .foregroundStyle(.textPrimary)
            }
            
            Spacer()
            
            if !selectedDay.isToday {
                Button {
                    jumpToToday()
                } label: {
                    Text("today")
                        .font(DS.Typography.captionMedium())
                        .foregroundStyle(.accentPrimary)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(
                            Capsule()
                                .fill(Color.accentPrimary.opacity(0.1))
                        )
                }
            }
            
            Button { showMemberFilter = true } label: {
                Image(systemName: selectedMemberIds.isEmpty ? "person.2" : "person.2.fill")
                    .font(DS.Typography.body())
                    .foregroundStyle(selectedMemberIds.isEmpty ? .textSecondary : .accentPrimary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.themeCardBackground)
                    )
            }
            
            Button(action: { showAddEvent = true }) {
                Image(systemName: "plus")
                    .font(DS.Typography.body())
                    .foregroundStyle(.accentPrimary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.themeCardBackground)
                    )
            }
        }
        .padding(.horizontal, DS.Spacing.xl)
        .padding(.vertical, DS.Spacing.lg)
    }
    
    // MARK: - Week Strip Section
    
    private var weekStripSection: some View {
        WeekStripView(
            weekDays: weekDays,
            selectedDay: selectedDay,
            todayDate: Date.now,
            itemCounts: weekItemCounts,
            onSelectDay: { date in
                withAnimation(.easeOut(duration: 0.15)) { selectedDay = date }
            },
            onSwipeBack: { navigateWeek(delta: -1) },
            onSwipeForward: { navigateWeek(delta: 1) }
        )
        .padding(.horizontal, DS.Spacing.screenH)
        .gesture(pullDownGesture)
    }
    
    private var pullDownGesture: some Gesture {
        DragGesture(minimumDistance: 20, coordinateSpace: .local)
            .onEnded { value in
                if value.translation.height > 60 && abs(value.translation.width) < 100 {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showMonthGrid = true
                        monthGridMonth = selectedDay.startOfMonth
                    }
                }
            }
    }
    
    private var monthGridOverlay: some View {
        ZStack {
            Color.black.opacity(0.15)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.easeOut(duration: 0.25)) { showMonthGrid = false }
                }
                .zIndex(1)
            
            VStack {
                Spacer().frame(height: DS.Spacing.md)
                
                MonthGridOverlay(
                    currentMonth: monthGridMonth,
                    selectedDay: selectedDay,
                    todayDate: Date.now,
                    itemCounts: cache.dayAgendas.mapValues { $0.totalCount },
                    onSelectDay: { date in
                        selectedDay = date
                        currentWeekStart = date.startOfWeek
                        let newMonthKey = AgendaDataCache.monthKey(for: date)
                        if newMonthKey != AgendaDataCache.monthKey(for: monthGridMonth) {
                            monthGridMonth = date.startOfMonth
                            loadMonthData()
                        }
                    },
                    onPreviousMonth: {
                        monthGridMonth = monthGridMonth.adding(months: -1)
                        loadMonthData()
                    },
                    onNextMonth: {
                        monthGridMonth = monthGridMonth.adding(months: 1)
                        loadMonthData()
                    },
                    onCollapse: { showMonthGrid = false }
                )
                .padding(.horizontal, DS.Spacing.screenH)
                
                Spacer()
            }
            .zIndex(2)
            .transition(.opacity)
        }
    }
    
    private var memberFilterSheet: some View {
        NavigationStack {
            List {
                Button(action: { selectedMemberIds.removeAll() }) {
                    HStack {
                        Text("show_all_members")
                            .font(DS.Typography.body())
                            .foregroundStyle(.textPrimary)
                        Spacer()
                        if selectedMemberIds.isEmpty {
                            Image(systemName: "checkmark")
                                .font(DS.Typography.label())
                                .foregroundStyle(.accentPrimary)
                        }
                    }
                }
                ForEach(familyMemberVM.familyMembers) { member in
                    Button(action: { toggleMember(member) }) {
                        HStack(spacing: DS.Spacing.md) {
                            AvatarView(user: member, size: DS.Avatar.sm)
                            Text(member.displayName)
                                .font(DS.Typography.body())
                                .foregroundStyle(.textPrimary)
                            Spacer()
                            if selectedMemberIds.contains(member.id ?? "") {
                                Image(systemName: "checkmark")
                                    .font(DS.Typography.label())
                                    .foregroundStyle(.accentPrimary)
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("filter_by_member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") { showMemberFilter = false }
                        .font(DS.Typography.label())
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Color.themeSurfacePrimary)
    }
    
    // MARK: - Helpers
    
    private func calendarDays(for month: Date) -> [Date?] {
        let startOfMonth = month.startOfMonth
        let firstWeekday = calendar.component(.weekday, from: startOfMonth)
        let daysInMonth = calendar.range(of: .day, in: .month, for: startOfMonth)?.count ?? 30
        
        var days: [Date?] = Array(repeating: nil, count: firstWeekday - 1)
        
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: startOfMonth) {
                days.append(date)
            }
        }
        
        while days.count % 7 != 0 {
            days.append(nil)
        }
        
        return days
    }
    
    private func jumpToToday() {
        let today = Date.now
        withAnimation(.easeOut(duration: 0.2)) {
            selectedDay = today
            currentWeekStart = today.startOfWeek
            monthGridMonth = today.startOfMonth
        }
        ensureMonthLoaded(for: today)
    }
    
    private func navigateWeek(delta: Int) {
        guard let newStart = calendar.date(byAdding: .weekOfYear, value: delta, to: currentWeekStart) else { return }
        withAnimation(.easeOut(duration: 0.2)) {
            currentWeekStart = newStart
            let weekday = calendar.component(.weekday, from: selectedDay)
            if let candidate = calendar.date(bySetting: .weekday, value: weekday, of: newStart),
               candidate >= newStart && candidate < newStart.adding(weeks: 1) {
                selectedDay = candidate
            } else {
                selectedDay = newStart
            }
        }
        ensureMonthLoaded(for: newStart)
    }
    
    private func toggleMember(_ member: FamilyUser) {
        guard let id = member.id else { return }
        if selectedMemberIds.contains(id) {
            selectedMemberIds.remove(id)
        } else {
            selectedMemberIds.insert(id)
        }
    }
    
    // MARK: - Data Loading
    
    private func initialLoad() async {
        let start = selectedDay.startOfMonth
        let end = start.adding(months: 1)
        await familyViewModel.loadCalendarEvents(from: start, to: end)
        rebuildCache()
    }
    
    private func loadMonthData() {
        Task {
            let start = monthGridMonth.startOfMonth
            let end = start.adding(months: 1)
            await familyViewModel.loadCalendarEvents(from: start, to: end)
            cache.rebuild(
                anchorDate: monthGridMonth,
                events: calendarVM.events,
                tasks: taskVM.activeTasks,
                selectedMemberIds: selectedMemberIds
            )
        }
    }
    
    private func ensureMonthLoaded(for date: Date) {
        let monthKey = AgendaDataCache.monthKey(for: date)
        guard monthKey != cache.loadedMonthKey else { return }
        monthGridMonth = date.startOfMonth
        loadMonthData()
    }
    
    private func rebuildCache() {
        cache.rebuild(
            anchorDate: currentWeekStart,
            events: calendarVM.events,
            tasks: taskVM.activeTasks,
            selectedMemberIds: selectedMemberIds
        )
    }
}

#Preview("iPhone") {
    let vm = FamilyViewModel()
    NavigationStack {
        CalendarView()
    }
    .environment(AuthViewModel())
    .environment(vm)
    .environment(vm.familyMemberVM)
    .environment(vm.taskVM)
    .environment(vm.calendarVM)
    .environment(vm.habitVM)
    .environment(vm.notificationVM)
    .environment(ThemeManager.shared)
}
