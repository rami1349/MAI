//  ToastBanner.swift
//  FamilyHub
//
//  Reusable toast/snackbar component for transient feedback.
//  Supports success, error, and info variants.
//  Auto-dismisses after a configurable duration.
//


import SwiftUI

// MARK: - Toast Style

enum ToastStyle {
    case success
    case error
    case info
    
    var icon: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var iconColor: Color {
        switch self {
        case .success: return Color.accentGreen
        case .error: return Color.accentRed
        case .info: return Color.accentPrimary
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .success: return Color.accentGreen
        case .error: return Color.accentRed
        case .info: return Color.accentPrimary
        }
    }
}

// MARK: - Toast Banner View

/// Lightweight value describing a transient notification with a style.
/// Used with `.toastBanner(item:)` modifier for success/error/info feedback.
struct ToastMessage: Equatable {
    let id = UUID()
    let message: String
    let style: ToastStyle

    static func success(_ message: String) -> ToastMessage {
        ToastMessage(message: message, style: .success)
    }

    static func error(_ message: String) -> ToastMessage {
        ToastMessage(message: message, style: .error)
    }

    static func info(_ message: String) -> ToastMessage {
        ToastMessage(message: message, style: .info)
    }

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Toast Banner View

struct ToastBanner: View {
    let message: String
    var style: ToastStyle = .error
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: style.icon)
                .font(.system(size: DS.IconSize.md)) // DT-exempt: icon sizing
                .foregroundStyle(.textOnAccent)
            
            Text(message)
                .font(DS.Typography.label())
                .foregroundStyle(.textOnAccent)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            
            Spacer()
            
            if let onDismiss {
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .font(.caption.bold())
                        .foregroundStyle(.textOnAccent.opacity(0.8))
                        .frame(width: DS.Control.compact, height: DS.Control.compact)
                        .contentShape(Rectangle())
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(style.backgroundColor.opacity(0.95))
        )
        .elevation2()
        .padding(.horizontal, DS.Spacing.lg)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

// MARK: - Global Error Banner Modifier

/// Attaches to MainTabView to show familyViewModel errors as a dismissible top banner.
/// Auto-dismisses after 4 seconds, or on tap of the X button.
struct GlobalErrorBannerModifier: ViewModifier {
    @Binding var errorMessage: String?
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let message = errorMessage, !message.isEmpty {
                    ToastBanner(
                        message: message,
                        style: .error,
                        onDismiss: { clearError() }
                    )
                    .padding(.top, DS.Spacing.sm)
                    .onAppear {
                        // Auto-dismiss after 4 seconds
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(4))
                            clearError()
                        }
                    }
                    .onTapGesture {
                        clearError()
                    }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: errorMessage)
    }
    
    private func clearError() {
        withAnimation {
            errorMessage = nil
        }
    }
}

extension View {
    func globalErrorBanner(errorMessage: Binding<String?>) -> some View {
        modifier(GlobalErrorBannerModifier(errorMessage: errorMessage))
    }
}

// MARK: - Style-Aware Toast Modifier

/// Like GlobalErrorBannerModifier but supports success/error/info styles.
/// Bind to an optional ToastMessage; auto-dismisses after 2.5s.
struct ToastBannerModifier: ViewModifier {
    @Binding var item: ToastMessage?

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let toast = item {
                    ToastBanner(
                        message: toast.message,
                        style: toast.style,
                        onDismiss: { dismiss() }
                    )
                    .padding(.top, DS.Spacing.sm)
                    .onAppear {
                        Task { @MainActor in
                            try? await Task.sleep(for: .seconds(2.5))
                            dismiss()
                        }
                    }
                    .onTapGesture { dismiss() }
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: item)
    }

    private func dismiss() {
        withAnimation { item = nil }
    }
}

extension View {
    /// Shows an auto-dismissing toast banner with success/error/info styling.
    func toastBanner(item: Binding<ToastMessage?>) -> some View {
        modifier(ToastBannerModifier(item: item))
    }
}

// MARK: - Success Dismiss Overlay

/// Full-screen checkmark overlay shown briefly after a successful create action.
/// Triggers a success haptic, displays for 600ms, then calls onComplete (which dismisses).
struct SuccessDismissOverlay: View {
    let message: String
    var onComplete: () -> Void
    
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 0
    
    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: DS.IconSize.jumbo)) // DT-exempt: icon sizing
                .foregroundStyle(.accentGreen)
                .scaleEffect(scale)
            
            Text(message)
                .font(DS.Typography.subheading())
                .foregroundStyle(.textPrimary)
        }
        .padding(DS.Spacing.xxl)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .fill(.ultraThinMaterial)
        )
        .elevation3()
        .opacity(opacity)
        .onAppear {
            // Haptic
            DS.Haptics.success()
            
            // Animate in
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                scale = 1.0
                opacity = 1.0
            }
            
            // Dismiss after delay
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(0.6))
                withAnimation(.easeOut(duration: 0.2)) {
                    opacity = 0
                }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(0.2))
                    onComplete()
                }
            }
        }
    }
}
// MARK: - Offline Banner Modifier

/// Shows a persistent info banner when the device loses connectivity.
/// Automatically hides when connectivity is restored. No auto-dismiss.
/// Uses NetworkMonitor.shared internally Ã¢â‚¬â€ no environment wiring needed.
struct OfflineBannerModifier: ViewModifier {
    private var networkMonitor: NetworkMonitor { .shared }
    
    @State private var showBanner = false
    @State private var debounceTask: Task<Void, Never>?
    
    func body(content: Content) -> some View {
        content
            .overlay(alignment: .bottom) {
                if showBanner {
                    ToastBanner(
                        message: "You're offline. Changes will sync when you're back online.",
                        style: .info
                    )
                    .padding(.bottom, DS.Spacing.jumbo + DS.Spacing.xl)
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: showBanner)
            .onChange(of: networkMonitor.isConnected) { _, connected in
                debounceTask?.cancel()
                
                if connected {
                    withAnimation { showBanner = false }
                } else {
                    // 1.5s delay to ignore momentary drops
                    debounceTask = Task {
                        try? await Task.sleep(for: .seconds(1.5))
                        guard !Task.isCancelled else { return }
                        await MainActor.run {
                            withAnimation { showBanner = true }
                        }
                    }
                }
            }
    }
}

extension View {
    func offlineBanner() -> some View {
        modifier(OfflineBannerModifier())
    }
}

// MARK: - Shake Effect Modifier

/// Applies a horizontal shake animation, useful for error feedback on form fields.
/// Toggle `trigger` to fire the shake.
struct ShakeEffect: GeometryEffect {
    var amount: CGFloat = 8
    var shakesPerUnit: CGFloat = 3
    var animatableData: CGFloat
    
    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(
            CGAffineTransform(translationX: amount * sin(animatableData * .pi * shakesPerUnit), y: 0)
        )
    }
}

extension View {
    func shake(trigger: Int) -> some View {
        self.modifier(ShakeEffect(animatableData: CGFloat(trigger)))
    }
}

// MARK: - Preview

#Preview("Toast Variants") {
    VStack(spacing: DS.Spacing.lg) {
        ToastBanner(message: "Task created successfully!", style: .success)
        ToastBanner(message: "Failed to save. Check your connection.", style: .error, onDismiss: {})
        ToastBanner(message: "Syncing your changes...", style: .info)
    }
    .padding()
}

#Preview("Success Overlay") {
    ZStack {
        Color.themeSurfacePrimary.ignoresSafeArea()
        SuccessDismissOverlay(message: "Task Created!", onComplete: {})
    }
}
