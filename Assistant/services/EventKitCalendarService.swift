//
//  EventKitCalendarService.swift
//
//  EventKit integration for iOS Calendar sync (Google Calendar, Outlook, iCloud, etc.)
//  Includes holiday detection from subscribed calendars
//
//  Key Decisions:
//  - Uses EKEventStore for unified calendar access
//  - Detects holiday calendars via subscription type + title matching
//  - Caches events to avoid repeated queries
//  - Async/await + @MainActor for thread-safe UI updates

import Foundation
import EventKit
import SwiftUI

// MARK: - External Calendar Event Model
/// Represents an event fetched from iOS EventKit (iCloud, Google, Outlook, etc.)
struct ExternalCalendarEvent: Identifiable, Hashable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let isAllDay: Bool
    let calendarTitle: String
    let calendarIdentifier: String
    let calendarColor: Color
    let location: String?
    let notes: String?
    let isHoliday: Bool
    
    /// Source type for disambiguation
    enum Source: String {
        case eventKit = "eventkit"
        case firestore = "firestore"
    }
    let source: Source
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ExternalCalendarEvent, rhs: ExternalCalendarEvent) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Calendar Info (for picker UI)
struct CalendarInfo: Identifiable, Hashable {
    let id: String
    let title: String
    let color: Color
    let source: String
    let isWritable: Bool
    let isHolidayCalendar: Bool
}

// MARK: - Authorization Status
enum CalendarAuthStatus {
    case notDetermined
    case authorized
    case denied
    case restricted
    
    var canAccess: Bool {
        self == .authorized
    }
}

// MARK: - EventKit Calendar Service
@MainActor
@Observable
final class EventKitCalendarService {
    static let shared = EventKitCalendarService()
    
    // MARK: - Published State
    private(set) var authStatus: CalendarAuthStatus = .notDetermined
    private(set) var events: [ExternalCalendarEvent] = []
    private(set) var holidayEvents: [ExternalCalendarEvent] = []
    private(set) var availableCalendars: [CalendarInfo] = []
    private(set) var isLoading = false
    var errorMessage: String?
    
    // MARK: - Private
    private let eventStore = EKEventStore()
    private var cachedDateRange: (start: Date, end: Date)?
    
    /// Titles that indicate a holiday calendar (case-insensitive)
    private let holidayKeywords = [
        "holiday", "holidays", "feiertage", "fÃªtes", "festivos",
        "dÃ­as festivos", "vacaciones", "ç¥æ—¥", "èŠ‚å‡æ—¥", "å…¬çœ¾å‡æœŸ"
    ]
    
    private init() {
        updateAuthStatus()
    }
    
    // MARK: - Authorization
    
    /// Updates the current authorization status
    private func updateAuthStatus() {
        let status: EKAuthorizationStatus
        if #available(iOS 17.0, *) {
            status = EKEventStore.authorizationStatus(for: .event)
        } else {
            status = EKEventStore.authorizationStatus(for: .event)
        }
        
