//
//  LocalizationManager.swift
//  FamilyHub
//
//  Refactored to use Apple's standard Localizable.strings files.
//
//  HOW IT WORKS:
//  - All translations live in standard .strings files:
//      en.lproj/Localizable.strings
//      es.lproj/Localizable.strings
//      zh-Hans.lproj/Localizable.strings
//  - LocalizationManager handles in-app language override by loading
//    the correct .lproj bundle at runtime.
//  - L10n provides type-safe accessors (unchanged public API).
//  - No more Strings.defaults dictionary â€” Apple's bundle system IS the source of truth.
//
//  MIGRATION NOTES:
//  - The Localizable.strings files you already have for es and zh-Hans remain as-is.
//  - You MUST add en.lproj/Localizable.strings with all English strings
//    (previously hardcoded in Strings.defaults). A generated copy is provided.
//  - Every call site using L10n.xxx continues to work with zero changes.
//

import Foundation
import SwiftUI

// MARK: - Supported Languages
// ⚠️ RENAMED: Was "AppLanguage" - now "LanguageOption" to avoid conflict with AppLanguage.swift class

enum LanguageOption: String, CaseIterable, Identifiable {
    case system  = "system"
    case english = "en"
    case spanish = "es"
    case chinese = "zh-Hans"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .system:  return "System Default"
        case .english: return "English"
        case .spanish: return "Español"
        case .chinese: return "中文"
        }
    }
    
    var shortName: String {
        switch self {
        case .system:  return "System"
        case .english: return "English"
        case .spanish: return "Español"
        case .chinese: return "中文"
        }
    }
}

// MARK: - Localization Manager

@Observable
final class LocalizationManager {
    static let shared = LocalizationManager()
    
    @ObservationIgnored private let languageKey = "app_language_preference"
    
    private(set) var currentLanguage: String
    private(set) var selectedLanguage: LanguageOption
    
    /// The .lproj bundle for the active language.
    /// `nil` only if the .lproj folder is missing from the app bundle.
    private(set) var bundle: Bundle
    
    // MARK: - Init
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: languageKey) ?? "system"
        let language = LanguageOption(rawValue: saved) ?? .system
        let resolved = language == .system
        ? Self.resolveSystemLanguage()
        : language.rawValue
        
        self.selectedLanguage = language
        self.currentLanguage = resolved
        self.bundle = Self.loadBundle(for: resolved)
    }
    
    // MARK: - Language Switching
    
    func setLanguage(_ language: LanguageOption) {
        selectedLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: languageKey)
        
        currentLanguage = language == .system
        ? Self.resolveSystemLanguage()
        : language.rawValue
        
        bundle = Self.loadBundle(for: currentLanguage)
        // Note: With @Observable, property changes automatically trigger view updates.
        // No need for objectWillChange.send() - that's the old ObservableObject pattern.
    }
    
    // MARK: - String Lookup
    
    /// Primary lookup â€” reads from the active .lproj bundle's Localizable.strings.
    func string(_ key: String) -> String {
        bundle.localizedString(forKey: key, value: key, table: "Localizable")
    }
    
    /// Format-string lookup with arguments.
    func string(_ key: String, _ arguments: CVarArg...) -> String {
        let format = string(key)
        return String(format: format, arguments: arguments)
    }
    
    // MARK: - Display Names
    
    var languageDisplayName: String {
        selectedLanguage == .system
        ? LanguageOption(rawValue: currentLanguage)?.displayName ?? "English"
        : selectedLanguage.displayName
    }
    
    var currentLanguageShortName: String {
        LanguageOption(rawValue: currentLanguage)?.shortName ?? "English"
    }
    
    // MARK: - Private Helpers
    
    private static func resolveSystemLanguage() -> String {
        let preferred = Locale.preferredLanguages.first ?? "en"
        if preferred.hasPrefix("es")       { return "es" }
        if preferred.hasPrefix("zh")       { return "zh-Hans" }
        return "en"
    }
    
    private static func loadBundle(for languageCode: String) -> Bundle {
        guard let path = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
              let lproj = Bundle(path: path) else {
            return .main
        }
        return lproj
    }
}

// MARK: - L10n Accessors


struct L10n {
    private static var loc: LocalizationManager { .shared }
    
    // App
    static var appName: String { loc.string("app_name") }
    static var appTitle: String { loc.string("app_title") }
    static var manageFamily: String { loc.string("manage_family") }
    
    // Common
    static var cancel: String { loc.string("cancel") }
    static var done: String { loc.string("done") }
    static var save: String { loc.string("save") }
    static var delete: String { loc.string("delete") }
    static var edit: String { loc.string("edit") }
    static var add: String { loc.string("add") }
    static var ok: String { loc.string("ok") }
    static var yes: String { loc.string("yes") }
    static var no: String { loc.string("no") }
    static var close: String { loc.string("close") }
    static var create: String { loc.string("create") }
    static var loading: String { loc.string("loading") }
    static var error: String { loc.string("error") }
    static var success: String { loc.string("success") }
    static var hi: String { loc.string("hi") }
    static var optional: String { loc.string("optional") }
    static var search: String { loc.string("search") }
    static var notes: String { loc.string("notes") }
    static var location: String { loc.string("location") }
    static var icon: String { loc.string("icon") }
    static var color: String { loc.string("color") }
    
    // Auth
    static var signIn: String { loc.string("sign_in") }
    static var signUp: String { loc.string("sign_up") }
    static var signOut: String { loc.string("sign_out") }
    static var email: String { loc.string("email") }
    static var password: String { loc.string("password") }
    static var confirmPassword: String { loc.string("confirm_password") }
    static var forgotPassword: String { loc.string("forgot_password") }
    static var passwordMatch: String { loc.string("password_match") }
    static var passwordDontMatch: String { loc.string("password_dont_match") }
    static var createAccount: String { loc.string("create_account") }
    static var alreadyHaveAccount: String { loc.string("already_have_account") }
    static var dontHaveAccount: String { loc.string("dont_have_account") }
    static var letSetupFamily: String { loc.string("let_setup_family") }
    static var dateOfBirth: String { loc.string("date_of_birth") }
    static var displayName: String { loc.string("display_name") }
    
    // Family
    static var createFamily: String { loc.string("create_family") }
    static var joinFamily: String { loc.string("join_family") }
    static var familyName: String { loc.string("family_name") }
    static var inviteCode: String { loc.string("invite_code") }
    static var invalidInviteCode: String { loc.string("invalid_invite_code") }
    static var familyMembers: String { loc.string("family_members") }
    static var inviteFamilyMember: String { loc.string("invite_family_member") }
    static var copyCode: String { loc.string("copy_code") }
    static var members: String { loc.string("members") }
    static var balance: String { loc.string("balance") }
    static var adult: String { loc.string("adult") }
    static var member: String { loc.string("member") }
    static var createFamilyMessage: String { loc.string("create_family_message") }
    static var enterInviteCode: String { loc.string("enter_invite_code") }
    
    // Tabs
    static var home: String { loc.string("home") }
    static var tasks: String { loc.string("tasks") }
    static var calendar: String { loc.string("calendar") }
    static var family: String { loc.string("family") }
    
