//
//  LocalizationManager.swift
//
//  Modern localization architecture using Localizable.xcstrings (String Catalog).
//
//  ARCHITECTURE (iOS 17+ / Xcode 15+):
//  ─────────────────────────────────────
//  Source of truth:  Localizable.xcstrings  (compiled to .lproj at build time)
//  SwiftUI views:    Text("key")           (auto-resolves via .environment(\.locale))
//  Code (VMs, etc):  AppStrings.localized("key")
//                    — or —
//                    String(localized: "key", locale: AppLanguage.shared.locale)
//  Format strings:   AppStrings.assignedYouTask(name, task)
//
//  RUNTIME LANGUAGE SWITCHING:
//  ───────────────────────────
//  1. AppLanguage.shared.setLanguage(.spanish)
//  2. SwiftUI picks it up via .environment(\.locale, appLanguage.locale)
//  3. Code callers use AppStrings.localized() which reads the current locale
//
//  MIGRATION FROM L10n:
//  ────────────────────
//  • Text(L10n.cancel)                →  Text("cancel")
//  • L10n.cancel  (in code)           →  AppStrings.localized("cancel")
//  • L10n.assignedYouTask(a, b)       →  AppStrings.assignedYouTask(a, b)
//  • LocalizationManager.shared       →  AppLanguage.shared
//

import SwiftUI


// MARK: - Supported Languages

/// The languages supported by the app.
/// Raw values match the locale identifiers used in Localizable.xcstrings.
enum LanguageCode: String, CaseIterable, Identifiable, Sendable {
    case system  = "system"
    case english = "en"
    case spanish = "es"
    case chinese = "zh-Hans"

    var id: String { rawValue }

    /// Display name shown in the language picker (in native script).
    var displayName: String {
        switch self {
        case .system:  String(localized: "language.system")
        case .english: "English"
        case .spanish: "Español"
        case .chinese: "中文"
        }
    }

    /// Locale identifier for SwiftUI environment injection.
    var localeIdentifier: String {
        switch self {
        case .system:  Self.resolveSystemLanguage()
        case .english: "en"
        case .spanish: "es"
        case .chinese: "zh-Hans"
        }
    }

    /// Resolves the device's preferred language to a supported language code.
    static func resolveSystemLanguage() -> String {
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("es") { return "es" }
        if preferred.hasPrefix("zh") { return "zh-Hans" }
        return "en"
    }
}


// MARK: - App Language Manager

/// Manages runtime language selection.
///
/// Inject into your SwiftUI hierarchy with:
/// ```swift
/// .environment(\.locale, AppLanguage.shared.locale)
/// ```
///
/// This makes all `Text("key")` calls resolve using the selected language
/// without any wrapper types.
@Observable
@MainActor
final class AppLanguage {

    // MARK: - Singleton

    static let shared = AppLanguage()

    // MARK: - Storage

    @ObservationIgnored
    private let storageKey = "app_language_preference"

    // MARK: - State

    /// The user's selected language preference.
    private(set) var selectedLanguage: LanguageCode

    /// The `Locale` to inject via `.environment(\.locale, …)`.
    var locale: Locale {
        Locale(identifier: resolvedLanguageCode)
    }

    // MARK: - Computed

    /// The actual language code in use (resolves "system" → real code).
    var resolvedLanguageCode: String {
        selectedLanguage == .system
            ? LanguageCode.resolveSystemLanguage()
            : selectedLanguage.rawValue
    }

    /// Human-readable label for the current selection (used in Settings).
    var displayName: String {
        if selectedLanguage == .system,
           let resolved = LanguageCode(rawValue: LanguageCode.resolveSystemLanguage()) {
            return "\(selectedLanguage.displayName) (\(resolved.displayName))"
        }
        return selectedLanguage.displayName
    }

    // MARK: - Init

    private init() {
        let saved = UserDefaults.standard.string(forKey: storageKey) ?? "system"
        self.selectedLanguage = LanguageCode(rawValue: saved) ?? .system
    }

    // MARK: - Public API

