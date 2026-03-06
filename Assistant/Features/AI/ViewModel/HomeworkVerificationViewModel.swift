// ============================================================================
// HomeworkVerificationViewModel.swift
// FamilyHub
//
// ViewModel for AI Homework Verification
//
// IMPORTANT: AI provides RECOMMENDATIONS only — parent makes final decision
// ============================================================================

import SwiftUI
import FirebaseFunctions

// MARK: - ViewModel

@MainActor
@Observable
class HomeworkVerificationViewModel {
    
    // MARK: - Published State
    
    var isVerifying = false
    var verificationResult: VerificationResult?
    var errorMessage: String?
    var showResults = false
    var canRetry = true
    
    // MARK: - Private
    
    @ObservationIgnored private let functions = Functions.functions(region: "us-west1")
    private var lastVerifiedTaskId: String?
    private var lastVerifiedImageUrl: String?
    
    // MARK: - Verify Homework
    
    /// Verify homework from an image URL
    /// Uses confirmAction with "verify_task" action type
    ///
    /// - Parameters:
    ///   - imageUrl: URL or base64 data URL of the homework image
    ///   - taskId: ID of the task being verified
    ///   - additionalContext: Optional extra context for the AI
    ///   - forceRefresh: If true, ignores cached result and re-verifies
    func verifyHomework(
        imageUrl: String,
        taskId: String,
        additionalContext: String? = nil,
        forceRefresh: Bool = false
    ) async {
        // Check cache (skip re-verification if same task/image)
        if !forceRefresh,
           let cached = verificationResult,
           lastVerifiedTaskId == taskId,
           lastVerifiedImageUrl == imageUrl {
            showResults = true
            return
        }
        
        isVerifying = true
        errorMessage = nil
        canRetry = true
        
        // Clear previous result
        if forceRefresh {
            verificationResult = nil
        }
        
        do {
            // Build action payload for confirmAction
            let actionData: [String: Any] = [
                "action": [
                    "type": "verify_task",
                    "data": [
                        "taskId": taskId,
                        "imageUrl": imageUrl,
                        "additionalContext": additionalContext ?? ""
                    ]
                ]
            ]
            
            let result = try await functions.httpsCallable("confirmAction").call(actionData)
            
            guard let responseData = result.data as? [String: Any] else {
                throw VerificationError.invalidResponse
            }
            
            // Check for error in response
            if let errorFlag = responseData["error"] as? Bool, errorFlag {
                let message = responseData["message"] as? String ?? "Verification failed"
                
                // Check if retry is possible
                if let retryAfter = responseData["retryAfter"] as? Int {
                    throw VerificationError.retryable(message: message, retryAfter: retryAfter)
                }
                
                throw VerificationError.serverError(message)
            }
            
            // Parse verification result using unified VerificationResult type
            if let verificationDict = responseData["verification"] as? [String: Any] {
                let jsonData = try JSONSerialization.data(withJSONObject: verificationDict)
                let verification = try JSONDecoder().decode(VerificationResult.self, from: jsonData)
                
                // Cache the result
                verificationResult = verification
                lastVerifiedTaskId = taskId
                lastVerifiedImageUrl = imageUrl
                showResults = true
            } else {
                throw VerificationError.invalidResponse
            }
            
        } catch {
            handleError(error)
        }
        
        isVerifying = false
    }
    
    /// Verify homework from UIImage
    /// Converts to base64 and uses confirmAction
    ///
    /// - Parameters:
    ///   - image: UIImage of the homework
    ///   - taskId: ID of the task being verified
    ///   - additionalContext: Optional extra context for the AI
    ///   - compressionQuality: JPEG compression (0.0-1.0, default 0.8)
    func verifyHomework(
        image: UIImage,
        taskId: String,
        additionalContext: String? = nil,
        compressionQuality: CGFloat = 0.8
    ) async {
        isVerifying = true
        errorMessage = nil
        verificationResult = nil
        
        // Convert image to base64 data URL
        guard let imageData = image.jpegData(compressionQuality: compressionQuality) else {
            errorMessage = "L10n.failedToProcessImage"
            isVerifying = false
            canRetry = false
            return
        }
        
        // Check image size (max 10MB)
        let maxSize = 10 * 1024 * 1024
        if imageData.count > maxSize {
            // Try with lower quality
            if compressionQuality > 0.3,
               let compressedData = image.jpegData(compressionQuality: 0.5),
               compressedData.count <= maxSize {
                let base64String = compressedData.base64EncodedString()
                let dataUrl = "data:image/jpeg;base64,\(base64String)"
                await verifyHomework(imageUrl: dataUrl, taskId: taskId, additionalContext: additionalContext)
                return
            }
            
            errorMessage = "L10n.imageTooLargePleaseUseASmallerImage"
            isVerifying = false
            canRetry = false
            return
        }
        
        let base64String = imageData.base64EncodedString()
        let dataUrl = "data:image/jpeg;base64,\(base64String)"
        
        // Use the URL-based method with data URL
        await verifyHomework(imageUrl: dataUrl, taskId: taskId, additionalContext: additionalContext)
    }
    
