
//  DateFormatters.swift
//  FamilyHub
//
//  TRIM-LIST 2.4: Shared DateFormatter instances.
//  Consolidates monthYearFormatter (was duplicated in CalendarViewModel,
//  AgendaDataCache, TodayTasksView) and fullDateFormatter (was duplicated
//  in HomeView, TodayTasksView, EventDetailView) into a single allocation.
//
//  DateFormatter is expensive to create — each allocation parses locale
//  data and builds an ICU pattern. Keeping one `static let` per format
//  string guarantees a single allocation for the lifetime of the process.
//

import Foundation

enum SharedFormatters {
    
    // MARK: - Month + Year  ("March 2026")
    
    /// "MMMM yyyy" – used by CalendarView, MonthGridOverlay, AgendaDataCache,
    /// CalendarViewModel, TodayTasksView.
    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMMM yyyy"
        return f
    }()
    
    // MARK: - Full Weekday + Date  ("Saturday, March 1")
    
    /// "EEEE, MMMM d" – used by HomeView header, TodayTasksView,
    /// EventDetailView.
    static let fullDate: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()
}