        switch status {
        case .notDetermined:
            authStatus = .notDetermined
        case .fullAccess, .authorized:
            authStatus = .authorized
        case .denied:
            authStatus = .denied
        case .restricted:
            authStatus = .restricted
        case .writeOnly:
            // writeOnly still allows creating events but not reading
            authStatus = .denied
        @unknown default:
            authStatus = .denied
        }
    }
    
    /// Request calendar access with async/await
    /// Returns true if access was granted
    @discardableResult
    func requestAccessIfNeeded() async -> Bool {
        updateAuthStatus()
        
        if authStatus == .authorized {
            return true
        }
        
        if authStatus == .notDetermined {
            do {
                let granted: Bool
                if #available(iOS 17.0, *) {
                    granted = try await eventStore.requestFullAccessToEvents()
                } else {
                    granted = try await eventStore.requestAccess(to: .event)
                }
                
                updateAuthStatus()
                return granted
            } catch {
                errorMessage = "Calendar access error: \(error.localizedDescription)"
                updateAuthStatus()
                return false
            }
        }
        
        return false
    }
    
    // MARK: - Load Events
    
    /// Loads events from all calendars within the given date range
    /// - Parameters:
    ///   - startDate: Start of the range (defaults to today)
    ///   - endDate: End of the range (defaults to 60 days from now)
    func loadEvents(from startDate: Date = Date(), to endDate: Date? = nil) async {
        if authStatus != .authorized {
            let granted = await requestAccessIfNeeded()
            if !granted { return }
        }
        
        isLoading = true
        errorMessage = nil
        
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: startDate)
        let end = endDate ?? calendar.date(byAdding: .day, value: 60, to: start) ?? start
        
        // Cache check - avoid refetching if same range
        if let cached = cachedDateRange,
           cached.start == start && cached.end == end && !events.isEmpty {
            isLoading = false
            return
        }
        
        // PERF-1: Move heavy EventKit work to background thread
        // EKEventStore is thread-safe for read operations
        let result = await Task.detached(priority: .userInitiated) { [eventStore, holidayKeywords] () -> (
            allEvents: [ExternalCalendarEvent],
            holidays: [ExternalCalendarEvent],
            calendars: [CalendarInfo]
        ) in
            // Get all calendars and identify holiday calendars
            let allCalendars = eventStore.calendars(for: .event)
            let holidayCalendarIds = Set(allCalendars.filter { cal in
                // Check if calendar title contains holiday keywords
                let lowercasedTitle = cal.title.lowercased()
                return holidayKeywords.contains { lowercasedTitle.contains($0) }
                    || cal.type == .subscription
                    && lowercasedTitle.contains("holiday")
            }.map { $0.calendarIdentifier })
            
            // Build calendar info list
            let calendarInfos = allCalendars.map { cal in
                CalendarInfo(
                    id: cal.calendarIdentifier,
                    title: cal.title,
                    color: Color(cgColor: cal.cgColor),
                    source: cal.source.title,
                    isWritable: cal.allowsContentModifications,
                    isHolidayCalendar: holidayCalendarIds.contains(cal.calendarIdentifier)
                )
            }.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
            
            // Create predicate for the date range
            let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: nil)
            let ekEvents = eventStore.events(matching: predicate)
            
            // Convert to our model
            var allEvents: [ExternalCalendarEvent] = []
            var holidays: [ExternalCalendarEvent] = []
            
            for ekEvent in ekEvents {
                let isHoliday = holidayCalendarIds.contains(ekEvent.calendar.calendarIdentifier)
                
                let event = ExternalCalendarEvent(
                    id: ekEvent.eventIdentifier ?? UUID().uuidString,
                    title: ekEvent.title ?? "Untitled",
                    startDate: ekEvent.startDate,
                    endDate: ekEvent.endDate,
                    isAllDay: ekEvent.isAllDay,
                    calendarTitle: ekEvent.calendar.title,
                    calendarIdentifier: ekEvent.calendar.calendarIdentifier,
                    calendarColor: Color(cgColor: ekEvent.calendar.cgColor),
                    location: ekEvent.location,
                    notes: ekEvent.notes,
                    isHoliday: isHoliday,
                    source: .eventKit
                )
                
                allEvents.append(event)
                if isHoliday {
                    holidays.append(event)
                }
            }
            
            return (allEvents, holidays, calendarInfos)
        }.value
        
        // PERF-2: Update on main thread - check if data actually changed
        let newEventIDs = Set(result.allEvents.map { $0.id })
        let oldEventIDs = Set(events.map { $0.id })
        
        if newEventIDs != oldEventIDs || availableCalendars.count != result.calendars.count {
            // Batch all updates together
            events = result.allEvents
            holidayEvents = result.holidays
            availableCalendars = result.calendars
        }
        
        cachedDateRange = (start, end)
        isLoading = false
    }
    
    /// Refreshes events for the cached date range
    func refreshEvents() async {
        cachedDateRange = nil  // Force refresh
        await loadEvents()
    }
    
    // MARK: - Holiday Lookup
    
    /// Returns holidays for a specific date
    /// Used by CalendarView to show holiday indicators and details
    func holidays(for date: Date) -> [ExternalCalendarEvent] {
        let calendar = Calendar.current
        let targetDay = calendar.startOfDay(for: date)
        
        return holidayEvents.filter { holiday in
            let holidayDay = calendar.startOfDay(for: holiday.startDate)
            return calendar.isDate(holidayDay, inSameDayAs: targetDay)
        }
    }
    
    // MARK: - Helper to check if calendar is holiday calendar
    
    private func isHolidayCalendar(_ calendar: EKCalendar) -> Bool {
        let lowercasedTitle = calendar.title.lowercased()
        return holidayKeywords.contains { lowercasedTitle.contains($0) }
            || (calendar.type == .subscription && lowercasedTitle.contains("holiday"))
    }
    
    // MARK: - Create Event in iOS Calendar
    
    /// Creates an event in the user's iOS calendar
    /// - Parameters:
    ///   - title: Event title
    ///   - startDate: Start date/time
    ///   - endDate: End date/time
    ///   - isAllDay: Whether it's an all-day event
    ///   - calendarIdentifier: Optional specific calendar ID to use
    /// - Returns: The created event's identifier, or nil if failed
    func createEvent(
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool = false,
        notes: String? = nil,
        calendarIdentifier: String? = nil
    ) async -> String? {
        guard authStatus == .authorized else {
            errorMessage = "Calendar access not authorized"
            return nil
        }
        
        let ekEvent = EKEvent(eventStore: eventStore)
        ekEvent.title = title
        ekEvent.startDate = startDate
        ekEvent.endDate = endDate
        ekEvent.isAllDay = isAllDay
        ekEvent.notes = notes
        
        // Set calendar
        if let calId = calendarIdentifier,
           let calendar = eventStore.calendar(withIdentifier: calId) {
            ekEvent.calendar = calendar
        } else {
            ekEvent.calendar = eventStore.defaultCalendarForNewEvents
        }
        
        do {
            try eventStore.save(ekEvent, span: .thisEvent)
            
            // Refresh events to include the new one
            await refreshEvents()
            
            return ekEvent.eventIdentifier
        } catch {
            errorMessage = "Failed to create event: \(error.localizedDescription)"
            return nil
        }
    }
    
    /// Deletes an event from iOS calendar
    func deleteEvent(identifier: String) async -> Bool {
        guard authStatus == .authorized else { return false }
        
        guard let ekEvent = eventStore.event(withIdentifier: identifier) else {
            return false
        }
        
        do {
            try eventStore.remove(ekEvent, span: .thisEvent)
            await refreshEvents()
            return true
        } catch {
            errorMessage = "Failed to delete event: \(error.localizedDescription)"
            return false
        }
    }
}

