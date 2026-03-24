
//  DateFormatters.swift
//  
//
//  PERFORMANCE: Shared DateFormatter instances.
//
//  DateFormatter is expensive to create — each allocation parses locale
//  data and builds an ICU pattern. Keeping one `static let` per format
//  string guarantees a single allocation for the lifetime of the process.
//
//  USAGE:
//    SharedFormatters.time.string(from: date)     // "3:30 PM"
//    SharedFormatters.monthDay.string(from: date) // "Mar 15"
//    date.formatted(with: .isoDate)               // "2026-03-15"
//
//  THREAD SAFETY:
//    DateFormatter is NOT thread-safe for mutation, but our static instances
//    are only read after initialization, so they're safe for concurrent reads.
//

import Foundation

// MARK: - Shared Formatters

enum SharedFormatters {
    
    // ═══════════════════════════════════════════════════════════════════════
    // MARK: Time Formats
    // ═══════════════════════════════════════════════════════════════════════
    
    /// "h:mm a" → "3:30 PM"
    /// Used by: EventDetailView, EditEventView, AddEventView, TodayTasksView, Date_Extensions
    static let time: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()
    
    // ═══════════════════════════════════════════════════════════════════════
    // MARK: Day Formats
    // ═══════════════════════════════════════════════════════════════════════
    
    /// "d" → "15"
    /// Used by: TodayTasksView, Date_Extensions
    static let dayOfMonth: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()
    
    /// "EEE" or "E" → "Mon"
    /// Used by: TodayTasksView, WeekHabitView, Date_Extensions, HabitTrackerView
    static let shortWeekday: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()
    
    // ═══════════════════════════════════════════════════════════════════════
    // MARK: Month Formats
    // ═══════════════════════════════════════════════════════════════════════
    
    /// "MMM" → "Mar"
    /// Used by: YearHabitView, CalendarCells, Date_Extensions
    static let shortMonth: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()
    
    /// "MMMM" → "March"
    /// Used by: FamilyView
    static let fullMonth: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM"
        return f
    }()
    
    /// "MMMM yyyy" → "March 2026"
    /// Used by: CalendarView, MonthGridOverlay, AgendaDataCache, CalendarViewModel, TodayTasksView
    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()
    
    // ═══════════════════════════════════════════════════════════════════════
    // MARK: Date Formats (Day + Month)
    // ═══════════════════════════════════════════════════════════════════════
    
    /// "MMM d" → "Mar 15"
    /// Used by: CalendarCards, EditEventView, AddEventView, RewardWalletView, Date_Extensions
    static let monthDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
    
    /// "EEE, MMM d" → "Mon, Mar 15"
    /// Used by: AddTaskView
    static let weekdayMonthDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()
    
    /// "EEE d" → "Mon 15"
    /// Used by: AddEventView
    static let weekdayDay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d"
        return f
    }()
    
    /// "EEEE, MMMM d" → "Monday, March 15"
    /// Used by: HomeView header, TodayTasksView, EventDetailView
    static let fullDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()
    
    /// "MMM d, yyyy" → "Mar 15, 2026"
    /// Used by: Date_Extensions
    static let mediumDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()
    
    // ═══════════════════════════════════════════════════════════════════════
    // MARK: Year Formats
    // ═══════════════════════════════════════════════════════════════════════
    
    /// "yyyy" → "2026"
    /// Used by: MemberDetailView, FamilyView, EditProfileSheet
    static let year: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy"
        return f
    }()
    
    // ═══════════════════════════════════════════════════════════════════════
    // MARK: ISO / API Formats
    // ═══════════════════════════════════════════════════════════════════════
    
    /// "yyyy-MM-dd" → "2026-03-15"
    /// Used by: TaskViewModel, HabitViewModel, FamilyView, AgendaDataCache, Date_Extensions
    static let isoDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX") // Ensure consistent parsing
        return f
    }()
    
    /// "yyyy-MM" → "2026-03"
    /// Used by: AgendaDataCache
    static let yearMonth: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    /// ISO8601 full format → "2026-03-15T14:30:00Z"
    /// Used by: HabitTrackerView (API calls)
    static let iso8601: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        return f
    }()
}

// MARK: - Date Extension for Convenient Formatting

extension Date {
    
    /// Format date using a shared formatter.
    ///
    /// Usage:
    /// ```swift
    /// date.formatted(with: .time)      // "3:30 PM"
    /// date.formatted(with: .monthDay)  // "Mar 15"
    /// date.formatted(with: .fullDate)  // "Monday, March 15"
    /// ```
    func formatted(with formatter: DateFormatter) -> String {
        formatter.string(from: self)
    }
    
    /// Format date using the ISO8601 formatter.
    func formattedISO8601() -> String {
        SharedFormatters.iso8601.string(from: self)
    }
    
    // MARK: - Convenience Properties
    
    /// "3:30 PM"
    var timeString: String { formatted(with: SharedFormatters.time) }
    
    /// "15" (day of month)
    var dayString: String { formatted(with: SharedFormatters.dayOfMonth) }
    
    /// "Mon" (short weekday)
    var weekdayString: String { formatted(with: SharedFormatters.shortWeekday) }
    
    /// "Mar" (short month)
    var shortMonthString: String { formatted(with: SharedFormatters.shortMonth) }
    
    /// "March" (full month)
    var fullMonthString: String { formatted(with: SharedFormatters.fullMonth) }
    
    /// "March 2026"
    var monthYearString: String { formatted(with: SharedFormatters.monthYear) }
    
    /// "Mar 15"
    var monthDayString: String { formatted(with: SharedFormatters.monthDay) }
    
    /// "Monday, March 15"
    var fullDateString: String { formatted(with: SharedFormatters.fullDate) }
    
    /// "2026-03-15" (ISO date for API/storage)
    var isoDateString: String { formatted(with: SharedFormatters.isoDate) }
    
    /// "2026" (year only)
    var yearString: String { formatted(with: SharedFormatters.year) }
}

// MARK: - Migration Guide
//
// BEFORE (creates new formatter each call — expensive!):
//   let formatter = DateFormatter()
//   formatter.dateFormat = "h:mm a"
//   return formatter.string(from: date)
//
// AFTER (uses shared formatter — single allocation):
//   return SharedFormatters.time.string(from: date)
//
// OR (using Date extension):
//   return date.timeString
//
// PERFORMANCE:
//   DateFormatter creation: ~0.5-2ms per instance
//   SharedFormatter access: ~0.001ms (just a pointer lookup)
//   With 40+ inline creations per screen refresh, this saves 20-80ms