    // Tasks View
    static var myTasks: String { loc.string("my_tasks") }
    static var myHabits: String { loc.string("my_habits") }
    static var habits: String { loc.string("habits") }
    static var noGroup: String { loc.string("no_group") }
    static var taskGroups: String { loc.string("task_groups") }
    static var groupName: String { loc.string("group_name") }
    static var newTaskGroup: String { loc.string("new_task_group") }
    static var deleteHabit: String { loc.string("deleteHabit") }
    static var deleteHabitConfirmation: String { loc.string("deleteHabitConfirm") }
    
    // Task Filters
    static var filterAll: String { loc.string("filter_all") }
    static var filterTodo: String { loc.string("filter_todo") }
    static var filterActive: String { loc.string("filter_active") }
    static var filterDone: String { loc.string("filter_done") }
    
    // Tasks
    static var todaysTasks: String { loc.string("todays_tasks") }
    static var viewTasks: String { loc.string("view_tasks") }
    static var inProgress: String { loc.string("in_progress") }
    static var pendingVerification: String { loc.string("pending_verification") }
    static var newTask: String { loc.string("new_task") }
    static var addTask: String { loc.string("add_task") }
    static var taskTitle: String { loc.string("task_title") }
    static var needToBeDone: String { loc.string("need_to_be_done") }
    static var description: String { loc.string("description") }
    static var addDetail: String { loc.string("add_detail") }
    static var dueDate: String { loc.string("due_date") }
    static var priority: String { loc.string("priority") }
    static var assignTo: String { loc.string("assign_to") }
    static var taskGroup: String { loc.string("task_group") }
    static var selectGroup: String { loc.string("select_group") }
    static var selectMember: String { loc.string("select_member") }
    static var unassigned: String { loc.string("unassigned") }
    static var createGroup: String { loc.string("create_group") }
    static var taskDetails: String { loc.string("task_details") }
    static var taskNotFound: String { loc.string("task_not_found") }
    static var scheduledTime: String { loc.string("scheduled_time") }
    static var assignedTo: String { loc.string("assigned_to") }
    static var assignedBy: String { loc.string("assigned_by") }
    static var createdBy: String { loc.string("created_by") }
    static var repeats: String { loc.string("repeats") }
    static var noTasks: String { loc.string("no_tasks") }
    static var noTasksFilter: String { loc.string("no_tasks_filter") }
    static var noTasksScheduled: String { loc.string("no_tasks_scheduled") }
    static var noTasksInGroup: String { loc.string("no_tasks_in_group") }
    static var nothingScheduledToday: String { loc.string("nothing_scheduled_today") }
    static var emptyDayMotivation: String { loc.string("empty_day_motivation") }
    static var addTasksToDay: String { loc.string("add_tasks_to_day") }
    static var scheduled: String { loc.string("scheduled") }
    static var pending: String { loc.string("pending") }
    static var task: String { loc.string("task") }
    static var addTasksToStart: String { loc.string("add_tasks_to_start") }
    
    // Task Actions
    static var startTask: String { loc.string("start_task") }
    static var focus: String { loc.string("focus") }
    static var complete: String { loc.string("complete") }
    static var startFocus: String { loc.string("start_focus") }
    static var pomodoroDescription: String { loc.string("pomodoro_description") }
    
    // Task Status
    static var todo: String { loc.string("todo") }
    static var completed: String { loc.string("completed") }
    static var markComplete: String { loc.string("mark_complete") }
    static var awaitingVerification: String { loc.string("awaiting_verification") }
    static var waitingForVerification: String { loc.string("waiting_for_verification") }
    static var taskCompleted: String { loc.string("task_completed") }
    static var taskStarted: String { loc.string("task_started") }
    
    // Task Stats
    static var totalTasks: String { loc.string("total_tasks") }
    static var progress: String { loc.string("progress") }
    
    // Task Group
    static var deleteGroup: String { loc.string("delete_group") }
    static var deleteTaskGroup: String { loc.string("delete_task_group") }
    static func deleteGroupWarning(_ count: Int) -> String { loc.string("delete_group_warning", count) }
    
    // Delete Confirmation
    static var deleteTask: String { loc.string("delete_task") }
    static var deleteTaskConfirm: String { loc.string("delete_task_confirm") }
    static var actionCannotBeUndone: String { loc.string("action_cannot_be_undone") }
    
    // Priority
    static var low: String { loc.string("low") }
    static var medium: String { loc.string("medium") }
    static var high: String { loc.string("high") }
    static var urgent: String { loc.string("urgent") }
    
    // Rewards & Proof
    static var reward: String { loc.string("reward") }
    static var addReward: String { loc.string("add_reward") }
    static var requiresProof: String { loc.string("requires_proof") }
    static var requireProof: String { loc.string("require_proof") }
    static var proofRequired: String { loc.string("proof_required") }
    static var photoOrVideo: String { loc.string("photo_or_video") }
    static var submitProof: String { loc.string("submit_proof") }
    static var submittedProof: String { loc.string("submitted_proof") }
    static var proofSubmitted: String { loc.string("proof_submitted") }
    static var approved: String { loc.string("approved") }
    static var rejected: String { loc.string("rejected") }
    static var yourTask: String { loc.string("your_task") }
    static var wasApproved: String { loc.string("was_approved") }
    static var yourProofFor: String { loc.string("your_proof_for") }
    static var wasNotAccepted: String { loc.string("was_not_accepted") }
    static var submittedProofFor: String { loc.string("submitted_proof_for") }
    static var youHaveNewTask: String { loc.string("you_have_new_task") }
    static var someone: String { loc.string("someone") }
    static func earnAmount(_ amount: String) -> String { loc.string("earn_amount", amount) }
    static func addProof(_ type: String) -> String { loc.string("add_proof", type) }
    static var showCompletedTask: String { loc.string("show_completed_task") }
    static var photoLabel: String { loc.string("photo") }
    static func verifiedOn(_ date: String) -> String { loc.string("verified_on", date) }
    
    // Progress Messages
    static var noTasksYet: String { loc.string("no_tasks_yet") }
    static var keepGoing: String { loc.string("keep_going") }
    static var almostDone: String { loc.string("almost_done") }
    static var allCompleted: String { loc.string("all_completed") }
    
    // Calendar
    static var noEvents: String { loc.string("no_events") }
    static var noEventsFound: String { loc.string("no_events_found") }
    static var tryDifferentSearch: String { loc.string("try_different_search") }
    static var addEvent: String { loc.string("add_event") }
    static var all: String { loc.string("all") }
    static var today: String { loc.string("today") }
    static var todayExclamation: String { loc.string("today_exclamation") }
    static var allDay: String { loc.string("all_day") }
    static var tomorrow: String { loc.string("tomorrow") }
    static var nextWeek: String { loc.string("next_week") }
    static var eventTitle: String { loc.string("event_title") }
    static var eventDetails: String { loc.string("event_details") }
    static var startDate: String { loc.string("start_date") }
    static var endDate: String { loc.string("end_date") }
    static var starts: String { loc.string("starts") }
    static var ends: String { loc.string("ends") }
    static var date: String { loc.string("date") }
    static var time: String { loc.string("time") }
    static var duration: String { loc.string("duration") }
    static var participants: String { loc.string("participants") }
    static var memberSingular: String { loc.string("member_singular") }
    static var membersPlural: String { loc.string("members_plural") }
    static var clearTime: String { loc.string("clear_time") }
    static var selectTime: String { loc.string("select_time") }
    static var filterByMember: String { loc.string("filter_by_member") }
    static var showAllMembers: String { loc.string("show_all_members") }
    static var searchEvents: String { loc.string("search_events") }
    static var searchEventsDescription: String { loc.string("search_events_description") }
    static var quickJump: String { loc.string("quick_jump") }
    static var travelTime: String { loc.string("travel_time") }
    
