//  HomeDerivedState.swift
//
//
//  Performance cache for HomeView.
//  Precomputes filtered task lists + week events once when source data changes.
//  Debounced search (300ms) filters against a pre-built index - never inside body.
//

import SwiftUI

// MARK: - Timeline Item (merged tasks + events)

enum TimelineItem: Identifiable {
    case task(FamilyTask)
    case event(UpcomingEvent)
    
    var id: String {
        switch self {
        case .task(let task): return "task-\(task.stableId)"
        case .event(let event): return "event-\(event.id)"
        }
    }
    
    var sortDate: Date {
        switch self {
        case .task(let task): return task.scheduledTime ?? task.dueDate
        case .event(let event): return event.date
        }
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(sortDate)
    }
    
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(sortDate)
    }
}

// MARK: - Derived State

@MainActor
@Observable
final class HomeDerivedState {
    
    // MARK: - Published Outputs (consumed by views)
    
    /// Active tasks (todo + inProgress + pendingVerification), sorted by priority then dueDate.
    private(set) var activeTasks: [FamilyTask] = []
    
    /// Completed tasks (hidden by default, shown when toggled).
    private(set) var completedTasks: [FamilyTask] = []
    
    /// Search-filtered tasks - equals activeTasks when search is empty.
    private(set) var displayedTasks: [FamilyTask] = []
    
    /// Focus Now: Top 5 highest-priority tasks that need attention.
    private(set) var focusTasks: [FamilyTask] = []
    
    /// This-week upcoming events (max 7), excludes today/tomorrow (those go in timeline).
    private(set) var weekEvents: [UpcomingEvent] = []
    
    /// Unified timeline: tasks and events merged by date for today/tomorrow
    private(set) var timelineItems: [TimelineItem] = []
    
    /// Whether we're currently showing completed tasks in the unified list.
    var showCompleted: Bool = false {
        didSet { refilter() }
    }
    
    /// Visible task groups with stats for current user.
    private(set) var myVisibleGroups: [TaskGroup] = []
    
    /// Tasks pending verification that were assigned BY this user.
    private(set) var myPendingVerificationTasks: [FamilyTask] = []
    
    /// Slot 6: Active tasks NOT in focusTasks (the overflow).
    private(set) var otherTasks: [FamilyTask] = []
    
    // MARK: - ADHD Completion Stats
    
    /// Today: tasks assigned to me that are due today (any status).
    private(set) var todayTotalCount: Int = 0
    
    /// Today: tasks completed today.
    private(set) var todayCompletedCount: Int = 0
    
    /// This week: total completed tasks.
    private(set) var weeklyCompletedCount: Int = 0
    
    /// This week: earnings (passed through from rebuild).
    private(set) var weeklyEarningsAmount: Double = 0
    
    /// Habit streak days (passed through from rebuild).
    private(set) var habitStreakDays: Int = 0

    // MARK: - v2 Home Slots

    /// Slot 1: Capability-driven personal stat. First match wins, zero branching.
    private(set) var personalStat: PersonalStat = .fallback

    /// Slot 2: Single most important pending action. Nil = slot collapses.
    private(set) var actionCard: ActionCardData? = nil

    /// Slot 5: Events for today/tomorrow only, max 5.
    private(set) var todayTomorrowEvents: [UpcomingEvent] = []
    
    /// Search text - drives debounced refilter.
    var searchText: String = "" {
        didSet {
            guard searchText != oldValue else { return }
            debounceSearch()
        }
    }
    
    // MARK: - Private
    
    /// Pre-built search index: taskId -> lowercased searchable string.
    private var searchIndex: [String: String] = [:]
    
    /// Task handle for debounced search.
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    
    /// Last rebuild fingerprint to skip redundant work.
    private var lastFingerprint: Int = 0
    
    // MARK: - Init
    
    init() {}
    
    // MARK: - Debounced Search
    
