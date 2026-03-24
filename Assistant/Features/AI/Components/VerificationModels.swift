// ============================================================================
// VerificationModels.swift
// 
//
// UNIFIED AI VERIFICATION MODELS
//
// This file consolidates duplicate verification types that were in:
// - ChatViewModel.swift (ChatVerificationResult, ChatAIRecommendation, etc.)
// - HomeworkVerificationViewModel.swift (VerificationResult, AIRecommendation, etc.)
//
// Now there's ONE source of truth used by both ViewModels.


import SwiftUI

// MARK: - AI Recommendation

/// AI verification recommendation status
/// Used by both chat inline verification and dedicated verification view
enum AIRecommendation: String, Codable {
    case approve = "approve"
    case review = "review"
    case unclear = "unclear"
    case cannotVerify = "cannot_verify"
    
    var emoji: String {
        switch self {
        case .approve: return "✅"
        case .review: return "⚠️"
        case .unclear: return "🧐"
        case .cannotVerify: return "❓"
        }
    }
    
    var color: Color {
        switch self {
        case .approve: return .green
        case .review: return .orange
        case .unclear: return .yellow
        case .cannotVerify: return .gray
        }
    }
    
    var title: String {
        switch self {
        case .approve: return "looksCorrect"
        case .review: return "needsReviewLabel"
        case .unclear: return "unclearLabel"
        case .cannotVerify: return "cannotVerify"
        }
    }
    
    /// Whether this recommendation suggests approval is safe
    var suggestsApproval: Bool {
        self == .approve
    }
    
    /// Whether manual review is recommended
    var requiresReview: Bool {
        self != .approve
    }
}

// MARK: - Question Assessment

/// Assessment status for individual homework questions
enum QuestionAssessment: String, Codable {
    case likelyCorrect = "likely_correct"
    case likelyIncorrect = "likely_incorrect"
    case uncertain = "uncertain"
    case needsReview = "needs_review"
    
    var emoji: String {
        switch self {
        case .likelyCorrect: return "✓"
        case .likelyIncorrect: return "✗"
        case .uncertain: return "?"
        case .needsReview: return "👀"
        }
    }
    
    var color: Color {
        switch self {
        case .likelyCorrect: return .green
        case .likelyIncorrect: return .red
        case .uncertain: return .orange
        case .needsReview: return .blue
        }
    }
    
    var accessibilityLabel: String {
        switch self {
        case .likelyCorrect: return "likelyCorrectLabel"
        case .likelyIncorrect: return "likelyIncorrectLabel"
        case .uncertain: return "uncertainLabel"
        case .needsReview: return "needsReviewLabel"
        }
    }
}

// MARK: - Verification Question

/// Individual question analysis from AI verification
struct VerificationQuestion: Codable, Identifiable, Hashable {
    var id: String { questionNumber }
    
    let questionNumber: String
    let questionText: String?
    let studentAnswer: String
    let expectedAnswer: String?
    let assessment: QuestionAssessment
    let note: String?
    let confidence: Double?
    
    enum CodingKeys: String, CodingKey {
        case questionNumber, questionText, studentAnswer, expectedAnswer
        case assessment, note, confidence
    }
    
    init(
        questionNumber: String,
        questionText: String? = nil,
        studentAnswer: String,
        expectedAnswer: String? = nil,
        assessment: QuestionAssessment,
        note: String? = nil,
        confidence: Double? = nil
    ) {
        self.questionNumber = questionNumber
        self.questionText = questionText
        self.studentAnswer = studentAnswer
        self.expectedAnswer = expectedAnswer
        self.assessment = assessment
        self.note = note
        self.confidence = confidence
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        questionNumber = try container.decode(String.self, forKey: .questionNumber)
        questionText = try container.decodeIfPresent(String.self, forKey: .questionText)
        studentAnswer = try container.decodeIfPresent(String.self, forKey: .studentAnswer) ?? "Unable to read"
        expectedAnswer = try container.decodeIfPresent(String.self, forKey: .expectedAnswer)
        
        // Handle assessment as string with fallback
        let assessmentString = try container.decodeIfPresent(String.self, forKey: .assessment) ?? "uncertain"
        assessment = QuestionAssessment(rawValue: assessmentString) ?? .uncertain
        
        note = try container.decodeIfPresent(String.self, forKey: .note)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence)
    }
    
    /// Whether this question needs attention (incorrect or uncertain)
    var needsAttention: Bool {
        assessment != .likelyCorrect
    }
}

// MARK: - Verification Analysis

/// Summary statistics from verification analysis
struct VerificationAnalysis: Codable, Hashable {
    let totalQuestions: Int
    let likelyCorrect: Int
    let likelyIncorrect: Int
    let uncertain: Int
    let scoreEstimate: String?
    
    /// Default empty analysis
    static let empty = VerificationAnalysis(
        totalQuestions: 0,
        likelyCorrect: 0,
        likelyIncorrect: 0,
        uncertain: 0,
        scoreEstimate: nil
    )
    
