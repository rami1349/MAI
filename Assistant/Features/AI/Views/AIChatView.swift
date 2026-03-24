//
//  AIChatView.swift
//
//
//  AI Chat assistant view with streaming support
//
//  MONETIZATION INTEGRATION (4 spots marked with ─── STORE ───):
//  1. @Environment(SubscriptionManager.self) var store
//  2. Paywall + Credits sheets in body
//  3. remainingBadge shows credits when daily exhausted
//  4. rateLimitBanner has Upgrade + Buy Credits buttons
//  5. inputBar allows sending with credits + shows credit indicator
//  6. canSend checks credits as fallback
//

import SwiftUI

struct AIChatView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @State private var viewModel = ChatViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    // ─── STORE (1): Read SubscriptionManager from environment ───
    @Environment(SubscriptionManager.self) var store
    
    /// When true, shows an X button (iPad sheet mode)
    var isSheet: Bool = false
    
    /// Called when back button is tapped (iPhone tab mode)
    var onBack: (() -> Void)? = nil
    
    @State private var inputText = ""
    @FocusState private var isInputFocused: Bool
    
    private var chatBackground: Color {
        colorScheme == .dark
        ? Color(.systemBackground)
        : Color(.systemGroupedBackground)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerBar
            Divider()
            messagesArea
            inputBar
        }
        .background(chatBackground.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        // Keep your existing confirmation sheet
        .sheet(isPresented: $viewModel.showConfirmation) {
            if let action = viewModel.pendingActionToConfirm {
                ActionConfirmationSheet(
                    action: action,
                    isConfirming: viewModel.isConfirming,
                    result: viewModel.confirmationResult,
                    onConfirm: {
                        Task { await viewModel.confirmPendingAction() }
                    },
                    onCancel: {
                        viewModel.cancelPendingAction()
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
        // ─── STORE (2): Paywall + Credits purchase sheets ───
        .sheet(isPresented: Binding(
            get: { store.showPaywall },
            set: { store.showPaywall = $0 }
        )) {
            PaywallView()
                .environment(store)
                .presentationBackground(Color.themeSurfacePrimary)
        }
        .sheet(isPresented: Binding(
            get: { store.showCreditsPurchase },
            set: { store.showCreditsPurchase = $0 }
        )) {
            CreditsPurchaseSheet()
                .environment(store)
                .presentationBackground(Color.themeSurfacePrimary)
        }
    }
    
    // MARK: - Custom Header Bar
    
    private var headerBar: some View {
        HStack(spacing: DS.Spacing.md) {
            // Leading: back or close
            if isSheet {
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(DS.Typography.subheading())
                        .foregroundStyle(.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.textTertiary.opacity(0.1))
                        )
                }
            } else if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(DS.Typography.subheading())
                        .foregroundStyle(.textPrimary)
                        .frame(width: 32, height: 32)
                        .background(
                            Circle()
                                .fill(Color.textTertiary.opacity(0.1))
                        )
                }
            }
            
            // Center: assistant info
            VStack(spacing: 1) {
                HStack(spacing: DS.Spacing.xs) {
                    Text("MAI")
                        .font(DS.Typography.heading())
                        .foregroundStyle(.textPrimary)
                    
                    if viewModel.isStreaming {
                        StreamingDot()
                    }
                }
                
                remainingBadge
            }
            .frame(maxWidth: .infinity)
            
            // Trailing: actions
            HStack(spacing: DS.Spacing.sm) {
                if !viewModel.messages.isEmpty {
                    Button {
                        withAnimation { viewModel.clearChat() }
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                            .font(DS.Typography.labelSmall())
                            .foregroundStyle(.textTertiary)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(Color.textTertiary.opacity(0.1))
                            )
                    }
                    .disabled(viewModel.isStreaming)
                    .opacity(viewModel.isStreaming ? 0.5 : 1)
                }
            }
        }
        .padding(.horizontal, DS.Spacing.lg)
        .padding(.vertical, DS.Spacing.sm)
        .background(Color.themeCardBackground)
    }
    
    // MARK: - Remaining Messages Badge
    
    // ─── STORE (3): Badge shows credits when daily quota exhausted ───
    private var remainingBadge: some View {
        let remaining = viewModel.remainingMessages
        let limit = viewModel.dailyLimit
        let credits = store.aiCredits
        
        return Group {
            if remaining <= 0 && credits > 0 {
                Text("\(credits) credits left")
                    .font(DS.Typography.captionMedium()) // was .rounded
                    .foregroundStyle(.accentPrimary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.accentPrimary.opacity(0.1))
                    )
            } else {
                Text("\(remaining)/\(limit)")
                    .font(DS.Typography.captionMedium()) // was .rounded
                    .foregroundStyle(remaining <= 3 ? .orange : .textTertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(remaining <= 3 ? Color.orange.opacity(0.1) : Color.textTertiary.opacity(0.08))
                    )
            }
        }
    }
    
    // MARK: - Messages Area
    
    private var messagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: DS.Spacing.xl) {
                    if viewModel.messages.isEmpty {
                        welcomeView
                            .padding(.top, 40)
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
                    }
                    
                    ForEach(viewModel.messages) { message in
                        if message.isRateLimit {
                            rateLimitBanner
                                .id(message.id)
                        } else {
                            MessageBubble(
                                message: message,
                                colorScheme: colorScheme,
                                isStreaming: viewModel.isStreaming && message.id == viewModel.messages.last?.id && message.role == "assistant",
                                onRetry: message.isError ? {
                                    Task { await viewModel.retryLast() }
                                } : nil
                            )
                            .id(message.id)
                            .transition(.asymmetric(
                                insertion: .opacity.combined(with: .move(edge: .bottom)),
                                removal: .opacity
                            ))
                        }
                    }
                    
                    if viewModel.isLoading && !viewModel.isStreaming {
                        typingIndicator
                            .id("typing")
                            .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                    
                    Color.clear.frame(height: 8)
                        .id("bottom")
                }
                .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
                .padding(.top, DS.Spacing.md)
                .constrainedWidth(.readable)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: viewModel.messages.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: viewModel.isLoading) { _, loading in
                if loading { scrollToBottom(proxy) }
            }
            .onChange(of: viewModel.streamingContent) { _, _ in
                if viewModel.isStreaming {
                    scrollToBottom(proxy)
                }
            }
        }
    }
    
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.25)) {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
    
    // MARK: - Rate Limit Banner
    
    // ─── STORE (4): Banner has Upgrade + Buy Credits buttons ───
    private var rateLimitBanner: some View {
        let limit = viewModel.dailyLimit
        let credits = store.aiCredits
        
        return VStack(spacing: DS.Spacing.md) {
            Image(systemName: "moon.zzz.fill")
                .font(DS.Typography.displayMedium())
                .foregroundStyle(.statusWarning)
            
            Text("daily_limit_reached")
                .font(DS.Typography.heading())
                .foregroundStyle(.textPrimary)
            
            if credits > 0 {
                Text(AppStrings.dailyLimitUsedWithCredits(limit, credits))
                    .font(DS.Typography.bodySmall())
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            } else {
                Text(AppStrings.dailyLimitUsed(limit))
                    .font(DS.Typography.bodySmall())
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
                
                HStack(spacing: DS.Spacing.md) {
                    if !store.tier.isPremium {
                        Button {
                            store.showPaywall = true
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "crown.fill")
                                    .font(.caption2)
                                Text("upgrade")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.textOnAccent)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(Capsule().fill(Color.accentPrimary))
                        }
                    }
                    
                    Button {
                        store.showCreditsPurchase = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.caption2)
                            Text("buy_credits")
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundStyle(.accentPrimary)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Capsule().fill(Color.accentPrimary.opacity(0.1)))
                    }
                }
            }
        }
        .padding(.vertical, DS.Spacing.xl)
        .padding(.horizontal, DS.Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .fill(Color.orange.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.xl)
                        .stroke(Color.orange.opacity(0.12), lineWidth: 0.5)
                )
        )
    }
    
    // MARK: - Welcome View
    
    private var welcomeView: some View {
        let remaining = viewModel.remainingMessages
        let limit = viewModel.dailyLimit
        
        return VStack(spacing: DS.Spacing.xl) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.accentPrimary.opacity(0.12),
                                Color.purple.opacity(0.08)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: DS.IconContainer.xl, height: DS.IconContainer.xl)
                
                Image("samy")
                    .resizable()
                    .scaledToFit()
                    .frame(width: DS.IconSize.xl, height: DS.IconSize.xl)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color.accentPrimary, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            
            VStack(spacing: DS.Spacing.sm) {
                Text("MAI")
                    .font(DS.Typography.displayMedium())
                    .foregroundStyle(.textPrimary)
            }
            
            VStack(spacing: DS.Spacing.sm) {
                suggestionChip("What are my tasks for today?", icon: "checkmark.circle")
            }
            .padding(.top, DS.Spacing.sm)
            
            Text("\(remaining) of \(limit) messages remaining today")
                .font(DS.Typography.badge())
                .foregroundStyle(.textTertiary)
        }
    }
    
    private func suggestionChip(_ text: String, icon: String) -> some View {
        Button {
            Task {
                inputText = ""
                await viewModel.sendMessageAuto(text)
            }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: icon)
                    .font(DS.Typography.labelSmall())
                    .foregroundStyle(.accentPrimary)
                
                Text(text)
                    .font(DS.Typography.bodySmall())
                    .foregroundStyle(.textPrimary)
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(Color.themeCardBackground)
                    .shadow(
                        color: .black.opacity(colorScheme == .dark ? 0.15 : 0.04),
                        radius: 2, y: 1
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(Color.textTertiary.opacity(0.08), lineWidth: 0.5)
            )
        }
        .disabled(viewModel.isLimitReached || viewModel.isStreaming)
        .opacity(viewModel.isLimitReached ? 0.5 : 1)
    }
    
    // MARK: - Typing Indicator
    
    private var typingIndicator: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            assistantAvatar
            
            HStack(spacing: 5) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.textTertiary.opacity(0.5))
                        .frame(width: 6, height: 6)
                        .scaleEffect(viewModel.isLoading ? 1.0 : 0.5)
                        .animation(
                            .easeInOut(duration: 0.5)
                            .repeatForever()
                            .delay(Double(i) * 0.15),
                            value: viewModel.isLoading
                        )
                }
            }
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.sm + 2)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.themeCardBackground)
                    .shadow(
                        color: .black.opacity(colorScheme == .dark ? 0.15 : 0.04),
                        radius: 2, y: 1
                    )
            )
            
            Spacer(minLength: 60)
        }
    }
    
    // MARK: - Input Bar
    
    // ─── STORE (5): Input bar shows credit indicator + upgrade/credits buttons when blocked ───
    private var inputBar: some View {
        let hasCredits = store.aiCredits > 0
        let effectivelyBlocked = viewModel.isLimitReached && !hasCredits
        
        return VStack(spacing: 0) {
            Divider()
            
            // Credit usage indicator
            if viewModel.isLimitReached && hasCredits {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "bolt.fill")
                        .font(DS.Typography.bodySmall())
                        .foregroundStyle(.accentPrimary)
                    
                    Text(AppStrings.usingCreditsRemaining(store.aiCredits))
                        .font(DS.Typography.bodySmall())
                        .foregroundStyle(.textSecondary)
                    
                    Spacer()
                    
                    Button {
                        store.showCreditsPurchase = true
                    } label: {
                        Text("getMore")
                            .font(.caption)
                            .foregroundStyle(.accentPrimary)
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.xs)
                .background(Color.accentPrimary.opacity(0.05))
            }
            
            if effectivelyBlocked {
                // Fully blocked — no daily left + no credits
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "moon.zzz.fill")
                        .font(DS.Typography.body())
                        .foregroundStyle(.statusWarning)
                    
                    Text("dailyLimitResets")
                        .font(DS.Typography.bodySmall())
                        .foregroundStyle(.textSecondary)
                    
                    Spacer()
                    
                    HStack(spacing: DS.Spacing.xs) {
                        if !store.tier.isPremium {
                            Button {
                                store.showPaywall = true
                            } label: {
                                Text("upgrade")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.textOnAccent)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 5)
                                    .background(Capsule().fill(Color.accentPrimary))
                            }
                        }
                        
                        Button {
                            store.showCreditsPurchase = true
                        } label: {
                            HStack(spacing: 2) {
                                Image(systemName: "bolt.fill")
                                    .font(DS.Typography.micro())
                                Text("credits")
                                    .font(.caption2)
                                    .fontWeight(.semibold)
                            }
                            .foregroundStyle(.accentPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.accentPrimary.opacity(0.1)))
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.md)
                .background(Color.themeCardBackground)
            } else {
                // Normal input
                HStack(alignment: .bottom, spacing: DS.Spacing.sm) {
                    TextField("messagePlaceholder", text: $inputText, axis: .vertical)
                        .font(DS.Typography.body())
                        .lineLimit(1...5)
                        .padding(.horizontal, DS.Spacing.md)
                        .padding(.vertical, 10)
                        .focused($isInputFocused)
                        .submitLabel(.send)
                        .onSubmit { sendMessage() }
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(chatBackground)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .stroke(
                                    isInputFocused
                                    ? Color.accentPrimary.opacity(0.3)
                                    : Color.textTertiary.opacity(0.1),
                                    lineWidth: isInputFocused ? 1.5 : 0.5
                                )
                        )
                        .disabled(viewModel.isStreaming)
                    
                    Button {
                        if viewModel.isStreaming {
                            viewModel.cancelStreaming()
                        } else {
                            sendMessage()
                        }
                    } label: {
                        Image(systemName: viewModel.isStreaming ? "stop.fill" : "arrow.up")
                            .font(DS.Typography.label())
                            .foregroundStyle(.textOnAccent)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(
                                        viewModel.isStreaming
                                        ? Color.red
                                        : (canSend ? Color.accentPrimary : Color.textTertiary.opacity(0.2))
                                    )
                            )
                    }
                    .disabled(!canSend && !viewModel.isStreaming)
                    .animation(.easeInOut(duration: 0.15), value: canSend)
                    .animation(.easeInOut(duration: 0.15), value: viewModel.isStreaming)
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(Color.themeCardBackground)
            }
        }
    }
    
    // MARK: - Helpers
    
    // ─── STORE (6): canSend allows sending when credits available ───
    private var canSend: Bool {
        let hasText = !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let notBusy = !viewModel.isLoading
        let hasQuota = !viewModel.isLimitReached || store.aiCredits > 0
        return hasText && notBusy && hasQuota
    }
    
    private func sendMessage() {
        let text = inputText
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        inputText = ""
        Task { await viewModel.sendMessageAuto(text) }
    }
    
    private var assistantAvatar: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.accentPrimary.opacity(0.12), .purple.opacity(0.08)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            Image("samy")
                .resizable()
                .scaledToFit()
                .frame(width: DS.IconSize.md, height: DS.IconSize.md)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentPrimary, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .frame(width: 26, height: 26)
    }
}