    private func debounceSearch() {
        searchTask?.cancel()
        searchTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            self?.refilter()
        }
    }
    
    // MARK: - Rebuild (called when source data changes)
    
    func rebuild(
        allTasks: [FamilyTask],
        userId: String,
        capabilities: MemberCapabilities,
        members: [FamilyUser],
        groups: [TaskGroup],
        upcomingEvents: [UpcomingEvent],
        habitStreakDays: Int = 0,
        weeklyEarnings: Double = 0,
        pendingPayoutAmount: Double = 0
    ) {
        // Comprehensive fingerprint: tasks + members + groups
        var hasher = Hasher()
        hasher.combine(userId)
        hasher.combine(allTasks.count)
        hasher.combine(members.count)
        hasher.combine(groups.count)
        for t in allTasks {
            hasher.combine(t.id)
            hasher.combine(t.status)
            hasher.combine(t.title)
        }
        for m in members {
            hasher.combine(m.id)
        }
        let fp = hasher.finalize()
        
        // Always rebuild events (they have their own data source)
        rebuildWeekEvents(upcomingEvents)
        
        guard fp != lastFingerprint else { return }
        lastFingerprint = fp
        
        // Build member lookup: id -> displayName
        let memberLookup = Dictionary(members.compactMap { m in
            m.id.map { ($0, m.displayName) }
        }, uniquingKeysWith: { first, _ in first })
        
        // Build group lookup: id -> name
        let groupLookup = Dictionary(groups.compactMap { g in
            g.id.map { ($0, g.name) }
        }, uniquingKeysWith: { first, _ in first })
        
        // ── Visible Groups with Stats (moved from HomeView computed property) ──
        // Previously ran on EVERY body evaluation, iterating all tasks twice.
        // Now runs once per debounced rebuild.
        let userGroupIds = Set(
            allTasks
                .filter { $0.assignedTo == userId || $0.assignedBy == userId }
                .compactMap { $0.groupId }
        )
        var tasksByGroupId: [String: [FamilyTask]] = [:]
        for task in allTasks {
            if let groupId = task.groupId {
                tasksByGroupId[groupId, default: []].append(task)
            }
        }
        myVisibleGroups = groups.filter { group in
            guard let gid = group.id else { return false }
            return group.createdBy == userId || userGroupIds.contains(gid)
        }.map { group in
            var g = group
            let tasks = tasksByGroupId[group.id ?? ""] ?? []
            g.taskCount = tasks.count
            let completed = tasks.filter { $0.status == .completed }.count
            g.completionPercentage = tasks.isEmpty ? 0 : Double(completed) / Double(tasks.count) * 100
            return g
        }
        
        // ── Pending Verification Tasks (moved from HomeView computed property) ──
        if capabilities.canVerifyHomework {
            myPendingVerificationTasks = allTasks.filter {
                $0.status == .pendingVerification && $0.assignedBy == userId
            }
        } else {
            myPendingVerificationTasks = []
        }
        
        // Filter to "my tasks": assigned to me OR created by me
        // Uses isAssigned(to:) which checks allAssignees (multi-assignee support)
        let myTasks = allTasks.filter { task in
            task.isAssigned(to: userId) || task.assignedBy == userId
        }
        
        // Partition into active vs completed
        var active: [FamilyTask] = []
        var completed: [FamilyTask] = []
        
        for task in myTasks {
            if task.status == .completed {
                completed.append(task)
            } else {
                active.append(task)
            }
        }
        
        // Sort active: urgent first, then by dueDate ascending
        active.sort { lhs, rhs in
            let lp = lhs.priority.sortOrder
            let rp = rhs.priority.sortOrder
            if lp != rp { return lp < rp }
            return lhs.dueDate < rhs.dueDate
        }
        
        // Sort completed: most recent first
        completed.sort { ($0.completedAt ?? $0.dueDate) > ($1.completedAt ?? $1.dueDate) }
        
        activeTasks = active
        completedTasks = completed
        
        // Build Focus Now: top 5 tasks needing attention
        buildFocusTasks(from: active)
        
        // Slot 6: Other tasks = active minus focus
        let focusIds = Set(focusTasks.compactMap { $0.id })
        otherTasks = active.filter { task in
            guard let id = task.id else { return false }
            return !focusIds.contains(id)
        }
        
        // ADHD stats: today's progress
        let calendar = Calendar.current
        let todayAll = allTasks.filter { task in
            calendar.isDateInToday(task.dueDate) &&
            (task.isAssigned(to: userId) || task.assignedBy == userId)
        }
        todayTotalCount = todayAll.count
        todayCompletedCount = todayAll.filter { $0.status == .completed }.count
        
        // ADHD stats: weekly completed
        let startOfWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start ?? .now
        weeklyCompletedCount = completed.filter { ($0.completedAt ?? $0.dueDate) >= startOfWeek }.count
        
        // Pass through values from rebuild params
        weeklyEarningsAmount = weeklyEarnings
        self.habitStreakDays = habitStreakDays
        
        // Build unified timeline
        buildTimeline(tasks: active, events: upcomingEvents)
        
        // ── v2 Slot 1: Personal Stat ─────────────────────────────────
        personalStat = PersonalStat.resolve(
            capabilities: capabilities,
            pendingReviewCount: myPendingVerificationTasks.count,
            weeklyEarnings: weeklyEarnings,
            habitStreakDays: habitStreakDays
        )
        
        // ── v2 Slot 2: Action Card ───────────────────────────────────
        let overdueTasks = active.filter { $0.isOverdue }
        actionCard = ActionCardData.resolve(
            capabilities: capabilities,
            pendingVerificationTasks: myPendingVerificationTasks,
            overdueTasks: overdueTasks,
            pendingPayoutAmount: pendingPayoutAmount
        )
        
        // ── v2 Slot 5: Today/Tomorrow Events ─────────────────────────
        todayTomorrowEvents = Array(
            upcomingEvents
                .filter { $0.daysUntil <= 1 }
                .sorted { $0.date < $1.date }
                .prefix(5)
        )
        
        // Build search index
        var index: [String: String] = [:]
        for task in myTasks {
            guard let id = task.id else { continue }
            var parts = [task.title.lowercased()]
            if let desc = task.description { parts.append(desc.lowercased()) }
            if let gid = task.groupId, let gname = groupLookup[gid] { parts.append(gname.lowercased()) }
            // Multi-assignee: index all assignee names for search
            for assigneeId in task.allAssignees {
                if let aname = memberLookup[assigneeId] { parts.append(aname.lowercased()) }
            }
            index[id] = parts.joined(separator: " ")
        }
        searchIndex = index
        
        // Apply current search/filter
        refilter()
    }
    
    // MARK: - Focus Tasks
    
    private func buildFocusTasks(from active: [FamilyTask]) {
        let calendar = Calendar.current
        let now = Date.now
        
        // Score each task for focus priority
        let scored = active.map { task -> (task: FamilyTask, score: Int) in
            var score = 0
            
            // Overdue tasks get highest priority
            if task.dueDate < now && !calendar.isDateInToday(task.dueDate) {
                score += 1000
            }
            
            // Due today
            if calendar.isDateInToday(task.dueDate) {
                score += 500
            }
            
            // Due tomorrow
            if calendar.isDateInTomorrow(task.dueDate) {
                score += 200
            }
            
            // Priority bonus
            switch task.priority {
            case .urgent: score += 100
            case .high: score += 50
            case .medium: score += 20
            case .low: score += 5
            }
            
            // In-progress tasks get a small boost (user already started)
            if task.status == .inProgress {
                score += 30
            }
            
            // Pending verification needs attention
            if task.status == .pendingVerification {
                score += 80
            }
            
            return (task, score)
        }
        
        // Sort by score descending, take top 5
        focusTasks = scored
            .sorted { $0.score > $1.score }
            .prefix(5)
            .map { $0.task }
    }
    
    // MARK: - Timeline
    
    private func buildTimeline(tasks: [FamilyTask], events: [UpcomingEvent]) {
        let calendar = Calendar.current
        
        // Get today and tomorrow tasks
        let timelineTasks = tasks.filter { task in
            calendar.isDateInToday(task.dueDate) || calendar.isDateInTomorrow(task.dueDate)
        }
        
        // Get today and tomorrow events
        let timelineEvents = events.filter { event in
            event.daysUntil == 0 || event.daysUntil == 1
        }
        
        // Merge into timeline items
        var items: [TimelineItem] = []
        items.append(contentsOf: timelineTasks.map { .task($0) })
        items.append(contentsOf: timelineEvents.map { .event($0) })
        
        // Sort by date/time
        items.sort { $0.sortDate < $1.sortDate }
        
        timelineItems = items
    }
    
    // MARK: - Week Events
    
    private func rebuildWeekEvents(_ events: [UpcomingEvent]) {
        // Show events within next 7 days, max 7 items
        // Exclude today/tomorrow (they're in the timeline)
        weekEvents = Array(events.filter { $0.daysUntil >= 2 && $0.daysUntil <= 7 }.prefix(7))
    }
    
    // MARK: - Refilter (search + completed toggle)
    
    private func refilter() {
        let base = showCompleted ? (activeTasks + completedTasks) : activeTasks
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        
        guard !query.isEmpty else {
            displayedTasks = base
            return
        }
        
        displayedTasks = base.filter { task in
            guard let id = task.id, let indexed = searchIndex[id] else { return false }
            return indexed.contains(query)
        }
    }
}

// MARK: - Priority Sort Order

private extension FamilyTask.TaskPriority {
    /// Lower number = higher priority (urgent first).
    var sortOrder: Int {
        switch self {
        case .urgent: return 0
        case .high: return 1
        case .medium: return 2
        case .low: return 3
        }
    }
}
