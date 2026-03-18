// ============================================================================
// ChatViewModel.swift

import SwiftUI
import FirebaseFunctions
import FirebaseAuth
import os

// MARK: - Constants

private enum ChatConstants {
    static let maxHistoryMessages = 20
    static let confirmationDismissDelay: Duration = .seconds(1.5)
    static let maxRetryAttempts = 3
    static let baseRetryDelaySeconds: Double = 2.0
    static let persistenceKey = "chat_history_v1"
    static let defaultDailyLimit = 10
}

// MARK: - Action Types

enum PendingActionType: String, Codable {
    case createTask    = "create_task"
    case completeTask  = "complete_task"
    case updateStatus  = "update_status"
    case createEvent   = "create_event"
    case assignTask    = "assign_task"
    case updateTask    = "update_task"
    case deleteTask    = "delete_task"
    case verifyTask    = "verify_task"
    case approveVerification = "approve_verification"
    case rejectVerification  = "reject_verification"
    
    var icon: String {
        switch self {
        case .createTask:   return "plus.circle.fill"
        case .completeTask: return "checkmark.circle.fill"
        case .updateStatus: return "arrow.triangle.2.circlepath"
        case .createEvent:  return "calendar.badge.plus"
        case .assignTask:   return "person.badge.plus"
        case .updateTask:   return "pencil.circle.fill"
        case .deleteTask:   return "trash.fill"
        case .verifyTask:   return "sparkles"
        case .approveVerification: return "checkmark.seal.fill"
        case .rejectVerification:  return "xmark.seal.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .createTask:   return .blue
        case .completeTask: return .green
        case .updateStatus: return .orange
        case .createEvent:  return .purple
        case .assignTask:   return .teal
        case .updateTask:   return .indigo
        case .deleteTask:   return .red
        case .verifyTask:   return .purple
        case .approveVerification: return .green
        case .rejectVerification:  return .red
        }
    }
    
    var title: String {
        switch self {
        case .createTask:   return L10n.createTask
        case .completeTask: return L10n.completeTask
        case .updateStatus: return L10n.updateStatus
        case .createEvent:  return L10n.createEvent
        case .assignTask:   return L10n.reassignTask
        case .updateTask:   return L10n.updateTask
        case .deleteTask:   return L10n.deleteTask
        case .verifyTask:   return L10n.verifyHomework
        case .approveVerification: return L10n.approve
        case .rejectVerification:  return L10n.reject
        }
    }
}

// MARK: - Chat Models

struct PendingAction: Codable {
    let type: PendingActionType
    let summary: String
    let data: [String: AnyCodable]
    let display: [String: AnyCodable]
}

struct ChatMessage: Identifiable, Codable {
    let id: UUID
    let role: String
    var content: String
    let pendingAction: PendingAction?
    let timestamp: Date
    var isRateLimit: Bool
    var isError: Bool
    var canRetry: Bool
    var retryAfter: Int?
    
    init(
        id: UUID = UUID(),
        role: String,
        content: String,
        pendingAction: PendingAction? = nil,
        timestamp: Date = Date(),
        isRateLimit: Bool = false,
        isError: Bool = false,
        canRetry: Bool = false,
        retryAfter: Int? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.pendingAction = pendingAction
        self.timestamp = timestamp
        self.isRateLimit = isRateLimit
        self.isError = isError
        self.canRetry = canRetry
        self.retryAfter = retryAfter
    }
}

struct ChatResponse: Codable {
    let reply: String
    let pendingAction: PendingAction?
    let remaining: Int?
    let limit: Int?
    let isUnlimited: Bool?
    let isError: Bool?
    let canRetry: Bool?
    let retryAfter: Int?
}

// MARK: - Confirm Response (Uses Unified VerificationResult)

struct ConfirmResponse: Codable {
    let success: Bool
    let message: String
    let taskId: String?
    let eventId: String?
    let rewardPaid: Bool?
    let verification: VerificationResult?  // ← Uses unified type from VerificationModels.swift
}

