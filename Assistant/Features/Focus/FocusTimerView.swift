//
//  FocusTimerView.swift
//  Full-screen Pomodoro timer with animated progress ring
//

import SwiftUI
import UIKit

struct FocusTimerView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(FamilyViewModel.self) var familyViewModel
    // PERFORMANCE: Direct singleton reference (computed — excluded from memberwise init)
    private var timerManager: FocusTimerManager { .shared }
    
    let task: FamilyTask
    
    @State private var showTimeDial = true  // Show dial first
    @State private var selectedMinutes: Int = 30
    @State private var showCompletionOptions = false
    @State private var animateRing = false
    @State private var pulseAnimation = false
    @State private var isCompletingTask = false
    @State private var showProofCapture = false
    
    // Adaptive ring size based on device/presentation
    private var ringSize: CGFloat {
        horizontalSizeClass == .regular ? DS.Timer.ringPad : DS.Timer.ringPhone
    }
    private let ringLineWidth: CGFloat = DS.Timer.ringStroke
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color.themeSurfaceSecondary
                    .ignoresSafeArea()
                
                if timerManager.state == .idle && showTimeDial {
                    // Time selection (initial state)
                    timeSelectionView
                } else {
                    // Active timer view
                    timerActiveView
                }
            }
            .navigationTitle(showTimeDial ? "" : (timerManager.isBreakMode ? "Break Time" : "Focus Mode"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("close") {
                        handleClose()
                    }
                }
            }
            .sheet(isPresented: $showCompletionOptions) {
                completionSheet
            }
            .sheet(isPresented: $showProofCapture) {
                ProofCaptureView(task: task)
            }
        }
        .interactiveDismissDisabled(timerManager.state == .running)
        .onAppear {
            // If timer is already running for this task, show timer
            if timerManager.state == .running || timerManager.state == .paused {
                showTimeDial = false
            }
        }
    }
    
    // Time adjustment constants
    private let timeStep: Int = 5
    private let minTime: Int = 5
    private let maxTime: Int = 120
    
    // MARK: - Time Selection View
    private var timeSelectionView: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Header
            VStack(spacing: DS.Spacing.sm) {
                Text("focus_timer")
                    .font(DS.Typography.displayMedium())
                    .foregroundStyle(.textPrimary)
                
                Text(task.title)
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, DS.Spacing.jumbo)
            }
            
            Spacer()
            
            // Time Control Row: [-] 30 mins [+]
            HStack(spacing: DS.Spacing.xxxl) {
                // Minus button
                Button(action: decrementTime) {
                    ZStack {
                        Circle()
                            .fill(Color.themeCardBackground)
                            .frame(width: DS.Control.large + 6, height: DS.Control.large + 6)
                            .overlay(
                                Circle()
                                    .stroke(Color.themeCardBorder, lineWidth: DS.Border.standard)
                            )
                        
                        Image(systemName: "minus")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(selectedMinutes <= minTime ? .textTertiary : .textPrimary)
                    }
                }
                .disabled(selectedMinutes <= minTime)
                
                // Time display
                Text("\(selectedMinutes) mins")
                    .font(DS.Typography.displayLarge()) // was .rounded
                    .foregroundStyle(.textPrimary)
                    .frame(minWidth: 140)
                
                // Plus button
                Button(action: incrementTime) {
                    ZStack {
                        Circle()
                            .fill(Color.themeCardBackground)
                            .frame(width: DS.Control.large + 6, height: DS.Control.large + 6)
                            .overlay(
                                Circle()
                                    .stroke(Color.themeCardBorder, lineWidth: DS.Border.standard)
                            )
                        
                        Image(systemName: "plus")
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundStyle(selectedMinutes >= maxTime ? .textTertiary : .textPrimary)
                    }
                }
                .disabled(selectedMinutes >= maxTime)
            }
            
            Spacer()
            
            // Start button
            Button(action: startFocusSession) {
                HStack(spacing: DS.Spacing.md) {
                    Image(systemName: "play.fill")
                    Text("start_focus")
                }
                .font(DS.Typography.heading())
                .foregroundStyle(.textOnAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.lg)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.xl)
                        .fill(Color.accentPrimary)
                )
            }
            .padding(.horizontal, DS.Spacing.xxl)
            .padding(.bottom, DS.Spacing.jumbo)
        }
    }
    
    private func decrementTime() {
        guard selectedMinutes > minTime else { return }
        withAnimation(.spring(response: 0.2)) {
            selectedMinutes -= timeStep
        }
        DS.Haptics.light()
    }
    
    private func incrementTime() {
        guard selectedMinutes < maxTime else { return }
        withAnimation(.spring(response: 0.2)) {
            selectedMinutes += timeStep
        }
        DS.Haptics.light()
    }
    
    // MARK: - Active Timer View
    private var timerActiveView: some View {
        VStack(spacing: DS.Spacing.jumbo) {
            Spacer()
            
            // Mode indicator
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: timerManager.isBreakMode ? "cup.and.saucer.fill" : "brain.head.profile")
                Text(timerManager.isBreakMode ? "Break Time" : "Deep Focus")
            }
            .font(.subheadline)
            .fontWeight(.medium)
            .foregroundStyle(.accentPrimary)
            .padding(.horizontal, DS.Spacing.lg)
            .padding(.vertical, DS.Spacing.sm)
            .background(Capsule().fill(Color.accentPrimary.opacity(0.12)))
            
            // Progress ring
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.fill, lineWidth: ringLineWidth)
                    .frame(width: ringSize, height: ringSize)
                
                // Progress ring (empties as time counts down)
                Circle()
                    .trim(from: 0, to: timerManager.remainingProgress)
                    .stroke(
                        LinearGradient(
                            colors: timerManager.isBreakMode
                                ? [Color.accentTertiary, Color.accentTertiary]
                                : [Color.accentPrimary, Color.accentSecondary],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                    )
                    .frame(width: ringSize, height: ringSize)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: timerManager.remainingProgress)
                
                // Pulse effect when paused
                if timerManager.state == .paused {
                    Circle()
                        .stroke(Color.accentPrimary.opacity(0.3), lineWidth: 4)
                        .frame(width: ringSize + 20, height: ringSize + 20)
                        .scaleEffect(pulseAnimation ? 1.1 : 1.0)
                        .opacity(pulseAnimation ? 0 : 0.5)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: false), value: pulseAnimation)
                        .onAppear { pulseAnimation = true }
                        .onDisappear { pulseAnimation = false }
                }
                
                // Center content
                VStack(spacing: DS.Spacing.sm) {
                    // Time display
                    Text(timerManager.formattedTime)
                        .font(.system(size: DS.Timer.displayFont, weight: .bold, design: .rounded)) // DT-exempt: timer display
                        .foregroundStyle(.textPrimary)
                        .contentTransition(.numericText())
                    
                    // State indicator
                    HStack(spacing: DS.Spacing.sm) {
                        Circle()
                            .fill(stateIndicatorColor)
                            .frame(width: 8, height: 8)
                        Text(stateText)
                            .font(.caption)
                            .foregroundStyle(.textSecondary)
                    }
                }
            }
            
            // Task title
            Text(task.title)
                .font(.headline)
                .foregroundStyle(.textSecondary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, DS.Spacing.jumbo)
            
            Spacer()
            
            // Control buttons
            controlButtons
        }
        .onChange(of: timerManager.state) { _, newState in
            if newState == .completed {
                showCompletionOptions = true
            }
        }
    }
    
    private var stateText: String {
        switch timerManager.state {
        case .running: return "Focusing..."
        case .paused: return "Paused"
        case .completed: return "Complete!"
        default: return ""
        }
    }
    
    private var stateIndicatorColor: Color {
        switch timerManager.state {
        case .running: return Color.statusSuccess
        case .paused: return Color.statusWarning
        case .completed: return Color.accentPrimary
        default: return Color.textTertiary
        }
    }
    
    // MARK: - Control Buttons
    private var controlButtons: some View {
        HStack(spacing: DS.Spacing.xxl) {
            // Reset button
            Button(action: {
                timerManager.reset()
                showTimeDial = true
            }) {
                Image(systemName: "arrow.counterclockwise")
                    .font(.system(size: DS.IconSize.lg)) // DT-exempt: icon sizing
                    .foregroundStyle(.textSecondary)
                    .frame(width: DS.Control.standard, height: DS.Control.standard)
                    .background(Circle().fill(Color.fill))
            }
            
            // Play/Pause button
            Button(action: toggleTimer) {
                Image(systemName: timerManager.state == .running ? "pause.fill" : "play.fill")
                    .font(.system(size: DS.IconSize.xl)) // DT-exempt: decorative icon
                    .foregroundStyle(.textOnAccent)
                    .frame(width: DS.Control.fab, height: DS.Control.fab)
                    .background(
                        Circle()
                            .fill(Color.accentPrimary)
                            .shadow(color: Color.accentPrimary.opacity(0.4), radius: DS.Spacing.sm, x: 0, y: DS.Spacing.xs)
                    )
            }
            
            // Complete button (skip to done)
            Button(action: {
                timerManager.complete()
            }) {
                Image(systemName: "checkmark")
                    .font(.system(size: DS.IconSize.lg)) // DT-exempt: icon sizing
                    .foregroundStyle(.statusSuccess)
                    .frame(width: DS.Control.standard, height: DS.Control.standard)
                    .background(Circle().fill(Color.statusSuccess.opacity(0.15)))
            }
        }
        .padding(.bottom, DS.Spacing.jumbo)
    }
    
    // MARK: - Completion Sheet
    private var completionSheet: some View {
        VStack(spacing: DS.Spacing.xl) {
            // Success animation
            ZStack {
                Circle()
                    .fill(Color.statusSuccess.opacity(0.15))
                    .frame(width: DS.EmptyState.iconContainer, height: DS.EmptyState.iconContainer)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: DS.EmptyState.icon)) // DT-exempt: decorative icon
                    .foregroundStyle(.statusSuccess)
                    .scaleEffect(animateRing ? 1.0 : 0.5)
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: animateRing)
            }
            .onAppear { animateRing = true }
            
            // Stats
            VStack(spacing: DS.Spacing.xs) {
                Text(timerManager.isBreakMode ? "Break Complete!" : "Focus Session Complete!")
                    .font(DS.Typography.heading())
                    .foregroundStyle(.textPrimary)
                
                if !timerManager.isBreakMode {
                    Text("\(timerManager.totalSeconds / 60) minutes of focused work")
                        .font(.subheadline)
                        .foregroundStyle(.textSecondary)
                }
            }
            
            Divider()
                .padding(.horizontal, DS.Spacing.jumbo)
            
            // Action buttons
            VStack(spacing: DS.Spacing.md) {
                if !timerManager.isBreakMode {
                    // Break options
                    Button(action: {
                        showCompletionOptions = false
                        timerManager.startBreak(.short)
                    }) {
                        HStack {
                            Image(systemName: "cup.and.saucer.fill")
                            Text("short_break")
                        }
                        .font(.headline)
                        .foregroundStyle(.accentPrimary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.card)
                                .fill(Color.accentPrimary.opacity(0.12))
                        )
                    }
                    
                    Button(action: {
                        showCompletionOptions = false
                        timerManager.startBreak(.long)
                    }) {
                        HStack {
                            Image(systemName: "figure.walk")
                            Text("long_break")
                        }
                        .font(.headline)
                        .foregroundStyle(.textSecondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.card)
                                .fill(Color.fill)
                        )
                    }
                }
                
                // Complete task OR submit proof
                if task.requiresProof {
                    // Task requires proof â€” can't mark complete directly
                    Button(action: {
                        showCompletionOptions = false
                        // Save focus session before navigating to proof
                        if let session = timerManager.getCompletedSession() {
                            saveFocusSession(session, wasInterrupted: false)
                        }
                        timerManager.clearSession()
                        timerManager.reset()
                        showProofCapture = true
                    }) {
                        HStack {
                            Image(systemName: "arrow.up.doc.fill")
                            Text("submit_proof")
                        }
                        .font(.headline)
                        .foregroundStyle(.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.button)
                                .fill(Color.accentSecondary)
                        )
                    }
                } else {
                    // No proof needed â€” complete directly
                    Button(action: {
                        completeTaskAndSave()
                    }) {
                        HStack {
                            if isCompletingTask {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(0.8)
                            }
                            Image(systemName: "checkmark.circle.fill")
                            Text("complete_task")
                        }
                        .font(.headline)
                        .foregroundStyle(.textOnAccent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DS.Spacing.lg)
                        .background(
                            RoundedRectangle(cornerRadius: DS.Radius.button)
                                .fill(isCompletingTask ? Color.gray : Color.statusSuccess)
                        )
                    }
                    .disabled(isCompletingTask)
                }
                
                // Continue later
                Button(action: {
                    saveSessionAndClose()
                }) {
                    Text("continue_later")
                        .font(.subheadline)
                        .foregroundStyle(.textSecondary)
                }
                .padding(.top, DS.Spacing.sm)
            }
            .padding(.horizontal, DS.Spacing.xxl)
        }
        .padding(.vertical, DS.Spacing.xxxl)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    
    // MARK: - Actions
    private func startFocusSession() {
        guard let taskId = task.id else { return }
        
        withAnimation(.spring(response: 0.4)) {
            showTimeDial = false
        }
        
        timerManager.start(taskId: taskId, durationMinutes: selectedMinutes)
        DS.Haptics.heavy()
    }
    
    private func toggleTimer() {
        switch timerManager.state {
        case .running:
            timerManager.pause()
        case .paused:
            timerManager.resume()
        default:
            break
        }
        DS.Haptics.medium()
    }
    
    private func handleClose() {
        if timerManager.state == .running || timerManager.state == .paused {
            // Save interrupted session
            if let session = timerManager.getCompletedSession() {
                saveFocusSession(session, wasInterrupted: true)
            }
            timerManager.reset()
        }
        dismiss()
    }
    
    private func completeTaskAndSave() {
        guard !isCompletingTask else { return }
        isCompletingTask = true
        
        // Save focus session
        if let session = timerManager.getCompletedSession() {
            saveFocusSession(session, wasInterrupted: false)
        }
        
        // Mark task as complete then dismiss entire sheet stack
        Task {
            await familyViewModel.updateTaskStatus(task, to: .completed)
            DS.Haptics.success()
            
            timerManager.clearSession()
            timerManager.reset()
            NotificationCenter.default.post(name: .dismissTaskSheets, object: nil)
        }
    }
    
    private func saveSessionAndClose() {
        // Save focus session
        if let session = timerManager.getCompletedSession() {
            saveFocusSession(session, wasInterrupted: false)
        }
        
        showCompletionOptions = false
        timerManager.clearSession()
        timerManager.reset()
        dismiss()
    }
    
    private func saveFocusSession(_ session: FocusSession, wasInterrupted: Bool) {
        var finalSession = session
        finalSession.wasInterrupted = wasInterrupted
        
        // Save to FamilyViewModel (which persists to Firebase)
        Task {
            await familyViewModel.saveFocusSession(finalSession, for: task)
        }
    }
}

// MARK: - Animated Progress Ring
struct AnimatedProgressRing: View {
    let progress: Double
    let lineWidth: CGFloat
    let gradient: LinearGradient
    
    @State private var animatedProgress: Double = 0
    
    var body: some View {
        Circle()
            .trim(from: 0, to: animatedProgress)
            .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
            .rotationEffect(.degrees(-90))
            .animation(.linear(duration: 1), value: animatedProgress)
            .onChange(of: progress) { _, newValue in
                animatedProgress = newValue
            }
            .onAppear {
                animatedProgress = progress
            }
    }
}

// MARK: - Preview
#Preview {
    let familyVM = FamilyViewModel()
    FocusTimerView(
        task: FamilyTask(
            familyId: "test",
            title: "Complete project review",
            assignedBy: "user1",
            dueDate: Date(),
            status: .inProgress,
            priority: .high,
            createdAt: Date(),
            hasReward: false,
            requiresProof: false,
            rewardPaid: false,
            isRecurring: false
        )
    )
    .environment(familyVM)
    .environment(familyVM.familyMemberVM)
    .environment(familyVM.taskVM)
    .environment(familyVM.calendarVM)
    .environment(familyVM.habitVM)
    .environment(familyVM.notificationVM)
}