    // Travel Time
    static var travelNone: String { loc.string("travel_none") }
    static var travel5Min: String { loc.string("travel_5_min") }
    static var travel15Min: String { loc.string("travel_15_min") }
    static var travel30Min: String { loc.string("travel_30_min") }
    static var travel1Hr: String { loc.string("travel_1_hr") }
    static var travel1Hr30Min: String { loc.string("travel_1hr_30min") }
    static var travel2Hr: String { loc.string("travel_2_hr") }
    
    // Notifications
    static var notifications: String { loc.string("notifications") }
    static var noNotifications: String { loc.string("no_notifications") }
    static var noNotificationsMessage: String { loc.string("no_notifications_message") }
    static var markAllRead: String { loc.string("mark_all_read") }
    static var deleteAll: String { loc.string("delete_all") }
    
    // Time
    static var ago: String { loc.string("ago") }
    static var day: String { loc.string("day") }
    static var days: String { loc.string("days") }
    static func xDays(_ count: Int) -> String { loc.string("x_days", count) }
    static var hour: String { loc.string("hour") }
    static var hours: String { loc.string("hours") }
    static var hr: String { loc.string("hr") }
    static var min: String { loc.string("min") }
    static var minute: String { loc.string("minute") }
    static var minutes: String { loc.string("minutes") }
    static var week: String { loc.string("week") }
    static var weeks: String { loc.string("weeks") }
    static var month: String { loc.string("month") }
    static var months: String { loc.string("months") }
    static var year: String { loc.string("year") }
    static var justNow: String { loc.string("just_now") }
    
    // Recurrence
    static var daily: String { loc.string("daily") }
    static var weekly: String { loc.string("weekly") }
    static var monthly: String { loc.string("monthly") }
    static func everyXDays(_ count: Int) -> String { loc.string("every_x_days", count) }
    static func everyXWeeks(_ count: Int) -> String { loc.string("every_x_weeks", count) }
    static func everyXMonths(_ count: Int) -> String { loc.string("every_x_months", count) }
    static func weeklyOn(_ days: String) -> String { loc.string("weekly_on", days) }
    static func everyXWeeksOn(_ count: Int, _ days: String) -> String {
        String(format: loc.string("every_x_weeks_on"), count, days)
    }
    
    // Day Abbreviations
    static var daySun: String { loc.string("day_sun") }
    static var dayMon: String { loc.string("day_mon") }
    static var dayTue: String { loc.string("day_tue") }
    static var dayWed: String { loc.string("day_wed") }
    static var dayThu: String { loc.string("day_thu") }
    static var dayFri: String { loc.string("day_fri") }
    static var daySat: String { loc.string("day_sat") }
    
    static var dayNames: [String] {
        ["", daySun, dayMon, dayTue, dayWed, dayThu, dayFri, daySat]
    }
    
    // Habits
    static var newHabit: String { loc.string("new_habit") }
    static var habitName: String { loc.string("habit_name") }
    static var habitPlaceholder: String { loc.string("habit_placeholder") }
    static var trackDaily: String { loc.string("track_daily") }
    static var addHabit: String { loc.string("add_habit") }
    static var noHabitsYet: String { loc.string("no_habits_yet") }
    static var noHabitsMessage: String { loc.string("no_habits_message") }
    static var todaysHabits: String { loc.string("todays_habits") }
    static var noHabitsShort: String { loc.string("no_habits_short") }
    static var addHabitsToTrack: String { loc.string("add_habits_to_track") }
    static var timeScopeWeek: String { loc.string("time_scope_week") }
    static var timeScopeMonth: String { loc.string("time_scope_month") }
    static var timeScopeYear: String { loc.string("time_scope_year") }
    
    // Settings
    static var settings: String { loc.string("settings") }
    static var language: String { loc.string("language") }
    static var account: String { loc.string("account") }
    static var version: String { loc.string("version") }
    static var about: String { loc.string("about") }
    static var role: String { loc.string("role") }
    static var updateNews: String { loc.string("updates_news") }
    
    // Photos
    static var takePhoto: String { loc.string("take_photo") }
    static var chooseFromLibrary: String { loc.string("choose_from_library") }
    
    // Navigation & Headers
    static var editProfile: String { loc.string("edit_profile") }
    static var appearance: String { loc.string("appearance") }
    static var chooseTheme: String { loc.string("choose_theme") }
    static var proofLabel: String { loc.string("proof") }
    static var focusTimer: String { loc.string("focus_timer") }
    static var focusSession: String { loc.string("focus_session") }
    
    // Profile & Settings
    static var changePhoto: String { loc.string("change_photo") }
    static var yearlyGoal: String { loc.string("yearly_goal") }
    static var yearlyGoalDescription: String { loc.string("yearly_goal_description") }
    static var yearlyGoalPlaceholder: String { loc.string("yearly_goal_placeholder") }
    static func goalForYear(_ year: String) -> String { loc.string("goal_for_year", year) }
    static var shareCodeMessage: String { loc.string("share_code_message") }
    static var themeColor: String { loc.string("theme_color") }
    static var languageDescription: String { loc.string("language_description") }
    
    // Stats & Counts
    static var stats: String { loc.string("stats") }
    static var rate: String { loc.string("rate") }
    static var recentTasks: String { loc.string("recent_tasks") }
    static func thisYearCount(_ count: Int) -> String { loc.string("this_year_count", count) }
    static func thisMonthCount(_ count: Int) -> String { loc.string("this_month_count", count) }
    static var noOtherMembers: String { loc.string("no_other_members") }
    static var inviteMembersMessage: String { loc.string("invite_members_message") }
    static func xMembers(_ count: Int) -> String { loc.string("x_members", count) }
    
    // Calendar & Events
    static var noEventsThisMonth: String { loc.string("no_events_this_month") }
    static var eventsAndTasksToday: String { loc.string("events_and_tasks_today") }
    static func eventsTasksCount(_ events: Int, _ tasks: Int) -> String {
        loc.string("events_tasks_count", events, tasks)
    }
    static func moreEvents(_ count: Int) -> String { loc.string("more_events", count) }
    static func monthEvents(_ month: String) -> String { loc.string("month_events", month) }
    
    // Focus Timer
    static var minutesLabel: String { loc.string("minutes_label") }
    static var mins: String { loc.string("mins") }
    static func minutesFocusedWork(_ minutes: Int) -> String { loc.string("minutes_focused_work", minutes) }
    static var shortBreak: String { loc.string("short_break") }
    static var longBreak: String { loc.string("long_break") }
    static var completeTask: String { loc.string("complete_task") }
    static var continueLater: String { loc.string("continue_later") }
    static var pomodoroForTask: String { loc.string("pomodoro_for_task") }
    
    // Task Actions Extended
    static var viewProof: String { loc.string("view_proof") }
    static var reject: String { loc.string("reject") }
    static var approveLabel: String { loc.string("approve") }
    static var videoPlayer: String { loc.string("video_player") }
    static func verifiedOnDate(_ date: String) -> String { loc.string("verified_on_date", date) }
    static var deleteTaskLabel: String { loc.string("delete_task_label") }
    
    // Calendar Access
    static var calendarAccess: String { loc.string("calendar_access") }
    static var enableCalendarMessage: String { loc.string("enable_calendar_message") }
    
