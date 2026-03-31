// ============================================================================
// HomeworkVerificationView.swift
//
//
// SwiftUI View for AI Homework Verification
//
// IMPORTANT: AI provides RECOMMENDATIONS only — Parent makes final decision
// ============================================================================

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
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("suggestions_only_you_decide")
                    .font(.caption)
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
                .font(.title3)
                .fontWeight(.semibold)
            
            if let description = task.description {
                Text(description)
                    .font(.subheadline)
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
            .accessibilityLabel("Homework ProofImage")
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
                .font(.headline)
            
            Text("get_mai_recommendation_to_help_you_review_this_homework")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            // Disclaimers
            VStack(spacing: 8) {
                disclaimerBanner
                
                // Additional warning
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.statusWarning)
                    
                    Text("MaiMayMakeMistakes")
                        .font(.caption)
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
                    .font(.headline)
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
    
    // MARK: - Verifying View
    
    private var verifyingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            
            Text("analyzing_homework")
                .font(.headline)
            
            VStack(spacing: 4) {
                Text("CheckingAnswers")
                Text("this_may_take_a_moment")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
            
            // Reminder during loading
            Text("remember_mai_suggestions_may_be_inaccurate")
                .font(.caption2)
                .foregroundStyle(.statusWarning)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(40)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("analyzing_homework_please_wait")
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
                    .font(.title2)
                    .foregroundStyle(.statusWarning)
                
                Text("low_confidence_analysis")
                    .font(.headline)
                    .foregroundStyle(.statusWarning)
            }
            
            Text(result.confidenceReason ?? "The AI is uncertain about this analysis. Please review carefully before making a decision.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Text("manual_review_strongly_recommended")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.statusWarning)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("warningLowConfidenceAnalysisManualReviewStro")
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
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("suggestion")
                            .font(.caption)
                            .foregroundStyle(.textOnAccent.opacity(0.8))
                    }
                    
                    Text(result.subject)
                        .font(.subheadline)
                        .foregroundStyle(.textOnAccent.opacity(0.9))
                }
                
                Spacer()
                
                // Confidence indicator
                confidenceIndicator(result.confidence)
            }
            
            if let message = result.recommendationMessage {
                Text(message)
                    .font(.subheadline)
                    .foregroundStyle(.textOnAccent.opacity(0.95))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .foregroundStyle(.textOnAccent)
        .padding()
        .background(result.recommendation.color.gradient)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("MAI Suggestion: \(result.recommendation.title) with \(result.confidencePercentage)% confidence")
    }
    
    // MARK: - Confidence Indicator
    
    private func confidenceIndicator(_ confidence: Double) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text("ai_confidence")
                .font(.caption2)
                .foregroundStyle(.textOnAccent.opacity(0.7))
            
            HStack(spacing: 4) {
                ForEach(0..<5, id: \.self) { index in
                    Circle()
                        .fill(index < Int(confidence * 5) ? Color.white : Color.white.opacity(0.3))
                        .frame(width: 6, height: 6)
                }
            }
            
            Text("\(Int(confidence * 100))%")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(confidence < 0.7 ? .accentYellow : .textOnAccent)
        }
    }
    
    // MARK: - Analysis Summary
    
    private func analysisSummary(_ result: VerificationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("analysis")
                    .font(.headline)
                
                Spacer()
                
                Text("mai_estimate")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            
            HStack(spacing: 0) {
                summaryItem(
                    value: "\(result.analysis.likelyCorrect)",
                    label: "Likely Correct",
                    color: .green
                )
                
                Divider().frame(height: 40)
                
                summaryItem(
                    value: "\(result.analysis.likelyIncorrect)",
                    label: "Likely Wrong",
                    color: .red
                )
                
                Divider().frame(height: 40)
                
                summaryItem(
                    value: "\(result.analysis.uncertain)",
                    label: "Uncertain",
                    color: .orange
                )
            }
            
            Text(result.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    private func summaryItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(color)
            
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
    
    // MARK: - Questions Breakdown
    
    private func questionsBreakdown(_ result: VerificationResult) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("question_details")
                .font(.headline)
            
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
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack(spacing: 4) {
                    Text(question.assessment.emoji)
                    Text(question.assessment.accessibilityLabel)
                        .font(.caption)
                        .foregroundStyle(question.assessment.color)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(question.assessment.color.opacity(0.15))
                .clipShape(Capsule())
            }
            
            if let questionText = question.questionText, !questionText.isEmpty {
                Text(questionText)
                    .font(.subheadline)
                    .lineLimit(2)
            }
            
            HStack {
                Text("student")
                    .foregroundStyle(.secondary)
                Text(question.studentAnswer)
                    .fontWeight(.medium)
            }
            .font(.caption)
            
            if question.assessment != .likelyCorrect, let expected = question.expectedAnswer {
                HStack {
                    Text("mai_suggests")
                        .foregroundStyle(.secondary)
                    Text(expected)
                        .foregroundStyle(.statusSuccess)
                }
                .font(.caption)
            }
            
            if let note = question.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
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
                .font(.title2)
                .foregroundStyle(.accentYellow)
            
            Text(result.encouragement)
                .font(.subheadline)
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
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.statusWarning)
            
            ForEach(areas, id: \.self) { area in
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 6, height: 6)
                    Text(area)
                        .font(.caption)
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
                    .font(.caption)
                    .fontWeight(.semibold)
            }
            
            Text("• Results are suggestions, not guarantees\n• Handwriting recognition may be inaccurate\n• You make the final decision")
                .font(.caption2)
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
                .font(.headline)
            
            // Low confidence reminder
            if confidence < 0.7 {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.statusWarning)
                    Text("low_ai_confidence_please_review_carefully")
                        .font(.caption)
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
                .font(.caption2)
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
                .font(.headline)
            
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            
            Text("please_review_the_homework_manually")
                .font(.caption)
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
            dueDate: Date(),
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