// MARK: - Streaming Dot Indicator

struct StreamingDot: View {
    @State private var isAnimating = false
    
    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 8, height: 8)
            .opacity(isAnimating ? 1 : 0.4)
            .animation(
                .easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear { isAnimating = true }
    }
}

// MARK: - Streaming Cursor

struct StreamingCursor: View {
    @State private var isVisible = true
    
    var body: some View {
        Text("▊")
            .font(DS.Typography.body())
            .foregroundStyle(.accentPrimary)
            .opacity(isVisible ? 0.8 : 0)
            .animation(
                .easeInOut(duration: 0.5).repeatForever(autoreverses: true),
                value: isVisible
            )
            .onAppear { isVisible = true }
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: ChatMessage
    let colorScheme: ColorScheme
    var isStreaming: Bool = false
    var onRetry: (() -> Void)? = nil
    
    private var isUser: Bool { message.role == "user" }
    
    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            if isUser { Spacer(minLength: 60) }
            
            if !isUser {
                ZStack {
                    Circle()
                        .fill(
                            LinearGradient(
                                colors: message.isError
                                ? [.orange.opacity(0.12)]
                                : [Color.accentPrimary.opacity(0.12), .purple.opacity(0.08)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    
                    if message.isError {
                        Image(systemName: "exclamationmark.triangle")
                            .font(DS.Typography.micro())
                            .foregroundStyle(.statusWarning)
                    } else {
                        Image("samy")
                            .resizable()
                            .scaledToFit()
                            .frame(width: DS.IconSize.sm, height: DS.IconSize.sm)
                    }
                }
                .frame(width: 26, height: 26)
                .padding(.top, 2)
            }
            
            VStack(alignment: isUser ? .trailing : .leading, spacing: DS.Spacing.xs) {
                HStack(alignment: .bottom, spacing: 0) {
                    Text(message.content.isEmpty && isStreaming ? " " : message.content)
                        .font(DS.Typography.body())
                        .foregroundStyle(isUser ? .textOnAccent : (message.isError ? .textSecondary : .textPrimary))
                        .textSelection(.enabled)
                    
                    if isStreaming && !isUser {
                        StreamingCursor()
                    }
                }
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm + 2)
                .background(bubbleBackground)
                
                if message.isError, let onRetry {
                    Button(action: onRetry) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(DS.Typography.micro())
                            Text("retry")
                                .font(DS.Typography.badge())
                        }
                        .foregroundStyle(.accentPrimary)
                        .padding(.horizontal, DS.Spacing.sm)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.accentPrimary.opacity(0.08))
                        )
                    }
                }
                
                if !isStreaming {
                    Text(message.timestamp, style: .time)
                        .font(DS.Typography.micro())
                        .foregroundStyle(.textTertiary)
                }
            }
            
            if !isUser { Spacer(minLength: 60) }
        }
    }
    
    @ViewBuilder
    private var bubbleBackground: some View {
        if isUser {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.accentPrimary)
        } else if message.isError {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.orange.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(Color.orange.opacity(0.15), lineWidth: 0.5)
                )
        } else {
            RoundedRectangle(cornerRadius: 18)
                .fill(Color.themeCardBackground)
                .shadow(
                    color: .black.opacity(colorScheme == .dark ? 0.2 : 0.05),
                    radius: 2, y: 1
                )
        }
    }
}

#Preview {
    AIChatView(onBack: {})
        .environment(AuthViewModel())
        .environment(SubscriptionManager())
}