    // Delete Confirmations
    static func deleteGroupConfirm(_ name: String) -> String { loc.string("delete_group_confirm", name) }
    
    // Heatmap
    static var less: String { loc.string("less") }
    static var moreLabel: String { loc.string("more") }
    
    // Recurrence UI
    static var repeatLabel: String { loc.string("repeat_label") }
    static var createRecurringTask: String { loc.string("create_recurring_task") }
    static var frequency: String { loc.string("frequency") }
    static var daysOfWeek: String { loc.string("days_of_week") }
    static var setEndDate: String { loc.string("set_end_date") }
    
    // Rewards UI
    static var incentivizeCompletion: String { loc.string("incentivize_completion") }
    static var rewardAmount: String { loc.string("reward_amount") }
    static var photoVideoEvidence: String { loc.string("photo_video_evidence") }
    static var proofType: String { loc.string("proof_type") }
    static var skipRewardStep: String { loc.string("skip_reward_step") }
    
    // Tour/Onboarding
    static var skip: String { loc.string("skip") }
    static var back: String { loc.string("back") }
    static var hello: String { loc.string("hello") }
    
    // Misc
    static var uploading: String { loc.string("uploading") }
    static var enable: String { loc.string("enable") }
    static var personal: String { loc.string("personal") }
    static func showMore(_ count: Int) -> String { loc.string("show_more", count) }
    static var showLess: String { loc.string("show_less") }
    static var noTaskGroupsYet: String { loc.string("no_task_groups_yet") }
    static var createTaskGroupsMessage: String { loc.string("create_task_groups_message") }
    static var justStarted: String { loc.string("just_started") }
    static var goodMorning: String { loc.string("good_morning") }
    static var goodAfternoon: String { loc.string("good_afternoon") }
    static var goodEvening: String { loc.string("good_evening") }
    static var night: String { loc.string("night") }
    
    // Auth Extended
    static var continueWithGoogle: String { loc.string("continue_with_google") }
    static var orDivider: String { loc.string("or_divider") }
    
    // Inline Validation
    static var invalidEmailFormat: String { loc.string("invalid_email_format") }
    static var validEmail: String { loc.string("valid_email") }
    static var charactersMinimum: String { loc.string("characters_minimum") }
    static var characters: String { loc.string("characters") }
    static var passwordWeak: String { loc.string("password_weak") }
    static var passwordFair: String { loc.string("password_fair") }
    static var passwordStrong: String { loc.string("password_strong") }
    
    // Edit Screens
    static var editTask: String { loc.string("edit_task") }
    static var editEvent: String { loc.string("edit_event") }
    static var descriptionOptional: String { loc.string("description_optional") }
    static var eventTitlePlaceholder: String { loc.string("event_title_placeholder") }
    
    // Delete Account
    static var deleteAccount: String { loc.string("delete_account") }
    static var deleteAccountPermanent: String { loc.string("delete_account_permanent") }
    static var deleteAccountRemoves: String { loc.string("delete_account_removes") }
    static var tasksUnassignedNote: String { loc.string("tasks_unassigned_note") }
    static func typeToConfirm(_ text: String) -> String { loc.string("type_to_confirm", text) }
    static var typeDeletePlaceholder: String { loc.string("type_delete_placeholder") }
    static var deleteMyAccount: String { loc.string("delete_my_account") }
    static var reenterPassword: String { loc.string("reenter_password") }
    static var confirmAndDelete: String { loc.string("confirm_and_delete") }
    static var deletingAccount: String { loc.string("deleting_account") }
    static var goBack: String { loc.string("go_back") }
    static var dangerZone: String { loc.string("danger_zone") }
    static var dangerZoneDescription: String { loc.string("danger_zone_description") }
    static var signOutConfirm: String { loc.string("sign_out_confirm") }
    
    // Events Extended
    static var newEvent: String { loc.string("new_event") }
    static var deleteEventConfirm: String { loc.string("delete_event_confirm") }
    static var filterEventsPlaceholder: String { loc.string("filter_events_placeholder") }
    
    // Home Sections
    static var thisWeek: String { loc.string("this_week") }
    
    // Profile Sections
    static var basicInfo: String { loc.string("basic_info") }
    static var goalIdeas: String { loc.string("goal_ideas") }
    static var appSection: String { loc.string("app_section") }
    
    // Chat / AI
    static var chat: String { loc.string("chat") }
    static var assistant: String { loc.string("assistant") }
    static var dailyLimitReached: String { loc.string("daily_limit_reached") }
    static func dailyLimitMessage(_ count: Int) -> String { loc.string("daily_limit_message", count) }
    static var assistantName: String { loc.string("assistant_name") }
    static var assistantDescription: String { loc.string("assistant_description") }
    static func messagesRemaining(_ remaining: Int, _ total: Int) -> String {
        loc.string("messages_remaining", remaining, total)
    }
    static var dailyLimitResets: String { loc.string("daily_limit_resets") }
    static var remaining: String { loc.string("remaining") }
    static var retry: String { loc.string("retry") }
    
    static var messagePlaceholder: String { loc.string("message_placeholder") }
    
    // Folders
    static var folders: String { loc.string("folders") }
    static var noFoldersYet: String { loc.string("no_folders_yet") }
    
    // Accessibility Hints
    static var tapToClose: String { loc.string("tap_to_close") }
    static var swipeDeleteHint: String { loc.string("swipe_delete_hint") }
    static var swipeCompleteDeleteHint: String { loc.string("swipe_complete_delete_hint") }
    
    // MARK: - Missing Localizations (PERF-5 audit)
    static var perfect: String { loc.string("perfect") }
    static var openGroup: String { loc.string("open_group") }
    static var addNewItem: String { loc.string("add_new_item") }
    static var viewSelector: String { loc.string("view_selector") }
    static var rename: String { loc.string("rename") }
    
    // MARK: - Task Assignment Notifications
    static func assignedYouTask(_ assigner: String, _ taskTitle: String) -> String { loc.string("assigned_you_task", assigner, taskTitle) }
    static func youAssignedTask(_ assignee: String, _ taskTitle: String) -> String { loc.string("you_assigned_task", assignee, taskTitle) }
    static var taskAssignment: String { loc.string("task_assignment") }
    static var taskRemoved: String { loc.string("task_removed") }
    static func memberRemovedTask(_ member: String, _ taskTitle: String) -> String { loc.string("member_removed_task", member, taskTitle) }
    
    // MARK: - Event Notifications
    static func addedYouToEvent(_ creator: String, _ eventTitle: String, _ date: String) -> String { loc.string("added_you_to_event", creator, eventTitle, date) }
    static func youCreatedEvent(_ eventTitle: String, _ date: String) -> String { loc.string("you_created_event", eventTitle, date) }
    
    // MARK: - Reminder Notifications
    static var taskDueTomorrow: String { loc.string("task_due_tomorrow") }
    static func taskDueTomorrowBody(_ title: String) -> String { loc.string("task_due_tomorrow_body", title) }
    static var taskDueSoon: String { loc.string("task_due_soon") }
    static func taskDueSoonBody(_ title: String) -> String { loc.string("task_due_soon_body", title) }
    static func taskStartedBody(_ performer: String, _ title: String) -> String { loc.string("task_started_body", performer, title) }
    static func proofSubmittedBody(_ performer: String, _ title: String) -> String { loc.string("proof_submitted_body", performer, title) }
    static func taskCompletedBody(_ performer: String, _ title: String) -> String { loc.string("task_completed_body", performer, title) }
    static var eventTomorrow: String { loc.string("event_tomorrow") }
    static func eventTomorrowBody(_ title: String) -> String { loc.string("event_tomorrow_body", title) }
    static var eventStartingSoon: String { loc.string("event_starting_soon") }
    static func eventStartingSoonBody(_ title: String) -> String { loc.string("event_starting_soon_body", title) }
    
