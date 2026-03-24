// ============================================================================
// FamilyTask.swift
//
// PURPOSE:
//   The core task model. Represents a unit of work assigned within a family —
//   from a simple chore to a recurring homework task with reward and photo proof.
//
// FIRESTORE COLLECTION: `tasks`
//   - Family-scoped (filtered by `familyId`).
//   - Queried by `dueDate` with a composite index (familyId ASC + dueDate ASC).
//   - Bounded query: last 30 days + future, max 200 documents (see TaskViewModel).
//
//   Same pattern for proof: `proofURL` (v1) and `proofURLs` (v2).
//   Use `allProofURLs` — never read raw fields directly.
//
// FOCUS TRACKING:
//   Tasks optionally track Pomodoro focus sessions. Aggregated stats
//   (totalFocusedSeconds, lastFocusDate) live on the task document.
//   Individual sessions live in a `focusSessions` subcollection.


import Foundation
import FirebaseFirestore
import SwiftUI

struct FamilyTask: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var familyId: String
    var groupId: String?
    var title: String
    var description: String?
    
    // MARK: - Stable ID for SwiftUI ForEach
    
    var stableId: String {
        id ?? "pending-\(familyId)-\(title.hashValue)-\(Int(createdAt.timeIntervalSince1970))"
    }
    
    // MARK: - Assignee Support
    
    var assignedTo: String?
    var assignees: [String]
    var assignedBy: String
    var dueDate: Date
    var scheduledTime: Date?
    var status: TaskStatus
    var priority: TaskPriority
    var createdAt: Date
    var completedAt: Date?
    
    // MARK: - Reward System
    
    var hasReward: Bool
    var rewardAmount: Double?
    var requiresProof: Bool
    var proofType: ProofType?
    var proofURL: String?
    var proofURLs: [String]?
    var proofVerifiedBy: String?
    var proofVerifiedAt: Date?
    var rewardPaid: Bool
    
    // MARK: - Recurrence
    
    var isRecurring: Bool
    var recurrenceRule: RecurrenceRule?
    
    // MARK: - Focus/Pomodoro Tracking
    
    var pomodoroDurationMinutes: Int?
    var totalFocusedSeconds: Int?
    var lastFocusDate: Date?
    
    // MARK: - Task Type & AI Verification
    
    var taskType: TaskType?
    var homeworkSubject: HomeworkSubject?
    var aiVerification: AIVerification?
    var aiVerificationStatus: String?
    
    // MARK: - Enums
    
    enum TaskStatus: String, Codable, CaseIterable {
        case todo = "to_do"
        case inProgress = "in_Progress"
        case pendingVerification = "Pending_Verification"
        case completed = "Completed"
        
        var displayName: String {
            switch self {
            case .todo: return "to_do"
            case .inProgress: return "in_Progress"
            case .pendingVerification: return "pending_Verification"
            case .completed: return "completed"
            }
        }
        
        var icon: String {
            switch self {
            case .todo: return "circle"
            case .inProgress: return "play.circle"
            case .pendingVerification: return "clock"
            case .completed: return "checkmark.circle.fill"
            }
        }
        
        /// Semantic color for this task status.
        /// Centralizes the status→color mapping that was duplicated across 20+ files.
        var color: Color {
            switch self {
            case .todo: return Color.statusTodo
            case .inProgress: return Color.statusInProgress
            case .pendingVerification: return Color.statusPending
            case .completed: return Color.statusCompleted
            }
        }
    }
    
    enum TaskPriority: String, Codable, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"
        case urgent = "Urgent"
        
        var displayName: String {
            switch self {
            case .low: return "low"
            case .medium: return "medium"
            case .high: return "high"
            case .urgent: return "urgent"
            }
        }
        
        /// Semantic color for this priority level.
        /// Centralizes the priority→color mapping that was duplicated across files.
        var color: Color {
            switch self {
            case .urgent: return Color.statusError
            case .high: return Color.accentOrange
            case .medium: return Color.statusWarning
            case .low: return Color.statusSuccess
            }
        }
    }
    
    
    enum ProofType: String, Codable, CaseIterable {
        case photo = "Photo"
        case video = "Video"
        case document = "Document"
        case any = "Any"
        
        var displayName: String {
            switch self {
            case .photo: return "Photo"
            case .video: return "Video"
            case .document: return "Document"
            case .any: return "Any File"
            }
        }
        
        var icon: String {
            switch self {
            case .photo: return "photo"
            case .video: return "video"
            case .document: return "doc.fill"
            case .any: return "paperclip"
            }
        }
        
        var description: String {
            switch self {
            case .photo: return "Upload a photo"
            case .video: return "Upload a video"
            case .document: return "Upload a PDF or document"
            case .any: return "Upload any file type"
            }
        }
        
        /// File types allowed for this proof type
        var allowedExtensions: [String] {
            switch self {
            case .photo:
                return ["jpg", "jpeg", "png", "heic", "gif", "webp"]
            case .video:
                return ["mp4", "mov", "m4v", "avi"]
            case .document:
                return ["pdf", "doc", "docx", "txt"]
            case .any:
                return ["jpg", "jpeg", "png", "heic", "gif", "webp", "mp4", "mov", "m4v", "pdf", "doc", "docx", "txt"]
            }
        }
    }
    
    // ============================================================================
    // USAGE IN ProofCaptureView:
    //
    // The ProofCaptureView already handles these types. Just make sure:
    // 1. When creating a task, you can now select .document or .any as proof type
    // 2. The picker filters will adjust automatically based on proof type
    // ============================================================================
    
    enum TaskType: String, Codable, CaseIterable {
        case chore = "chore"
        case homework = "homework"
        
        var displayName: String {
            switch self {
            case .chore: return "taskTypeChore"
            case .homework: return "taskTypeHomework"
            }
        }
        
        var icon: String {
            switch self {
            case .chore: return "sparkles"
            case .homework: return "book.fill"
            }
        }
    }
    
    enum HomeworkSubject: String, Codable, CaseIterable {
        case math = "math"
        case language = "language"
        case reading = "reading"
        case science = "science"
        case other = "other"
        
        var displayName: String {
            switch self {
            case .math: return "subjectMath"
            case .language: return "subjectLanguage"
            case .reading: return "subjectReading"
            case .science: return "subjectScience"
            case .other: return "subjectOther"
            }
        }
        
        var isAIVerifiable: Bool {
            switch self {
            case .math, .language, .science: return true
            case .reading, .other: return false
            }
        }
    }
    
    struct RecurrenceRule: Codable, Hashable {
        var frequency: Frequency
        var interval: Int
        var daysOfWeek: [Int]?
        var endDate: Date?
        
        enum Frequency: String, Codable, CaseIterable {
            case daily, weekly, monthly
        }
    }
    
    struct AIVerification: Codable, Hashable {
        var recommendation: String      // "approve", "review", "unclear", "cannot_verify"
        var recommendationMessage: String?
        var confidence: Double
        var confidenceReason: String?
        
        // Analysis summary (nested in Firestore)
        var analysis: AnalysisSummary?
        
        // Individual questions (was "issues")
        var questions: [AIVerificationQuestion]?
        
        var summary: String
        var encouragement: String?
        var disclaimer: String?
        var subject: String?
        var detectedLanguage: String?
        var areasToReview: [String]?
        
        var verifiedAt: Date?
        var verifiedBy: String?
        
        // MARK: - Nested Types
        
        struct AnalysisSummary: Codable, Hashable {
            var totalQuestions: Int?
            var likelyCorrect: Int?
            var likelyIncorrect: Int?
            var uncertain: Int?
            var scoreEstimate: String?
        }
        
        // MARK: - Computed Properties (for backwards compatibility)
        
        var totalCount: Int? {
            analysis?.totalQuestions
        }
        
        var correctCount: Int? {
            analysis?.likelyCorrect
        }
        
        var isVerifiable: Bool {
            recommendation != "cannot_verify"
        }
        
        // Legacy alias for TaskDetailView
        var issues: [AIVerificationIssue]? {
            questions?.map { q in
                AIVerificationIssue(
                    question: q.questionNumber,
                    expected: q.expectedAnswer,
                    found: q.studentAnswer,
                    note: q.note ?? ""
                )
            }
        }
    }
    
    struct AIVerificationQuestion: Codable, Hashable {
        var questionNumber: String
        var questionText: String?
        var studentAnswer: String?
        var expectedAnswer: String?
        var assessment: String?
        var note: String?
        var confidence: Double?
    }
    
    // Keep the old struct for backwards compatibility
    struct AIVerificationIssue: Codable, Hashable {
        var question: String
        var expected: String?
        var found: String?
        var note: String
    }
    
    // MARK: - Multi-Assignee Computed Properties
    
    var allAssignees: [String] {
        var result = assignees
        if let legacyAssignee = assignedTo, !result.contains(legacyAssignee) {
            result.insert(legacyAssignee, at: 0)
        }
        return result
    }
    
    func isAssigned(to userId: String) -> Bool {
        allAssignees.contains(userId)
    }
    
    var hasAssignees: Bool {
        !allAssignees.isEmpty
    }
    
    var primaryAssignee: String? {
        allAssignees.first
    }
    
    // MARK: - Proof URL Computed Properties
    
    var allProofURLs: [String] {
        var urls: [String] = []
        if let proofURLs = proofURLs {
            urls = proofURLs
        }
        if urls.isEmpty, let legacyURL = proofURL {
            urls = [legacyURL]
        }
        return urls
    }
    
    var hasProofUploaded: Bool {
        !allProofURLs.isEmpty
    }
    
    var firstProofURL: String? {
        allProofURLs.first
    }
    
    // MARK: - Focus Computed Properties
    
    var totalFocusedMinutes: Int {
        (totalFocusedSeconds ?? 0) / 60
    }
    
    var formattedFocusTime: String {
        let seconds = totalFocusedSeconds ?? 0
        let hours = seconds / 3600
        let minutes = (seconds % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        }
        return "0m"
    }
    
    var hasFocusData: Bool {
        (totalFocusedSeconds ?? 0) > 0
    }
    
    var isCompletedOneOff: Bool {
        status == .completed && !isRecurring
    }
    
    // MARK: - Implicit Priority System
    
    /// Computed priority score for sorting (higher = more urgent)
    /// Based on: due date urgency (0-100) + reward bonus (0-30)
    var implicitPriorityScore: Double {
        var score: Double = 0
        
        // Factor 1: Due date urgency
        let hoursUntilDue = dueDate.timeIntervalSince(Date()) / 3600
        
        if hoursUntilDue <= 0 {
            score += 100  // Overdue
        } else if hoursUntilDue <= 2 {
            score += 90   // Due in < 2 hours
        } else if hoursUntilDue <= 6 {
            score += 80   // Due in < 6 hours
        } else if hoursUntilDue <= 24 {
            score += 60   // Due today
        } else if hoursUntilDue <= 48 {
            score += 50   // Due tomorrow
        } else if hoursUntilDue <= 72 {
            score += 40   // Due in 2-3 days
        } else if hoursUntilDue <= 168 {
            score += 20   // Due this week
        } else {
            score += 10   // Due later
        }
        
        // Factor 2: Reward bonus ($1 = 3 points, max 30)
        if let reward = rewardAmount, reward > 0 {
            score += min(reward * 3, 30)
        }
        
        return score
    }
    
    /// Display priority derived from score
    var displayPriority: TaskPriority {
        let score = implicitPriorityScore
        if score >= 90 { return .urgent }
        if score >= 70 { return .high }
        if score >= 40 { return .medium }
        return .low
    }
    
    /// Priority color for UI (uses displayPriority's color)
    var priorityColor: Color {
        displayPriority.color
    }
    
    /// Whether task is overdue
    var isOverdue: Bool {
        dueDate < Date() && status != .completed
    }
    
    /// Whether task is due soon (within 2 hours)
    var isDueSoon: Bool {
        let hours = dueDate.timeIntervalSince(Date()) / 3600
        return hours > 0 && hours <= 2 && status != .completed
    }
    
    /// Human-readable time until due
    var timeUntilDueText: String {
        let hours = dueDate.timeIntervalSince(Date()) / 3600
        
        if hours <= 0 {
            return "overdue"
        } else if hours < 1 {
            let minutes = Int(hours * 60)
            return AppStrings.dueInMinutes(minutes)
        } else if hours < 24 {
            let h = Int(hours)
            return AppStrings.dueInHours(h)
        } else if hours < 48 {
            return "due_Tomorrow"
        } else {
            let days = Int(hours / 24)
            return AppStrings.dueInDays(days)
        }
    }
    
    /// Whether this homework task should auto-verify with AI
    var shouldAutoVerify: Bool {
        guard let type = taskType, type == .homework,
              requiresProof,
              let subject = homeworkSubject else {
            return false
        }
        return subject.isAIVerifiable
    }
    
    /// Whether AI verification is in progress
    var isAIVerifying: Bool {
        aiVerificationStatus == "processing"
    }
    
    /// Whether AI verification completed
    var hasAIVerification: Bool {
        aiVerification != nil && aiVerificationStatus == "complete"
    }
    
    // MARK: - CodingKeys
    
    enum CodingKeys: String, CodingKey {
        case familyId
        case groupId
        case title
        case description
        case assignedTo
        case assignees
        case assignedBy
        case dueDate
        case scheduledTime
        case status
        case priority
        case createdAt
        case completedAt
        case hasReward
        case rewardAmount
        case requiresProof
        case proofType
        case proofURL
        case proofURLs
        case proofVerifiedBy
        case proofVerifiedAt
        case rewardPaid
        case isRecurring
        case recurrenceRule
        case pomodoroDurationMinutes
        case totalFocusedSeconds
        case lastFocusDate
        case taskType
        case homeworkSubject
        case aiVerification
        case aiVerificationStatus
    }
    
    // MARK: - Custom Decoder
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        familyId = try container.decode(String.self, forKey: .familyId)
        groupId = try container.decodeIfPresent(String.self, forKey: .groupId)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        assignedTo = try container.decodeIfPresent(String.self, forKey: .assignedTo)
        assignees = try container.decodeIfPresent([String].self, forKey: .assignees) ?? []
        assignedBy = try container.decode(String.self, forKey: .assignedBy)
        dueDate = try container.decode(Date.self, forKey: .dueDate)
        scheduledTime = try container.decodeIfPresent(Date.self, forKey: .scheduledTime)
        status = try container.decode(TaskStatus.self, forKey: .status)
        priority = try container.decode(TaskPriority.self, forKey: .priority)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        completedAt = try container.decodeIfPresent(Date.self, forKey: .completedAt)
        hasReward = try container.decode(Bool.self, forKey: .hasReward)
        rewardAmount = try container.decodeIfPresent(Double.self, forKey: .rewardAmount)
        requiresProof = try container.decode(Bool.self, forKey: .requiresProof)
        proofType = try container.decodeIfPresent(ProofType.self, forKey: .proofType)
        proofURL = try container.decodeIfPresent(String.self, forKey: .proofURL)
        proofURLs = try container.decodeIfPresent([String].self, forKey: .proofURLs)
        proofVerifiedBy = try container.decodeIfPresent(String.self, forKey: .proofVerifiedBy)
        proofVerifiedAt = try container.decodeIfPresent(Date.self, forKey: .proofVerifiedAt)
        rewardPaid = try container.decode(Bool.self, forKey: .rewardPaid)
        isRecurring = try container.decode(Bool.self, forKey: .isRecurring)
        recurrenceRule = try container.decodeIfPresent(RecurrenceRule.self, forKey: .recurrenceRule)
        pomodoroDurationMinutes = try container.decodeIfPresent(Int.self, forKey: .pomodoroDurationMinutes)
        totalFocusedSeconds = try container.decodeIfPresent(Int.self, forKey: .totalFocusedSeconds)
        lastFocusDate = try container.decodeIfPresent(Date.self, forKey: .lastFocusDate)
        
        // NEW fields
        taskType = try container.decodeIfPresent(TaskType.self, forKey: .taskType)
        homeworkSubject = try container.decodeIfPresent(HomeworkSubject.self, forKey: .homeworkSubject)
        aiVerification = try container.decodeIfPresent(AIVerification.self, forKey: .aiVerification)
        aiVerificationStatus = try container.decodeIfPresent(String.self, forKey: .aiVerificationStatus)
    }
    
    // MARK: - Memberwise Initializer
    
    init(
        id: String? = nil,
        familyId: String,
        groupId: String? = nil,
        title: String,
        description: String? = nil,
        assignedTo: String? = nil,
        assignees: [String] = [],
        assignedBy: String,
        dueDate: Date,
        scheduledTime: Date? = nil,
        status: TaskStatus,
        priority: TaskPriority,
        createdAt: Date,
        completedAt: Date? = nil,
        hasReward: Bool,
        rewardAmount: Double? = nil,
        requiresProof: Bool,
        proofType: ProofType? = nil,
        proofURL: String? = nil,
        proofURLs: [String]? = nil,
        proofVerifiedBy: String? = nil,
        proofVerifiedAt: Date? = nil,
        rewardPaid: Bool,
        isRecurring: Bool,
        recurrenceRule: RecurrenceRule? = nil,
        pomodoroDurationMinutes: Int? = nil,
        totalFocusedSeconds: Int? = nil,
        lastFocusDate: Date? = nil,
        taskType: TaskType? = nil,
        homeworkSubject: HomeworkSubject? = nil,
        aiVerification: AIVerification? = nil,
        aiVerificationStatus: String? = nil
    ) {
        self.id = id
        self.familyId = familyId
        self.groupId = groupId
        self.title = title
        self.description = description
        self.assignedTo = assignedTo
        self.assignees = assignees
        self.assignedBy = assignedBy
        self.dueDate = dueDate
        self.scheduledTime = scheduledTime
        self.status = status
        self.priority = priority
        self.createdAt = createdAt
        self.completedAt = completedAt
        self.hasReward = hasReward
        self.rewardAmount = rewardAmount
        self.requiresProof = requiresProof
        self.proofType = proofType
        self.proofURL = proofURL
        self.proofURLs = proofURLs
        self.proofVerifiedBy = proofVerifiedBy
        self.proofVerifiedAt = proofVerifiedAt
        self.rewardPaid = rewardPaid
        self.isRecurring = isRecurring
        self.recurrenceRule = recurrenceRule
        self.pomodoroDurationMinutes = pomodoroDurationMinutes
        self.totalFocusedSeconds = totalFocusedSeconds
        self.lastFocusDate = lastFocusDate
        self.taskType = taskType
        self.homeworkSubject = homeworkSubject
        self.aiVerification = aiVerification
        self.aiVerificationStatus = aiVerificationStatus
    }
}