    // MARK: - Retry
    
    /// Retry the last verification
    func retry() async {
        guard let taskId = lastVerifiedTaskId,
              let imageUrl = lastVerifiedImageUrl else {
            errorMessage = "L10n.nothingToRetry"
            return
        }
        
        await verifyHomework(imageUrl: imageUrl, taskId: taskId, forceRefresh: true)
    }
    
    // MARK: - Error Handling
    
    enum VerificationError: LocalizedError {
        case invalidResponse
        case serverError(String)
        case imageProcessingFailed
        case retryable(message: String, retryAfter: Int)
        case circuitOpen(retryAfter: Int)
        
        var errorDescription: String? {
            switch self {
            case .invalidResponse:
                return "L10n.invalidResponseFromServer"
            case .serverError(let message):
                return message
            case .imageProcessingFailed:
                return "L10n.failedToProcessImage"
            case .retryable(let message, _):
                return message
            case .circuitOpen(let retryAfter):
                return L10n.aiServiceUnavailableRetry(retryAfter)
            }
        }
        
        var isRetryable: Bool {
            switch self {
            case .retryable, .circuitOpen:
                return true
            case .invalidResponse, .imageProcessingFailed:
                return true
            case .serverError:
                return false
            }
        }
    }
    
    private func handleError(_ error: Error) {
        print("[HomeworkVerification] Error: \(error)")
        
        // Handle our custom errors
        if let verificationError = error as? VerificationError {
            errorMessage = verificationError.localizedDescription
            canRetry = verificationError.isRetryable
            return
        }
        
        // Handle Firebase Functions errors
        if let functionsError = error as NSError?,
           functionsError.domain == FunctionsErrorDomain {
            
            switch FunctionsErrorCode(rawValue: functionsError.code) {
            case .unauthenticated:
                errorMessage = "L10n.pleaseSignInToVerifyHomework"
                canRetry = false
                
            case .invalidArgument:
                errorMessage = "L10n.couldNotProcessImagePleaseTryAClearerPhoto"
                canRetry = true
                
            case .resourceExhausted:
                errorMessage = "L10n.dailyVerificationLimitReachedTryAgainTomorro"
                canRetry = false
                
            case .notFound:
                errorMessage = L10n.taskNotFound
                canRetry = false
                
            case .failedPrecondition:
                errorMessage = "L10n.noProofImageFoundForThisTask"
                canRetry = false
                
            case .unavailable:
                errorMessage = "L10n.aiServiceTemporarilyUnavailablePleaseTryAgai"
                canRetry = true
                
            case .deadlineExceeded:
                errorMessage = "L10n.requestTimedOutPleaseTryAgain"
                canRetry = true
                
            default:
                errorMessage = "L10n.verificationFailedPleaseReviewManually"
                canRetry = true
            }
        } else {
            errorMessage = "L10n.unableToAnalyzePleaseReviewManually"
            canRetry = true
        }
    }
    
    // MARK: - Reset
    
    /// Reset the verification state
    func reset() {
        verificationResult = nil
        errorMessage = nil
        showResults = false
        canRetry = true
        // Keep cache references for potential retry
    }
    
    /// Fully clear all state including cache
    func clearAll() {
        reset()
        lastVerifiedTaskId = nil
        lastVerifiedImageUrl = nil
    }
}

// MARK: - Preview Helpers

#if DEBUG
extension HomeworkVerificationViewModel {
    /// Create a mock result for previews
    static func mockWithResult() -> HomeworkVerificationViewModel {
        let vm = HomeworkVerificationViewModel()
        // Note: Can't easily mock VerificationResult due to Codable init
        // In previews, use actual API call or skip verification display
        return vm
    }
}
#endif