    /// Switch the app's language. UI updates automatically via SwiftUI environment.
    func setLanguage(_ language: LanguageCode) {
        selectedLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: storageKey)
    }

    /// Switch using a raw code string.
    func setLanguage(code: String) {
        if let language = LanguageCode(rawValue: code) {
            setLanguage(language)
        }
    }
}


// MARK: - Environment Key

private struct AppLanguageKey: EnvironmentKey {
    static var defaultValue: AppLanguage {
        MainActor.assumeIsolated { AppLanguage.shared }
    }
}

extension EnvironmentValues {
    var appLanguage: AppLanguage {
        get { self[AppLanguageKey.self] }
        set { self[AppLanguageKey.self] = newValue }
    }
}


// ════════════════════════════════════════════════════════════════════════
// MARK: - AppStrings
// ════════════════════════════════════════════════════════════════════════

/// Typed string accessors for use in **non-SwiftUI code** (ViewModels,
/// services, notifications, etc.) where `Text("key")` isn't available.
///
/// All functions are **nonisolated** — safe to call from any actor context
/// (background services, notification handlers, etc.).
///
/// For SwiftUI views, prefer `Text("key")` directly — it auto-resolves
/// via `.environment(\.locale)` and avoids an extra layer.
///
/// Usage:
/// ```swift
/// let title = AppStrings.localized("task_completed")
/// let msg   = AppStrings.assignedYouTask("Mom", "Clean Room")
/// ```
enum AppStrings {

    // MARK: - Nonisolated Locale Resolution

    /// Resolves the active locale by reading directly from UserDefaults.
    ///
    /// This avoids `@MainActor` isolation — UserDefaults reads are thread-safe.
    /// Mirrors the same logic as `AppLanguage.resolvedLanguageCode`.
    private static var currentLocale: Locale {
        let saved = UserDefaults.standard.string(forKey: "app_language_preference") ?? "system"
        let code: String
        switch saved {
        case "en":      code = "en"
        case "es":      code = "es"
        case "zh-Hans": code = "zh-Hans"
        case "system":  code = LanguageCode.resolveSystemLanguage()
        default:        code = "en"
        }
        return Locale(identifier: code)
    }

    // MARK: - Core Lookup

    /// Resolve a key from Localizable.xcstrings using the active locale.
    static func localized(_ key: String.LocalizationValue) -> String {
        String(localized: key, locale: currentLocale)
    }

    /// Resolve a key with a specific locale override (e.g. for push notifications).
    static func localized(_ key: String.LocalizationValue, locale: Locale) -> String {
        String(localized: key, locale: locale)
    }

    // MARK: - Format Helpers (parameterized strings)
    //
    // These replace the old `L10n.someFunction(arg)` calls.
    // Each one maps to a format-string key in Localizable.xcstrings.
    // The xcstrings value uses %@ (String) or %d / %lld (Int).

    // ── Task Assignment ──────────────────────────────────────────────

    static func assignedYouTask(_ assigner: String, _ task: String) -> String {
        format("assigned_you_task", assigner, task)
    }

    static func youAssignedTask(_ assignee: String, _ task: String) -> String {
        format("you_assigned_task", assignee, task)
    }

    static func memberRemovedTask(_ member: String, _ task: String) -> String {
        format("member_removed_task", member, task)
    }

    // ── Event Notifications ──────────────────────────────────────────

    static func addedYouToEvent(_ creator: String, _ title: String, _ date: String) -> String {
        format("added_you_to_event", creator, title, date)
    }

    static func youCreatedEvent(_ title: String, _ date: String) -> String {
        format("you_created_event", title, date)
    }

    static func eventUpdatedNotifBody(_ title: String) -> String {
        format("event_updated_notif_body", title)
    }

    static func eventCanceledNotifBody(_ title: String, _ canceler: String) -> String {
        format("event_canceled_notif_body", title, canceler)
    }

    static func eventTomorrowBody(_ title: String) -> String {
        format("event_tomorrow_body", title)
    }

    static func eventStartingSoonBody(_ title: String) -> String {
        format("event_starting_soon_body", title)
    }

    // ── Task Notifications ───────────────────────────────────────────