// MARK: - Upcoming Events Builder (optimized)

/// Builder for upcoming events combining multiple sources
enum UpcomingEventsBuilder {
    
    /// Builds a sorted list of upcoming items from various sources
    /// - PERF: This is a pure function - can be called from view but should be cached
    static func build(
        familyMembers: [FamilyUser],
        eventKitHolidays: [ExternalCalendarEvent],
        eventKitEvents: [ExternalCalendarEvent],
        firestoreEvents: [CalendarEvent],
        maxDays: Int = 60,
        includeEventKitRegularEvents: Bool = false
    ) -> [UpcomingItem] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        var items: [UpcomingItem] = []
        
        // 1. Add birthdays from family members
        for member in familyMembers {
            let birthday = member.dateOfBirth
            
            var nextBirthdayComponents = calendar.dateComponents([.month, .day], from: birthday)
            nextBirthdayComponents.year = calendar.component(.year, from: today)
            
            if var nextBirthday = calendar.date(from: nextBirthdayComponents) {
                if nextBirthday < today {
                    nextBirthdayComponents.year = calendar.component(.year, from: today) + 1
                    nextBirthday = calendar.date(from: nextBirthdayComponents) ?? nextBirthday
                }
                
                let daysUntil = calendar.dateComponents([.day], from: today, to: nextBirthday).day ?? 0
                
                if daysUntil >= 0 && daysUntil <= maxDays {
                    let birthYear = calendar.component(.year, from: birthday)
                    let nextYear = calendar.component(.year, from: nextBirthday)
                    let turningAge = nextYear - birthYear
                    
                    items.append(UpcomingItem(
                        id: "birthday_\(member.id ?? UUID().uuidString)",
                        title: "\(member.displayName)'s Birthday",
                        subtitle: "Turning \(turningAge)",
                        date: nextBirthday,
                        daysUntil: daysUntil,
                        icon: "gift.fill",
                        color: Color.accentPrimary,
                        type: .birthday,
                        source: .birthday(memberId: member.id ?? "")
                    ))
                }
            }
        }
        
