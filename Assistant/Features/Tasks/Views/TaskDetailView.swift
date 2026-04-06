//
//  TaskDetailView.swift
//
//
//
//  PURPOSE:
//    Full detail screen for a single task. Shows status, assignee,
//    due date, proof submissions, MAI analysis results, focus timer
//    link, and parent approval/rejection controls.
//
//  ARCHITECTURE ROLE:
//    Detail view — the deepest navigation destination in the task flow.
//    Reads task from TaskViewModel, triggers proof/verification actions.
//
//  DATA FLOW:
//    TaskViewModel → task lookup, status updates
//    HomeworkVerificationViewModel → AI analysis display
//    FamilyViewModel → approve/reject/complete actions
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
        taskVM.task(byStableId: taskId)
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
              let currentUser = authViewModel.currentUser else { return false }
        // Task creator can always verify their own assignments
        if task.assignedBy == currentUser.id { return true }
        // Otherwise check canVerifyHomework capability
        return currentUser.resolvedCapabilities.canVerifyHomework
    }
    
    // Check if this is a homework task with AI verification
    private var isHomeworkTask: Bool {
        task?.taskType == .homework
    }
    
    var statusColor: Color {
        guard let task = task else { return .gray }
        switch task.status {
        case .todo: return Color.statusTodo
        case .inProgress: return Color.statusInProgress
        case .pendingVerification: return Color.statusPending
        case .completed: return Color.statusCompleted
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
                        VStack(spacing: DS.Spacing.lg) {
                            headerSection(task: task)
                            titleSection(task: task)
                            infoSection(task: task)
                            
                            // Show proof section if proof exists
                            if task.hasProofUploaded {
                                proofSection(task: task)
                            }
                            
                            actionButtons(task: task)
                            Spacer().frame(height: DS.Spacing.jumbo)
                        }
                        .padding(DS.Layout.adaptiveScreenPadding)
                        .constrainedWidth(.readable)
                    }
                } else {
                    VStack(spacing: DS.Spacing.lg) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(DS.Typography.displayLarge())
                            .foregroundStyle(.textSecondary)
                        Text("task_not_found")
                            .font(DS.Typography.subheading())
                            .foregroundStyle(.textSecondary)
                    }
                }
            }
            .navigationTitle("task_details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close") { dismiss() }
                }
                ToolbarItem(placement: .destructiveAction) {
                    Menu {
                        if task?.assignedBy == authViewModel.currentUser?.id {
                            Button(action: { showEditTask = true }) {
                                Label("edit_task", systemImage: "pencil")
                            }
                        }
                        Button(role: .destructive, action: { showDeleteConfirm = true }) {
                            Label("delete_task", systemImage: "trash")
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
                        .presentationBackground(Color.themeSurfacePrimary)
                }
            }
            .alert("delete_task_confirm", isPresented: $showDeleteConfirm) {
                Button("cancel", role: .cancel) {}
                Button("delete", role: .destructive) {
                    deleteTask()
                }
            } message: {
                Text("action_cannot_be_undone")
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
                Text(task.taskType?.displayName ?? String(localized: "task"))
            }
            .font(DS.Typography.caption())
            
            .foregroundStyle(task.taskType == .homework ? .accentPrimary : .textSecondary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                Capsule().fill(
                    task.taskType == .homework
                        ? Color.accentPrimary.opacity(0.15)
                        : Color.themeCardBackground
                )
            )
            
            Spacer()
            
            // Status badge
            HStack(spacing: DS.Spacing.xs) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 8, height: 8)
                Text(task.status.rawValue)
                    .font(DS.Typography.caption())
                    
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
                .font(DS.Typography.displayMedium())
                .foregroundStyle(.textPrimary)
            
            if let description = task.description, !description.isEmpty {
                Text(description)
                    .font(DS.Typography.body())
                    .foregroundStyle(.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    // MARK: - Info Section
    
    private func infoSection(task: FamilyTask) -> some View {
        VStack(spacing: DS.Spacing.md) {
            if let assignee = assignee {
                infoRow(icon: "person.fill", label: "assigned_to") {
                    HStack(spacing: DS.Spacing.xs) {
                        AvatarView(user: assignee, size: 24)
                        Text(assignee.displayName)
                            .foregroundStyle(.textPrimary)
                    }
                }
            }
            
            infoRow(icon: "calendar", label: "due_date") {
                Text(task.dueDate.formattedDate)
                    .foregroundStyle(task.isOverdue ? .red : .textPrimary)
            }
            
            if let scheduledTime = task.scheduledTime {
                infoRow(icon: "clock.fill", label: "scheduled_time") {
                    Text(scheduledTime.formatted(date: .omitted, time: .shortened))
                        .foregroundStyle(.textPrimary)
                }
            }
            
            if let group = taskGroup {
                infoRow(icon: "folder.fill", label: "group_name") {
                    HStack(spacing: DS.Spacing.xs) {
                        Image(systemName: group.icon)
                            .foregroundStyle(Color(hex: group.color))
                        Text(group.name)
                            .foregroundStyle(.textPrimary)
                    }
                }
            }
            
            if task.hasReward, let amount = task.rewardAmount {
                infoRow(icon: "dollarsign.circle.fill", label: "reward") {
                    Text(amount.currencyString)
                        .foregroundStyle(.accentGreen)
                        
                }
            }
            
            // Show homework subject if applicable
            if task.taskType == .homework, let subject = task.homeworkSubject {
                infoRow(icon: "book.fill", label: String(localized: "subject")) {
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
                .font(DS.Typography.body())
                .foregroundStyle(.textSecondary)
            Spacer()
            content()
                .font(DS.Typography.body())
        }
    }
    
    // MARK: - Proof Section
    
    private func proofSection(task: FamilyTask) -> some View {
        VStack(alignment: .leading, spacing: DS.Spacing.lg) {
            // Header
            HStack {
                Image(systemName: "doc.text.image")
                    .foregroundStyle(.accentPrimary)
                Text("submitted_proof")
                    .font(DS.Typography.subheading())
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
                    Text(AppStrings.verifiedOnDate(verifiedAt.formattedDate))
                        .font(DS.Typography.caption())
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
                    Text("pending")
                }
                .font(DS.Typography.caption())
                
                .foregroundStyle(.textOnAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Capsule().fill(Color.statusPending))
                
            case .completed:
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.seal.fill")
                    Text("verified")
                }
                .font(DS.Typography.caption())
                
                .foregroundStyle(.textOnAccent)
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
                        .fill(Color.themeCardBackground)
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
                                    .fill(Color.themeCardBackground)
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
                        .font(DS.Typography.heading())
                        .foregroundStyle(recommendationColor(computedStats.recommendation))
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: DS.Spacing.xs) {
                        Image("samy")
                            .resizable()
                            .scaledToFit()
                            .frame(width: DS.IconSize.md, height: DS.IconSize.md)
                            .font(DS.Typography.caption())
                        Text("mai_analysis")
                            .font(DS.Typography.caption())
                            
                    }
                    .foregroundStyle(.textSecondary)
                    
                    Text(recommendationMessage(computedStats.recommendation))
                        .font(DS.Typography.body())
                        
                        .foregroundStyle(recommendationColor(computedStats.recommendation))
                }
                
                Spacer()
                
                // Show computed score percentage instead of AI "confidence"
                if computedStats.total > 0 {
                    VStack(spacing: 2) {
                        Text("\(computedStats.scorePercent)%")
                            .font(DS.Typography.caption())
                            
                            .foregroundStyle(confidenceColor(Double(computedStats.scorePercent) / 100.0))
                        Text("score")
                            .font(DS.Typography.micro())
                            .foregroundStyle(.textTertiary)
                    }
                } else {
                    VStack(spacing: 2) {
                        Text("\(Int(verification.confidence * 100))%")
                            .font(DS.Typography.caption())
                            
                            .foregroundStyle(confidenceColor(verification.confidence))
                        Text("confidence_short")
                            .font(DS.Typography.micro())
                            .foregroundStyle(.textTertiary)
                    }
                }
            }
            
            // Score breakdown — derived from actual questions array
            if computedStats.total > 0 {
                HStack(spacing: DS.Spacing.lg) {
                    statItem(value: "\(computedStats.correct)", label: String(localized: "correct"), color: Color.accentGreen)
                    if computedStats.wrong > 0 {
                        statItem(value: "\(computedStats.wrong)", label: String(localized: "wrong"), color: .red)
                    }
                    if computedStats.uncertain > 0 {
                        statItem(value: "\(computedStats.uncertain)", label: String(localized: "uncertain"), color: .orange)
                    }
                    Spacer()
                    statItem(value: "\(computedStats.correct)/\(computedStats.total)", label: String(localized: "score"), color: Color.textPrimary)
                }
            }
            
            // Per-question detail (expandable)
            if let questions = verification.questions, !questions.isEmpty {
                questionBreakdown(questions: questions)
            }
            
            // Encouragement for the child
            if let encouragement = verification.encouragement, !encouragement.isEmpty {
                Text(encouragement)
                    .font(DS.Typography.caption())
                    .foregroundStyle(.accentPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            
            // Disclaimer
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "info.circle")
                    .font(DS.Typography.micro())
                Text("mai_may_make_mistakes_parent_has_final_say")
                    .font(DS.Typography.micro())
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
        case "approve": return String(localized: "looks_correct")
        case "review": return String(localized: "some_issues_found")
        case "unclear": return String(localized: "couldnt_read_clearly")
        case "cannot_verify": return String(localized: "cant_verify_this_type")
        default: return String(localized: "analysis_complete")
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
    
    private func questionBreakdown(questions: [FamilyTask.AIVerificationQuestion]) -> some View {
        let wrong = questions.filter { $0.assessment == "likely_incorrect" || $0.assessment == "uncertain" || $0.assessment == "needs_review" }
        let correct = questions.filter { $0.assessment == "likely_correct" }
        
        return VStack(alignment: .leading, spacing: DS.Spacing.sm) {
            // Show wrong/uncertain answers first (these are what parents care about)
            if !wrong.isEmpty {
                Text("needs_attention")
                    .font(DS.Typography.caption())
                    
                    .foregroundStyle(.statusError)
                
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
                    Text(AppStrings.correctAnswersCount(correct.count))
                        .font(DS.Typography.caption())
                        
                        .foregroundStyle(.accentGreen)
                }
                .tint(Color.accentGreen)
            }
        }
    }
    
    private func questionRow(_ q: FamilyTask.AIVerificationQuestion, isCorrect: Bool) -> some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(DS.Typography.caption())
                .foregroundStyle(isCorrect ? .accentGreen : .red)
                .padding(.top, 2)
            
            VStack(alignment: .leading, spacing: 2) {
                // Question number + text
                if let text = q.questionText, !text.isEmpty {
                    Text(AppStrings.questionNumberWithText(q.questionNumber, text))
                        .font(DS.Typography.caption())
                        .foregroundStyle(.textPrimary)
                        .lineLimit(2)
                } else {
                    Text(AppStrings.questionNumberLabel(q.questionNumber))
                        .font(DS.Typography.caption())
                        .foregroundStyle(.textPrimary)
                }
                
                // Student answer vs expected
                if let student = q.studentAnswer, !student.isEmpty {
                    HStack(spacing: 4) {
                        Text("answer")
                            .font(DS.Typography.micro())
                            .foregroundStyle(.textTertiary)
                        Text("student")
                            .font(DS.Typography.micro())
                            .foregroundStyle(isCorrect ? .accentGreen : .red)
                    }
                }
                
                if !isCorrect, let expected = q.expectedAnswer, !expected.isEmpty {
                    HStack(spacing: 4) {
                        Text("expected")
                            .font(DS.Typography.micro())
                            .foregroundStyle(.textTertiary)
                    }
                }
                
                // Note if any
                if let note = q.note, !note.isEmpty, !isCorrect {
                    Text(note)
                        .font(DS.Typography.micro())
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
                .font(DS.Typography.body())
                
                .foregroundStyle(color)
            Text(label)
                .font(DS.Typography.micro())
                .foregroundStyle(.textSecondary)
        }
    }
    
    // MARK: - AI Loading Card
    
    private func aiLoadingCard() -> some View {
        HStack(spacing: DS.Spacing.md) {
            ProgressView()
                .tint(Color.accentPrimary)
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: DS.Spacing.xs) {
                    Image("samy")
                        .resizable()
                        .scaledToFit()
                        .frame(width: DS.IconSize.md, height: DS.IconSize.md)
                    Text("mai_analysis")
                        
                }
                .font(DS.Typography.caption())
                .foregroundStyle(.accentPrimary)
                
                Text("checking_homework")
                    .font(DS.Typography.caption())
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
                .foregroundStyle(.statusWarning)
            VStack(alignment: .leading, spacing: 2) {
                Text("mai_couldnt_analyze_please_review_manually")
                    .font(DS.Typography.caption())
                    
                    .foregroundStyle(.statusWarning)
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
                    Text("review_the_photo_and_decide_if_the_chore_is_done")
                        .font(DS.Typography.caption())
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
                        Text("needs_redo")
                    }
                    .font(DS.Typography.body())
                    
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.red.opacity(0.1))
                    .foregroundStyle(.statusError)
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
                        Text("approve")
                    }
                    .font(DS.Typography.body())
                    
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.accentGreen)
                    .foregroundStyle(.textOnAccent)
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
                .font(DS.Typography.caption())
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    
    private func guidanceMessage(_ recommendation: String) -> String {
        switch recommendation {
        case "approve": return String(localized: "mai_suggests_approving")
        case "review": return String(localized: "mai_found_issues")
        case "unclear": return String(localized: "mai_couldnt_read")
        case "cannot_verify": return String(localized: "mai_cant_verify")
        default: return String(localized: "review_and_decide")
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
        case "approve": return Color.accentGreen
        case "review": return .orange
        case "unclear": return .yellow
        case "cannot_verify": return .gray
        default: return Color.textSecondary
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
        if confidence >= 0.8 { return Color.accentGreen }
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
                        title: "start_task",
                        isLoading: actionInFlight
                    ) {
                        startTask(task)
                    }
                    
                case .inProgress:
                    Button(action: { showFocusTimer = true }) {
                        HStack(spacing: DS.Spacing.sm) {
                            Image(systemName: "timer")
                                .font(DS.Typography.heading())
                            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                                Text("start_focus")
                                    .font(DS.Typography.subheading())
                                Text("pomodoro_for_task")
                                    .font(DS.Typography.caption())
                                    .opacity(0.8)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(DS.Typography.caption())
                        }
                        .foregroundStyle(.textOnAccent)
                        .padding(DS.Spacing.md)
                        .background(
                            LinearGradient(
                                colors: [Color.accentPrimary, Color.accentBlue],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
                    }
                    .disabled(actionInFlight)
                    
                    if task.requiresProof {
                        PrimaryButton(
                            title: "submit_proof",
                            isDisabled: actionInFlight
                        ) {
                            showProofCapture = true
                        }
                    } else {
                        PrimaryButton(
                            title: "mark_complete",
                            isLoading: actionInFlight
                        ) {
                            completeTask(task)
                        }
                    }
                    
                case .pendingVerification:
                    if canVerifyProof {
                        statusMessage("Review the submitted proof above", color: Color.statusPending)
                    } else {
                        statusMessage("waiting_for_verification", color: Color.statusPending)
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
            toast = .success("task_started")
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
        toast = .success(String(localized: "task_approved"))
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
        toast = .info(String(localized: "sent_back_for_redo"))
        DS.Haptics.warning()
    }
    
    private func statusMessage(_ text: String, color: Color) -> some View {
        Text(text)
            .font(DS.Typography.body())
            .foregroundStyle(.textSecondary)
            .frame(maxWidth: .infinity)
            .padding()
            .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(color.opacity(0.1)))
    }
    
    private var completedMessage: some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.statusCompleted)
            Text("task_completed")
                
        }
        .font(DS.Typography.body())
        .foregroundStyle(.statusCompleted)
        .frame(maxWidth: .infinity)
        .padding()
        .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(Color.statusCompleted.opacity(0.1)))
    }
}
