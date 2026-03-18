//
//  TodayTasksView.swift
//  FamilyHub
//
//  LUXURY CALM REDESIGN
//  - Clean, minimal navigation (no gradient header)
//  - Soft cream background throughout
//  - Elegant week calendar strip
//  - Premium card styling
//  - Refined typography and spacing
//  - Calming, anxiety-free design
//

import SwiftUI

struct TodayTasksView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    @Environment(TaskViewModel.self) var taskVM
    
    @State private var selectedDate = Date()
    @State private var currentWeekStart = Date()
    @State private var selectedTask: FamilyTask?
    @State private var focusTask: FamilyTask?
    @State private var inFlightActions: Set<String> = []
    @State private var toast: ToastMessage? = nil
    
    private let calendar = Calendar.current
    
    // MARK: - Computed Properties
    
    var tasksForSelectedDate: [FamilyTask] {
        taskVM.tasksFor(date: selectedDate)
    }
    
    var taskCount: Int {
        tasksForSelectedDate.count
    }
    
    var completedCount: Int {
        tasksForSelectedDate.filter { $0.status == .completed }.count
    }
    
    var scheduledMinutes: Int {
        tasksForSelectedDate.compactMap { $0.pomodoroDurationMinutes }.reduce(0, +)
    }
    
    var isSelectedToday: Bool {
        calendar.isDateInToday(selectedDate)
    }
    
    // MARK: - Formatters
    
    private static let monthYearFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()
    
    private static let fullDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // Clean theme background
            Color.themeSurfacePrimary
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Clean navigation header
                navigationHeader
                
                // Week calendar strip
                weekCalendarStrip
                    .padding(.top, DS.Spacing.md)
                
                // Content
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.Spacing.xl) {
                        // Date summary header
                        dateSummarySection
                        
                        // Task list or empty state
                        if tasksForSelectedDate.isEmpty {
                            emptyState
                        } else {
                            tasksList
                        }
                    }
                    .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
                    .padding(.top, DS.Spacing.lg)
                    .padding(.bottom, 120)
                    .constrainedWidth(.content)
                }
            }
        }
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            currentWeekStart = selectedDate.startOfWeek
        }
        .sheet(item: $selectedTask) { task in
            TaskDetailView(task: task)
        }
        .toastBanner(item: $toast)
    }
    
    // MARK: - Navigation Header
    
    private var navigationHeader: some View {
        HStack(spacing: DS.Spacing.md) {
            // Back button - solid, visible
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(DS.Typography.subheading())
                    .foregroundStyle(.textPrimary)
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color.themeCardBackground)
                            .elevation2()
                    )
            }
            
            Spacer()
            
            // Title
            Text(" schedule")
                .font(DS.Typography.subheading())
                .foregroundStyle(.textPrimary)
            
            Spacer()
            
            // Today button
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    selectedDate = Date()
                    currentWeekStart = Date().startOfWeek
                }
            } label: {
                Text(L10n.today)
                    .font(DS.Typography.captionMedium())
                    .foregroundStyle(isSelectedToday ? .textTertiary : .accentPrimary)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(isSelectedToday ? Color.clear : Color.accentPrimary.opacity(0.1))
                    )
            }
            .disabled(isSelectedToday)
        }
        .padding(.horizontal, DS.Spacing.screenH)
        .padding(.vertical, DS.Spacing.sm)
    }
    
    // MARK: - Week Calendar Strip
    
    private var weekCalendarStrip: some View {
        VStack(spacing: DS.Spacing.md) {
            // Month navigation
            HStack {
                Button { previousWeek() } label: {
                    Image(systemName: "chevron.left")
                        .font(DS.Typography.label())
                        .foregroundStyle(.textSecondary)
                        .frame(width: 32, height: 32)
                }
                
                Spacer()
                
                Text(Self.monthYearFormatter.string(from: currentWeekStart))
                    .font(DS.Typography.labelSmall())
                    .foregroundStyle(.textSecondary)
                
                Spacer()
                
                Button { nextWeek() } label: {
                    Image(systemName: "chevron.right")
                        .font(DS.Typography.label())
                        .foregroundStyle(.textSecondary)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, DS.Spacing.screenH)
            
            // Week days
            HStack(spacing: DS.Spacing.xs) {
                ForEach(weekDays, id: \.self) { date in
                    WeekDayCell(
                        date: date,
                        isSelected: calendar.isDate(date, inSameDayAs: selectedDate),
                        isToday: calendar.isDateInToday(date),
                        hasTask: !taskVM.tasksFor(date: date).isEmpty
                    ) {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedDate = date
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.screenH)
        }
        .padding(.bottom, DS.Spacing.md)
        .background(Color.themeSurfacePrimary)
    }
    
    // MARK: - Date Summary Section
    
    private var dateSummarySection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Date title
            Text(Self.fullDateFormatter.string(from: selectedDate))
                .font(DS.Typography.heading())
                .foregroundStyle(.textPrimary)
            
            // Stats row
            HStack(spacing: DS.Spacing.lg) {
                // Task count
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "checklist")
                        .font(DS.Typography.body())
                        .foregroundStyle(.accentPrimary)
                    
                    Text("\(taskCount) \(taskCount == 1 ? "task" : "tasks")")
                        .font(DS.Typography.bodySmall())
                        .foregroundStyle(.textSecondary)
                }
                
                if completedCount > 0 {
                    Text("•")
                        .foregroundStyle(.textTertiary)
                    
                    Text("\(completedCount) done")
                        .font(DS.Typography.bodySmall())
                        .foregroundStyle(.accentGreen)
                }
                
                Spacer()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Tasks List
    
    private var tasksList: some View {
        VStack(spacing: DS.Spacing.sm) {
            ForEach(tasksForSelectedDate, id: \.stableId) { task in
                TodayTaskCard(
                    task: task,
                    isLoading: inFlightActions.contains(task.id ?? ""),
                    groupName: task.groupId.flatMap { familyMemberVM.getTaskGroup(by: $0)?.name },
                    onTap: { selectedTask = task },
                    onStartTask: { startTask(task) },
                    onStartFocus: { focusTask = task },
                    onMarkComplete: { completeTask(task) }
                )
            }
        }
    }
    
    // MARK: - Empty State
    
    private var emptyState: some View {
        VStack(spacing: DS.Spacing.lg) {
            Spacer()
                .frame(height: DS.Spacing.xxl)
            
            // Icon
            ZStack {
                Circle()
                    .fill(Color.accentPrimary.opacity(0.08))
                    .frame(width: 88, height: 88)
                
                Image(systemName: "leaf")
                    .font(DS.Typography.displayMedium())
                    .foregroundStyle(.accentPrimary.opacity(0.5))
            }
            
            // Text
            VStack(spacing: DS.Spacing.xs) {
                Text(isSelectedToday ? "Nothing scheduled" : "No tasks")
                    .font(DS.Typography.subheading())
                    .foregroundStyle(.textPrimary)
                
                Text(isSelectedToday ? "Enjoy your free time" : "This day is clear")
                    .font(DS.Typography.bodySmall())
                    .foregroundStyle(.textTertiary)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xxl)
    }
    
    // MARK: - Helper Methods
    
    private var weekDays: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: currentWeekStart) }
    }
    
    private func previousWeek() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if let newStart = calendar.date(byAdding: .day, value: -7, to: currentWeekStart) {
                currentWeekStart = newStart
                selectedDate = newStart
            }
        }
    }
    
    private func nextWeek() {
        withAnimation(.easeInOut(duration: 0.2)) {
            if let newStart = calendar.date(byAdding: .day, value: 7, to: currentWeekStart) {
                currentWeekStart = newStart
                selectedDate = newStart
            }
        }
    }
    
    // MARK: - Task Actions
    
    private func startTask(_ task: FamilyTask) {
        guard let id = task.id, !inFlightActions.contains(id) else { return }
        inFlightActions.insert(id)
        
        Task {
            await familyViewModel.updateTaskStatus(task, to: .inProgress)
            await MainActor.run {
                inFlightActions.remove(id)
                toast = ToastMessage(message: "Task started", style: .success)
            }
        }
    }
    
    private func completeTask(_ task: FamilyTask) {
        guard let id = task.id, !inFlightActions.contains(id) else { return }
        inFlightActions.insert(id)
        
        Task {
            await familyViewModel.updateTaskStatus(task, to: .completed)
            await MainActor.run {
                inFlightActions.remove(id)
                toast = ToastMessage(message: "Well done!", style: .success)
            }
        }
    }
}

