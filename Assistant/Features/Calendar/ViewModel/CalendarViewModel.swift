// ============================================================================
// CalendarViewModel.swift
// FamilyHub
//
// PURPOSE:
//   Manages calendar events for the family — creation, editing, deletion, and
//   date-range querying. Also provides pure utility functions for month grid
//   generation and event/task lookup by date.
//
// ARCHITECTURE ROLE:
//   - Owned by FamilyViewModel (coordinator). Views observe it via @Environment.
//   - Does NOT own task data — tasks are passed as parameters to query helpers
//     to avoid coupling with TaskViewModel.
//   - Does NOT handle notifications — FamilyViewModel orchestrates those after
//     calling CalendarViewModel operations.
//
// DATA MODEL:
//   Firestore `events` collection:
//     - familyId (family-scoped)
//     - startDate (Timestamp, used for range queries)
//     - linkedTaskId (optional — links a calendar entry to a task, prevents duplication)
//     - participants (array of user IDs)
//
// KEY DESIGN DECISIONS:
//   - Real-time listener for live updates across family members
//   - Events linked to tasks (`linkedTaskId != nil`) are excluded from `eventsFor(date:)`
//     to prevent the same item appearing in both the task list and event list.
//   - `updateEvent()` uses optimistic local update with rollback on failure
//   - Cached DateFormatter for performance
//   - Multi-assignee aware filtering for tasks

import Foundation
import Observation
import FirebaseFirestore

/// Manages calendar events and date-based queries for the family calendar.
///
/// Provides CRUD for `CalendarEvent` documents, filtered queries combining events
/// and tasks, and utility functions for month grid rendering.
@MainActor
@Observable
final class CalendarViewModel {
    
    // MARK: - Published State
    
    /// All events loaded for the currently visible date range.
    /// Updated by real-time listener automatically.
    private(set) var events: [CalendarEvent] = []
    
    /// Currently selected date in the calendar view (drives day/agenda panel).
    var selectedDate = Date()
    
    /// The month currently displayed in the grid (separate from selectedDate).
    var currentMonth = Date() {
        didSet {
            // Invalidate cached month string when month changes
            _cachedMonthYearString = nil
        }
    }
    
    /// Active member filter. When non-empty, only events/tasks involving
    /// these user IDs are shown. Empty set = show all family members.
    var selectedMemberIds: Set<String> = []
    
    /// Indicates an in-flight Firestore fetch. Used by skeleton loaders.
    private(set) var isLoading = false
    
    /// Localized error message for Firestore operation failures.
    var errorMessage: String?
    
    // MARK: - Private
    
    /// Firestore singleton — @ObservationIgnored (infrastructure, not UI state).
    private var db: Firestore { Firestore.firestore() }
    
    /// Shared Calendar instance for all date arithmetic in this ViewModel.
    @ObservationIgnored private let calendar = Calendar.current
    
    /// Real-time Firestore listener for events (FIX: SUGGESTION 1)
    @ObservationIgnored private var eventsListener: ListenerRegistration?
    
    /// Currently loaded family ID (for listener management)
    @ObservationIgnored private var currentFamilyId: String?
    
    /// Currently loaded date range (to avoid redundant listener setup)
    @ObservationIgnored private var loadedStartDate: Date?
    @ObservationIgnored private var loadedEndDate: Date?
    
    /// Cached month/year string - recomputed only when currentMonth changes (FIX: SUGGESTION 2)
    @ObservationIgnored private var _cachedMonthYearString: String?
    
    
    deinit {
        eventsListener?.remove()
    }
    
    // MARK: - Setup Listener (FIX: SUGGESTION 1)
    
    /// Sets up a real-time Firestore listener for events in the date range.
    ///
    /// The listener automatically updates the `events` array when any family
    /// member creates, edits, or deletes an event. This ensures all family
    /// members see changes instantly without manual refresh.
    ///
    /// - Parameters:
    ///   - familyId: The family's Firestore document ID.
    ///   - start: Start of the date range (inclusive).
    ///   - end: End of the date range (exclusive).
    func setupListener(familyId: String, from start: Date, to end: Date) {
        // Skip if identical query is already active
        if currentFamilyId == familyId,
           loadedStartDate == start,
           loadedEndDate == end,
           eventsListener != nil {
            return
        }
        
        // Remove existing listener before setting up new one
        eventsListener?.remove()
        
        currentFamilyId = familyId
        loadedStartDate = start
        loadedEndDate = end
        isLoading = true
        
        eventsListener = db.collection("events")
            .whereField("familyId", isEqualTo: familyId)
            .whereField("startDate", isGreaterThanOrEqualTo: start)
            .whereField("startDate", isLessThan: end)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }
                
