//
//  FocusTimerManager.swift
//  Assistant
//
//  Created by Ramiro  on 1/25/26.
//  Manages Pomodoro timer state, background notifications, and persistence
//

import SwiftUI
import UserNotifications
import AVFoundation

@MainActor
@Observable
final class FocusTimerManager {
    static let shared = FocusTimerManager()
    
    // MARK: - Published Properties
    var state: FocusTimerState = .idle
    var remainingSeconds: Int = 0
    var totalSeconds: Int = 0
    var currentSession: FocusSession?
    var currentTaskId: String?
    var isBreakMode: Bool = false
    var breakType: BreakType = .short
    
    // MARK: - Private Properties
    @ObservationIgnored private var timer: Timer?
@ObservationIgnored     private var startTime: Date?
    @ObservationIgnored private var pausedTime: Date?
@ObservationIgnored     private var accumulatedPauseTime: TimeInterval = 0
    @ObservationIgnored private var audioPlayer: AVAudioPlayer?
@ObservationIgnored     private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid
    @ObservationIgnored private var lifecycleTasks: [Task<Void, Never>] = []
    
    // PERFORMANCE: Reusable haptic generators (avoid allocation per feedback)
    @ObservationIgnored private let notificationGenerator = UINotificationFeedbackGenerator()
@ObservationIgnored     private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    @ObservationIgnored private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
@ObservationIgnored     private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    // Notification identifiers
    @ObservationIgnored private let timerNotificationID = "com.familyhub.focustimer.completion"
    
    // MARK: - Computed Properties
    var progress: Double {
        guard totalSeconds > 0 else { return 0 }
        return Double(totalSeconds - remainingSeconds) / Double(totalSeconds)
    }
    
    var remainingProgress: Double {
        guard totalSeconds > 0 else { return 1 }
        return Double(remainingSeconds) / Double(totalSeconds)
    }
    
