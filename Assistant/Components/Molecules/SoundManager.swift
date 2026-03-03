//
//  SoundManager.swift
//  Assistant
//
//  Centralized sound and haptic feedback manager for app-wide use
//

import SwiftUI
import AVFoundation
import AudioToolbox

@MainActor
class SoundManager {
    static let shared = SoundManager()
    
    // MARK: - Private Properties
    private var audioPlayer: AVAudioPlayer?
    
    // PERFORMANCE: Reusable haptic generators
    private let notificationGenerator = UINotificationFeedbackGenerator()
    private let lightImpactGenerator = UIImpactFeedbackGenerator(style: .light)
    private let mediumImpactGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let heavyImpactGenerator = UIImpactFeedbackGenerator(style: .heavy)
    
    // MARK: - Sound Settings
    @AppStorage("soundEnabled") var soundEnabled: Bool = true
    @AppStorage("hapticEnabled") var hapticEnabled: Bool = true
    
    // MARK: - Initialization
    private init() {
        setupAudioSession()
        prepareHaptics()
    }
    
    private func setupAudioSession() {
        do {
            try AVAudioSession.sharedInstance().setCategory(.ambient, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)
        } catch {
            // Audio session setup failed - sounds will still attempt to play
        }
    }
    
    /// Prepare haptic generators for reduced latency
    func prepareHaptics() {
        notificationGenerator.prepare()
        lightImpactGenerator.prepare()
        mediumImpactGenerator.prepare()
        heavyImpactGenerator.prepare()
    }
    
    // MARK: - App Event Sounds
    
    /// Play when a task is marked complete - satisfying ding
    func playTaskCompleted() {
        guard soundEnabled else { return }
        
        playSound(named: "task_complete", volume: 0.7)
        
        if hapticEnabled {
            // Quick celebratory pattern: medium → light → success
            mediumImpactGenerator.impactOccurred(intensity: 0.7)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.lightImpactGenerator.impactOccurred(intensity: 0.5)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                self?.notificationGenerator.notificationOccurred(.success)
            }
        }
    }
    
    /// Play when user earns a reward - bigger celebration
    func playRewardEarned() {
        guard soundEnabled else { return }
        
        playSound(named: "reward_earned", volume: 0.8)
        
        if hapticEnabled {
            // Bigger celebration: heavy → medium → light → success
            heavyImpactGenerator.impactOccurred(intensity: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.mediumImpactGenerator.impactOccurred(intensity: 0.8)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.lightImpactGenerator.impactOccurred(intensity: 0.6)
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
                self?.notificationGenerator.notificationOccurred(.success)
            }
        }
    }
    
    /// Subtle tap for UI interactions (buttons, selections)
    func playTap() {
        guard hapticEnabled else { return }
        lightImpactGenerator.impactOccurred(intensity: 0.4)
    }
    
    /// Medium feedback for confirmations
    func playConfirm() {
        guard hapticEnabled else { return }
        mediumImpactGenerator.impactOccurred(intensity: 0.6)
    }
    
    /// Error/warning feedback
    func playError() {
        guard hapticEnabled else { return }
        notificationGenerator.notificationOccurred(.error)
    }
    
    /// Warning feedback
    func playWarning() {
        guard hapticEnabled else { return }
        notificationGenerator.notificationOccurred(.warning)
    }
    
    // MARK: - Core Sound Player
    
    private func playSound(named name: String, volume: Float = 0.7) {
        // Try custom bundled sound first
        if let soundURL = Bundle.main.url(forResource: name, withExtension: "aiff") {
            do {
                audioPlayer = try AVAudioPlayer(contentsOf: soundURL)
                audioPlayer?.volume = volume
                audioPlayer?.play()
                return
            } catch {
                // Fall through to system sound
            }
        }
        
        // Fallback to system sound
        AudioServicesPlaySystemSound(1057)  // Gentle "tink"
    }
    
    func stopSound() {
        audioPlayer?.stop()
        audioPlayer = nil
    }
}

// MARK: - Convenience View Extension
extension View {
    /// Add tap sound to any view
    func withTapSound() -> some View {
        self.simultaneousGesture(
            TapGesture().onEnded {
                Task { @MainActor in
                    SoundManager.shared.playTap()
                }
            }
        )
    }
}