// MARK: - Week Day Cell

struct WeekDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let hasTask: Bool
    let onTap: () -> Void
    
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DS.Spacing.xxs) {
                // Day name
                Text(Self.dayFormatter.string(from: date).prefix(3).uppercased())
                    .font(DS.Typography.micro())
                    .foregroundStyle(isSelected ? .accentPrimary : .textTertiary)
                
                // Date number
                Text(Self.dateFormatter.string(from: date))
                    .font(DS.Typography.body()).fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? .accentPrimary : (isToday ? .textPrimary : .textSecondary))
                
                // Indicator dot
                Circle()
                    .fill(indicatorColor)
                    .frame(width: 5, height: 5)
                    .opacity(hasTask || isToday ? 1 : 0)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(isSelected ? Color.accentPrimary.opacity(0.1) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    private var indicatorColor: Color {
        if isSelected {
            return Color.accentPrimary
        }
        if isToday {
            return Color.accentPrimary.opacity(0.5)
        }
        return hasTask ? Color.textTertiary : .clear
    }
}

// MARK: - Today Task Card

struct TodayTaskCard: View {
    let task: FamilyTask
    var isLoading: Bool = false
    let groupName: String?
    let onTap: () -> Void
    var onStartTask: (() -> Void)?
    var onStartFocus: (() -> Void)?
    var onMarkComplete: (() -> Void)?
    