    var formattedTime: String {
        let minutes = remainingSeconds / 60
        let seconds = remainingSeconds % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var elapsedSeconds: Int {
        totalSeconds - remainingSeconds
    }
    
    // MARK: - Initialization
    private init() {
        setupNotificationObservers()
        requestNotificationPermission()
        setupAudioSession()
        loadPersistedState()
        prepareHaptics()  // PERFORMANCE: Prepare generators for reduced latency
    }
    
    // MARK: - Audio Setup
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Audio session setup failed - timer will work without custom sounds
        }
    }
    
    // MARK: - Notification Permission
    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in
            // Permission result handled silently
        }
    }
    
    // MARK: - App Lifecycle Observers
    private func setupNotificationObservers() {
        lifecycleTasks.append(Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: UIApplication.willResignActiveNotification) {
                self?.handleAppBackgrounded()
            }
        })
        
        lifecycleTasks.append(Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: UIApplication.didBecomeActiveNotification) {
                self?.handleAppForegrounded()
            }
        })
        
        lifecycleTasks.append(Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: UIApplication.willTerminateNotification) {
                self?.persistState()
            }
        })
    }
    
    // MARK: - Timer Controls
    func start(taskId: String, durationMinutes: Int, isBreak: Bool = false) {
        currentTaskId = taskId
        totalSeconds = durationMinutes * 60
        remainingSeconds = totalSeconds
        isBreakMode = isBreak
        accumulatedPauseTime = 0
        
        // Create session for work (not breaks)
        if !isBreak {
            currentSession = FocusSession(
                taskId: taskId,
                startedAt: Date(),
                plannedDurationSeconds: totalSeconds
            )
        }
        
        startTime = Date()
        state = .running
        startTimer()
        persistState()
        
        // Play appropriate start sound and haptic
        if isBreak {
            playBreakStartSound()
            lightImpactGenerator.impactOccurred(intensity: 0.4)  // Softer for break
        } else {
            playTimerStartSound()
            mediumImpactGenerator.impactOccurred(intensity: 0.6)  // Firmer for focus
        }
        
        // Schedule notification for when timer ends
        scheduleCompletionNotification()
    }
    
    func pause() {
        guard state == .running else { return }
        
        timer?.invalidate()
        timer = nil
        pausedTime = Date()
        state = .paused
        
        // Cancel scheduled notification
        cancelScheduledNotification()
        persistState()
    }
    
    func resume() {
        guard state == .paused else { return }
        
        if let paused = pausedTime {
            accumulatedPauseTime += Date().timeIntervalSince(paused)
        }
        pausedTime = nil
        
        state = .running
        startTimer()
        
        // Reschedule notification
        scheduleCompletionNotification()
        persistState()
    }
    
    func reset() {
        timer?.invalidate()
        timer = nil
        
        // Mark session as interrupted if it was running
        if var session = currentSession, state == .running || state == .paused {
            session.wasInterrupted = true
            session.actualDurationSeconds = elapsedSeconds
            session.endedAt = Date()
            currentSession = session
        }
        
        state = .idle
        remainingSeconds = 0
        totalSeconds = 0
        startTime = nil
        pausedTime = nil
        accumulatedPauseTime = 0
        
        cancelScheduledNotification()
        clearPersistedState()
    }
    
    func complete() {
        timer?.invalidate()
        timer = nil
        
        // Finalize session
        if var session = currentSession {
            session.wasCompleted = true
            session.actualDurationSeconds = totalSeconds
            session.endedAt = Date()
            currentSession = session
        }
        
        state = .completed
        
        // Trigger completion effects with appropriate haptic pattern
        playCompletionSound()
        if isBreakMode {
            playBreakEndHaptic()  // Softer "time to refocus" pattern
        } else {
            playCelebrationHaptic()  // Rewarding "great job!" pattern
        }
        
        cancelScheduledNotification()
        clearPersistedState()
    }
    
    func startBreak(_ type: BreakType) {
        breakType = type
        guard let taskId = currentTaskId else { return }
        start(taskId: taskId, durationMinutes: type.durationMinutes, isBreak: true)
    }
    
    // MARK: - Timer Engine
    private func startTimer() {
        timer?.invalidate()
        
        // P-7 FIX: Use MainActor.assumeIsolated instead of Task { @MainActor in }.
        // Timer fires on RunLoop.main (main thread guaranteed), so assumeIsolated
        // is correct and avoids allocating a Task object every second.
        // Before: 1 Task allocation per tick × 60 ticks/min = 60 allocations/min.
        // After: 0 allocations — synchronous main-thread call.
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.tick()
            }
        }
        
        // Ensure timer runs during scroll
        if let timer = timer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }
    
    private func tick() {
        guard state == .running else { return }
        
        if remainingSeconds > 0 {
            remainingSeconds -= 1
            
            // Haptic every minute
            if remainingSeconds > 0 && remainingSeconds % 60 == 0 {
                triggerHapticFeedback(style: .light)
            }
        }
        
        if remainingSeconds <= 0 {
            complete()
        }
    }
    
    // MARK: - Background Handling
    private func handleAppBackgrounded() {
        guard state == .running else { return }
        
        // Begin background task
        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
        
        persistState()
    }
    
    private func handleAppForegrounded() {
        endBackgroundTask()
        
        // Recalculate remaining time based on actual elapsed time
        if state == .running, let start = startTime {
            let elapsed = Date().timeIntervalSince(start) - accumulatedPauseTime
            let newRemaining = max(0, totalSeconds - Int(elapsed))
            
            if newRemaining != remainingSeconds {
                remainingSeconds = newRemaining
                
                if remainingSeconds <= 0 {
                    complete()
                }
            }
        }
        
        // Cancel notification since we're back in foreground
        cancelScheduledNotification()
        
        // Reschedule if still running
        if state == .running {
            scheduleCompletionNotification()
        }
    }
    
    private func endBackgroundTask() {
        if backgroundTaskID != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskID)
            backgroundTaskID = .invalid
        }
    }
    
    // MARK: - Local Notifications
    private func scheduleCompletionNotification() {
        let content = UNMutableNotificationContent()
        content.title = isBreakMode ? "Break Complete! " : "Focus Session Complete! "
        content.body = isBreakMode ? "Ready to get back to work?" : "Great job! Take a break or continue."
        content.sound = UNNotificationSound(named: UNNotificationSoundName("timer_complete.aiff"))
        content.categoryIdentifier = "FOCUS_TIMER"
        
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: TimeInterval(remainingSeconds),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: timerNotificationID,
            content: content,
            trigger: trigger
        )
        
        UNUserNotificationCenter.current().add(request) { _ in
            // Notification scheduled - errors handled silently
        }
    }
    
    private func cancelScheduledNotification() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [timerNotificationID]
        )
    }
    
    // MARK: - Sound & Haptics
    
    /// Refined completion chime - uses pleasant system sounds for a calm feel
    private func playCompletionSound() {
        // First, try custom bundled sound (singing bowl / meditation chime)
        if let soundURL = Bundle.main.url(forResource: "timer_complete", withExtension: "aiff") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.volume = 0.7  // Slightly softer for refinement
                audioPlayer?.play()
                
                // Auto-stop after sound completes (max 5 seconds)
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(5))
                    self?.audioPlayer?.stop()
                }
                return
            } catch {
                // Fall through to system sounds
            }
        }
        
        // Fallback: Use refined system sounds
        // 1013 = Mail sent (soft whoosh) - calm
        // 1057 = Tink (gentle tap)
        // 1025 = New mail (pleasant chime)
        // 1016 = Tweet sent (gentle)
        // For a zen/calm feel, we use the gentle tink followed by a softer confirmation
        AudioServicesPlaySystemSound(1057)  // Gentle "tink"
        
        // Add a second gentle tone after a brief pause for richness
        Task {
            try? await Task.sleep(for: .milliseconds(300))
            AudioServicesPlaySystemSound(1075)  // Soft confirmation tone
        }
    }
    
    func stopAlarm() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
    
    /// Celebratory haptic pattern for timer completion - feels rewarding and premium
    private func playCelebrationHaptic() {
        // A satisfying three-beat pattern: strong → medium → light (like a "ta-da!")
        heavyImpactGenerator.impactOccurred(intensity: 1.0)
        
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(100))
            self?.mediumImpactGenerator.impactOccurred(intensity: 0.7)
            
            try? await Task.sleep(for: .milliseconds(100))
            self?.lightImpactGenerator.impactOccurred(intensity: 0.5)
            
            // Final success notification after the pattern
            try? await Task.sleep(for: .milliseconds(200))
            self?.notificationGenerator.notificationOccurred(.success)
        }
    }
    
    /// Break completion uses a softer, single haptic (more "time to refocus")
    private func playBreakEndHaptic() {
        mediumImpactGenerator.impactOccurred(intensity: 0.6)
        
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(150))
            self?.notificationGenerator.notificationOccurred(.warning)
        }
    }
    
    /// Subtle sound when focus session starts - confirms action, sets intention
    private func playTimerStartSound() {
        // Try custom bundled sound first
        if let soundURL = Bundle.main.url(forResource: "timer_start", withExtension: "aiff") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.volume = 0.5  // Subtle, not distracting
                audioPlayer?.play()
                return
            } catch {
                // Fall through to system sound
            }
        }
        
        // Fallback: Soft, subtle system sound
        // 1104 = Camera shutter (too loud)
        // 1057 = Tink (gentle)
        // 1306 = Begin recording (subtle click)
        AudioServicesPlaySystemSound(1113)  // Subtle "begin" tone
    }
    
    /// Light, airy sound when break starts - signals transition to rest
    private func playBreakStartSound() {
        // Try custom bundled sound first
        if let soundURL = Bundle.main.url(forResource: "break_start", withExtension: "aiff") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.volume = 0.5
                audioPlayer?.play()
                return
            } catch {
                // Fall through to system sound
            }
        }
        
        // Fallback: Light, refreshing system sound
        // Using a gentler tone that feels like "exhale" or "relax"
        AudioServicesPlaySystemSound(1109)  // Soft, airy tone
    }
    
    func triggerHapticFeedback(style: UINotificationFeedbackGenerator.FeedbackType) {
        // PERFORMANCE: Reuse prepared generator instead of allocating new one
        notificationGenerator.notificationOccurred(style)
    }
    
    func triggerHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        // PERFORMANCE: Reuse prepared generator instead of allocating new one
        switch style {
        case .light:
            lightImpactGenerator.impactOccurred()
        case .medium:
            mediumImpactGenerator.impactOccurred()
        case .heavy:
            heavyImpactGenerator.impactOccurred()
        case .soft:
            lightImpactGenerator.impactOccurred()
        case .rigid:
            heavyImpactGenerator.impactOccurred()
        @unknown default:
            mediumImpactGenerator.impactOccurred()
        }
    }
    
    /// Call this when timer view appears to reduce haptic latency
    func prepareHaptics() {
        notificationGenerator.prepare()
        lightImpactGenerator.prepare()
        mediumImpactGenerator.prepare()
        heavyImpactGenerator.prepare()
    }
    
    // MARK: - Persistence
    @ObservationIgnored private let persistenceKey = "com.familyhub.focustimer.state"
    
    private func persistState() {
        guard state == .running || state == .paused else { return }
        
        let data: [String: Any] = [
            "state": state.rawValue,
            "totalSeconds": totalSeconds,
            "remainingSeconds": remainingSeconds,
            "startTime": startTime?.timeIntervalSince1970 ?? 0,
            "accumulatedPauseTime": accumulatedPauseTime,
            "taskId": currentTaskId ?? "",
            "isBreakMode": isBreakMode
        ]
        
        UserDefaults.standard.set(data, forKey: persistenceKey)
    }
    
    private func loadPersistedState() {
        guard let data = UserDefaults.standard.dictionary(forKey: persistenceKey),
              let stateRaw = data["state"] as? String,
              let savedState = FocusTimerState(rawValue: stateRaw),
              savedState == .running || savedState == .paused else {
            return
        }
        
        totalSeconds = data["totalSeconds"] as? Int ?? 0
        currentTaskId = data["taskId"] as? String
        isBreakMode = data["isBreakMode"] as? Bool ?? false
        accumulatedPauseTime = data["accumulatedPauseTime"] as? TimeInterval ?? 0
        
        if let startTimeInterval = data["startTime"] as? TimeInterval, startTimeInterval > 0 {
            let restoredStartTime = Date(timeIntervalSince1970: startTimeInterval)
            startTime = restoredStartTime
            
            // Calculate actual remaining time
            let elapsed = Date().timeIntervalSince(restoredStartTime) - accumulatedPauseTime
            remainingSeconds = max(0, totalSeconds - Int(elapsed))
            
            if remainingSeconds > 0 {
                state = savedState
                if savedState == .running {
                    startTimer()
                    scheduleCompletionNotification()
                }
            } else {
                // Timer completed while app was closed
                complete()
            }
        }
    }
    
    private func clearPersistedState() {
        UserDefaults.standard.removeObject(forKey: persistenceKey)
    }
    
    // MARK: - Session Retrieval
    func getCompletedSession() -> FocusSession? {
        return currentSession
    }
    
    func clearSession() {
        currentSession = nil
    }
}

// MARK: - Haptic Feedback Extension
extension FocusTimerManager {
    func dialHaptic(at minutes: Int) {
        // Haptic every 5 minutes on the dial
        if minutes % 5 == 0 {
            triggerHapticFeedback(style: .medium)
        } else {
            triggerHapticFeedback(style: .light)
        }
    }
}