    static func taskCompletedNotifBody(_ performer: String, _ title: String) -> String {
        format("task_completed_notif_body", performer, title)
    }

    static func taskUpdatedNotifBody(_ title: String) -> String {
        format("task_updated_notif_body", title)
    }

    static func taskReassignedNotifBody(_ title: String) -> String {
        format("task_reassigned_notif_body", title)
    }

    static func taskOverdueNotifBody(_ title: String) -> String {
        format("task_overdue_notif_body", title)
    }

    static func taskStartedBody(_ performer: String, _ title: String) -> String {
        format("task_started_body", performer, title)
    }

    static func proofSubmittedBody(_ performer: String, _ title: String) -> String {
        format("proof_submitted_body", performer, title)
    }

    static func taskCompletedBody(_ performer: String, _ title: String) -> String {
        format("task_completed_body", performer, title)
    }

    static func taskDueTomorrowBody(_ title: String) -> String {
        format("task_due_tomorrow_body", title)
    }

    static func taskDueSoonBody(_ title: String) -> String {
        format("task_due_soon_body", title)
    }

    // ── Task Groups ──────────────────────────────────────────────────

    static func deleteGroupWarning(_ count: Int) -> String {
        format("delete_group_warning", count)
    }

    static func deleteGroupConfirm(_ name: String) -> String {
        format("delete_group_confirm", name)
    }

    // ── Time / Recurrence ────────────────────────────────────────────

    static func dueInMinutes(_ count: Int) -> String {
        format("due_in_minutes", count)
    }

    static func dueInHours(_ count: Int) -> String {
        format("due_in_hours", count)
    }

    static func dueInDays(_ count: Int) -> String {
        format("due_in_days", count)
    }

    static func xDays(_ count: Int) -> String {
        format("x_days", count)
    }

    static func everyXDays(_ count: Int) -> String {
        format("every_x_days", count)
    }

    static func everyXWeeks(_ count: Int) -> String {
        format("every_x_weeks", count)
    }

    static func everyXMonths(_ count: Int) -> String {
        format("every_x_months", count)
    }

    static func weeklyOn(_ days: String) -> String {
        format("weekly_on", days)
    }

    static func everyXWeeksOn(_ count: Int, _ days: String) -> String {
        format("every_x_weeks_on", count, days)
    }

    // ── Stats & Counts ───────────────────────────────────────────────

    static func xMembers(_ count: Int) -> String {
        format("x_members", count)
    }

    static func thisYearCount(_ count: Int) -> String {
        format("this_year_count", count)
    }

    static func thisMonthCount(_ count: Int) -> String {
        format("this_month_count", count)
    }

    static func showMore(_ count: Int) -> String {
        format("show_more", count)
    }

    static func moreEvents(_ count: Int) -> String {
        format("more_events", count)
    }

    static func monthEvents(_ month: String) -> String {
        format("month_events", month)
    }

    static func eventsTasksCount(_ events: Int, _ tasks: Int) -> String {
        format("events_tasks_count", events, tasks)
    }

    // ── Rewards ──────────────────────────────────────────────────────

    static func earnedFromTasks(_ count: Int) -> String {
        format("earned_from_tasks", count)
    }

    static func fromPerson(_ name: String) -> String {
        format("from_person", name)
    }

    static func requestedFrom(_ name: String) -> String {
        format("requested_from", name)
    }

    static func payAmount(_ amount: String) -> String {
        format("pay_amount", amount)
    }

    static func requestedPayoutFrom(_ name: String, _ amount: Int) -> String {
        format("requested_payout_from", name, amount)
    }

    static func payoutApprovedBody(_ name: String, _ amount: Int) -> String {
        format("payout_approved_body", name, amount)
    }

    static func payoutRejectedBody(_ name: String, _ amount: Int) -> String {
        format("payout_rejected_body", name, amount)
    }

    static func rewardEarnedBody(_ amount: Int, _ task: String, _ from: String) -> String {
        format("reward_earned_body", amount, task, from)
    }

    // ── Proof & Verification ─────────────────────────────────────────

    static func earnAmount(_ amount: String) -> String {
        format("earn_amount", amount)
    }

