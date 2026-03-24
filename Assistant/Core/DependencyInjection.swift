//
//  DependencyInjection.swift
//
//
//  Lightweight dependency injection for testability.
//  This file contains everything needed - add it to your project.
//
//  MIGRATION STEPS:
//  1. Add this file to your main target
//  2. In AssistantApp.swift, add .withLiveDependencies() to ContentView
//  3. (Optional) Add MockServices.swift to your test target for unit tests
//

import SwiftUI

// ============================================================================
// MARK: - SERVICE PROTOCOLS
// ============================================================================
// These protocols match your existing singleton APIs exactly.
// Your singletons already conform - we just need to declare it.

/// Protocol for ThemeManager
@MainActor
protocol ThemeServiceProtocol: Observable {
    var currentTheme: AppTheme { get set }
    var appearanceMode: AppearanceMode { get set }
    var palette: ColorPalette { get }
    var colorScheme: ColorScheme? { get }
}

/// Protocol for AppLanguage (runtime language switching)
@MainActor
protocol LocalizationServiceProtocol: Observable {
    var resolvedLanguageCode: String { get }
    var selectedLanguage: LanguageCode { get }
    var locale: Locale { get }
    func setLanguage(_ language: LanguageCode)
}

/// Protocol for TourManager
@MainActor
protocol TourServiceProtocol: Observable {
    var isActive: Bool { get set }
    var currentStep: TourStep? { get }
    func startIfNeeded()
    func next()
    func skip()
    func finish()
    func reset()
    var hasCompletedTour: Bool { get }
}

/// Protocol for FocusTimerManager
@MainActor
protocol FocusTimerServiceProtocol: Observable {
    var state: FocusTimerState { get }
    var remainingSeconds: Int { get }
    var totalSeconds: Int { get }
    var currentTaskId: String? { get }
    var isBreakMode: Bool { get }
    func start(taskId: String, durationMinutes: Int, isBreak: Bool)
    func pause()
    func resume()
    func reset()
    func complete()
}

/// Protocol for EventKitCalendarService
@MainActor
protocol CalendarServiceProtocol: Observable {
    var authStatus: CalendarAuthStatus { get }
    var events: [ExternalCalendarEvent] { get }
    var holidayEvents: [ExternalCalendarEvent] { get }
    var isLoading: Bool { get }
    func requestAccessIfNeeded() async -> Bool
    func loadEvents(from startDate: Date, to endDate: Date?) async
    func refreshEvents() async
}


// ============================================================================
// MARK: - PROTOCOL CONFORMANCE
// ============================================================================
// Your singletons already implement these methods - this just declares conformance.

extension ThemeManager: ThemeServiceProtocol {}
extension AppLanguage: LocalizationServiceProtocol {}
extension TourManager: TourServiceProtocol {}
extension FocusTimerManager: FocusTimerServiceProtocol {}
extension EventKitCalendarService: CalendarServiceProtocol {}


// ============================================================================
// MARK: - DEPENDENCY CONTAINER
// ============================================================================

/// Central container for all app dependencies.
/// In production, holds singletons. In tests, can hold mocks.
@MainActor
@Observable
final class DependencyContainer {
    
    // Services
    let theme: any ThemeServiceProtocol
    let localization: any LocalizationServiceProtocol
    let tour: any TourServiceProtocol
    let focusTimer: any FocusTimerServiceProtocol
    let calendar: any CalendarServiceProtocol
    
    // Production container (uses singletons)
    static let live = DependencyContainer(
        theme: ThemeManager.shared,
        localization: AppLanguage.shared,
        tour: TourManager.shared,
        focusTimer: FocusTimerManager.shared,
        calendar: EventKitCalendarService.shared
    )
    
    init(
        theme: any ThemeServiceProtocol,
        localization: any LocalizationServiceProtocol,
        tour: any TourServiceProtocol,
        focusTimer: any FocusTimerServiceProtocol,
        calendar: any CalendarServiceProtocol
    ) {
        self.theme = theme
        self.localization = localization
        self.tour = tour
        self.focusTimer = focusTimer
        self.calendar = calendar
    }
}


// ============================================================================
// MARK: - ENVIRONMENT INJECTION
// ============================================================================

private struct DependencyContainerKey: EnvironmentKey {
    static var defaultValue: DependencyContainer {
        // Access on MainActor since DependencyContainer is MainActor-isolated
        MainActor.assumeIsolated {
            DependencyContainer.live
        }
    }
}

extension EnvironmentValues {
    var deps: DependencyContainer {
        get { self[DependencyContainerKey.self] }
        set { self[DependencyContainerKey.self] = newValue }
    }
}


// ============================================================================
// MARK: - VIEW EXTENSIONS
// ============================================================================

extension View {
    /// Injects production dependencies (singletons)
    /// Use this in your App's WindowGroup
    @MainActor
    func withLiveDependencies() -> some View {
        self
            .environment(\.deps, .live)
            // Also inject as EnvironmentObjects for backward compatibility
            .environment(ThemeManager.shared)
            .environment(AppLanguage.shared)
            .environment(TourManager.shared)
    }
    
    /// Injects custom dependencies (for testing)
    @MainActor
    func withDependencies(_ container: DependencyContainer) -> some View {
        self.environment(\.deps, container)
    }
}