// MARK: - Array Extension for Priority Sorting

extension Array where Element == FamilyTask {
    
    // ═══════════════════════════════════════════════════════════════════════
    // MARK: Sorting
    // ═══════════════════════════════════════════════════════════════════════
    
    /// Sort by implicit priority (urgent first)
    func sortedByPriority() -> [FamilyTask] {
        sorted { $0.implicitPriorityScore > $1.implicitPriorityScore }
    }
    
    /// Sort by due date (soonest first)
    func sortedByDueDate() -> [FamilyTask] {
        sorted { $0.dueDate < $1.dueDate }
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // MARK: Filtering
    // ═══════════════════════════════════════════════════════════════════════
    
    /// Tasks filtered by status.
    func with(status: FamilyTask.TaskStatus) -> [FamilyTask] {
        filter { $0.status == status }
    }
    
    /// Tasks assigned to a specific user.
    func assigned(to userId: String) -> [FamilyTask] {
        filter { $0.assignedTo == userId }
    }
    
    /// Tasks due within the specified date range.
    func due(in range: ClosedRange<Date>) -> [FamilyTask] {
        filter { range.contains($0.dueDate) }
    }
    
    // ═══════════════════════════════════════════════════════════════════════
    // MARK: Computed Properties
    // ═══════════════════════════════════════════════════════════════════════
    
    /// Number of completed tasks in this array.
    var completedCount: Int {
        filter { $0.status == .completed }.count
    }
    
    /// Completion percentage (0-100) for this array of tasks.
    /// Returns 0 if the array is empty.
    var completionPercentage: Double {
        guard !isEmpty else { return 0 }
        return Double(completedCount) / Double(count) * 100
    }
    
    /// Tasks due today.
    var dueToday: [FamilyTask] {
        let calendar = Calendar.current
        return filter { calendar.isDateInToday($0.dueDate) }
    }
    
    /// Overdue tasks (past due date and not completed).
    var overdue: [FamilyTask] {
        let now = Date()
        return filter { $0.dueDate < now && $0.status != .completed }
    }
    
    /// Tasks due soon (within 2 hours).
    var dueSoon: [FamilyTask] {
        filter { $0.isDueSoon }
    }
}

// MARK: - Task Group Model

struct TaskGroup: Identifiable, Codable, Hashable {
    @DocumentID var id: String?
    var familyId: String
    var name: String
    var icon: String
    var color: String
    var createdBy: String
    var createdAt: Date
    
    var taskCount: Int = 0
    var completionPercentage: Double = 0
    
    enum CodingKeys: String, CodingKey {
        case familyId, name, icon, color, createdBy, createdAt
    }
}