        // 2. Add holidays from EventKit
        for holiday in eventKitHolidays {
            let eventDate = calendar.startOfDay(for: holiday.startDate)
            let daysUntil = calendar.dateComponents([.day], from: today, to: eventDate).day ?? 0
            
            if daysUntil >= 0 && daysUntil <= maxDays {
                items.append(UpcomingItem(
                    id: "eventkit_holiday_\(holiday.id)",
                    title: holiday.title,
                    subtitle: holiday.calendarTitle,
                    date: holiday.startDate,
                    daysUntil: daysUntil,
                    icon: holidayIcon(for: holiday.title),
                    color: holiday.calendarColor,
                    type: .holiday,
                    source: .eventKit(eventId: holiday.id)
                ))
            }
        }
        
        // 3. Optionally add regular EventKit events
        if includeEventKitRegularEvents {
            for event in eventKitEvents where !event.isHoliday {
                let eventDate = calendar.startOfDay(for: event.startDate)
                let daysUntil = calendar.dateComponents([.day], from: today, to: eventDate).day ?? 0
                
                if daysUntil >= 0 && daysUntil <= maxDays {
                    items.append(UpcomingItem(
                        id: "eventkit_event_\(event.id)",
                        title: event.title,
                        subtitle: event.calendarTitle,
                        date: event.startDate,
                        daysUntil: daysUntil,
                        icon: "calendar",
                        color: event.calendarColor,
                        type: .eventkitEvent,
                        source: .eventKit(eventId: event.id)
                    ))
                }
            }
        }
        
        // 4. Add Firestore events
        for event in firestoreEvents {
            let eventDate = calendar.startOfDay(for: event.startDate)
            let daysUntil = calendar.dateComponents([.day], from: today, to: eventDate).day ?? 0
            
            if daysUntil >= 0 && daysUntil <= maxDays {
                items.append(UpcomingItem(
                    id: "firestore_event_\(event.id ?? UUID().uuidString)",
                    title: event.title,
                    subtitle: event.isAllDay ? "All Day" : event.startDate.formattedTime,
                    date: event.startDate,
                    daysUntil: daysUntil,
                    icon: "calendar.badge.clock",
                    color: Color(hex: event.color),
                    type: .firestoreEvent,
                    source: .firestore(eventId: event.id ?? "")
                ))
            }
        }
        