    // MARK: - Hybrid Notification Keys
    static var taskCompletedNotif: String { loc.string("task_completed_notif") }
    static func taskCompletedNotifBody(_ performer: String, _ title: String) -> String { loc.string("task_completed_notif_body", performer, title) }
    static var taskUpdatedNotif: String { loc.string("task_updated_notif") }
    static func taskUpdatedNotifBody(_ title: String) -> String { loc.string("task_updated_notif_body", title) }
    static var taskReassignedNotif: String { loc.string("task_reassigned_notif") }
    static func taskReassignedNotifBody(_ title: String) -> String { loc.string("task_reassigned_notif_body", title) }
    static var taskOverdueNotif: String { loc.string("task_overdue_notif") }
    static func taskOverdueNotifBody(_ title: String) -> String { loc.string("task_overdue_notif_body", title) }
    static var eventUpdatedNotif: String { loc.string("event_updated_notif") }
    static func eventUpdatedNotifBody(_ title: String) -> String { loc.string("event_updated_notif_body", title) }
    static var eventCanceledNotif: String { loc.string("event_canceled_notif") }
    static func eventCanceledNotifBody(_ title: String, _ canceler: String) -> String { loc.string("event_canceled_notif_body", title, canceler) }
    
    //
    //  LocalizationManager - ADDITIONS
    //
    //  Add these L10n accessors to the existing L10n struct in LocalizationManager.swift
    //  (Add after the existing entries, before the closing brace)
    //
    
    // MARK: - Welcome Slides (Phase 1 Onboarding)
    static var welcomeSlide1Headline: String { loc.string("welcome_slide_1_headline") }
    static var welcomeSlide1Subheadline: String { loc.string("welcome_slide_1_subheadline") }
    static var welcomeSlide2Headline: String { loc.string("welcome_slide_2_headline") }
    static var welcomeSlide2Subheadline: String { loc.string("welcome_slide_2_subheadline") }
    static var welcomeSlide3Headline: String { loc.string("welcome_slide_3_headline") }
    static var welcomeSlide3Subheadline: String { loc.string("welcome_slide_3_subheadline") }
    static var welcomeSlide4Headline: String { loc.string("welcome_slide_4_headline") }
    static var welcomeSlide4Subheadline: String { loc.string("welcome_slide_4_subheadline") }
    static var getStarted: String { loc.string("get_started") }
    static var swipeToContinue: String { loc.string("swipe_to_continue") }
    
    // MARK: - First Success Tour (Phase 3 Onboarding)
    static var tourFirstSuccessName: String { loc.string("tour_first_success_name") }
    static var tourWelcomeTitle: String { loc.string("tour_welcome_title") }
    static var tourWelcomeMessage: String { loc.string("tour_welcome_message") }
    static var tourCreateTaskTitle: String { loc.string("tour_create_task_title") }
    static var tourCreateTaskMessage: String { loc.string("tour_create_task_message") }
    static var tourAddTaskTitle: String { loc.string("tour_add_task_title") }
    static var tourAddTaskMessage: String { loc.string("tour_add_task_message") }
    static var tourHabitsTitle: String { loc.string("tour_habits_title") }
    static var tourHabitsMessage: String { loc.string("tour_habits_message") }
    static var tourCompleteTitle: String { loc.string("tour_complete_title") }
    static var tourCompleteMessage: String { loc.string("tour_complete_message") }
    
    // MARK: - Quick Setup Tour
    static var tourQuickStartName: String { loc.string("tour_quick_start_name") }
    static var tourDashboardTitle: String { loc.string("tour_dashboard_title") }
    static var tourDashboardMessage: String { loc.string("tour_dashboard_message") }
    static var tourAssistantTitle: String { loc.string("tour_assistant_title") }
    static var tourAssistantMessage: String { loc.string("tour_assistant_message") }
    static var tourInviteFamilyTitle: String { loc.string("tour_invite_family_title") }
    static var tourInviteFamilyMessage: String { loc.string("tour_invite_family_message") }
    // Task Type
    static var taskTypeChore: String { loc.string("task_type_chore") }
    static var taskTypeHomework: String { loc.string("task_type_homework") }

    // Homework Subjects
    static var subjectMath: String { loc.string("subject_math") }
    static var subjectLanguage: String { loc.string("subject_language") }
    static var subjectReading: String { loc.string("subject_reading") }
    static var subjectScience: String { loc.string("subject_science") }
    static var subjectOther: String { loc.string("subject_other") }

    // AI Verification
    static var aiWillIdentifySubject: String { loc.string("ai_will_identify_subject") }
    static var aiVerifying: String { loc.string("ai_verifying") }
    static var aiVerified: String { loc.string("ai_verified") }

    // Task Form
    static var taskName: String { loc.string("task_name") }
    static var incentives: String { loc.string("incentives") }
    static var assignedToMe: String { loc.string("assigned_to_me") }
    static var createTask: String { loc.string("create_task") }
    static var taskCreated: String { loc.string("task_created") }
    static var videoLabel: String { loc.string("video_label") }
    static var proofAutoEnabledHint: String { loc.string("proof_auto_enabled_hint") }
    static var thisWeekend: String { loc.string("this_weekend") }
    static var subjectLabel: String { loc.string("subject_label") }
    // Priority Time
    static var overdue: String { loc.string("overdue") }
    static var dueTomorrow: String { loc.string("due_tomorrow") }
    static func dueInMinutes(_ count: Int) -> String { loc.string("due_in_minutes", count) }
    static func dueInHours(_ count: Int) -> String { loc.string("due_in_hours", count) }
    static func dueInDays(_ count: Int) -> String { loc.string("due_in_days", count) }
    
    
    // Event Creation - Progressive Disclosure
    static var eventWhatHappening: String { loc.string("event_what_happening") }

    static var eventCreated: String { loc.string("event_created") }
    static var eventUpdated: String { loc.string("event_updated") }
    
    // Quick Time Chips
    static var tonight: String { loc.string("tonight") }
 
    static var change: String { loc.string("change") }
    
    // Collapsible Fields
    static var addParticipants: String { loc.string("add_participants") }
    static var addNotes: String { loc.string("add_notes") }
    static var moreOptions: String { loc.string("more_options") }
    
    // Event Detail
    static var todayAllDay: String { loc.string("today_all_day") }
    static var tomorrowAllDay: String { loc.string("tomorrow_all_day") }
    static var yesterday: String { loc.string("yesterday") }


    // Reward Wallet - Unified
    static var rewardWallet: String { loc.string("reward_wallet") }
    static var recentEarnings: String { loc.string("recent_earnings") }
    static var whoOwesYou: String { loc.string("who_owes_you") }
    static var owesYou: String { loc.string("owes_you") }
    static var payoutRequestsToYou: String { loc.string("payout_requests_to_you") }
    static var payoutRequested: String { loc.string("payout_requested") }
    static var requestedPayout: String { loc.string("requested_payout") }
    static var requested: String { loc.string("requested") }
    static var paid: String { loc.string("paid") }
    