    static func addProof(_ type: String) -> String {
        format("add_proof", type)
    }

    static func verifiedOn(_ date: String) -> String {
        format("verified_on", date)
    }

    static func verifiedOnDate(_ date: String) -> String {
        format("verified_on_date", date)
    }

    // ── Profile ──────────────────────────────────────────────────────

    static func goalForYear(_ year: Any) -> String {
        format("goal_for_year", "\(year)")
    }

    static func typeToConfirm(_ text: String) -> String {
        format("type_to_confirm", text)
    }

    // ── Focus Timer ──────────────────────────────────────────────────

    static func minutesFocusedWork(_ minutes: Int) -> String {
        format("minutes_focused_work", minutes)
    }

    // ── Habits ───────────────────────────────────────────────────────

    static func thisWeekHabits(_ completed: Int, _ total: Int) -> String {
        format("this_week_habits", completed, total)
    }

    // ── Chat / AI ────────────────────────────────────────────────────

    static func dailyLimitMessage(_ count: Int) -> String {
        format("daily_limit_message", count)
    }

    static func messagesRemaining(_ remaining: Int, _ total: Int) -> String {
        format("messages_remaining", remaining, total)
    }

    static func dailyLimitUsedWithCredits(_ limit: Int, _ credits: Int) -> String {
        format("daily_limit_used_with_credits", limit, credits)
    }

    static func dailyLimitUsed(_ limit: Int) -> String {
        format("daily_limit_used", limit)
    }

    static func usingCreditsRemaining(_ count: Int) -> String {
        format("using_credits_remaining", count)
    }

    static func dailyAiActionsUsed(_ count: Int) -> String {
        format("daily_ai_actions_used", count)
    }

    static func questionNumberShort(_ num: String) -> String {
        format("question_number_short", num)
    }

    static func questionNumberWithText(_ num: String, _ text: String) -> String {
        format("question_number_with_text", num, text)
    }

    static func questionNumberLabel(_ num: String) -> String {
        format("question_number_label", num)
    }

    static func aiUnavailableRetrySeconds(_ seconds: Int) -> String {
        format("ai_unavailable_retry_seconds", seconds)
    }

    static func maiUnavailableRetrySeconds(_ seconds: Int) -> String {
        format("mai_unavailable_retry_seconds", seconds)
    }

    static func aiServiceUnavailableRetry(_ seconds: Int) -> String {
        format("ai_service_unavailable_retry", seconds)
    }

    // ── Home v2 Slots ────────────────────────────────────────────

    static func tasksWaitingReview(_ count: Int) -> String {
        format("tasks_waiting_review", count)
    }

    static func earnedThisWeekStat(_ amount: String) -> String {
        format("earned_this_week_stat", amount)
    }

    static func habitStreakGoing(_ days: Int) -> String {
        format("habit_streak_going", days)
    }

    static func earnedRewardClaim(_ amount: String) -> String {
        format("earned_reward_claim", amount)
    }

    // ── Me Tab ───────────────────────────────────────────────

    static func xToReview(_ count: Int) -> String {
        format("x_to_review", count)
    }

    // MARK: - Day Name Array Helper

    /// Day abbreviations indexed by Calendar weekday (1 = Sun … 7 = Sat).
    static var dayNames: [String] {
        [
            "",
            localized("day_sun"),
            localized("day_mon"),
            localized("day_tue"),
            localized("day_wed"),
            localized("day_thu"),
            localized("day_fri"),
            localized("day_sat"),
        ]
    }

    // MARK: - Plural Helpers

    static func pluralMembers(_ count: Int) -> String {
        count == 1 ? localized("member_singular") : localized("members_plural")
    }

    static func membersCount(_ count: Int) -> String {
        "\(count) \(pluralMembers(count))"
    }

    // MARK: - Private Format Helper

    /// Resolves a key from xcstrings, then applies `String(format:)` with the given args.
    private static func format(_ key: String, _ args: CVarArg...) -> String {
        let locale = currentLocale
        let pattern = String(localized: String.LocalizationValue(key), locale: locale)
        return String(format: pattern, locale: locale, arguments: args)
    }
}
