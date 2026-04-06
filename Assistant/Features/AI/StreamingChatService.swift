// StreamingChatService.swift
//
//
// Service for handling Server-Sent Events (SSE) streaming from AI chat
// Provides real-time response streaming instead of waiting for complete response

import Foundation
import Observation
import FirebaseAuth
import os

// MARK: - Stream Event Types

enum StreamEvent {
    case meta(remaining: Int?, isUnlimited: Bool)
    case start(timestamp: Int)
    case content(delta: String, full: String)
    case toolCall(tools: [String])
    case processing(message: String)
    case done(content: String, pendingAction: PendingAction?, remaining: Int?)
    case error(message: String, canRetry: Bool)
}

// MARK: - Stream Delegate

protocol StreamingChatDelegate: AnyObject {
    func streamDidStart()
    func streamDidReceiveContent(_ delta: String, fullContent: String)
    func streamDidReceiveToolCall(_ tools: [String])
    func streamDidComplete(content: String, pendingAction: PendingAction?, remaining: Int?)
    func streamDidFail(error: Error, canRetry: Bool)
}

// MARK: - Streaming Chat Service

@Observable
final class StreamingChatService: NSObject {
    
    // MARK: - Published State (must be accessed on MainActor)
    
    @MainActor var isStreaming = false
    @MainActor var currentContent = ""
    @MainActor var pendingAction: PendingAction?
    @MainActor var error: StreamError?
    
    // MARK: - Configuration
    
    private let baseURL: String
    @ObservationIgnored private var currentTask: URLSessionDataTask?
    
    // Thread-safe buffer using NSLock
    @ObservationIgnored private let bufferLock = NSLock()
    @ObservationIgnored private var _buffer = Data()
    
    weak var delegate: StreamingChatDelegate?
    
    // Callbacks for SwiftUI (alternative to delegate)
    var onContentDelta: ((String, String) -> Void)?
    var onComplete: ((String, PendingAction?, Int?) -> Void)?
    var onError: ((Error) -> Void)?
    
    // MARK: - Thread-Safe Buffer Access
    
    private func appendToBuffer(_ data: Data) {
        bufferLock.lock()
        _buffer.append(data)
        bufferLock.unlock()
    }
    
    private func getBufferString() -> String? {
        bufferLock.lock()
        let string = String(data: _buffer, encoding: .utf8)
        bufferLock.unlock()
        return string
    }
    
    private func setBuffer(_ data: Data) {
        bufferLock.lock()
        _buffer = data
        bufferLock.unlock()
    }
    
    private func clearBuffer() {
        bufferLock.lock()
        _buffer = Data()
        bufferLock.unlock()
    }
    
    // MARK: - Initialization
    
    init(region: String = "us-west1", projectId: String? = nil) {
        // Get project ID from Firebase if not provided
        let project = projectId ?? (Bundle.main.object(forInfoDictionaryKey: "FIREBASE_PROJECT_ID") as? String) ?? "your-project-id"
        self.baseURL = "https://\(region)-\(project).cloudfunctions.net/aiChatStream"
        super.init()
    }
    
    // MARK: - Send Streaming Message
    