    // Format functions
    static func earnedFromTasks(_ count: Int) -> String { loc.string("earned_from_tasks", count) }
    static func fromPerson(_ name: String) -> String { loc.string("from_person", name) }
    static func requestedFrom(_ name: String) -> String { loc.string("requested_from", name) }
    static func payAmount(_ amount: String) -> String { loc.string("pay_amount", amount) }
    // Reward Notifications
    static var payoutRequest: String { loc.string("payout_request") }
    static var payoutApproved: String { loc.string("payout_approved") }
    static var payoutRejected: String { loc.string("payout_rejected") }
    static var rewardEarned: String { loc.string("reward_earned") }
    
    static func requestedPayoutFrom(_ name: String, _ amount: Int) -> String {
        loc.string("requested_payout_from", name, amount)
    }
    static func payoutApprovedBody(_ name: String, _ amount: Int) -> String {
        loc.string("payout_approved_body", name, amount)
    }
    static func payoutRejectedBody(_ name: String, _ amount: Int) -> String {
        loc.string("payout_rejected_body", name, amount)
    }
    static func rewardEarnedBody(_ amount: Int, _ task: String, _ from: String) -> String {
        loc.string("reward_earned_body", amount, task, from)
    }



    // MARK: - Tour Completion
    static var tourAllSetTitle: String { loc.string("tour_all_set_title") }
    static var tourAllSetMessage: String { loc.string("tour_all_set_message") }
    static var letsGo: String { loc.string("lets_go") }
    // Habit Stats
    static func thisWeekHabits(_ completed: Int, _ total: Int) -> String {
        loc.string("this_week_habits", completed, total)
    }
    
    // MARK: - Plural Helpers
    static func pluralMembers(_ count: Int) -> String {
        count == 1 ? memberSingular : membersPlural
    }
    
    static func membersCount(_ count: Int) -> String {
        "\(count) \(pluralMembers(count))"
    }

    // ════════════════════════════════════════════════════════════════
    // MARK: - Phase 5 Localization Extraction (163 new keys)
    // ════════════════════════════════════════════════════════════════

    // ACTION
    static var actionCompletedSuccessfully: String { loc.string("action_completed_successfully") }
    static var actionFailed: String { loc.string("action_failed") }
    static var confirmAction: String { loc.string("confirm_action") }
    static var confirmBtn: String { loc.string("confirm") }
    static var processingEllipsis: String { loc.string("processing") }

    // AI
    static var aiAnalysis: String { loc.string("ai_analysis") }
    static var aiCredits: String { loc.string("ai_credits") }
    static var aiProvidesSuggestionsOnly: String { loc.string("ai_provides_suggestions_only__you_make_the_final_d") }
    static var aiSuggestion: String { loc.string("ai_suggestion") }
    static var aiUsage: String { loc.string("ai_usage") }
    static var betaLabel: String { loc.string("beta") }
    static var buyCredits: String { loc.string("buy_credits") }
    static var creditsLabel: String { loc.string("credits") }
    static var currentBalance: String { loc.string("current_balance") }
    static var dailyLimit: String { loc.string("daily_limit") }
    static var maiLabel: String { loc.string("mai") }
    static var messagesRemainingToday: String { loc.string("messages_remaining_today") }
    static var purchaseBtn: String { loc.string("purchase") }
    static var suggestionsOnlyYouDecide: String { loc.string("suggestions_only__you_decide") }
    static var unlimitedLabel: String { loc.string("unlimited") }
    static var upgradeBtn: String { loc.string("upgrade") }
    static var upgradeForMore: String { loc.string("upgrade_for_more") }
    static var youHaveCredits: String { loc.string("you_have_credits") }

    // CHAT
    static var aiAssistant: String { loc.string("ai_assistant") }
    static var askMaiAnything: String { loc.string("ask_mai_anything") }
    static var clearChat: String { loc.string("clear_chat") }
    static var creditsAvailable: String { loc.string("credits_available") }
    static var newChat: String { loc.string("new_chat") }
    static var sendMessage: String { loc.string("send_message") }
    static var typeAMessage: String { loc.string("type_a_message") }
    static var useCredit: String { loc.string("use_credit") }

    // COMMON
    static var aboutLabel: String { loc.string("about") }
    static var addPhotos: String { loc.string("add_photos") }
    static var allLabel: String { loc.string("all") }
    static var analyzingHomeworkWithAi: String { loc.string("analyzing_homework_with_ai") }
    static var appearanceLabel: String { loc.string("appearance") }
    static var approveBtn: String { loc.string("approve") }
    static var areasToReview: String { loc.string("areas_to_review") }
    static var assignedByLabel: String { loc.string("assigned_by") }
    static var assignedToLabel: String { loc.string("assigned_to") }
    static var backLabel: String { loc.string("back") }
    static var balanceLabel: String { loc.string("balance") }
    static var bestValue: String { loc.string("best_value") }
    static var calendarLabel: String { loc.string("calendar") }
    static var chatLabel: String { loc.string("chat") }
    static var closeLabel: String { loc.string("close_label") }
    static var confidenceLabel: String { loc.string("confidence") }
    static var continueBtn: String { loc.string("continue") }
    static var correctLabel: String { loc.string("correct") }
    static var dateJoined: String { loc.string("date_joined") }
    static var deleteAccountLabel: String { loc.string("delete_account_label") }
    static var descriptionLabel: String { loc.string("description") }
    static var disclaimerLabel: String { loc.string("disclaimer") }
    static var dueDateLabel: String { loc.string("due_date") }
    static var editLabel: String { loc.string("edit_label") }
    static var emailLabel: String { loc.string("email_label") }
    static var encouragementLabel: String { loc.string("encouragement") }
    static var enhancingImage: String { loc.string("enhancing_image") }
    static var errorLabel: String { loc.string("error_label") }
    static var expectedAnswer: String { loc.string("expected_answer") }
    static var familyLabel: String { loc.string("family") }
    static var filterLabel: String { loc.string("filter") }
    static var freeTrial: String { loc.string("free_trial") }
    static var habitsLabel: String { loc.string("habits") }
    static var homeLabel: String { loc.string("home") }
    static var homeworkCheck: String { loc.string("homework_check") }
    static var imageQualityWarning: String { loc.string("image_quality_may_affect_verification_accuracy") }
    static var incorrectLabel: String { loc.string("incorrect") }
    static var itemsSelected: String { loc.string("items_selected") }
    static var languageLabel: String { loc.string("language") }
    static var loadingEventsEllipsis: String { loc.string("loading_events") }
    static var loadingHabitsEllipsis: String { loc.string("loading_habits") }
    static var loadingTasksEllipsis: String { loc.string("loading_tasks") }
    static var memberDetails: String { loc.string("member_details") }
    static var monthlyLabel: String { loc.string("monthly") }
    static var needsReviewLabel: String { loc.string("needs_review") }
    static var nextLabel: String { loc.string("next") }
    static var noTextDetectedInImage: String { loc.string("no_text_detected_in_image") }
    static var noteLabel: String { loc.string("note") }
    static var notificationsLabel: String { loc.string("notifications_label") }
    static var overviewLabel: String { loc.string("overview") }
    static var overdueLabel: String { loc.string("overdue") }
    static var perMonth: String { loc.string("per_month") }
    static var perYear: String { loc.string("per_year") }
    static var premiumLabel: String { loc.string("premium") }
    static var previousLabel: String { loc.string("previous") }
    static var priorityLabel: String { loc.string("priority") }
    static var processingImage: String { loc.string("processing_image") }
    static var profileLabel: String { loc.string("profile") }
    static var proofImage: String { loc.string("proof_image") }
    static var questionLabel: String { loc.string("question") }
    static var questionsLabel: String { loc.string("questions") }
    static var rejectBtn: String { loc.string("reject") }
    static var removeLabel: String { loc.string("remove") }
    static var restorePurchases: String { loc.string("restore_purchases") }
    static var retryLabel: String { loc.string("retry") }
    static var retryVerification: String { loc.string("retry_verification") }
    static var rewardLabel: String { loc.string("reward") }
    static var rewardsLabel: String { loc.string("rewards") }
    static var roleLabel: String { loc.string("role") }
    static var scoreLabel: String { loc.string("score") }
    static var searchLabel: String { loc.string("search") }
    static var settingsLabel: String { loc.string("settings") }
    static var signOutLabel: String { loc.string("sign_out") }
    static var sortLabel: String { loc.string("sort") }
    static var statusLabel: String { loc.string("status") }
    static var studentAnswer: String { loc.string("student_answer") }
    static var submitBtn: String { loc.string("submit") }
    static var summaryLabel: String { loc.string("summary") }
    static var taskLabel: String { loc.string("task") }
    static var tasksAssigned: String { loc.string("tasks_assigned") }
    static var tasksCompleted: String { loc.string("tasks_completed") }
    static var tasksLabel: String { loc.string("tasks") }
    static var thisMayTakeAMoment: String { loc.string("this_may_take_a_moment") }
    static var tryAgain: String { loc.string("try_again") }
    static var uncertainLabel: String { loc.string("uncertain") }
    static var unlockPremium: String { loc.string("unlock_premium") }
    static var uploadFiles: String { loc.string("upload_files") }
    static var uploadingEllipsis: String { loc.string("uploading") }
    static var versionLabel: String { loc.string("version") }
    static var verifyNow: String { loc.string("verify_now") }
    static var verifyingEllipsis: String { loc.string("verifying") }
    static var yearlyLabel: String { loc.string("yearly") }

