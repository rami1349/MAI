
//  AgendaDataCache.swift
//  FamilyHub
//
//  Lightweight per-day cache for calendar agenda items.
//  Prevents repeated O(n) filtering on every SwiftUI body evaluation.
//
//  Cache invalidation: source fingerprint (hash of event IDs + task IDs + member filter).
//  When the fingerprint changes, the entire cache is rebuilt for the loaded month.
//

import Foundation
import SwiftUI

// MARK: - Day Agenda (cached result for a single day)

struct DayAgenda: Equatable {
    let events: [CalendarEvent]
    let tasks: [FamilyTask]
    
    var totalCount: Int { events.count + tasks.count }
    var isEmpty: Bool { events.isEmpty && tasks.isEmpty }
    
    static let empty = DayAgenda(events: [], tasks: [])
    
    static func == (lhs: DayAgenda, rhs: DayAgenda) -> Bool {
        lhs.events.map(\.id) == rhs.events.map(\.id) &&
        lhs.tasks.map(\.id) == rhs.tasks.map(\.id)
    }
}

// MARK: - Agenda Data Cache

/// Caches filtered day agendas for an entire month so that
/// tapping between days in the week strip is instant (no re-filtering).
@MainActor
@Observable
final class AgendaDataCache {
    
    // MARK: - Published
    private(set) var dayAgendas: [String: DayAgenda] = [:]
    private(set) var loadedMonthKey: String = ""
    
    // MARK: - Private
    private let calendar = Calendar.current
    private var lastFingerprint: Int = 0
    
    // MARK: - Static Formatters
    private static let keyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    
    static let monthKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
    // MARK: - Key Helpers
    
    static func dayKey(for date: Date) -> String {
        keyFormatter.string(from: date)
    }
    
    static func monthKey(for date: Date) -> String {
        monthKeyFormatter.string(from: date)
    }
    
    // MARK: - Cache Lookup
    
    func agenda(for date: Date) -> DayAgenda {
        dayAgendas[Self.dayKey(for: date)] ?? .empty
    }
    
    func itemCount(for date: Date) -> Int {
        agenda(for: date).totalCount
    }
    
    /// Returns a dictionary of dayKey → itemCount for the given dates.
    /// Used by WeekStripView to show badges without per-day lookups in body.
    func itemCounts(for dates: [Date]) -> [String: Int] {
        var result: [String: Int] = [:]
        for date in dates {
            let key = Self.dayKey(for: date)
            if let agenda = dayAgendas[key], agenda.totalCount > 0 {
                result[key] = agenda.totalCount
            }
        }
        return result
    }
    
    // MARK: - Rebuild Cache
    
    /// Rebuilds the cache for the month containing `anchorDate`.
    /// Only does work if the source data fingerprint has changed.
    func rebuild(
        anchorDate: Date,
        events: [CalendarEvent],
        tasks: [FamilyTask],
        selectedMemberIds: Set<String>
    ) {
        let fingerprint = computeFingerprint(events: events, tasks: tasks, memberIds: selectedMemberIds)
        let newMonthKey = Self.monthKey(for: anchorDate)
        
        guard fingerprint != lastFingerprint || newMonthKey != loadedMonthKey else { return }
        lastFingerprint = fingerprint
        loadedMonthKey = newMonthKey
        
        guard let monthInterval = calendar.dateInterval(of: .month, for: anchorDate) else { return }
        
        // Pre-filter to month (single pass each)
        let monthEvents = events.filter { event in
            event.linkedTaskId == nil &&
            event.startDate >= monthInterval.start &&
            event.startDate < monthInterval.end
        }
        let monthTasks = tasks.filter { task in
            task.dueDate >= monthInterval.start &&
            task.dueDate < monthInterval.end
        }
        
        // Build per-day lookup
        var newAgendas: [String: DayAgenda] = [:]
        var date = monthInterval.start
        
        while date < monthInterval.end {
            let key = Self.dayKey(for: date)
            
            let dayEvents = monthEvents.filter { event in
                calendar.isDate(event.startDate, inSameDayAs: date)
            }.filter { event in
                selectedMemberIds.isEmpty ||
                selectedMemberIds.contains(event.createdBy) ||
                event.participants.contains(where: { selectedMemberIds.contains($0) })
            }
            
            let dayTasks = monthTasks.filter { task in
                calendar.isDate(task.dueDate, inSameDayAs: date)
            }.filter { task in
                if selectedMemberIds.isEmpty { return true }
                if let assignedTo = task.assignedTo {
                    return selectedMemberIds.contains(assignedTo)
                }
                return selectedMemberIds.contains(task.assignedBy)
            }
            
            if !dayEvents.isEmpty || !dayTasks.isEmpty {
                newAgendas[key] = DayAgenda(events: dayEvents, tasks: dayTasks)
            }
            
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }
        
        dayAgendas = newAgendas
    }
    
    // MARK: - Fingerprint
    
    private func computeFingerprint(
        events: [CalendarEvent],
        tasks: [FamilyTask],
        memberIds: Set<String>
    ) -> Int {
        var hasher = Hasher()
        for e in events { hasher.combine(e.id); hasher.combine(e.startDate); hasher.combine(e.title) }
        for t in tasks { hasher.combine(t.id); hasher.combine(t.dueDate); hasher.combine(t.status) }
        for m in memberIds.sorted() { hasher.combine(m) }
        return hasher.finalize()
    }
}