// MARK: - AnyCodable Utility

struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dict = try? container.decode([String: AnyCodable].self) {
            value = dict.mapValues { $0.value }
        } else if container.decodeNil() {
            value = NSNull()
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Unsupported type"
            )
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let string as String:  try container.encode(string)
        case let int as Int:        try container.encode(int)
        case let double as Double:  try container.encode(double)
        case let bool as Bool:      try container.encode(bool)
        case is NSNull:             try container.encodeNil()
        default:
            if let jsonData = try? JSONSerialization.data(withJSONObject: value),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                try container.encode(jsonString)
            } else {
                try container.encodeNil()
            }
        }
    }
    
    var stringValue: String? { value as? String }
    var intValue: Int? { value as? Int }
    var doubleValue: Double? { value as? Double }
    var boolValue: Bool? { value as? Bool }
    var arrayValue: [Any]? { value as? [Any] }
    var dictionaryValue: [String: Any]? { value as? [String: Any] }
}

// MARK: - ViewModel

@MainActor
@Observable
final class ChatViewModel {
    // MARK: Published State
    
    var messages: [ChatMessage] = []
    var isLoading = false
    var errorMessage: String?
    var remainingMessages: Int = ChatConstants.defaultDailyLimit
    var messageLimit: Int = ChatConstants.defaultDailyLimit
    var isUnlimited = false

    // Confirmation flow
    var pendingActionToConfirm: PendingAction?
    var showConfirmation = false
    var isConfirming = false
    var confirmationResult: String?
    
    // Circuit breaker state
    var isAIUnavailable = false
    var aiUnavailableUntil: Date?

        // ═══════════════════════════════════════════════════════════════════════
        // STREAMING - ADD THESE PROPERTIES
        // ═══════════════════════════════════════════════════════════════════════
        
        /// Whether streaming is in progress
        var isStreaming = false
        
        /// Current content being streamed (updates in real-time)
        var streamingContent = ""
        
        /// Toggle to enable/disable streaming (defaults to true)
        var useStreaming = true
        
        /// Streaming service instance
        @ObservationIgnored private var streamingService: StreamingChatService?
        
        /// ID of the placeholder message being streamed into
        @ObservationIgnored private var streamingMessageId: UUID?
    // MARK: Computed Properties
    
    
    /// Daily message limit (non-binding accessor)
    var dailyLimit: Int {
        messageLimit
    }
    
    /// Whether the user has reached their daily limit
    var isLimitReached: Bool {
        !isUnlimited && remainingMessages <= 0
    }
    
    // MARK: Private
    
    @ObservationIgnored private let functions = Functions.functions(region: "us-west1")
    @ObservationIgnored private var retryCount = 0
    
    // MARK: - Initialization
    
    init() {
            loadPersistedHistory()
            setupStreaming()
        }
    // ═══════════════════════════════════════════════════════════════════════
        // STREAMING METHODS
        // ═══════════════════════════════════════════════════════════════════════
        
        /// Setup streaming service and callbacks
        private func setupStreaming() {
            streamingService = StreamingChatService(projectId: "assisted-e3cc6")
            streamingService?.onContentDelta = { [weak self] _, fullContent in
                Task { @MainActor in
                    self?.streamingContent = fullContent
                    // Update the placeholder message content
                    if let id = self?.streamingMessageId,
                       let index = self?.messages.firstIndex(where: { $0.id == id }) {
                        self?.messages[index].content = fullContent
                    }
                }
            }
            
            streamingService?.onComplete = { [weak self] content, action, remaining in
                Task { @MainActor in
                    self?.handleStreamComplete(content: content, action: action, remaining: remaining)
                }
            }
            
            streamingService?.onError = { [weak self] error in
                Task { @MainActor in
                    self?.handleStreamError(error)
                }
            }
        }
        