    // PROFILE
    static var personalGoal: String { loc.string("personal_goal") }
    static var saveChanges: String { loc.string("save_changes") }

    // TASK
    static var tasksCompletedLabel: String { loc.string("tasks_completed_label") }

    // VERIFICATION
    static var cannotVerify: String { loc.string("cannot_verify") }
    static var looksCorrect: String { loc.string("looks_correct") }
    static var unclearLabel: String { loc.string("unclear_label") }
    static var likelyCorrectLabel: String { loc.string("likely_correct") }
    static var likelyIncorrectLabel: String { loc.string("likely_incorrect") }
    static var verificationFailed: String { loc.string("verification_failed") }
    
    // MARK: - Task Detail Verification UI (added for TaskDetailView.swift)
    static var needsAttention: String { loc.string("needs_attention") }
    static var answer: String { loc.string("answer") }
    static var expected: String { loc.string("expected") }
    static var verified: String { loc.string("verified") }

    // ════════════════════════════════════════════════════════════════
    // MARK: - Missing Keys (Build Fix - 113 properties)
    // ════════════════════════════════════════════════════════════════
    
    // Common/UI
    static var active: String { loc.string("active") }
    static var activeTasks: String { loc.string("active_tasks") }
    static var addMore: String { loc.string("add_more") }
    static var addProofOfCompletion: String { loc.string("add_proof_of_completion") }
    static var allCaughtUp: String { loc.string("all_caught_up") }
    static var analysis: String { loc.string("analysis") }
    static var approve: String { loc.string("approve") }
    static var beta: String { loc.string("beta") }
    static var clearAll: String { loc.string("clear_all") }
    static var clearSchedule: String { loc.string("clear_schedule") }
    static var confirm: String { loc.string("confirm") }
    static var createEvent: String { loc.string("create_event") }
    static var credits: String { loc.string("credits") }
    static var details: String { loc.string("details") }
    static var dynamicTypeTest: String { loc.string("dynamic_type_test") }
    static var enhanced: String { loc.string("enhanced") }
    static var filterEventsTasks: String { loc.string("filter_events_tasks") }
    static var focusNow: String { loc.string("focus_now") }
    static var getMore: String { loc.string("get_more") }
    static var manageSubscription: String { loc.string("manage_subscription") }
    static var plan: String { loc.string("plan") }
    static var printReport: String { loc.string("print_report") }
    static var questionDetails: String { loc.string("question_details") }
    static var reassignTask: String { loc.string("reassign_task") }
    static var reviewManually: String { loc.string("review_manually") }
    static var save33: String { loc.string("save_33") }
    static var schedule: String { loc.string("schedule") }
    static var searchTasks: String { loc.string("search_tasks") }
    static var start: String { loc.string("start") }
    static var student: String { loc.string("student") }
    static var subscribe: String { loc.string("subscribe") }
    static var subscription: String { loc.string("subscription") }
    static var suggestion: String { loc.string("suggestion") }
    static var tabBar: String { loc.string("tab_bar") }
    static var toDo: String { loc.string("to_do") }
    static var todayTomorrow: String { loc.string("today_tomorrow") }
    static var type: String { loc.string("type") }
    static var updateStatus: String { loc.string("update_status") }
    static var updateTask: String { loc.string("update_task") }
    static var upgrade: String { loc.string("upgrade") }
    static var upgradeToPremium: String { loc.string("upgrade_to_premium") }
    static var useAnyway: String { loc.string("use_anyway") }
    static var whatYouGet: String { loc.string("what_you_get") }
    static var yourDecision: String { loc.string("your_decision") }
    
    // AI/MAI Related
    static var aiAssistantIsTemporarilyUnavailable: String { loc.string("ai_assistant_is_temporarily_unavailable") }
    static var aiConfidence: String { loc.string("ai_confidence") }
    static var aiServiceTemporarilyUnavailablePleaseTryAgai: String { loc.string("ai_service_temporarily_unavailable_please_try_again") }
    static var analyzingHomework: String { loc.string("analyzing_homework") }
    static var analyzingHomeworkPleaseWait: String { loc.string("analyzing_homework_please_wait") }
    static var getMaiRecommendationToHelpYouReviewThisHom: String { loc.string("get_mai_recommendation_to_help_you_review_this_homework") }
    static var getMaiSuggestion: String { loc.string("get_mai_suggestion") }
    static var lowAiConfidencePleaseReviewCarefully: String { loc.string("low_ai_confidence_please_review_carefully") }
    static var lowConfidenceAnalysis: String { loc.string("low_confidence_analysis") }
    static var mai: String { loc.string("mai") }
    static var maiEstimate: String { loc.string("mai_estimate") }
    static var maiLimitations: String { loc.string("mai_limitations") }
    static var maiMayMakeMistakesReadingHandwritingOrSolvi: String { loc.string("mai_may_make_mistakes_reading_handwriting_or_solving") }
    static var maiSuggests: String { loc.string("mai_suggests") }
    static var maiWillCheckYourWork: String { loc.string("mai_will_check_your_work") }
    static var manualReviewStronglyRecommended: String { loc.string("manual_review_strongly_recommended") }
    static var onlyYouCanApproveOrRejectAiCannotMakeThis: String { loc.string("only_you_can_approve_or_reject_ai_cannot_make_this") }
    static var optimizingForMai: String { loc.string("optimizing_for_mai") }
    static var parentWillReview: String { loc.string("parent_will_review") }
    static var pleaseReviewTheHomeworkManually: String { loc.string("please_review_the_homework_manually") }
    static var readingHandwritingCheckingAnswers: String { loc.string("reading_handwriting_checking_answers") }
    static var rememberMaiSuggestionsMayBeInaccurate: String { loc.string("remember_mai_suggestions_may_be_inaccurate") }
    static var suggestedPracticeAreas: String { loc.string("suggested_practice_areas") }
    static var verifyHomework: String { loc.string("verify_homework") }
    static var maiAnalysis: String { loc.string("mai_analysis") }
    static var maiMayMakeMistakesParentHasFinalSay: String { loc.string("mai_may_make_mistakes_parent_has_final_say") }
    static var checkingHomework: String { loc.string("checking_homework") }
    static var maiCouldntAnalyzePleaseReviewManually: String { loc.string("mai_couldnt_analyze_please_review_manually") }
    static var reviewThePhotoAndDecideIfTheChoreIsDone: String { loc.string("review_the_photo_and_decide_if_the_chore_is_done") }
    static var needsRedo: String { loc.string("needs_redo") }
    
