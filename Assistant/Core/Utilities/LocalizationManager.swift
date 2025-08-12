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

enum AppLanguage: String, CaseIterable, Identifiable {
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
        case .chinese: return "Chinese"
        }
    }
    
    var shortName: String {
        switch self {
        case .system:  return "System"
        case .english: return "English"
        case .spanish: return "Español"
        case .chinese: return "Chinese"
        }
    }
}

// MARK: - Localization Manager

final class LocalizationManager: ObservableObject {
    static let shared = LocalizationManager()
    
    private let languageKey = "app_language_preference"
    
    @Published private(set) var currentLanguage: String
    @Published private(set) var selectedLanguage: AppLanguage
    
    /// The .lproj bundle for the active language.
    /// `nil` only if the .lproj folder is missing from the app bundle.
    private(set) var bundle: Bundle
    
    // MARK: - Init
    
    private init() {
        let saved = UserDefaults.standard.string(forKey: languageKey) ?? "system"
        let language = AppLanguage(rawValue: saved) ?? .system
        let resolved = language == .system
        ? Self.resolveSystemLanguage()
        : language.rawValue
        
        self.selectedLanguage = language
        self.currentLanguage = resolved
        self.bundle = Self.loadBundle(for: resolved)
    }
    
    // MARK: - Language Switching
    
    func setLanguage(_ language: AppLanguage) {
        selectedLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: languageKey)
        
        currentLanguage = language == .system
        ? Self.resolveSystemLanguage()
        : language.rawValue
        
        bundle = Self.loadBundle(for: currentLanguage)
        objectWillChange.send()
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
        ? AppLanguage(rawValue: currentLanguage)?.displayName ?? "English"
        : selectedLanguage.displayName
    }
    
    var currentLanguageShortName: String {
        AppLanguage(rawValue: currentLanguage)?.shortName ?? "English"
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
}
