//
//  Date+Extensions.swift
//
//  Date formatting and utility extensions.
//  Uses SharedFormatters for performance (single allocation per format).
//

import Foundation

extension Date {
    
    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Formatted Strings (using SharedFormatters)
    // ═══════════════════════════════════════════════════════════════════════
    
    /// "3:30 PM"
    var formattedTime: String {
        SharedFormatters.time.string(from: self)
    }
    
    /// "Mar 15, 2026"
    var formattedDate: String {
        SharedFormatters.mediumDate.string(from: self)
    }
    
    /// "Mar 15"
    var formattedShortDate: String {
        SharedFormatters.monthDay.string(from: self)
    }
    
    /// "Mon"
    var dayOfWeek: String {
        SharedFormatters.shortWeekday.string(from: self)
    }
    
    /// "15"
    var dayNumber: String {
        SharedFormatters.dayOfMonth.string(from: self)
    }
    
    /// "Mar"
    var monthName: String {
        SharedFormatters.shortMonth.string(from: self)
    }
    
    /// "2026-03-15" (ISO format for storage/API)
    var habitDateString: String {
        SharedFormatters.isoDate.string(from: self)
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Date Checks
    // ═══════════════════════════════════════════════════════════════════════
    
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }
    
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Time Ago
    // ═══════════════════════════════════════════════════════════════════════
    
    func timeAgo() -> String {
        let now = Date()
        let components = Calendar.current.dateComponents(
            [.year, .month, .weekOfYear, .day, .hour, .minute, .second],
            from: self,
            to: now
        )
        
        if let years = components.year, years > 0 {
            return years == 1 ? "1 year ago" : "\(years) years ago"
        }
        if let months = components.month, months > 0 {
            return months == 1 ? "1 month ago" : "\(months) months ago"
        }
        if let weeks = components.weekOfYear, weeks > 0 {
            return weeks == 1 ? "1 week ago" : "\(weeks) weeks ago"
        }
        if let days = components.day, days > 0 {
            return days == 1 ? "1 day ago" : "\(days) days ago"
        }
        if let hours = components.hour, hours > 0 {
            return hours == 1 ? "1 hour ago" : "\(hours) hours ago"
        }
        if let minutes = components.minute, minutes > 0 {
            return minutes == 1 ? "1 minute ago" : "\(minutes) minutes ago"
        }
        if let seconds = components.second, seconds > 5 {
            return "\(seconds) seconds ago"
        }
        return "Just now"
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // MARK: - Calendar Helpers
    // ═══════════════════════════════════════════════════════════════════════
    
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    var endOfDay: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay)
            ?? startOfDay.addingTimeInterval(86399) // Fallback: 23:59:59
    }
    
    var startOfWeek: Date {
        let components = Calendar.current.dateComponents([.yearForWeekOfYear, .weekOfYear], from: self)
        return Calendar.current.date(from: components) ?? self
    }
    
    var startOfMonth: Date {
        let components = Calendar.current.dateComponents([.year, .month], from: self)
        return Calendar.current.date(from: components) ?? self
    }
    
    var startOfYear: Date {
        let components = Calendar.current.dateComponents([.year], from: self)
        return Calendar.current.date(from: components) ?? self
    }
    
    func adding(days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
    
    func adding(weeks: Int) -> Date {
        Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: self) ?? self
    }
    
    func adding(months: Int) -> Date {
        Calendar.current.date(byAdding: .month, value: months, to: self) ?? self
    }
    
    func isSameDay(as other: Date) -> Bool {
        Calendar.current.isDate(self, inSameDayAs: other)
    }
    
    func isSameMonth(as other: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.component(.year, from: self) == calendar.component(.year, from: other) &&
        calendar.component(.month, from: self) == calendar.component(.month, from: other)
    }
    
    // Convenience method for adding days
    func addingDays(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: days, to: self) ?? self
    }
}