        /// Send message with streaming response
        func sendMessageStreaming(_ text: String) async {
            let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedText.isEmpty else { return }
            
            // Check circuit breaker
            if let unavailableUntil = aiUnavailableUntil, Date() < unavailableUntil {
                let remaining = Int(unavailableUntil.timeIntervalSinceNow)
                addErrorMessage(
                    L10n.aiUnavailableRetrySeconds(remaining),
                    canRetry: true,
                    retryAfter: remaining
                )
                return
            }
            
            // Reset circuit breaker if time passed
            if let until = aiUnavailableUntil, Date() >= until {
                isAIUnavailable = false
                aiUnavailableUntil = nil
            }
            
            // Add user message
            let userMessage = ChatMessage(role: "user", content: trimmedText)
            messages.append(userMessage)
            
            // Reset state
            isLoading = true
            isStreaming = true
            streamingContent = ""
            errorMessage = nil
            
            // Add placeholder message for streaming
            let placeholderId = UUID()
            streamingMessageId = placeholderId
            let placeholder = ChatMessage(
                id: placeholderId,
                role: "assistant",
                content: ""  // Will be filled by streaming
            )
            messages.append(placeholder)
            
            // Build conversation history
            let history = buildConversationHistory()
            
            do {
                try await streamingService?.sendMessage(
                    trimmedText,
                    conversationHistory: history,
                    isFirstMessage: false
                )
            } catch {
                handleStreamError(error)
            }
        }
        
        /// Handle stream completion
        private func handleStreamComplete(content: String, action: PendingAction?, remaining: Int?) {
            isLoading = false
            isStreaming = false
            
            // Update placeholder message with final content
            if let id = streamingMessageId,
               let index = messages.firstIndex(where: { $0.id == id }) {
                messages[index] = ChatMessage(
                    id: id,
                    role: "assistant",
                    content: content,
                    pendingAction: action,
                    timestamp: messages[index].timestamp
                )
            }
            
            streamingMessageId = nil
            
            // Update remaining count
            if let remaining = remaining {
                remainingMessages = remaining
            }
            
            // Set pending action for inline confirmation (no sheet)
            if let action = action {
                pendingActionToConfirm = action
                showConfirmation = true

            }
            
            persistHistory()
        }
        
        /// Handle stream error
        private func handleStreamError(_ error: Error) {
            isLoading = false
            isStreaming = false
            
            // Remove placeholder if empty
            if let id = streamingMessageId,
               let index = messages.firstIndex(where: { $0.id == id }),
               messages[index].content.isEmpty {
                messages.remove(at: index)
            }
            
            streamingMessageId = nil
            
            let errorText: String
            let canRetry: Bool
            
            if let streamError = error as? StreamingChatService.StreamError {
                switch streamError {
                case .notAuthenticated:
                    errorText = L10n.pleaseSignInToChat
                    canRetry = false
                case .connectionFailed:
                    errorText = L10n.connectionFailedPleaseTryAgain
                    canRetry = true
                case .serverError(let message):
                    errorText = message
                    canRetry = true
                case .timeout:
                    errorText = L10n.requestTimedOutPleaseTryAgain
                    canRetry = true
                case .cancelled:
                    return // Don't show error for cancellation
                }
            } else {
                errorText = L10n.somethingWentWrongPleaseTryAgain
                canRetry = true
            }
            
            addErrorMessage(errorText, canRetry: canRetry)
        }
        
        /// Build conversation history for API call
        private func buildConversationHistory() -> [[String: String]] {
            return messages
                .filter { !$0.isError && !$0.isRateLimit && !$0.content.isEmpty }
                .suffix(ChatConstants.maxHistoryMessages)
                .map { ["role": $0.role, "content": $0.content] }
        }
        
        /// Cancel ongoing stream
        func cancelStreaming() {
            Task { @MainActor in
                await streamingService?.cancelStream()
            }
            isStreaming = false
            isLoading = false
            
            // Remove empty placeholder
            if let id = streamingMessageId,
               let index = messages.firstIndex(where: { $0.id == id }),
               messages[index].content.isEmpty {
                messages.remove(at: index)
            }
            
            streamingMessageId = nil
        }
        