    // Verification Status
    static var likelyCorrect: String { loc.string("likely_correct") }
    static var likelyIncorrect: String { loc.string("likely_incorrect") }
    static var needsReview: String { loc.string("needs_review") }
    static var needsReviewStringlocalized: String { loc.string("needs_review") }
    static var uncertain: String { loc.string("uncertain") }
    static var unclear: String { loc.string("unclear") }
    static var couldNotAnalyze: String { loc.string("could_not_analyze") }
    static var unableToAnalyzePleaseReviewManually: String { loc.string("unable_to_analyze_please_review_manually") }
    static var verificationFailedPleaseReviewManually: String { loc.string("verification_failed_please_review_manually") }
    static var warningLowConfidenceAnalysisManualReviewStro: String { loc.string("warning_low_confidence_analysis_manual_review_strongly") }
    
    // Error Messages
    static var connectionFailedPleaseTryAgain: String { loc.string("connection_failed_please_try_again") }
    static var couldNotProcessImagePleaseTryAClearerPhoto: String { loc.string("could_not_process_image_please_try_a_clearer_photo") }
    static var failedToProcessImage: String { loc.string("failed_to_process_image") }
    static var imageTooLargePleaseUseASmallerImage: String { loc.string("image_too_large_please_use_a_smaller_image") }
    static var invalidResponseFromServer: String { loc.string("invalid_response_from_server") }
    static var nothingToRetry: String { loc.string("nothing_to_retry") }
    static var requestTimedOut: String { loc.string("request_timed_out") }
    static var requestTimedOutPleaseTryAgain: String { loc.string("request_timed_out_please_try_again") }
    static var serviceTemporarilyUnavailable: String { loc.string("service_temporarily_unavailable") }
    static var somethingWentWrongPleaseTryAgain: String { loc.string("something_went_wrong_please_try_again") }
    static var thisImageMayNotContainReadableHomeworkTheA: String { loc.string("this_image_may_not_contain_readable_homework_the_analysis") }
    static var noTextDetected: String { loc.string("no_text_detected") }
    static var noProofImageFoundForThisTask: String { loc.string("no_proof_image_found_for_this_task") }
    
    // Empty States
    static var enjoyAPeacefulWeek: String { loc.string("enjoy_a_peaceful_week") }
    static var noUrgentTasksRightNow: String { loc.string("no_urgent_tasks_right_now") }
    static var nothingScheduledForTodayOrTomorrow: String { loc.string("nothing_scheduled_for_today_or_tomorrow") }
    static var thisDayIsClear: String { loc.string("this_day_is_clear") }
    
    // Credits/Subscription
    static var buyCreditsToKeepChattingCreditsNeverExpire: String { loc.string("buy_credits_to_keep_chatting_credits_never_expire") }
    static var dailyVerificationLimitReachedTryAgainTomorro: String { loc.string("daily_verification_limit_reached_try_again_tomorrow") }
    static var messageLimitReached: String { loc.string("message_limit_reached") }
    static var moreMessagesSmarterAiAndUnlimitedPotentialF: String { loc.string("more_messages_smarter_ai_and_unlimited_potential_for") }
    static var needMoreMessages: String { loc.string("need_more_messages") }
    static var orUpgradeToPremiumFor300day: String { loc.string("or_upgrade_to_premium_for_3_00_day") }
    static var paymentWillBeChargedToYourAppleIdAccountS: String { loc.string("payment_will_be_charged_to_your_apple_id_account_subscription") }
    static var unlockTheFullMaiExperience: String { loc.string("unlock_the_full_mai_experience") }
    static var youveUsedAllYourMessagesForTodayTryAgainT: String { loc.string("youve_used_all_your_messages_for_today_try_again_tomorrow") }
    
    // Proof/Homework
    static var homeworkProofImage: String { loc.string("homework_proof_image") }
    static var tipsForHomeworkPhotos: String { loc.string("tips_for_homework_photos") }
    static var uploadPhotosVideosOrDocumentsToShowYourWor: String { loc.string("upload_photos_videos_or_documents_to_show_your_work") }
    
    // Auth
    static var pleaseSignInToChat: String { loc.string("please_sign_in_to_chat") }
    static var pleaseSignInToVerifyHomework: String { loc.string("please_sign_in_to_verify_homework") }
    
    // Action Confirmation
    static var actionCancelledLetMeKnowIfYoudLikeToTryS: String { loc.string("action_cancelled_let_me_know_if_youd_like_to_try_something") }
    static var thisActionWillBePerformedAfterYouConfirm: String { loc.string("this_action_will_be_performed_after_you_confirm") }
    
    // Misc/Debug
    static var xxx: String { loc.string("xxx") }
    static var zZZ: String { loc.string("zzz") }
    
    // Number formatting placeholder (used in code)
    static var _100: String { "100" }

    // ════════════════════════════════════════════════════════════════
    // MARK: - Format Functions (interpolated strings)
    // ════════════════════════════════════════════════════════════════

    static func dailyLimitUsedWithCredits(_ limit: Int, _ credits: Int) -> String {
        loc.string("daily_limit_used_with_credits", limit, credits)
    }
    static func dailyLimitUsed(_ limit: Int) -> String {
        loc.string("daily_limit_used", limit)
    }
    static func usingCreditsRemaining(_ count: Int) -> String {
        loc.string("using_credits_remaining", count)
    }
    static func dailyAiActionsUsed(_ count: Int) -> String {
        loc.string("daily_ai_actions_used", count)
    }
    static func questionNumberShort(_ num: String) -> String {
        loc.string("question_number_short", num)
    }
    static func goalForYear(_ year: Int) -> String {
        loc.string("goal_for_year", year)
    }
    static func questionNumberWithText(_ num: String, _ text: String) -> String {
        loc.string("question_number_with_text", num, text)
    }
    static func questionNumberLabel(_ num: String) -> String {
        loc.string("question_number_label", num)
    }
    static func aiUnavailableRetrySeconds(_ seconds: Int) -> String {
        loc.string("ai_unavailable_retry_seconds", seconds)
    }
    static func maiUnavailableRetrySeconds(_ seconds: Int) -> String {
        loc.string("mai_unavailable_retry_seconds", seconds)
    }
    static func aiServiceUnavailableRetry(_ seconds: Int) -> String {
        loc.string("ai_service_unavailable_retry", seconds)
    }
}
