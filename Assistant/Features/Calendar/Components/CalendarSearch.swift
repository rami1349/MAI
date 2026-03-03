
//  CalendarSearch.swift
//  FamilyHub
//
//  Search functionality for calendar events and tasks
//

import SwiftUI

// MARK: - Search Item (Event or Task)

enum SearchItem: Identifiable {
    case event(CalendarEvent)
    case task(FamilyTask)
    
    var id: String {
        switch self {
        case .event(let event): return "event_\(event.id ?? UUID().uuidString)"
        case .task(let task): return "task_\(task.id ?? UUID().uuidString)"
        }
    }
}

// MARK: - Calendar Search Sheet
/// Unified search for Events + Tasks
/// IMPORTANT: Uses source ViewModels directly to avoid debounce-related stale data

struct CalendarSearchSheet: View {
    @Environment(\.dismiss) var dismiss
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    @Environment(TaskViewModel.self) var taskVM
    @Environment(CalendarViewModel.self) var calendarVM
    
    @State private var searchText = ""
    @FocusState private var isSearchFocused: Bool
    
    let onEventSelected: (CalendarEvent) -> Void
    let onDateSelected: (Date) -> Void
    
    private let calendar = Calendar.current
    
    // MARK: - Live Computed Properties (NEVER cache in @State)
    
    /// Filtered events - derived directly from CalendarViewModel.events (live, no debounce)
    private var filteredEvents: [CalendarEvent] {
        // Access source VM directly - bypasses FamilyViewModel's 100ms debounce
        let liveEvents = calendarVM.events
        guard !searchText.isEmpty else {
            // Show upcoming events when no search
            return liveEvents
                .filter { $0.startDate >= calendar.startOfDay(for: Date()) }
                .sorted { $0.startDate < $1.startDate }
        }
        let lowercasedSearch = searchText.lowercased()
        return liveEvents
            .filter { event in
                event.title.lowercased().contains(lowercasedSearch) ||
                (event.description?.lowercased().contains(lowercasedSearch) ?? false)
            }
            .sorted { $0.startDate < $1.startDate }
    }
    
    /// Filtered tasks - derived directly from TaskViewModel.allTasks (live, no debounce)
    private var filteredTasks: [FamilyTask] {
        // Access source VM directly - bypasses FamilyViewModel's 100ms debounce
        let liveTasks = taskVM.allTasks
        guard !searchText.isEmpty else {
            // Show upcoming tasks when no search
            return liveTasks
                .filter { $0.id != nil && $0.dueDate >= calendar.startOfDay(for: Date()) }
                .sorted { $0.dueDate < $1.dueDate }
        }
        let lowercasedSearch = searchText.lowercased()
        return liveTasks
            .filter { task in
                task.id != nil && (
                    task.title.lowercased().contains(lowercasedSearch) ||
                    (task.description?.lowercased().contains(lowercasedSearch) ?? false)
                )
            }
            .sorted { $0.dueDate < $1.dueDate }
    }
    
    /// Combined and grouped by date - derived from filtered results (live)
    private var groupedItems: [(Date, [SearchItem])] {
        var itemsByDate: [Date: [SearchItem]] = [:]
        
        // Add events
        for event in filteredEvents {
            let dateKey = calendar.startOfDay(for: event.startDate)
            var items = itemsByDate[dateKey] ?? []
            items.append(.event(event))
            itemsByDate[dateKey] = items
        }
        
        // Add tasks
        for task in filteredTasks {
            let dateKey = calendar.startOfDay(for: task.dueDate)
            var items = itemsByDate[dateKey] ?? []
            items.append(.task(task))
            itemsByDate[dateKey] = items
        }
        
        return itemsByDate
            .sorted { $0.key < $1.key }
    }
    
    private var hasResults: Bool {
        !filteredEvents.isEmpty || !filteredTasks.isEmpty
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Search Bar
                HStack(spacing: 12) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.textSecondary)
                        