        /// Send message - automatically selects streaming or non-streaming
        /// Also intercepts confirmation messages when an action is pending
        func sendMessageAuto(_ text: String) async {
            // If there's a pending action and user says yes/confirm, execute it
            if pendingActionToConfirm != nil {
                let lower = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                let confirmWords = ["yes", "confirm", "ok", "sure", "go ahead", "do it", "yep", "yeah", "sí", "si", "好", "确认", "是"]
                let cancelWords = ["no", "cancel", "nevermind", "never mind", "nope", "取消", "不"]
                
                if confirmWords.contains(where: { lower == $0 || lower.hasPrefix($0) }) {
                    // Add user message to chat
                    messages.append(ChatMessage(role: "user", content: text))
                    await confirmPendingAction()
                    return
                }
                
                if cancelWords.contains(where: { lower == $0 || lower.hasPrefix($0) }) {
                    messages.append(ChatMessage(role: "user", content: text))
                    cancelPendingAction()
                    return
                }
            }
            
            if useStreaming {
                await sendMessageStreaming(text)
            } else {
                await sendMessage(text)
            }
        }
    // MARK: - Send Message
    
    func sendMessage(_ text: String) async {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else { return }
        
        // Check circuit breaker
        if let unavailableUntil = aiUnavailableUntil, Date() < unavailableUntil {
            let remaining = Int(unavailableUntil.timeIntervalSinceNow)
            addErrorMessage(
                L10n.maiUnavailableRetrySeconds(remaining),
                canRetry: true,
                retryAfter: remaining
            )
            return
        }
        
        // Reset circuit breaker if time has passed
        if let until = aiUnavailableUntil, Date() >= until {
            isAIUnavailable = false
            aiUnavailableUntil = nil
        }
        
        let userMessage = ChatMessage(role: "user", content: trimmedText)
        messages.append(userMessage)
        
        isLoading = true
        errorMessage = nil
        retryCount = 0
        
        await sendWithRetry(trimmedText)
        
        isLoading = false
        persistHistory()
    }
    
    // MARK: - Retry Logic
    
    private func sendWithRetry(_ text: String) async {
        while retryCount <= ChatConstants.maxRetryAttempts {
            do {
                try await performSend(text)
                return
            } catch {
                let shouldRetry = handleSendError(error)
                
                if shouldRetry && retryCount < ChatConstants.maxRetryAttempts {
                    retryCount += 1
                    let delay = ChatConstants.baseRetryDelaySeconds * pow(2, Double(retryCount - 1))
                    try? await Task.sleep(for: .seconds(delay))
                } else {
                    return
                }
            }
        }
    }
    
    private func performSend(_ text: String) async throws {
        let recentHistory = Array(messages.suffix(ChatConstants.maxHistoryMessages))
            .filter { !$0.isError && !$0.isRateLimit }
            .map { ["role": $0.role, "content": $0.content] }
        
        let payload: [String: Any] = [
            "message": text,
            "conversationHistory": recentHistory,
            "isFirstMessage": false
        ]
        
        let result = try await functions.httpsCallable("aiChat").call(payload)
        
        guard let data = result.data as? [String: Any] else {
            throw ChatError.invalidResponse
        }
        
        let jsonData = try JSONSerialization.data(withJSONObject: data)
        let response = try JSONDecoder().decode(ChatResponse.self, from: jsonData)
        
        if response.isError == true {
            if response.canRetry == true {
                throw ChatError.retryable(message: response.reply, retryAfter: response.retryAfter ?? 10)
            } else {
                throw ChatError.nonRetryable(message: response.reply)
            }
        }
        
        // Update rate limit state
        if let remaining = response.remaining {
            remainingMessages = remaining
        }
        if let limit = response.limit {
            messageLimit = limit
        }
        isUnlimited = response.isUnlimited ?? false
        
        let assistantMessage = ChatMessage(
            role: "assistant",
            content: response.reply,
            pendingAction: response.pendingAction
        )
        messages.append(assistantMessage)
        
        // Set pending action for inline confirmation (no sheet)
        if let action = response.pendingAction {
            pendingActionToConfirm = action
            showConfirmation = true

        }
    }
    
