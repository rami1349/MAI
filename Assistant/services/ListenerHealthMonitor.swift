
//  ListenerHealthMonitor.swift
//  FamilyHub
//
//  Debug-only monitoring for Firestore listener health
//  Tracks: active listeners, fire rates, update vs skip ratios
//
//  Usage:
//    ListenerHealthMonitor.shared.register("TaskVM")
//    ListenerHealthMonitor.shared.didFire("TaskVM", updated: true)
//    ListenerHealthMonitor.shared.unregister("TaskVM")
//

import Foundation

#if DEBUG

// MARK: - Listener Stats

struct ListenerStats {
    let name: String
    var fireCount: Int = 0
    var updateCount: Int = 0
    var skipCount: Int = 0
    var lastFired: Date?
    var registeredAt: Date = Date()
    
    var skipRate: Double {
        guard fireCount > 0 else { return 0 }
        return Double(skipCount) / Double(fireCount) * 100
    }
    
    var firesPerMinute: Double {
        let elapsed = Date().timeIntervalSince(registeredAt)
        guard elapsed > 0 else { return 0 }
        return Double(fireCount) / (elapsed / 60)
    }
}

// MARK: - Listener Health Monitor

@MainActor
@Observable
final class ListenerHealthMonitor {
    static let shared = ListenerHealthMonitor()
    
    private(set) var listeners: [String: ListenerStats] = [:]
    private(set) var totalFires: Int = 0
    private(set) var totalUpdates: Int = 0
    private(set) var totalSkips: Int = 0
    
    private var logEnabled = true
    
    private init() {}
    
    // MARK: - Registration
    
    /// Register a new listener
    func register(_ name: String) {
        listeners[name] = ListenerStats(name: name)
        log("Listener registered: \(name) (total: \(listeners.count))")
    }
    
    /// Unregister a listener
    func unregister(_ name: String) {
        if let stats = listeners.removeValue(forKey: name) {
            log(" Listener removed: \(name) - fires: \(stats.fireCount), updates: \(stats.updateCount), skips: \(stats.skipCount)")
        }
    }
    
    // MARK: - Event Tracking
    
    /// Called when a listener fires
    /// - Parameters:
    ///   - name: Listener identifier
    ///   - updated: true if data was published, false if deduped/skipped
    func didFire(_ name: String, updated: Bool) {
        guard var stats = listeners[name] else {
            log(" Unknown listener fired: \(name)")
            return
        }
        
        stats.fireCount += 1
        stats.lastFired = Date()
        totalFires += 1
        
        if updated {
            stats.updateCount += 1
            totalUpdates += 1
        } else {
            stats.skipCount += 1
            totalSkips += 1
        }
        
        listeners[name] = stats
        
        // Log high-frequency firing (more than 10/min)
        if stats.firesPerMinute > 10 {
            log("High fire rate: \(name) at \(String(format: "%.1f", stats.firesPerMinute))/min")
        }
    }
    
    // MARK: - Reporting
    
    /// Print current listener health report
    func printReport() {
        print("\n" + String(repeating: "=", count: 60))
        print("LISTENER HEALTH REPORT")
        print(String(repeating: "=", count: 60))
        print("Active listeners: \(listeners.count)")
        print("Total fires: \(totalFires) | Updates: \(totalUpdates) | Skips: \(totalSkips)")
        
        if totalFires > 0 {
            let overallSkipRate = Double(totalSkips) / Double(totalFires) * 100
            print("Overall skip rate: \(String(format: "%.1f", overallSkipRate))%")
        }
        
        print(String(repeating: "-", count: 60))
        
        for (name, stats) in listeners.sorted(by: { $0.key < $1.key }) {
            let lastFiredStr = stats.lastFired.map { 
                RelativeDateTimeFormatter().localizedString(for: $0, relativeTo: Date())
            } ?? "never"
            
            print("""
            \(name):
              Fires: \(stats.fireCount) | Updates: \(stats.updateCount) | Skips: \(stats.skipCount)
              Skip rate: \(String(format: "%.1f", stats.skipRate))% | Rate: \(String(format: "%.1f", stats.firesPerMinute))/min
              Last fired: \(lastFiredStr)
            """)
        }
        print(String(repeating: "=", count: 60) + "\n")
    }
    
    /// Get summary string for debug overlay
    var summaryString: String {
        let skipRate = totalFires > 0 ? Double(totalSkips) / Double(totalFires) * 100 : 0
        return " \(listeners.count) listeners | \(totalFires) fires | \(String(format: "%.0f", skipRate))% skipped"
    }
    
    // MARK: - Configuration
    
    func setLogging(enabled: Bool) {
        logEnabled = enabled
    }
    
    func reset() {
        listeners.removeAll()
        totalFires = 0
        totalUpdates = 0
        totalSkips = 0
        log(" Listener monitor reset")
    }
    
    private func log(_ message: String) {
        guard logEnabled else { return }
        print("[ListenerMonitor] \(message)")
    }
}

// MARK: - Debug View

import SwiftUI

/// Floating debug overlay showing listener health
struct ListenerHealthOverlay: View {
    var monitor = ListenerHealthMonitor.shared
    @State private var isExpanded = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button(action: { isExpanded.toggle() }) {
                HStack {
                    Text(monitor.summaryString)
                        .font(DS.Typography.micro())
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(DS.Typography.micro())
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.7))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            
            if isExpanded {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(monitor.listeners.keys.sorted()), id: \.self) { name in
                        if let stats = monitor.listeners[name] {
                            HStack {
                                Text(name)
                                    .font(DS.Typography.micro().monospaced())
                                Spacer()
                                Text("\(stats.fireCount)↓ \(stats.skipCount)⏭")
                                    .font(DS.Typography.micro().monospaced())
                            }
                            .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    
                    Divider().background(Color.white.opacity(0.3))
                    
                    Button("Print Report") {
                        monitor.printReport()
                    }
                    .font(DS.Typography.micro())
                    .foregroundStyle(.cyan)
                }
                .padding(8)
                .background(Color.black.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
        }
    }
}

#else

// MARK: - Release Build Stubs (No-op)

@MainActor
final class ListenerHealthMonitor {
    static let shared = ListenerHealthMonitor()
    private init() {}
    
    @inlinable func register(_ name: String) {}
    @inlinable func unregister(_ name: String) {}
    @inlinable func didFire(_ name: String, updated: Bool) {}
    @inlinable func printReport() {}
    @inlinable func setLogging(enabled: Bool) {}
    @inlinable func reset() {}
}

#endif
