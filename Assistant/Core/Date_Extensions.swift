//
//  Date+Extensions.swift
//
//  Date formatting and utility extensions
//

import Foundation

extension Date {
    // MARK: - Formatters (cached for performance)
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mm a"
        return f
    }()
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d, yyyy"
        return f
    }()
    
    private static let shortDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()
    
    private static let dayOfWeekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()
    
    private static let dayNumberFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()
    
    private static let monthNameFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f
    }()
    
    private static let habitDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    
    // MARK: - Computed Properties
    var formattedTime: String {
        Self.timeFormatter.string(from: self)
    }
    
    var formattedDate: String {
        Self.dateFormatter.string(from: self)
    }
    
    var formattedShortDate: String {
        Self.shortDateFormatter.string(from: self)
    }
    
    var dayOfWeek: String {
        Self.dayOfWeekFormatter.string(from: self)
    }
    
    var dayNumber: String {
        Self.dayNumberFormatter.string(from: self)
    }
    
    var monthName: String {
        Self.monthNameFormatter.string(from: self)
    }
    
    var habitDateString: String {
        Self.habitDateFormatter.string(from: self)
    }
    
    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }
    
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(self)
    }
    
    var isYesterday: Bool {
        Calendar.current.isDateInYesterday(self)
    }
    
    // MARK: - Time Ago
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
    
    // MARK: - Calendar Helpers
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }
    
    var endOfDay: Date {
        Calendar.current.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay)!
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