    private var timeString: String? {
        guard let time = task.scheduledTime else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: time)
    }
    
    private var isCompleted: Bool {
        task.status == .completed
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                // Top row: time and status
                HStack {
                    if let time = timeString {
                        Text(time)
                            .font(DS.Typography.captionMedium())
                            .foregroundStyle(.textTertiary)
                    }
                    
                    Spacer()
                    
                    // Status indicator
                    statusIndicator
                }
                
                // Title
                Text(task.title)
                    .font(DS.Typography.label())
                    .foregroundStyle(isCompleted ? .textTertiary : .textPrimary)
                    .strikethrough(isCompleted, color: Color.textTertiary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                
                // Bottom row: metadata
                HStack(spacing: DS.Spacing.md) {
                    if let name = groupName {
                        HStack(spacing: DS.Spacing.xxs) {
                            Image(systemName: "folder")
                                .font(DS.Typography.micro())
                            Text(name)
                                .font(DS.Typography.caption())
                        }
                        .foregroundStyle(.textTertiary)
                    }
                    
                    Spacer()
                    
                    // Reward
                    if task.hasReward, let amount = task.rewardAmount {
                        HStack(spacing: DS.Spacing.xxs) {
                            Image(systemName: "dollarsign.circle.fill")
                                .font(DS.Typography.bodySmall())
                            Text(amount.currencyString)
                                .font(DS.Typography.captionMedium())
                        }
                        .foregroundStyle(.accentGreen)
                    }
                }
                
                // Action buttons
                if !isCompleted && task.status != .pendingVerification {
                    actionButtons
                        .padding(.top, DS.Spacing.xs)
                }
            }
            .padding(DS.Spacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(Color.themeCardBackground)
            )
            .elevation1()
        }
        .buttonStyle(.plain)
    }
    
    // MARK: - Status Indicator
    
    @ViewBuilder
    private var statusIndicator: some View {
        switch task.status {
        case .todo:
            Circle()
                .stroke(Color.textTertiary.opacity(0.3), lineWidth: 1.5)
                .frame(width: 18, height: 18)
            
        case .inProgress:
            HStack(spacing: DS.Spacing.xxs) {
                Circle()
                    .fill(Color.statusInProgress)
                    .frame(width: 6, height: 6)
                Text(L10n.inProgress)
                    .font(DS.Typography.micro())
                    .foregroundStyle(.statusInProgress)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(
                Capsule()
                    .fill(Color.statusInProgress.opacity(0.1))
            )
            
        case .pendingVerification:
            HStack(spacing: DS.Spacing.xxs) {
                Circle()
                    .fill(Color.statusPending)
                    .frame(width: 6, height: 6)
                Text(L10n.pending)
                    .font(DS.Typography.micro())
                    .foregroundStyle(.statusPending)
            }
            .padding(.horizontal, DS.Spacing.sm)
            .padding(.vertical, DS.Spacing.xxs)
            .background(
                Capsule()
                    .fill(Color.statusPending.opacity(0.1))
            )
            
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .font(DS.Typography.heading())
                .foregroundStyle(.accentGreen)
        }
    }
    
    // MARK: - Action Buttons
    
    @ViewBuilder
    private var actionButtons: some View {
        switch task.status {
        case .todo:
            Button(action: { onStartTask?() }) {
                HStack(spacing: DS.Spacing.xs) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                            .tint(Color.accentPrimary)
                    } else {
                        Image(systemName: "play.fill")
                            .font(DS.Typography.micro())
                    }
                    Text("start")
                        .font(DS.Typography.captionMedium())
                }
                .foregroundStyle(.accentPrimary)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(
                    Capsule()
                        .fill(Color.accentPrimary.opacity(0.1))
                )
            }
            .disabled(isLoading)
            
        case .inProgress:
            HStack(spacing: DS.Spacing.sm) {
                // Focus button
                Button(action: { onStartFocus?() }) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: "scope")
                            .font(DS.Typography.micro())
                        Text(L10n.focus)
                            .font(DS.Typography.captionMedium())
                    }
                    .foregroundStyle(.textSecondary)
                    .padding(.horizontal, DS.Spacing.md)
                    .padding(.vertical, DS.Spacing.sm)
                    .background(
                        Capsule()
                            .fill(Color.fill)
                    )
                }
                
                // Complete button
                if !task.requiresProof {
                    Button(action: { onMarkComplete?() }) {
                        HStack(spacing: DS.Spacing.xs) {
                            if isLoading {
                                ProgressView()
                                    .scaleEffect(0.6)
                                    .tint(.white)
                            } else {
                                Image(systemName: "checkmark")
                                    .font(DS.Typography.micro())
                            }
                            Text(L10n.done)
                                .font(DS.Typography.captionMedium())
                        }
                        .foregroundStyle(.textOnAccent)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, DS.Spacing.sm)
                        .background(
                            Capsule()
                                .fill(isLoading ? Color.textTertiary : Color.accentPrimary)
                        )
                    }
                    .disabled(isLoading)
                }
            }
            
        default:
            EmptyView()
        }
    }
}

// MARK: - Preview

#Preview {
    let familyVM = FamilyViewModel()
    NavigationStack {
        TodayTasksView()
            .environment(FamilyViewModel())
            .environment(familyVM.familyMemberVM)
            .environment(familyVM.taskVM)
    }
}