    private func handleSendError(_ error: Error) -> Bool {
        var errorText = L10n.somethingWentWrongPleaseTryAgain
        var canRetry = true
        var retryAfter: Int? = nil
        
        if let chatError = error as? ChatError {
            switch chatError {
            case .retryable(let message, let after):
                errorText = message
                retryAfter = after
                if after >= 60 {
                    isAIUnavailable = true
                    aiUnavailableUntil = Date().addingTimeInterval(TimeInterval(after))
                }
                return true
                
            case .nonRetryable(let message):
                errorText = message
                canRetry = false
                return false
                
            case .invalidResponse:
                return true
            }
        }
        
        if let functionsError = error as NSError?,
           functionsError.domain == FunctionsErrorDomain {
            
            // Check for specific error codes in details
            if let details = functionsError.userInfo["details"] as? String,
               let data = details.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                
                if json["code"] as? String == "DAILY_LIMIT_REACHED" {
                    addRateLimitMessage()
                    return false
                }
                
                if json["code"] as? String == "CIRCUIT_OPEN" {
                    let after = json["retryAfter"] as? Int ?? 300
                    isAIUnavailable = true
                    aiUnavailableUntil = Date().addingTimeInterval(TimeInterval(after))
                    errorText = L10n.aiAssistantIsTemporarilyUnavailable
                    retryAfter = after
                }
            }
            
            switch FunctionsErrorCode(rawValue: functionsError.code) {
            case .unauthenticated:
                errorText = L10n.pleaseSignInToChat
                canRetry = false
            case .resourceExhausted:
                errorText = L10n.messageLimitReached
                canRetry = true
                retryAfter = 60
            case .unavailable:
                errorText = L10n.serviceTemporarilyUnavailable
                canRetry = true
            case .deadlineExceeded:
                errorText = L10n.requestTimedOut
                canRetry = true
            default:
                break
            }
        }
        
        if retryCount >= ChatConstants.maxRetryAttempts || !canRetry {
            addErrorMessage(errorText, canRetry: canRetry, retryAfter: retryAfter)
        }
        
