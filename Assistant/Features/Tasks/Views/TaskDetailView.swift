//
//  TaskDetailView.swift
//  FamilyHub
//
//  IMPROVED: Smart verification UI
//  - Homework: Shows AI analysis inline (no modal)
//  - Chores: Simple approve/reject (no AI UI)
//

import SwiftUI
import UIKit

struct TaskDetailView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    @Environment(TaskViewModel.self) var taskVM
    
    let taskId: String
    
    @State private var showProofCapture = false
    @State private var showDeleteConfirm = false
    @State private var showFocusTimer = false
    @State private var showEditTask = false
    
    // Verification state
    @State private var isApproving = false
    @State private var isRejecting = false
    
    // Action feedback
    @State private var actionInFlight = false
    @State private var isDeleting = false
    @State private var toast: ToastMessage? = nil
    
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    private var task: FamilyTask? {
        taskVM.allTasks.first { $0.stableId == taskId }
    }
    
    var assignee: FamilyUser? {
        task?.assignedTo.flatMap { familyMemberVM.getMember(by: $0) }
    }
    
    var assigner: FamilyUser? {
        guard let task = task else { return nil }
        return familyMemberVM.getMember(by: task.assignedBy)
    }
    
    var taskGroup: TaskGroup? {
        task?.groupId.flatMap { familyMemberVM.getTaskGroup(by: $0) }
    }
    
    var canSubmitProof: Bool {
        guard let task = task else { return false }
        return (task.assignedTo == nil || task.assignedTo == authViewModel.currentUser?.id) &&
        task.requiresProof &&
        (task.status == .todo || task.status == .inProgress)
    }
    
    var canVerifyProof: Bool {
        guard let task = task,
              let currentUserId = authViewModel.currentUser?.id else { return false }
        
        if task.assignedBy == currentUserId { return true }
        
        if let currentUser = authViewModel.currentUser {
            if currentUser.role == .admin || currentUser.role == .adult {
                return true
            }
        }
        return false
    }
    
    // Check if this is a homework task with AI verification
    private var isHomeworkTask: Bool {
        task?.taskType == .homework
    }
    
    var statusColor: Color {
        guard let task = task else { return .gray }
        switch task.status {
        case .todo: return .statusTodo
        case .inProgress: return .statusInProgress
        case .pendingVerification: return .statusPending
        case .completed: return .statusCompleted
        }
    }
    
    var canManageTask: Bool {
        guard let task = task else { return false }
        return task.assignedTo == nil || task.assignedTo == authViewModel.currentUser?.id
    }
    
    init(task: FamilyTask) {
        self.taskId = task.stableId
    }
    
    init(taskId: String) {
        self.taskId = taskId
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackgroundView()
                    .ignoresSafeArea()
                
                if let task = task {
                    ScrollView(showsIndicators: false) {
                        VStack(spacing: DS.Spacing.xl) {
                            headerSection(task: task)
                            titleSection(task: task)
                            infoSection(task: task)
                            
                            // Show proof section if proof exists
                            if task.hasProofUploaded {
                                proofSection(task: task)
                            }
                            
                            Spacer().frame(height: DS.Spacing.xl)
                            actionButtons(task: task)
                            Spacer().frame(height: DS.Spacing.jumbo * 2.5)
                        }
                        .padding(DS.Layout.adaptiveScreenPadding)
                        .constrainedWidth(.readable)
                    }
                } else {
                    VStack(spacing: DS.Spacing.lg) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundStyle(.textSecondary)
                        Text(L10n.taskNotFound)
                            .font(.headline)
                            .foregroundStyle(.textSecondary)
                    }
                }
            }
            .navigationTitle(L10n.taskDetails)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.close) { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Menu {
                        if task?.assignedBy == authViewModel.currentUser?.id {
                            Button(action: { showEditTask = true }) {
                                Label(L10n.editTask, systemImage: "pencil")
                            }
                        }
                        Button(role: .destructive, action: { showDeleteConfirm = true }) {
                            Label(L10n.deleteTask, systemImage: "trash")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .disabled(isDeleting)
                }
            }
            .sheet(isPresented: $showProofCapture) {
                if let task = task {
                    ProofCaptureView(task: task)
                }
            }
            .sheet(isPresented: $showFocusTimer) {
                if let task = task {
                    FocusTimerView(task: task)
                        .presentationDetents([.large])
                }
            }
            .sheet(isPresented: $showEditTask) {
                if let task = task {
                    EditTaskView(task: task)
                        .presentationBackground(Color.backgroundPrimary)
                }
            }
            .alert(L10n.deleteTaskConfirm, isPresented: $showDeleteConfirm) {
                Button(L10n.cancel, role: .cancel) {}
                Button(L10n.delete, role: .destructive) {
                    deleteTask()
                }
            } message: {
                Text(L10n.actionCannotBeUndone)
            }
            .toastBanner(item: $toast)
            .onReceive(NotificationCenter.default.publisher(for: .dismissTaskSheets)) { _ in
                dismiss()
            }
        }
    }
    
    // MARK: - Header Section
    
    private func headerSection(task: FamilyTask) -> some View {
        HStack {
            // Task type badge
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: task.taskType?.icon ?? "checklist")
                Text(task.taskType?.displayName ?? "Task")
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(task.taskType == .homework ? .accentPrimary : .textSecondary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                Capsule().fill(
                    task.taskType == .homework
                        ? Color.accentPrimary.opacity(0.15)
                        : Color.backgroundSecondary
                )
            )
            
            Spacer()
            
            // Status badge
            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(task.status.rawValue)
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            .foregroundStyle(statusColor)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(Capsule().fill(statusColor.opacity(0.15)))
        }
    }
    
    // MARK: - Title Section
    
    private func titleSection(task: FamilyTask) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            Text(task.title)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(.textPrimary)
            
            if let description = task.description, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Info Section
    
    private func infoSection(task: FamilyTask) -> some View {
        VStack(spacing: DS.Spacing.md) {
            if let assignee = assignee {
                infoRow(icon: "person.fill", label: L10n.assignedTo) {
                    HStack(spacing: DS.Spacing.xs) {
                        AvatarView(user: assignee, size: 24)
                        Text(assignee.displayName)
                            .foregroundStyle(.textPrimary)
                    }
                }
            }
            
            infoRow(icon: "calendar", label: L10n.dueDate) {
                Text(task.dueDate.formattedDate)
                    .foregroundStyle(task.isOverdue ? .red : .textPrimary)
            }
            
            if let scheduledTime = task.scheduledTime {
                infoRow(icon: "clock.fill", label: L10n.scheduledTime) {
                    Text(scheduledTime.formatted(date: .omitted, time: .shortened))
                        .foregroundStyle(.textPrimary)
                }
            }
            
            if let group = taskGroup {
                infoRow(icon: "folder.fill", label: L10n.groupName) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: group.icon)
                            .foregroundStyle(Color(hex: group.color))
                        Text(group.name)
                            .foregroundStyle(.textPrimary)
                    }
                }
            }
            
            if task.hasReward, let amount = task.rewardAmount {
                infoRow(icon: "dollarsign.circle.fill", label: L10n.reward) {
                    Text(amount.currencyString)
                        .foregroundStyle(.accentGreen)
                        .fontWeight(.semibold)
                }
            }
            
            // Show homework subject if applicable
            if task.taskType == .homework, let subject = task.homeworkSubject {
                infoRow(icon: "book.fill", label: "Subject") {
                    Text(subject.displayName)
                        .foregroundStyle(.textPrimary)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(Color.backgroundCard))
    }
    
    private func infoRow<Content: View>(icon: String, label: String, @ViewBuilder content: () -> Content) -> some View {
        HStack {
            Label(label, systemImage: icon)
                .font(.subheadline)
                .foregroundStyle(.textSecondary)
            Spacer()
            content()
                .font(.subheadline)
        }
    }
    
    // MARK: - Proof Section
    
    private func proofSection(task: FamilyTask) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Header
            HStack {
                Image(systemName: "doc.text.image")
                    .foregroundStyle(.accentPrimary)
                Text("Submitted Proof")
                    .font(.headline)
                Spacer()
                proofStatusBadge(task: task)
            }
            
            // Proof images
            proofImagesView(task: task)
            
            // HOMEWORK: Show AI verification result inline
            if isHomeworkTask {
                if let verification = task.aiVerification {
                    aiVerificationCard(verification: verification)
                } else if task.isAIVerifying {
                    aiLoadingCard()
                } else if task.aiVerificationStatus == "failed" {
                    aiFailedCard()
                }
            }
            
            // Verified badge
            if task.status == .completed, let verifiedAt = task.proofVerifiedAt {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(.accentGreen)
                    Text(L10n.verifiedOnDate(verifiedAt.formattedDate))
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                }
            }
            
            // Action buttons
            if task.status == .pendingVerification && canVerifyProof {
                verificationActions(task: task)
            }
        }
        .padding(DS.Spacing.lg)
        .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(Color.backgroundCard))
    }
    
    // MARK: - Proof Status Badge
    
    private func proofStatusBadge(task: FamilyTask) -> some View {
        Group {
            switch task.status {
            case .pendingVerification:
                HStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                    Text("Pending")
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.statusPending))
                
            case .completed:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("Verified")
                }
                .font(.caption)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.accentGreen))
                
            default:
                EmptyView()
            }
        }
    }
    
    // MARK: - Proof Images
    
    private func proofImagesView(task: FamilyTask) -> some View {
        Group {
            if task.allProofURLs.count == 1, let proofURL = task.firstProofURL {
                AsyncImage(url: URL(string: proofURL)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(height: isRegularWidth ? 280 : 200)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
                } placeholder: {
                    RoundedRectangle(cornerRadius: DS.Radius.card)
                        .fill(Color.backgroundSecondary)
                        .frame(height: isRegularWidth ? 280 : 200)
                        .overlay(ProgressView())
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.md) {
                        ForEach(task.allProofURLs, id: \.self) { urlString in
                            AsyncImage(url: URL(string: urlString)) { image in
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 140, height: 140)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
                            } placeholder: {
                                RoundedRectangle(cornerRadius: DS.Radius.md)
                                    .fill(Color.backgroundSecondary)
                                    .frame(width: 140, height: 140)
                                    .overlay(ProgressView())
                            }
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - AI Verification Card (Homework Only)
    
    private func aiVerificationCard(verification: FamilyTask.AIVerification) -> some View {
        // Derive accurate stats from questions array when available
        let computedStats = computeStats(from: verification)
        
        return VStack(spacing: DS.Spacing.md) {
            // Header row: icon + recommendation + score
            HStack(spacing: DS.Spacing.sm) {
                ZStack {
                    Circle()
                        .fill(recommendationColor(computedStats.recommendation).opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: recommendationIcon(computedStats.recommendation))
                        .font(.title3)
                        .foregroundStyle(recommendationColor(computedStats.recommendation))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image("samy")
                            .resizable()
                            .scaledToFit()
                            .frame(width: DS.IconSize.md, height: DS.IconSize.md)
                            .font(.caption)
                        Text("MAI Analysis")
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .foregroundStyle(.textSecondary)
                    
                    Text(recommendationMessage(computedStats.recommendation))
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(recommendationColor(computedStats.recommendation))
                }
                
                Spacer()
                
                // Show computed score percentage instead of AI "confidence"
                if computedStats.total > 0 {
                    VStack(spacing: 2) {
                        Text("\(computedStats.scorePercent)%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(confidenceColor(Double(computedStats.scorePercent) / 100.0))
                        Text("score")
                            .font(.caption2)
                            .foregroundStyle(.textTertiary)
                    }
                } else {
                    VStack(spacing: 2) {
                        Text("\(Int(verification.confidence * 100))%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(confidenceColor(verification.confidence))
                        Text("conf.")
                            .font(.caption2)
                            .foregroundStyle(.textTertiary)
                    }
                }
            }
            
            // Score breakdown — derived from actual questions array
            if computedStats.total > 0 {
                HStack(spacing: DS.Spacing.lg) {
                    statItem(value: "\(computedStats.correct)", label: "Correct", color: .accentGreen)
                    if computedStats.wrong > 0 {
                        statItem(value: "\(computedStats.wrong)", label: "Wrong", color: .red)
                    }
                    if computedStats.uncertain > 0 {
                        statItem(value: "\(computedStats.uncertain)", label: "Uncertain", color: .orange)
                    }
                    Spacer()
                    statItem(value: "\(computedStats.correct)/\(computedStats.total)", label: "Score", color: .textPrimary)
                }
            }
            
            // Per-question detail (expandable)
            if let questions = verification.questions, !questions.isEmpty {
                questionBreakdown(questions: questions)
            }
            
            // Encouragement for the child
            if let encouragement = verification.encouragement, !encouragement.isEmpty {
                Text(encouragement)
                    .font(.caption)
                    .foregroundStyle(.accentPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Disclaimer
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "info.circle")
                    .font(.caption2)
                Text("MAI may make mistakes. Parent has final say.")
                    .font(.caption2)
            }
            .foregroundStyle(.textTertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .fill(recommendationColor(computedStats.recommendation).opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.md)
                        .stroke(recommendationColor(computedStats.recommendation).opacity(0.2), lineWidth: 1)
                )
        )
    }
    
    private func recommendationMessage(_ recommendation: String) -> String {
        switch recommendation {
        case "approve": return "Looks correct!"
        case "review": return "Some issues found"
        case "unclear": return "Couldn't read clearly"
        case "cannot_verify": return "Can't verify this type"
        default: return "Analysis complete"
        }
    }
    
    // MARK: - Compute Accurate Stats
    
    private struct ComputedStats {
        let correct: Int
        let wrong: Int
        let uncertain: Int
        let total: Int
        let scorePercent: Int
        let recommendation: String  // overridden from AI if numbers don't match
    }
    
    private func computeStats(from verification: FamilyTask.AIVerification) -> ComputedStats {
        guard let questions = verification.questions, !questions.isEmpty else {
            // No per-question data — fall back to AI summary
            let total = verification.totalCount ?? 0
            let correct = verification.correctCount ?? 0
            let pct = total > 0 ? Int(Double(correct) / Double(total) * 100) : Int(verification.confidence * 100)
            return ComputedStats(
                correct: correct,
                wrong: max(0, total - correct),
                uncertain: 0,
                total: total,
                scorePercent: pct,
                recommendation: verification.recommendation
            )
        }
        
        let correct = questions.filter { $0.assessment == "likely_correct" }.count
        let wrong = questions.filter { $0.assessment == "likely_incorrect" }.count
        let uncertain = questions.count - correct - wrong
        let total = questions.count
        let pct = total > 0 ? Int(Double(correct) / Double(total) * 100) : 0
        
        // Override recommendation based on actual computed score
        let recommendation: String
        if wrong == 0 && uncertain == 0 {
            recommendation = "approve"
        } else if wrong > 0 || uncertain > 0 {
            recommendation = pct >= 90 ? "approve" : "review"
        } else {
            recommendation = verification.recommendation
        }
        
        return ComputedStats(
            correct: correct,
            wrong: wrong,
            uncertain: uncertain,
            total: total,
            scorePercent: pct,
            recommendation: recommendation
        )
    }
    
    // MARK: - Per-Question Breakdown
    
    @ViewBuilder
    private func questionBreakdown(questions: [FamilyTask.AIVerificationQuestion]) -> some View {
        let wrong = questions.filter { $0.assessment == "likely_incorrect" || $0.assessment == "uncertain" || $0.assessment == "needs_review" }
        let correct = questions.filter { $0.assessment == "likely_correct" }
        
        VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Show wrong/uncertain answers first (these are what parents care about)
            if !wrong.isEmpty {
                Text("Needs attention")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.red)
                
                ForEach(wrong, id: \.questionNumber) { q in
                    questionRow(q, isCorrect: false)
                }
            }
            
            // Show correct answers (collapsed if many)
            if !correct.isEmpty {
                DisclosureGroup {
                    ForEach(correct, id: \.questionNumber) { q in
                        questionRow(q, isCorrect: true)
                    }
                } label: {
                    Text("\(correct.count) correct answers")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.accentGreen)
                }
                .tint(.accentGreen)
            }
        }
    }
    
    private func questionRow(_ q: FamilyTask.AIVerificationQuestion, isCorrect: Bool) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.caption)
                .foregroundStyle(isCorrect ? .accentGreen : .red)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                // Question number + text
                if let text = q.questionText, !text.isEmpty {
                    Text("Q\(q.questionNumber): \(text)")
                        .font(.caption)
                        .foregroundStyle(.textPrimary)
                        .lineLimit(2)
                } else {
                    Text("Question \(q.questionNumber)")
                        .font(.caption)
                        .foregroundStyle(.textPrimary)
                }
                
                // Student answer vs expected
                if let student = q.studentAnswer, !student.isEmpty {
                    HStack(spacing: 4) {
                        Text("Answer:")
                            .font(.caption2)
                            .foregroundStyle(.textTertiary)
                        Text(student)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(isCorrect ? .accentGreen : .red)
                    }
                }
                
                if !isCorrect, let expected = q.expectedAnswer, !expected.isEmpty {
                    HStack(spacing: 4) {
                        Text("Expected:")
                            .font(.caption2)
                            .foregroundStyle(.textTertiary)
                        Text(expected)
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundStyle(.accentGreen)
                    }
                }
                
                // Note if any
                if let note = q.note, !note.isEmpty, !isCorrect {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(.textSecondary)
                        .italic()
                }
            }
        }
        .padding(.vertical, 2)
    }
    
    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.textSecondary)
        }
    }
    
    // MARK: - AI Loading Card
    
    private func aiLoadingCard() -> some View {
        HStack(spacing: DS.Spacing.md) {
            ProgressView()
                .tint(.accentPrimary)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DS.Spacing.xs) {
                    Image("samy")
                        .resizable()
                        .scaledToFit()
                        .frame(width: DS.IconSize.md, height: DS.IconSize.md)
                    Text("MAI Analysis")
                        .fontWeight(.medium)
                }
                .font(.caption)
                .foregroundStyle(.accentPrimary)
                
                Text("Checking homework...")
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .fill(Color.accentPrimary.opacity(0.05))
        )
    }
    
    // MARK: - AI Failed Card
    
    private func aiFailedCard() -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("MAI couldn't analyze. Please review manually.")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.orange)
            }
            
            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .fill(Color.orange.opacity(0.1))
        )
    }
    
    // MARK: - Verification Actions
    
    private func verificationActions(task: FamilyTask) -> some View {
        VStack(spacing: DS.Spacing.md) {
            Divider()
            
            // Guidance text
            if isHomeworkTask, let verification = task.aiVerification {
                let stats = computeStats(from: verification)
                guidanceText(recommendation: stats.recommendation)
            } else if !isHomeworkTask {
                // Chores: simple guidance
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "eye.fill")
                        .foregroundStyle(.textSecondary)
                    Text("Review the photo and decide if the chore is done")
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Two buttons
            HStack(spacing: DS.Spacing.md) {
                Button {
                    Task { await rejectTask(task) }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        if isRejecting {
                            ProgressView().tint(.red)
                        } else {
                            Image(systemName: "arrow.uturn.backward.circle.fill")
                        }
                        Text("Needs Redo")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.1))
                    .foregroundStyle(.red)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
                }
                .disabled(isApproving || isRejecting)
                
                Button {
                    Task { await approveTask(task) }
                } label: {
                    HStack(spacing: DS.Spacing.xs) {
                        if isApproving {
                            ProgressView().tint(.white)
                        } else {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text("Approve")
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentGreen)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.card))
                }
                .disabled(isApproving || isRejecting)
            }
        }
    }
    
    // MARK: - Guidance Text
    
    private func guidanceText(recommendation: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: guidanceIcon(recommendation))
                .foregroundStyle(recommendationColor(recommendation))
            
            Text(guidanceMessage(recommendation))
                .font(.caption)
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func guidanceMessage(_ recommendation: String) -> String {
        switch recommendation {
        case "approve": return "MAI suggests approving – looks good!"
        case "review": return "MAI found some issues – please check"
        case "unclear": return "MAI couldn't read clearly – check manually"
        case "cannot_verify": return "MAI can't verify – use your judgment"
        default: return "Review and decide"
        }
    }
    
    private func guidanceIcon(_ recommendation: String) -> String {
        switch recommendation {
        case "approve": return "hand.thumbsup.fill"
        case "review": return "eye.fill"
        case "unclear": return "questionmark.circle.fill"
        default: return "info.circle.fill"
        }
    }
    
    // MARK: - Helper Functions
    
    private func recommendationColor(_ recommendation: String) -> Color {
        switch recommendation {
        case "approve": return .accentGreen
        case "review": return .orange
        case "unclear": return .yellow
        case "cannot_verify": return .gray
        default: return .textSecondary
        }
    }
    
    private func recommendationIcon(_ recommendation: String) -> String {
        switch recommendation {
        case "approve": return "checkmark.circle.fill"
        case "review": return "exclamationmark.triangle.fill"
        case "unclear": return "questionmark.circle.fill"
        case "cannot_verify": return "eye.slash.fill"
        default: return "sparkles"
        }
    }
    
    private func confidenceColor(_ confidence: Double) -> Color {
        if confidence >= 0.8 { return .accentGreen }
        if confidence >= 0.6 { return .orange }
        return .red
    }
    
    // MARK: - Action Buttons
    
    private func actionButtons(task: FamilyTask) -> some View {
        VStack(spacing: DS.Spacing.md) {
            if canManageTask {
                switch task.status {
                case .todo:
                    PrimaryButton(
                        title: L10n.startTask,
                        isLoading: actionInFlight
                    ) {
                        startTask(task)
                    }
                    
                case .inProgress:
                    Button(action: { showFocusTimer = true }) {
                        HStack(spacing: 10) {
                            Image(systemName: "timer")
                                .font(.title3)
                            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                Text(L10n.startFocus)
                                    .font(.headline)
                                Text(L10n.pomodoroForTask)
                                    .font(.caption)
                                    .opacity(0.8)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                        }
                        .foregroundStyle(.white)
                        .padding(16)
                        .background(
                            LinearGradient(
                                colors: [.accentPrimary, .accentBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    }
                    .disabled(actionInFlight)
                    
                    if task.requiresProof {
                        PrimaryButton(
                            title: L10n.submitProof,
                            isDisabled: actionInFlight
                        ) {
                            showProofCapture = true
                        }
                    } else {
                        PrimaryButton(
                            title: L10n.markComplete,
                            isLoading: actionInFlight
                        ) {
                            completeTask(task)
                        }
                    }
                    
                case .pendingVerification:
                    if canVerifyProof {
                        statusMessage("Review the submitted proof above", color: .statusPending)
                    } else {
                        statusMessage(L10n.waitingForVerification, color: .statusPending)
                    }
                    
                case .completed:
                    completedMessage
                }
            }
        }
    }
    
    // MARK: - Actions
    
    private func startTask(_ task: FamilyTask) {
        guard !actionInFlight else { return }
        actionInFlight = true
        Task {
            await familyViewModel.updateTaskStatus(task, to: .inProgress)
            actionInFlight = false
            toast = .success(L10n.taskStarted)
            DS.Haptics.success()
        }
    }
    
    private func completeTask(_ task: FamilyTask) {
        guard !actionInFlight else { return }
        actionInFlight = true
        Task {
            await familyViewModel.updateTaskStatus(task, to: .completed, authViewModel: authViewModel)
            DS.Haptics.success()
            NotificationCenter.default.post(name: .dismissTaskSheets, object: nil)
        }
    }
    
    private func deleteTask() {
        guard !isDeleting else { return }
        isDeleting = true
        Task {
            if let task = task {
                await familyViewModel.deleteTask(task)
            }
            isDeleting = false
            dismiss()
        }
    }
    
    private func approveTask(_ task: FamilyTask) async {
        guard !isApproving else { return }
        isApproving = true
        
        await familyViewModel.verifyProof(
            for: task,
            verifierId: authViewModel.currentUser?.id ?? "",
            approved: true
        )
        
        await authViewModel.refreshCurrentUser()
        
        isApproving = false
        toast = .success("Task approved!")
        DS.Haptics.success()
        
        try? await Task.sleep(for: .seconds(0.5))
        NotificationCenter.default.post(name: .dismissTaskSheets, object: nil)
    }
    
    private func rejectTask(_ task: FamilyTask) async {
        guard !isRejecting else { return }
        isRejecting = true
        
        await familyViewModel.verifyProof(
            for: task,
            verifierId: authViewModel.currentUser?.id ?? "",
            approved: false
        )
        
        isRejecting = false
        toast = .info("Sent back for redo")
        DS.Haptics.warning()
    }
    
    private func statusMessage(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.textSecondary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(color.opacity(0.1)))
    }
    
    private var completedMessage: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.statusCompleted)
            Text(L10n.taskCompleted)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
        .foregroundStyle(.statusCompleted)
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(Color.statusCompleted.opacity(0.1)))
    }
}
