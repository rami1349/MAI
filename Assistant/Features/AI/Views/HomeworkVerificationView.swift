// HomeworkVerificationView.swift
//
//  PURPOSE:
//    MAI homework analysis results screen. Shows per-question
//    breakdown with correct/incorrect/needs-review status,
//    confidence scores, and parent approve/reject controls.
//
//  ARCHITECTURE ROLE:
//    Detail view — presented after proof submission triggers
//    AI verification. Reads HomeworkVerificationViewModel.
//
//  DATA FLOW:
//    HomeworkVerificationViewModel → analysis results, confidence
//    FamilyViewModel → approve/reject task
//

import SwiftUI

struct HomeworkVerificationView: View {
    let task: FamilyTask
    let proofImage: UIImage?
    let proofURL: String?
    
    var onApprove: (() -> Void)?
    var onReject: (() -> Void)?
    
    @State private var viewModel = HomeworkVerificationViewModel()
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // AI Suggestion Banner (always visible)
                    aiSuggestionBanner
                    
                    // Task Header
                    taskHeader
                    
                    // Proof Image
                    if let image = proofImage {
                        proofImageView(image)
                    }
                    
                    // Content based on state
                    contentView
                }
                .padding()
            }
            .navigationTitle("homework_check")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close") { dismiss() }
                }
            }
        }
    }
    
    // MARK: - Content View (State-Based)
    
    @ViewBuilder
    private var contentView: some View {
        if viewModel.isVerifying {
            verifyingView
        } else if let result = viewModel.verificationResult {
            resultsView(result)
        } else if let error = viewModel.errorMessage {
            errorView(error)
        } else {
            initialView
        }
    }
    
    // MARK: - AI Suggestion Banner
    
    private var aiSuggestionBanner: some View {
        HStack(spacing: 10) {
            Image("samy")
                .resizable()
                .scaledToFit()
                .frame(width: DS.IconSize.xl, height: DS.IconSize.xl)
                .foregroundStyle(.statusInfo)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("mai")
                    .font(DS.Typography.bodySmall())
                    .fontWeight(.semibold)
                
                Text("suggestions_only_you_decide")
                    .font(DS.Typography.caption())
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
        }
        .padding()
        .background(Color.purple.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityElement(children: .combine)
    }
    
    // MARK: - Task Header
    
    private var taskHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(task.title)
                .font(DS.Typography.heading())
                .fontWeight(.semibold)
            
            if let description = task.description {
                Text(description)
                    .font(DS.Typography.bodySmall())
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    // MARK: - Proof Image
    
    private func proofImageView(_ image: UIImage) -> some View {
        Image(uiImage: image)
            .resizable()
            .scaledToFit()
            .frame(maxHeight: 250)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 1)
            )
            .accessibilityLabel(String(localized: "homework_proof_image"))
    }
    
    // MARK: - Initial View
    
    private var initialView: some View {
        VStack(spacing: 16) {
            Image("samy")
                .resizable()
                .scaledToFit()
                .frame(width: DS.IconSize.xl, height: DS.IconSize.xl)
                .foregroundStyle(.statusInfo)
            
            Text("mai")
                .font(DS.Typography.subheading())
            
            Text("get_mai_recommendation_to_help_you_review_this_homework")
                .font(DS.Typography.bodySmall())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            // Disclaimers
            VStack(spacing: 8) {
                disclaimerBanner
                
                // Additional warning
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.statusWarning)
                    
                    Text("mai_may_make_mistakes")
                        .font(DS.Typography.caption())
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            
            Button {
                Task { await verify() }
            } label: {
                Label("get_mai_suggestion", image: "samy")
                    .font(DS.Typography.subheading())
                    .frame(maxWidth: .infinity)
                    .padding()
            }
            .buttonStyle(.borderedProminent)
            .disabled(proofImage == nil && proofURL == nil)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }
    
    // MARK: - Verifying View (Skeleton)

    private var verifyingView: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Animated status header
            HStack(spacing: DS.Spacing.md) {
                ProgressView()
                    .tint(.accentPrimary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("analyzing_homework")
                        .font(DS.Typography.subheading())
                        .foregroundStyle(.textPrimary)

                    Text("this_may_take_a_moment")
                        .font(DS.Typography.caption())
                        .foregroundStyle(.textSecondary)
                }

                Spacer()
            }
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(Color.accentPrimary.opacity(0.06))
            )

            // Skeleton: Recommendation banner
            HStack(spacing: DS.Spacing.md) {
                SkeletonCircle(size: 40)

                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    SkeletonShape(width: 160, height: 16)
                    SkeletonShape(width: 100, height: 12)
                }

                Spacer()

                VStack(spacing: DS.Spacing.xs) {
                    SkeletonShape(width: 50, height: 10)
                    HStack(spacing: 3) {
                        ForEach(0..<5, id: \.self) { _ in
                            SkeletonCircle(size: 6)
                        }
                    }
                }
            }
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(Color.textTertiary.opacity(0.06))
            )

            // Skeleton: Analysis summary (3 stat columns)
            VStack(spacing: DS.Spacing.md) {
                HStack {
                    SkeletonShape(width: 80, height: 14)
                    Spacer()
                    SkeletonShape(width: 60, height: 10)
                }

                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { _ in
                        VStack(spacing: DS.Spacing.xs) {
                            SkeletonShape(width: 28, height: 24)
                            SkeletonShape(width: 50, height: 10)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }

                SkeletonShape(height: 12)
                SkeletonShape(width: 200, height: 12)
            }
            .padding(DS.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(Color.textTertiary.opacity(0.06))
            )

            // Skeleton: Question rows
            VStack(spacing: DS.Spacing.sm) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: DS.Spacing.md) {
                        SkeletonCircle(size: 28)

                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            SkeletonShape(width: 180, height: 14)
                            SkeletonShape(width: 120, height: 10)
                        }

                        Spacer()

                        SkeletonShape(width: 60, height: 22, radius: DS.Radius.badge)
                    }
                    .padding(DS.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: DS.Radius.md)
                            .fill(Color.textTertiary.opacity(0.04))
                    )
                }
            }

            // Skeleton: Action buttons
            HStack(spacing: DS.Spacing.md) {
                SkeletonShape(height: 44, radius: DS.Radius.lg)
                SkeletonShape(height: 44, radius: DS.Radius.lg)
            }

            // Disclaimer
            Text("remember_mai_suggestions_may_be_inaccurate")
                .font(DS.Typography.micro())
                .foregroundStyle(.textTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(String(localized: "analyzing_homework"))
    }
    
    // MARK: - Results View
    
    private func resultsView(_ result: VerificationResult) -> some View {
        VStack(spacing: 16) {
            // Low confidence warning (if applicable)
            if result.isLowConfidence {
                lowConfidenceWarning(result)
            }
            
            // Recommendation Banner
            recommendationBanner(result)
            
            // Analysis Summary
            analysisSummary(result)
            
            // Questions Breakdown
            if !result.questions.isEmpty {
                questionsBreakdown(result)
            }
            
            // Encouragement for child
            encouragementCard(result)
            
            // Areas to review
            if let areas = result.areasToReview, !areas.isEmpty {
                areasCard(areas)
            }
            
            disclaimerBanner
            
            // Parent Action Buttons
            parentActionButtons(confidence: result.confidence)
        }
    }
    
    // MARK: - Low Confidence Warning
    
    private func lowConfidenceWarning(_ result: VerificationResult) -> some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(DS.Typography.displayMedium())
                    .foregroundStyle(.statusWarning)
                
                Text("low_confidence_analysis")
                    .font(DS.Typography.subheading())
                    .foregroundStyle(.statusWarning)
            }
            
            Text(result.confidenceReason ?? "The AI is uncertain about this analysis. Please review carefully before making a decision.")
                .font(DS.Typography.bodySmall())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Text("manual_review_strongly_recommended")
                .font(DS.Typography.caption())
                .fontWeight(.semibold)
                .foregroundStyle(.statusWarning)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("warning_low_confidence_manual_review")
    }
    
    // MARK: - Recommendation Banner
    
    private func recommendationBanner(_ result: VerificationResult) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                Text(result.recommendation.emoji)
                    .font(DS.Typography.displayLarge())
                
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(result.recommendation.title)
                            .font(DS.Typography.subheading())
                            .fontWeight(.bold)
                        
                        Text("suggestion")
                            .font(DS.Typography.caption())
                            .foregroundStyle(.textOnAccent.opacity(0.8))
                    }
                    
                    Text(result.subject)
                        .font(DS.Typography.bodySmall())
                        .foregroundStyle(.textOnAccent.opacity(0.9))
                }
                
                Spacer()
                
                // Confidence indicator
                confidenceIndicator(result.confidence)
            }
            
            if let message = result.recommendationMessage {
                Text(message)
                    .font(DS.Typography.bodySmall())
                    .foregroundStyle(.textOnAccent.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(.textOnAccent)
        .padding()
        .background(result.recommendation.color.gradient)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(String(localized: "mai_suggests")): \(result.recommendation.title) — \(result.confidencePercentage)%")
    }
    
    // MARK: - Confidence Indicator
    
    private func confidenceIndicator(_ confidence: Double) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("ai_confidence")
                .font(DS.Typography.micro())
                .foregroundStyle(.textOnAccent.opacity(0.7))
            
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(index < Int(confidence * 5) ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            
            Text("\(Int(confidence * 100))%")
                .font(DS.Typography.caption())
                .fontWeight(.semibold)
                .foregroundStyle(confidence < 0.7 ? .accentYellow : .textOnAccent)
        }
    }
    
    // MARK: - Analysis Summary
    
    private func analysisSummary(_ result: VerificationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("analysis")
                    .font(DS.Typography.subheading())
                
                Spacer()
                
                Text("mai_estimate")
                    .font(DS.Typography.micro())
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 0) {
                summaryItem(
                    value: "\(result.analysis.likelyCorrect)",
                    label: String(localized: "likely_correct"),
                    color: .green
                )
                
                Divider().frame(height: 40)
                
                summaryItem(
                    value: "\(result.analysis.likelyIncorrect)",
                    label: String(localized: "likely_wrong"),
                    color: .red
                )
                
                Divider().frame(height: 40)
                
                summaryItem(
                    value: "\(result.analysis.uncertain)",
                    label: String(localized: "uncertain"),
                    color: .orange
                )
            }
            
            Text(result.summary)
                .font(DS.Typography.bodySmall())
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    private func summaryItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(DS.Typography.displayMedium())
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(label)
                .font(DS.Typography.micro())
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Questions Breakdown
    
    private func questionsBreakdown(_ result: VerificationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("question_details")
                .font(DS.Typography.subheading())
            
            ForEach(result.questions) { question in
                questionRow(question)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    private func questionRow(_ question: VerificationQuestion) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(AppStrings.questionNumberShort(question.questionNumber))
                    .font(DS.Typography.bodySmall())
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(question.assessment.emoji)
                    Text(question.assessment.accessibilityLabel)
                        .font(DS.Typography.caption())
                        .foregroundStyle(question.assessment.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(question.assessment.color.opacity(0.15))
                .clipShape(Capsule())
            }
            
            if let questionText = question.questionText, !questionText.isEmpty {
                Text(questionText)
                    .font(DS.Typography.bodySmall())
                    .lineLimit(2)
            }
            
            HStack {
                Text("student")
                    .foregroundStyle(.secondary)
                Text(question.studentAnswer)
                    .fontWeight(.medium)
            }
            .font(DS.Typography.caption())
            
            if question.assessment != .likelyCorrect, let expected = question.expectedAnswer {
                HStack {
                    Text("mai_suggests")
                        .foregroundStyle(.secondary)
                    Text(expected)
                        .foregroundStyle(.statusSuccess)
                }
                .font(DS.Typography.caption())
            }
            
            if let note = question.note, !note.isEmpty {
                Text(note)
                    .font(DS.Typography.caption())
                    .foregroundStyle(.secondary)
                    .padding(.top, 2)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
    
    // MARK: - Encouragement Card
    
    private func encouragementCard(_ result: VerificationResult) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "star.fill")
                .font(DS.Typography.displayMedium())
                .foregroundStyle(.accentYellow)
            
            Text(result.encouragement)
                .font(DS.Typography.bodySmall())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.yellow.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    // MARK: - Areas to Review
    
    private func areasCard(_ areas: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("suggested", systemImage: "lightbulb.fill")
                .font(DS.Typography.bodySmall())
                .fontWeight(.medium)
                .foregroundStyle(.statusWarning)
            
            ForEach(areas, id: \.self) { area in
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                    Text(area)
                        .font(DS.Typography.caption())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.orange.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    // MARK: - Disclaimer Banner
    
    private var disclaimerBanner: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.statusInfo)
                
                Text("mai_limitations")
                    .font(DS.Typography.caption())
                    .fontWeight(.semibold)
            }
            
            Text("mai_limitations_detail")
                .font(DS.Typography.micro())
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
    
    // MARK: - Parent Action Buttons
    
    private func parentActionButtons(confidence: Double) -> some View {
        VStack(spacing: 12) {
            Text("your_decision")
                .font(DS.Typography.subheading())
            
            // Low confidence reminder
            if confidence < 0.7 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.statusWarning)
                    Text("low_ai_confidence_please_review_carefully")
                        .font(DS.Typography.caption())
                        .foregroundStyle(.statusWarning)
                }
            }
            
            HStack(spacing: 12) {
                Button {
                    onReject?()
                    dismiss()
                } label: {
                    Label("reject", systemImage: "xmark")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
                .tint(.red)
                
                Button {
                    onApprove?()
                    dismiss()
                } label: {
                    Label("approve", systemImage: "checkmark")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
            
            Text("only_you_can_approve_or_reject_ai_cannot_make_this")
                .font(DS.Typography.micro())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    // MARK: - Error View
    
    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(DS.Typography.displayLarge())
                .foregroundStyle(.statusWarning)
            
            Text("could_not_analyze")
                .font(DS.Typography.subheading())
            
            Text(message)
                .font(DS.Typography.bodySmall())
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Text("please_review_the_homework_manually")
                .font(DS.Typography.caption())
                .foregroundStyle(.secondary)
            
            HStack(spacing: 12) {
                if viewModel.canRetry {
                    Button("try_again") {
                        Task { await viewModel.retry() }
                    }
                    .buttonStyle(.bordered)
                }
                
                Button("review_manually") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
    }
    
    // MARK: - Actions
    
    private func verify() async {
        if let url = proofURL {
            await viewModel.verifyHomework(imageUrl: url, taskId: task.id ?? "")
        } else if let image = proofImage {
            await viewModel.verifyHomework(image: image, taskId: task.id ?? "")
        }
    }
}

// MARK: - Preview

#Preview {
    HomeworkVerificationView(
        task: FamilyTask(
            id: "preview",
            familyId: "fam1",
            groupId: nil,
            title: " Homework",
            description: "Complete problems 1-10",
            assignedTo: "user1",
            assignees: [],
            assignedBy: "parent1",
            dueDate: .now,
            scheduledTime: nil,
            status: .pendingVerification,
            priority: .medium,
            createdAt: Date.now,
            completedAt: nil,
            hasReward: true,
            rewardAmount: 5.0,
            requiresProof: true,
            proofType: .photo,
            proofURL: nil,
            proofURLs: nil,
            proofVerifiedBy: nil,
            proofVerifiedAt: nil,
            rewardPaid: false,
            isRecurring: false,
            recurrenceRule: nil,
            pomodoroDurationMinutes: nil,
            totalFocusedSeconds: nil,
            lastFocusDate: nil
        ),
        proofImage: nil,
        proofURL: nil,
        onApprove: { print("Approved") },
        onReject: { print("Rejected") }
    )
}