        // Sort by days until, then by title
        return items.sorted {
            if $0.daysUntil != $1.daysUntil {
                return $0.daysUntil < $1.daysUntil
            }
            return $0.title < $1.title
        }
    }
    
    /// Returns an appropriate icon for a holiday title
    private static func holidayIcon(for title: String) -> String {
        let lowercased = title.lowercased()
        
        if lowercased.contains("christmas") { return "gift.fill" }
        if lowercased.contains("thanksgiving") { return "leaf.fill" }
        if lowercased.contains("easter") { return "hare.fill" }
        if lowercased.contains("halloween") { return "moon.stars.fill" }
        if lowercased.contains("valentine") { return "heart.fill" }
        if lowercased.contains("independence") || lowercased.contains("july 4") { return "flag.fill" }
        if lowercased.contains("new year") { return "sparkles" }
        if lowercased.contains("memorial") { return "flag.fill" }
        if lowercased.contains("labor") { return "hammer.fill" }
        if lowercased.contains("mother") { return "heart.fill" }
        if lowercased.contains("father") { return "heart.fill" }
        if lowercased.contains("chinese") || lowercased.contains("lunar") { return "flame.fill" }
        
        return "star.fill"
    }
    
    // MARK: - Build UpcomingEvents Directly (Single Model)
    
    /// Builds a filtered and sorted list of `UpcomingEvent` for the given month.
    /// This is a single-pass alternative to `build()` + manual mapping, eliminating
    /// the intermediate `UpcomingItem` model and ~40 lines of boilerplate type mapping.
    ///
    /// Sorting: birthdays first, then by date ascending.
    static func buildEvents(
        familyMembers: [FamilyUser],
        eventKitHolidays: [ExternalCalendarEvent],
        eventKitEvents: [ExternalCalendarEvent],
        firestoreEvents: [CalendarEvent],
        month: Date = Date(),
        maxDays: Int = 60,
        includeEventKitRegularEvents: Bool = false
    ) -> [UpcomingEvent] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let targetMonth = calendar.component(.month, from: month)
        let targetYear = calendar.component(.year, from: month)
        var events: [UpcomingEvent] = []
        
        /// Helper: only include events within maxDays AND in the target month.
        func inRange(_ date: Date) -> (daysUntil: Int, pass: Bool) {
            let daysUntil = calendar.dateComponents([.day], from: today, to: date).day ?? 0
            guard daysUntil >= 0 && daysUntil <= maxDays else { return (daysUntil, false) }
            let m = calendar.component(.month, from: date)
            let y = calendar.component(.year, from: date)
            guard m == targetMonth && y == targetYear else { return (daysUntil, false) }
            return (daysUntil, true)
        }
        
        // 1. Birthdays
        for member in familyMembers {
            let birthday = member.dateOfBirth
            var components = calendar.dateComponents([.month, .day], from: birthday)
            components.year = calendar.component(.year, from: today)
            
            if var nextBirthday = calendar.date(from: components) {
                if nextBirthday < today {
                    components.year = calendar.component(.year, from: today) + 1
                    nextBirthday = calendar.date(from: components) ?? nextBirthday
                }
                let (daysUntil, pass) = inRange(nextBirthday)
                if pass {
                    let turningAge = calendar.component(.year, from: nextBirthday) - calendar.component(.year, from: birthday)
                    events.append(UpcomingEvent(
                        id: "birthday_\(member.id ?? UUID().uuidString)",
                        title: "\(member.displayName)'s Birthday",
                        subtitle: "Turning \(turningAge)",
                        date: nextBirthday,
                        daysUntil: daysUntil,
                        icon: "gift.fill",
                        color: Color.accentPrimary,
                        type: .birthday,
                        source: .birthday(memberId: member.id ?? "")
                    ))
                }
            }
        }
        
        // 2. Holidays from EventKit
        for holiday in eventKitHolidays {
            let eventDate = calendar.startOfDay(for: holiday.startDate)
            let (daysUntil, pass) = inRange(eventDate)
            if pass {
                events.append(UpcomingEvent(
                    id: "eventkit_holiday_\(holiday.id)",
                    title: holiday.title,
                    subtitle: holiday.calendarTitle,
                    date: holiday.startDate,
                    daysUntil: daysUntil,
                    icon: holidayIcon(for: holiday.title),
                    color: holiday.calendarColor,
                    type: .holiday,
                    source: .eventKit(eventId: holiday.id)
                ))
            }
        }
        
        // 3. Regular EventKit events (optional)
        if includeEventKitRegularEvents {
            for event in eventKitEvents where !event.isHoliday {
                let eventDate = calendar.startOfDay(for: event.startDate)
                let (daysUntil, pass) = inRange(eventDate)
                if pass {
                    events.append(UpcomingEvent(
                        id: "eventkit_event_\(event.id)",
                        title: event.title,
                        subtitle: event.calendarTitle,
                        date: event.startDate,
                        daysUntil: daysUntil,
                        icon: "calendar",
                        color: event.calendarColor,
                        type: .event,
                        source: .eventKit(eventId: event.id)
                    ))
                }
            }
        }
        
        // 4. Firestore events
        for event in firestoreEvents {
            let eventDate = calendar.startOfDay(for: event.startDate)
            let (daysUntil, pass) = inRange(eventDate)
            if pass {
                events.append(UpcomingEvent(
                    id: "firestore_event_\(event.id ?? UUID().uuidString)",
                    title: event.title,
                    subtitle: event.isAllDay ? "allDay" : event.startDate.formattedTime,
                    date: event.startDate,
                    daysUntil: daysUntil,
                    icon: "calendar.badge.clock",
                    color: Color(hex: event.color),
                    type: .event,
                    source: .firestore(eventId: event.id ?? "")
                ))
            }
        }
        
        // Sort: birthdays first, then by date
        return events.sorted { lhs, rhs in
            if lhs.type == .birthday && rhs.type != .birthday { return true }
            if lhs.type != .birthday && rhs.type == .birthday { return false }
            return lhs.date < rhs.date
        }
    }
}

// MARK: - UpcomingItem Model

struct UpcomingItem: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let date: Date
    let daysUntil: Int
    let icon: String
    let color: Color
    let type: UpcomingItemType
    let source: UpcomingItemSource
    
    enum UpcomingItemType {
        case birthday
        case holiday
        case eventkitEvent
        case firestoreEvent
    }
    
    enum UpcomingItemSource {
        case birthday(memberId: String)
        case eventKit(eventId: String)
        case firestore(eventId: String)
        case hardcodedHoliday
    }
}
