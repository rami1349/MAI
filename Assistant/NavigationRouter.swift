// ============================================================================
// NavigationRouter.swift
//
// CENTRALIZED NAVIGATION STATE
//
// PURPOSE:
//   Single source of truth for ALL navigation in the app.
//   Replaces scattered @State booleans across 10+ views.
//
//
// USAGE:
//   @Environment(NavigationRouter.self) var router
//   router.present(.taskDetail(task))
//   router.push(.todayTasks)
//   router.navigate(to: url)
//
//
// ============================================================================

import SwiftUI

// MARK: - Navigation Item (Tab Identity)

/// The 5 app tabs. Lives here because NavigationRouter depends on it
/// and it's fundamentally a navigation concept.
enum NavigationItem: String, CaseIterable, Identifiable, Sendable {
    case home
    case calendar
    case mai
    case tasks
    case me

    var id: String { rawValue }

    static var phoneTabs: [NavigationItem] { allCases }

    static var sidebarTabs: [NavigationItem] { [.home, .calendar, .tasks] }

    var localizationKey: String {
        switch self {
        case .home:     "home"
        case .calendar: "calendar"
        case .mai:      "mai"
        case .tasks:    "tasks"
        case .me:       "me_tab"
        }
    }

    var title: String {
        AppStrings.localized(.init(localizationKey))
    }

    var icon: String {
        switch self {
        case .home:     "house.fill"
        case .calendar: "calendar"
        case .mai:      "sparkles"
        case .tasks:    "checkmark.circle"
        case .me:       "person.circle"
        }
    }

    var selectedIcon: String {
        switch self {
        case .home:     "house.fill"
        case .calendar: "calendar"
        case .mai:      "sparkles"
        case .tasks:    "checkmark.circle.fill"
        case .me:       "person.circle.fill"
        }
    }
}


// MARK: - Tab Routes (push destinations per tab's NavigationStack)

enum HomeRoute: Hashable, Codable, Sendable {
    case todayTasks
    case taskGroup(id: String)
}

enum CalendarRoute: Hashable, Codable, Sendable {
    case eventDetail(id: String)
}

enum TasksRoute: Hashable, Codable, Sendable {
    case taskGroupDetail(id: String)
}

enum MeRoute: Hashable, Codable, Sendable {
    case settings
    case memberDetail(id: String)
}


// MARK: - Sheet Routes (modal presentations)

/// Every primary modal presentation in the app.
/// Declared once, presented via `router.present(...)`, shown in MainTabView.
///
/// Secondary sheets (e.g. EditTask from within TaskDetail) stay local
/// to their parent — only top-level entry points live here.
///
/// Equatable implemented manually since CalendarEvent lacks Equatable.
enum AppSheet: Identifiable {

    // ── Create ──
    case addTask(groupId: String? = nil)
    case addEvent
    case addHabit
    case createGroup

    // ── Detail ──
    case taskDetail(FamilyTask)
    case eventDetail(CalendarEvent)

    // ── Utility ──
    case notifications
    case rewardWallet
    case inviteCode
    case paywall

    // MARK: Identifiable

    var id: String {
        switch self {
        case .addTask(let groupId):     return "addTask-\(groupId ?? "none")"
        case .addEvent:                 return "addEvent"
        case .addHabit:                 return "addHabit"
        case .createGroup:              return "createGroup"
        case .taskDetail(let task):     return "taskDetail-\(task.stableId)"
        case .eventDetail(let event):   return "eventDetail-\(event.id ?? "new")"
        case .notifications:            return "notifications"
        case .rewardWallet:             return "rewardWallet"
        case .inviteCode:               return "inviteCode"
        case .paywall:                  return "paywall"
        }
    }
}

extension AppSheet: Equatable {
    static func == (lhs: AppSheet, rhs: AppSheet) -> Bool {
        lhs.id == rhs.id
    }
}


// MARK: - Deep Link Destination

enum DeepLink: Sendable {
    case tab(NavigationItem)
    case task(id: String)
    case event(id: String)
    case addTask
    case addEvent
    case notifications
}


// MARK: - Navigation Router

@MainActor
@Observable
final class NavigationRouter {

    // ── Tab Selection ──
    var selectedTab: NavigationItem = .home

    // ── Push Navigation (one path per tab) ──
    var homePath = NavigationPath()
    var calendarPath = NavigationPath()
    var tasksPath = NavigationPath()
    var mePath = NavigationPath()

    // ── Sheet Presentation ──
    var activeSheet: AppSheet? = nil


    // MARK: - Sheet Presentation

    func present(_ sheet: AppSheet) {
        activeSheet = sheet
    }

    func dismissSheet() {
        activeSheet = nil
    }

    /// Dismiss all sheets and pop to root on every tab.
    func dismissAll() {
        activeSheet = nil
        homePath = NavigationPath()
        calendarPath = NavigationPath()
        tasksPath = NavigationPath()
        mePath = NavigationPath()
    }


    // MARK: - Push Navigation

    func push(_ route: HomeRoute) {
        selectedTab = .home
        homePath.append(route)
    }

    func push(_ route: CalendarRoute) {
        selectedTab = .calendar
        calendarPath.append(route)
    }

    func push(_ route: TasksRoute) {
        selectedTab = .tasks
        tasksPath.append(route)
    }

    func push(_ route: MeRoute) {
        selectedTab = .me
        mePath.append(route)
    }

    func popToRoot(tab: NavigationItem) {
        switch tab {
        case .home:     homePath = NavigationPath()
        case .calendar: calendarPath = NavigationPath()
        case .tasks:    tasksPath = NavigationPath()
        case .me:       mePath = NavigationPath()
        case .mai:      break
        }
    }

    func handleTabReselection(_ tab: NavigationItem) {
        if tab == selectedTab {
            popToRoot(tab: tab)
        }
    }


    // MARK: - Deep Linking

    func navigate(to url: URL) {
        guard let deepLink = parseDeepLink(url) else { return }
        navigate(to: deepLink)
    }

    func navigate(to link: DeepLink) {
        dismissSheet()

        switch link {
        case .tab(let tab):
            selectedTab = tab

        case .task(let id):
            selectedTab = .tasks
            NotificationCenter.default.post(
                name: .deepLinkTask,
                object: nil,
                userInfo: ["taskId": id]
            )

        case .event(let id):
            selectedTab = .calendar
            NotificationCenter.default.post(
                name: .deepLinkEvent,
                object: nil,
                userInfo: ["eventId": id]
            )

        case .addTask:
            present(.addTask())

        case .addEvent:
            present(.addEvent)

        case .notifications:
            present(.notifications)
        }
    }


    // MARK: - Private

    private func parseDeepLink(_ url: URL) -> DeepLink? {
        guard url.scheme == "assistant" else { return nil }

        let host = url.host ?? ""
        let pathComponents = url.pathComponents.filter { $0 != "/" }

        switch host {
        case "home":
            return .tab(.home)
        case "calendar":
            if let eventId = pathComponents.first {
                return .event(id: eventId)
            }
            return .tab(.calendar)
        case "tasks":
            if let taskId = pathComponents.first {
                return .task(id: taskId)
            }
            return .tab(.tasks)
        case "me":
            return .tab(.me)
        case "mai":
            return .tab(.mai)
        case "notifications":
            return .notifications
        case "add-task":
            return .addTask
        case "add-event":
            return .addEvent
        default:
            return nil
        }
    }
}


// MARK: - Notification Names for Deep Linking

extension Notification.Name {
    static let deepLinkTask = Notification.Name("deepLinkTask")
    static let deepLinkEvent = Notification.Name("deepLinkEvent")
}