        return canRetry
    }
    
    // MARK: - Error Helpers
    
    private func addErrorMessage(_ text: String, canRetry: Bool, retryAfter: Int? = nil) {
        let errorMsg = ChatMessage(
            role: "assistant",
            content: text,
            isError: true,
            canRetry: canRetry,
            retryAfter: retryAfter
        )
        messages.append(errorMsg)
        errorMessage = text
    }
    
    private func addRateLimitMessage() {
        let rateLimitMessage = ChatMessage(
            role: "assistant",
            content: L10n.youveUsedAllYourMessagesForTodayTryAgainT,
            isRateLimit: true
        )
        messages.append(rateLimitMessage)
        remainingMessages = 0
    }
    
    // MARK: - Confirm Action
    
    func confirmPendingAction() async {
        guard let action = pendingActionToConfirm else { return }
        
        isConfirming = true
        confirmationResult = nil
        
        do {
            let actionDict: [String: Any] = [
                "type": action.type.rawValue,
                "data": action.data.mapValues { $0.value }
            ]
            
            let result = try await functions.httpsCallable("confirmAction").call(["action": actionDict])
            
            guard let data = result.data as? [String: Any] else {
                throw ChatError.invalidResponse
            }
            
            let jsonData = try JSONSerialization.data(withJSONObject: data)
            let response = try JSONDecoder().decode(ConfirmResponse.self, from: jsonData)
            
            if response.success {
                confirmationResult = response.message
                
                let confirmMessage = ChatMessage(role: "assistant", content: "✅ \(response.message)")
                messages.append(confirmMessage)
                
                // Handle verification result if present (compact format)
                if let verification = response.verification {
                    let verificationMessage = ChatMessage(
                        role: "assistant",
                        content: formatVerificationResult(verification)
                    )
                    messages.append(verificationMessage)
                }
                
                // Clear pending action after short delay so card updates
                try await Task.sleep(for: .seconds(0.5))
                pendingActionToConfirm = nil
            } else {
                confirmationResult = "❌ " + response.message
            }
            
        } catch {
            confirmationResult = "❌ Failed: " + error.localizedDescription
        }
        
        isConfirming = false
        persistHistory()
    }
    
    /// Format verification result for chat display (compact)
    /// Uses unified VerificationResult from VerificationModels.swift
    private func formatVerificationResult(_ result: VerificationResult) -> String {
        let emoji = result.recommendation.emoji
        var text = "\(emoji) \(result.subject) — \(result.confidencePercentage)% confidence"
        
        if result.analysis.totalQuestions > 0 {
            text += "\n\(result.analysis.likelyCorrect)/\(result.analysis.totalQuestions) correct"
            if result.analysis.likelyIncorrect > 0 {
                text += ", \(result.analysis.likelyIncorrect) need review"
            }
        }
        
        if let msg = result.recommendationMessage {
            text += "\n\n\(msg)"
        }
        
        text += "\n\n⚠️ AI analysis may contain errors."
        return text
    }
    
    // MARK: - Cancel Action
    
    func cancelPendingAction() {
        pendingActionToConfirm = nil
        
        let cancelMessage = ChatMessage(
            role: "assistant",
            content: L10n.actionCancelledLetMeKnowIfYoudLikeToTryS
        )
        messages.append(cancelMessage)
        persistHistory()
    }
    
    // MARK: - Session Management
    func clearChat() {
        messages = []
        errorMessage = nil
        pendingActionToConfirm = nil
        retryCount = 0
        isStreaming = false
        streamingContent = ""
        streamingMessageId = nil
        clearPersistedHistory()
        
        // Clear backend summary cache
        clearBackendSummaryCache()
    }
    
    // MARK: - Persistence
    
    private func persistHistory() {
        let toSave = Array(messages.suffix(ChatConstants.maxHistoryMessages))
        do {
            let data = try JSONEncoder().encode(toSave)
            UserDefaults.standard.set(data, forKey: ChatConstants.persistenceKey)
        } catch {
            Log.chat.debug("Failed to persist: \(error, privacy: .public)")
        }
    }
    
    private func loadPersistedHistory() {
        guard let data = UserDefaults.standard.data(forKey: ChatConstants.persistenceKey) else { return }
        do {
            let loaded = try JSONDecoder().decode([ChatMessage].self, from: data)
            messages = loaded.filter { !$0.isError && !$0.isRateLimit }
        } catch {
            Log.chat.debug("Failed to load: \(error, privacy: .public)")
        }
    }
    
    private func clearPersistedHistory() {
        UserDefaults.standard.removeObject(forKey: ChatConstants.persistenceKey)
    }
    /// Clears the conversation summary cache on the backend
    /// This is fire-and-forget - we don't block the UI
    private func clearBackendSummaryCache() {
        Task {
            do {
                let _ = try await functions.httpsCallable("clearChatSummary").call()
                Log.chat.debug("Cleared backend summary cache")
            } catch {
                // Non-critical - just log the error
                Log.chat.debug("Failed to clear summary cache: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
    
    // MARK: - Retry
    
    func retryLast() async {
        guard let lastUserMessage = messages.last(where: { $0.role == "user" }) else { return }
        messages.removeAll { $0.isError }
        await sendMessageAuto(lastUserMessage.content)
    }
    
    // MARK: - Error Types
    
    enum ChatError: LocalizedError {
        case invalidResponse
        case retryable(message: String, retryAfter: Int)
        case nonRetryable(message: String)
        
        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "Invalid response"
            case .retryable(let msg, _): return msg
            case .nonRetryable(let msg): return msg
            }
        }
    }
}