                Task { @MainActor in
                    self.isLoading = false
                    
                    if let error = error {
                        self.errorMessage = "Failed to sync events: \(error.localizedDescription)"
                        return
                    }
                    
                    guard let documents = snapshot?.documents else { return }
                    
                    self.events = documents.compactMap { doc in
                        try? doc.data(as: CalendarEvent.self)
                    }
                }
            }
    }
    
    // MARK: - Load Events
    
    /// Fetches events for a specific date range using real-time listener.
    ///
    /// This method now delegates to `setupListener()` for real-time updates.
    /// Kept for backward compatibility with existing callers.
    ///
    /// - Parameters:
    ///   - familyId: The family's Firestore document ID.
    ///   - start: Start of the date range (inclusive).
    ///   - end: End of the date range (exclusive).
    func loadEvents(familyId: String, from start: Date, to end: Date) async {
        setupListener(familyId: familyId, from: start, to: end)
    }
    
    // MARK: - CRUD Operations
    
    /// Creates a new calendar event and persists it to Firestore.
    ///
    /// Color normalization: strips any leading `#` from the input and re-adds it
    /// to ensure all stored colors have consistent `#RRGGBB` format.
    ///
    /// The real-time listener will automatically add the event to the local array.
    ///
    /// - Parameters:
    ///   - familyId: The family this event belongs to.
    ///   - title: Event display name.
    ///   - description: Optional event notes or agenda.
    ///   - startDate: Event start time.
    ///   - endDate: Event end time (must be >= startDate).
    ///   - isAllDay: If `true`, time components are ignored in display.
    ///   - color: Hex color string (with or without `#` prefix).
    ///   - createdBy: Firebase UID of the event creator.
    ///   - participants: Array of Firebase UIDs who are invited.
    ///   - linkedTaskId: Optional task Firestore ID — links this event to a task
    ///     to prevent duplicate display in the calendar.
    /// - Returns: The Firestore document ID of the created event, or `nil` on failure.
    func createEvent(
        familyId: String,
        title: String,
        description: String?,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        color: String,
        createdBy: String,
        participants: [String],
        linkedTaskId: String? = nil
    ) async -> String? {
        let event = CalendarEvent(
            familyId: familyId,
            title: title,
            description: description,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            // Normalize color to always include '#' prefix
            color: "#\(color.replacingOccurrences(of: "#", with: ""))",
            createdBy: createdBy,
            participants: participants,
            linkedTaskId: linkedTaskId,
            eventType: nil,
            createdAt: Date()
        )
        
        do {
            let ref = try db.collection("events").addDocument(from: event)
            // Real-time listener will add to local array automatically
            return ref.documentID
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }
    
    /// Deletes a calendar event from Firestore.
    ///
    /// The real-time listener will automatically remove the event from the local array.
    ///
    /// - Parameter event: The event to delete. Must have a non-nil `id`.
    func deleteEvent(_ event: CalendarEvent) async {
        guard let id = event.id else { return }
        
        do {
            try await db.collection("events").document(id).delete()
            // Real-time listener handles local removal automatically
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Updates an existing calendar event in Firestore.
    ///
    /// Performs an optimistic local update immediately, with rollback on failure.
    /// Uses `merge: true` to avoid overwriting fields not included in the model.
    ///
    /// - Parameter event: The fully updated `CalendarEvent` model. Must have a non-nil `id`.
    func updateEvent(_ event: CalendarEvent) async {
        guard let id = event.id else { return }
        
        // FIX (SUGGESTION 3): Capture original for rollback
        let originalEvent = events.first { $0.id == id }
        
        // OPTIMISTIC UPDATE: Reflect changes in the local array immediately
        if let index = events.firstIndex(where: { $0.id == id }) {
            events[index] = event
        }
        
        do {
            try db.collection("events").document(id).setData(from: event, merge: true)
        } catch {
            errorMessage = error.localizedDescription
            
            // ROLLBACK: Restore original event on failure
            if let original = originalEvent,
               let index = events.firstIndex(where: { $0.id == id }) {
                events[index] = original
            }
        }
    }
    
    // MARK: - Query Helpers
    
    /// Returns filtered events and tasks for a specific date, respecting the member filter.
    ///
    /// Deduplication logic: Events with a `linkedTaskId` are excluded because their
    /// corresponding task will appear in the `filteredTasks` result. This prevents
    /// the same activity from appearing twice (once as an event, once as a task).
    ///
    /// Member filter: When `selectedMemberIds` is non-empty, only items involving
    /// those users are returned (event creator, participant, or task assignee).
    ///
    /// - Parameters:
    ///   - date: The date to query.
    ///   - tasks: The family's full task list (from TaskViewModel). Passed as parameter
    ///     to avoid coupling CalendarViewModel to TaskViewModel.
    /// - Returns: Tuple of filtered events and tasks for the given date.
    func eventsFor(date: Date, tasks: [FamilyTask]) -> (events: [CalendarEvent], tasks: [FamilyTask]) {
        // Filter events: exclude task-linked events, filter to matching date, apply member filter
        let filteredEvents = events
            .filter { event in
                // Exclude events linked to tasks — the task list shows them instead
                event.linkedTaskId == nil &&
                calendar.isDate(event.startDate, inSameDayAs: date)
            }
            .filter { event in
                // Member filter: show all if no filter, or check creator/participant membership
                selectedMemberIds.isEmpty ||
                selectedMemberIds.contains(event.createdBy) ||
                event.participants.contains(where: { selectedMemberIds.contains($0) })
            }
        
        // Filter tasks to this date, applying member filter
        // FIX (SUGGESTION 4): Use allAssignees for multi-assignee support
        let filteredTasks = tasks
            .filter { task in
                calendar.isDate(task.dueDate, inSameDayAs: date)
            }
            .filter { task in
                if selectedMemberIds.isEmpty { return true }
                
                // Check all assignees (multi-assignee support)
                let taskAssignees = task.allAssignees
                if taskAssignees.contains(where: { selectedMemberIds.contains($0) }) {
                    return true
                }
                
                // Also check task creator
                return selectedMemberIds.contains(task.assignedBy)
            }
        
        return (filteredEvents, filteredTasks)
    }
    
    /// Returns boolean indicators of whether a date has events and/or tasks.
    ///
    /// Used by the month grid to render dot indicators on dates with activity.
    /// Delegates to `eventsFor(date:tasks:)` for consistent filtering.
    ///
    /// - Parameters:
    ///   - date: The date to check.
    ///   - tasks: The family's task list.
    /// - Returns: Tuple of `(hasEvents, hasTasks)` booleans.
    func hasEvents(on date: Date, tasks: [FamilyTask]) -> (hasEvents: Bool, hasTasks: Bool) {
        let result = eventsFor(date: date, tasks: tasks)
        return (!result.events.isEmpty, !result.tasks.isEmpty)
    }
    
    // MARK: - Navigation Helpers
    
    /// Navigates to the previous calendar month.
    func previousMonth() {
        currentMonth = calendar.date(byAdding: .month, value: -1, to: currentMonth) ?? currentMonth
    }
    
    /// Navigates to the next calendar month.
    func nextMonth() {
        currentMonth = calendar.date(byAdding: .month, value: 1, to: currentMonth) ?? currentMonth
    }
    
    /// Generates the ordered array of dates (and nil padding) for the month grid.
    ///
    /// Algorithm:
    /// 1. Get the date interval for the current month.
    /// 2. Find the start of the first week that contains the month's first day.
    ///    This may be in the previous month (e.g., if the 1st falls on Wednesday).
    /// 3. Iterate day-by-day until the month ends AND the grid row is complete.
    ///    - Days before the month start → `nil` (renders as blank cells).
    ///    - Days after the month end (to fill the last row) → `nil`.
    ///    - Days within the month → `Date`.
    ///
    /// The result is always a multiple of 7 (complete weeks), suitable for
    /// a 7-column grid layout. Typically 28, 35, or 42 cells.
    ///
    /// - Returns: Array of optional Dates. `nil` entries are blank grid cells.
    func generateDaysInMonth() -> [Date?] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: currentMonth),
              let firstWeek = calendar.dateInterval(of: .weekOfMonth, for: monthInterval.start)
        else { return [] }
        
        var days: [Date?] = []
        var date = firstWeek.start // Start from the Sunday before the month begins
        
        // Continue until the month is done AND the current row is complete (% 7 == 0)
        while date < monthInterval.end || days.count % 7 != 0 {
            if date < monthInterval.start || date >= monthInterval.end {
                days.append(nil) // Pad with nil for days outside current month
            } else {
                days.append(date)
            }
            // FIX (SUGGESTION 5): Safe guard instead of force-unwrap
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: date) else { break }
            date = nextDate
        }
        
        return days
    }
    
    /// Formatted "Month YYYY" string for the calendar header (e.g., "February 2026").
    ///
    /// FIX (SUGGESTION 2): Cached and only recomputed when `currentMonth` changes.
    /// Uses static DateFormatter for performance.
    var monthYearString: String {
        if let cached = _cachedMonthYearString {
            return cached
        }
        let result = SharedFormatters.monthYear.string(from: currentMonth)
        _cachedMonthYearString = result
        return result
    }
    
    // MARK: - Cleanup
    
    /// Removes the real-time listener. Call when the calendar view disappears
    /// or when switching families.
    func stopListener() {
        eventsListener?.remove()
        eventsListener = nil
        currentFamilyId = nil
        loadedStartDate = nil
        loadedEndDate = nil
    }
}