    /// Send a message and receive streaming response
    @MainActor
    func sendMessage(
        _ message: String,
        conversationHistory: [[String: String]] = [],
        isFirstMessage: Bool = false
    ) async throws {
        // Cancel any existing stream
        cancelStream()
        
        // Reset state
        currentContent = ""
        pendingAction = nil
        error = nil
        isStreaming = true
        clearBuffer()
        
        delegate?.streamDidStart()
        
        // Get auth token
        guard let user = Auth.auth().currentUser else {
            throw StreamError.notAuthenticated
        }
        
        let token = try await user.getIDToken()
        
        // Build request
        guard let url = URL(string: baseURL) else {
            throw StreamError.connectionFailed
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 120
        
        let body: [String: Any] = [
            "message": message,
            "conversationHistory": conversationHistory,
            "isFirstMessage": isFirstMessage
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        // Create streaming session
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        currentTask = session.dataTask(with: request)
        currentTask?.resume()
    }
    
    /// Cancel ongoing stream
    @MainActor
    func cancelStream() {
        currentTask?.cancel()
        currentTask = nil
        isStreaming = false
    }
    
    // MARK: - Parse SSE Event (called from background, dispatches to main)
    
    private func parseSSEEvent(_ eventString: String) {
        var eventType = ""
        var eventData = ""
        
        for line in eventString.components(separatedBy: "\n") {
            if line.hasPrefix("event: ") {
                eventType = String(line.dropFirst(7))
            } else if line.hasPrefix("data: ") {
                eventData = String(line.dropFirst(6))
            }
        }
        
        guard !eventType.isEmpty, !eventData.isEmpty else { return }
        
        // Parse JSON data
        guard let data = eventData.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return
        }
        
        // Handle event on main actor
        Task { @MainActor in
            self.handleEvent(type: eventType, data: json)
        }
    }
    
    @MainActor
    private func handleEvent(type: String, data: [String: Any]) {
        switch type {
        case "meta":
            let remaining = data["remaining"] as? Int
            let isUnlimited = data["isUnlimited"] as? Bool ?? false
            Log.stream.debug("Meta: remaining=\(remaining ?? -1, privacy: .public), unlimited=\(isUnlimited, privacy: .public)")
            
        case "start":
            Log.stream.debug("Stream started")
            
        case "content":
            let delta = data["delta"] as? String ?? ""
            let full = data["full"] as? String ?? ""
            currentContent = full
            delegate?.streamDidReceiveContent(delta, fullContent: full)
            onContentDelta?(delta, full)
            
        case "tool_call":
            let tools = data["tools"] as? [String] ?? []
            delegate?.streamDidReceiveToolCall(tools)
            
        case "processing":
            let message = data["message"] as? String ?? "Processing..."
            Log.stream.debug("Processing: \(message, privacy: .public)")
            
        case "done":
            isStreaming = false
            let content = data["content"] as? String ?? currentContent
            let remaining = data["remaining"] as? Int
            
            // Parse pending action if present
            if let actionData = data["pendingAction"] as? [String: Any] {
                pendingAction = parsePendingAction(actionData)
            }
            
            delegate?.streamDidComplete(content: content, pendingAction: pendingAction, remaining: remaining)
            onComplete?(content, pendingAction, remaining)
            
        case "error":
            isStreaming = false
            let message = data["message"] as? String ?? String(localized: "error_unknown")
            let canRetry = data["canRetry"] as? Bool ?? false
            let streamError = StreamError.serverError(message)
            error = streamError
            delegate?.streamDidFail(error: streamError, canRetry: canRetry)
            onError?(streamError)
            
        default:
            Log.stream.debug("Unknown event: \(type, privacy: .public)")
        }
    }
    
    private func parsePendingAction(_ data: [String: Any]) -> PendingAction? {
        guard let typeString = data["type"] as? String,
              let type = PendingActionType(rawValue: typeString),
              let summary = data["summary"] as? String else {
            return nil
        }
        
        // Convert dictionaries to AnyCodable
        let actionData = (data["data"] as? [String: Any])?.mapValues { AnyCodable($0) } ?? [:]
        let displayData = (data["display"] as? [String: Any])?.mapValues { AnyCodable($0) } ?? [:]
        
        return PendingAction(
            type: type,
            summary: summary,
            data: actionData,
            display: displayData
        )
    }
    
    // MARK: - Error Types
    
    enum StreamError: LocalizedError {
        case notAuthenticated
        case connectionFailed
        case serverError(String)
        case timeout
        case cancelled
        
        var errorDescription: String? {
            switch self {
            case .notAuthenticated:
                return String(localized: "please_sign_in_to_chat")
            case .connectionFailed:
                return String(localized: "could_not_connect")
            case .serverError(let message):
                return message
            case .timeout:
                return String(localized: "request_timed_out")
            case .cancelled:
                return String(localized: "request_cancelled")
            }
        }
    }
}

// MARK: - URLSession Delegate for SSE

extension StreamingChatService: URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        // Thread-safe buffer append
        appendToBuffer(data)
        
        // Process complete events (separated by double newline)
        guard let bufferString = getBufferString() else { return }
        
        let events = bufferString.components(separatedBy: "\n\n")
        
        // Keep incomplete event in buffer
        if !bufferString.hasSuffix("\n\n") && events.count > 1 {
            setBuffer(events.last?.data(using: .utf8) ?? Data())
            for event in events.dropLast() where !event.isEmpty {
                parseSSEEvent(event)
            }
        } else {
            clearBuffer()
            for event in events where !event.isEmpty && !event.hasPrefix(":") {
                parseSSEEvent(event)
            }
        }
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        Task { @MainActor in
            self.isStreaming = false
            
            if let error = error {
                if (error as NSError).code == NSURLErrorCancelled {
                    self.error = .cancelled
                } else if (error as NSError).code == NSURLErrorTimedOut {
                    self.error = .timeout
                    self.delegate?.streamDidFail(error: StreamError.timeout, canRetry: true)
                    self.onError?(StreamError.timeout)
                } else {
                    let streamError = StreamError.connectionFailed
                    self.error = streamError
                    self.delegate?.streamDidFail(error: streamError, canRetry: true)
                    self.onError?(streamError)
                }
            }
        }
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        // Check for HTTP errors
        if let httpResponse = response as? HTTPURLResponse {
            if httpResponse.statusCode != 200 {
                Task { @MainActor in
                    self.isStreaming = false
                    let error = StreamError.serverError("HTTP \(httpResponse.statusCode)")
                    self.error = error
                    self.delegate?.streamDidFail(error: error, canRetry: httpResponse.statusCode >= 500)
                    self.onError?(error)
                }
                completionHandler(.cancel)
                return
            }
        }
        completionHandler(.allow)
    }
}

// MARK: - SwiftUI Integration Helper

extension StreamingChatService {
    
    /// Convenience method for SwiftUI with async/callback pattern
    @MainActor
    func stream(
        message: String,
        history: [[String: String]] = [],
        isFirst: Bool = false,
        onDelta: @escaping (String) -> Void,
        onComplete: @escaping (String, PendingAction?) -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.onContentDelta = { delta, _ in
            onDelta(delta)
        }
        
        self.onComplete = { content, action, _ in
            onComplete(content, action)
        }
        
        self.onError = onError
        
        Task {
            do {
                try await sendMessage(message, conversationHistory: history, isFirstMessage: isFirst)
            } catch {
                onError(error)
            }
        }
    }
}