                        TextField("Filter events & tasks...", text: $searchText)
                            .focused($isSearchFocused)
                            .submitLabel(.search)
                        
                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(.textSecondary)
                            }
                        }
                    }
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.backgroundSecondary)
                    )
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                
                // Results count and filter status
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(searchText.isEmpty ? "Upcoming" : "Results")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.textPrimary)
                        
                        if searchText.isEmpty && hasResults {
                            Text(L10n.eventsAndTasksToday)
                                .font(.caption2)
                                .foregroundStyle(.textTertiary)
                        }
                    }
                    
                    Spacer()
                    
                    Text("\(filteredEvents.count) events, \(filteredTasks.count) tasks")
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
                
                if !hasResults {
                    // No results
                    VStack(spacing: 12) {
                        Spacer()
                        
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(DS.Typography.displayLarge())
                            .foregroundStyle(.textTertiary)
                        
                        Text(searchText.isEmpty ? L10n.noEvents : L10n.noEventsFound)
                            .font(.headline)
                            .foregroundStyle(.textPrimary)
                        
                        if !searchText.isEmpty {
                            Text(L10n.tryDifferentSearch)
                                .font(.subheadline)
                                .foregroundStyle(.textSecondary)
                        }
                        
                        Spacer()
                    }
                } else {
                    // Results List
                    ScrollView {
                        LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                            ForEach(groupedItems, id: \.0) { date, items in
                                Section {
                                    ForEach(items) { item in
                                        switch item {
                                        case .event(let event):
                                            SearchEventRow(event: event) {
                                                onEventSelected(event)
                                            }
                                        case .task(let task):
                                            SearchTaskRow(task: task) {
                                                onDateSelected(task.dueDate)
                                            }
                                        }
                                    }
                                } header: {
                                    HStack {
                                        Text(date.formattedDate)
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                            .foregroundStyle(.textSecondary)
                                        
                                        if calendar.isDateInToday(date) {
                                            Text(L10n.today)
                                                .font(.caption2)
                                                .fontWeight(.medium)
                                                .foregroundStyle(.primary)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(Capsule().fill(Color.primary.opacity(0.1)))
                                        }
                                        
                                        Spacer()
                                    }
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 8)
                                    .background(Color.backgroundPrimary)
                                }
                            }
                        }
                        .padding(.bottom, 20)
                    }
                }
            }
            .background(Color.backgroundPrimary)
            .navigationTitle(L10n.search)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
            }
        }
        .onAppear {
            // Don't auto-focus - let user see all items first
            // User can tap search field to start filtering
        }
    }
}

// MARK: - Search Event Row

struct SearchEventRow: View {
    let event: CalendarEvent
    let onTap: () -> Void
    
    private var timeString: String {
        if event.isAllDay {
            return L10n.allDay
        }
        return event.startDate.formattedTime
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Color indicator
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: event.color))
                    .frame(width: 4, height: 40)
                
                Image(systemName: "calendar")
                    .font(.subheadline)
                    .foregroundStyle(Color(hex: event.color))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(event.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                    
                    Text(timeString)
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Search Task Row

struct SearchTaskRow: View {
    let task: FamilyTask
    let onTap: () -> Void
    
    private var statusColor: Color {
        switch task.status {
        case .todo: return Color.statusTodo
        case .inProgress: return Color.statusInProgress
        case .pendingVerification: return Color.statusPending
        case .completed: return Color.statusCompleted
        }
    }
    
    private var timeString: String {
        if let time = task.scheduledTime {
            return time.formattedTime
        }
        return task.dueDate.formattedTime
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Color indicator
                RoundedRectangle(cornerRadius: 3)
                    .fill(statusColor)
                    .frame(width: 4, height: 40)
                
                Image(systemName: task.status == .completed ? "checkmark.circle.fill" : "circle")
                    .font(.subheadline)
                    .foregroundStyle(statusColor)
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(1)
                    
                    Text(timeString)
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                }
                
                Spacer()
                
                if task.hasReward, let amount = task.rewardAmount {
                    Text(amount.currencyString)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.accentGreen)
                }
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.textTertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