    init(
        totalQuestions: Int = 0,
        likelyCorrect: Int = 0,
        likelyIncorrect: Int = 0,
        uncertain: Int = 0,
        scoreEstimate: String? = nil
    ) {
        self.totalQuestions = totalQuestions
        self.likelyCorrect = likelyCorrect
        self.likelyIncorrect = likelyIncorrect
        self.uncertain = uncertain
        self.scoreEstimate = scoreEstimate
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        totalQuestions = try container.decodeIfPresent(Int.self, forKey: .totalQuestions) ?? 0
        likelyCorrect = try container.decodeIfPresent(Int.self, forKey: .likelyCorrect) ?? 0
        likelyIncorrect = try container.decodeIfPresent(Int.self, forKey: .likelyIncorrect) ?? 0
        uncertain = try container.decodeIfPresent(Int.self, forKey: .uncertain) ?? 0
        scoreEstimate = try container.decodeIfPresent(String.self, forKey: .scoreEstimate)
    }
    
    /// Number of questions needing attention
    var questionsNeedingAttention: Int {
        likelyIncorrect + uncertain
    }
    
    /// Percentage of correct answers (0-100)
    var correctPercentage: Double {
        guard totalQuestions > 0 else { return 0 }
        return Double(likelyCorrect) / Double(totalQuestions) * 100
    }
    
    /// Human-readable score string
    var scoreText: String {
        if let estimate = scoreEstimate {
            return estimate
        }
        guard totalQuestions > 0 else { return "N/A" }
        return "\(likelyCorrect)/\(totalQuestions)"
    }
}

// MARK: - Verification Result

/// Complete verification result from AI analysis
struct VerificationResult: Codable {
    let recommendation: AIRecommendation
    let recommendationMessage: String?
    let confidence: Double
    let confidenceReason: String?
    
    let subject: String
    let detectedLanguage: String?
    
    let analysis: VerificationAnalysis
    let questions: [VerificationQuestion]
    
    let summary: String
    let disclaimer: String?
    let encouragement: String
    let areasToReview: [String]?
    
    enum CodingKeys: String, CodingKey {
        case recommendation, recommendationMessage, confidence, confidenceReason
        case subject, detectedLanguage
        case analysis, questions
        case summary, disclaimer, encouragement, areasToReview
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle recommendation as string with fallback
        let recString = try container.decodeIfPresent(String.self, forKey: .recommendation) ?? "unclear"
        recommendation = AIRecommendation(rawValue: recString) ?? .unclear
        
        recommendationMessage = try container.decodeIfPresent(String.self, forKey: .recommendationMessage)
        confidence = try container.decodeIfPresent(Double.self, forKey: .confidence) ?? 0
        confidenceReason = try container.decodeIfPresent(String.self, forKey: .confidenceReason)
        subject = try container.decodeIfPresent(String.self, forKey: .subject) ?? "Unknown"
        detectedLanguage = try container.decodeIfPresent(String.self, forKey: .detectedLanguage)
        
        // Handle optional analysis with default
        if let analysisData = try? container.decode(VerificationAnalysis.self, forKey: .analysis) {
            analysis = analysisData
        } else {
            analysis = .empty
        }
        
        questions = try container.decodeIfPresent([VerificationQuestion].self, forKey: .questions) ?? []
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? "Unable to analyze."
        disclaimer = try container.decodeIfPresent(String.self, forKey: .disclaimer)
        encouragement = try container.decodeIfPresent(String.self, forKey: .encouragement) ?? "Keep up the good work!"
        areasToReview = try container.decodeIfPresent([String].self, forKey: .areasToReview)
    }
    
    /// Whether confidence is considered low (below 70%)
    var isLowConfidence: Bool {
        confidence < 0.7
    }
    
    /// Confidence as percentage (0-100)
    var confidencePercentage: Int {
        Int(confidence * 100)
    }
    
    /// Color for confidence indicator
    var confidenceColor: Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.6 {
            return .orange
        } else {
            return .red
        }
    }
}

// MARK: - Confirm Action Response

/// Response from confirmAction Cloud Function for verification
struct VerificationConfirmResponse: Codable {
    let success: Bool
    let message: String?
    let taskId: String?
    let taskTitle: String?
    let verification: VerificationResult?
    let error: Bool?
    let rewardPaid: Bool?
    let eventId: String?
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decode(Bool.self, forKey: .success)
        message = try container.decodeIfPresent(String.self, forKey: .message)
        taskId = try container.decodeIfPresent(String.self, forKey: .taskId)
        taskTitle = try container.decodeIfPresent(String.self, forKey: .taskTitle)
        verification = try container.decodeIfPresent(VerificationResult.self, forKey: .verification)
        error = try container.decodeIfPresent(Bool.self, forKey: .error)
        rewardPaid = try container.decodeIfPresent(Bool.self, forKey: .rewardPaid)
        eventId = try container.decodeIfPresent(String.self, forKey: .eventId)
    }
}
