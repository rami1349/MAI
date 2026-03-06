//
//  SwipeToDeleteModifier.swift
//  FamilyHub
//
//  Generic swipe-to-delete modifier that can be applied to any view
//  Replaces 4 duplicate implementations (SwipeableTaskCard, SwipeableNotificationCard,
//  SwipeableHabitRow, SwipeableHabitCard)
//

import SwiftUI

// MARK: - Swipe Action Configuration
struct SwipeAction {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
}

// MARK: - Swipeable View Modifier
struct SwipeableModifier: ViewModifier {
    let leadingAction: SwipeAction?
    let trailingAction: SwipeAction?
    
    @State private var offset: CGFloat = 0
    @State private var isDeleting = false
    
    private let actionWidth: CGFloat = 80
    private let triggerThreshold: CGFloat = 100
    private let velocityThreshold: CGFloat = 500
    
    func body(content: Content) -> some View {
        ZStack {
            // Background actions
            HStack(spacing: 0) {
                // Leading action (swipe right)
                if let leading = leadingAction, offset > 0 {
                    actionButton(leading, width: offset)
                }
                
                Spacer()
                
                // Trailing action (swipe left)
                if let trailing = trailingAction, offset < 0 {
                    actionButton(trailing, width: abs(offset))
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
            
            // Main content
            content
                .offset(x: offset)
                .gesture(swipeGesture)
        }
        .opacity(isDeleting ? 0 : 1)
        .frame(height: isDeleting ? 0 : nil)
        .clipped()
        .animation(.spring(response: 0.3), value: isDeleting)
    }
    
    private func actionButton(_ action: SwipeAction, width: CGFloat) -> some View {
        Button {
            executeAction(action)
        } label: {
            ZStack {
                action.color
                VStack(spacing: 4) {
                    Image(systemName: action.icon)
                        .font(.title3)
                    Text(action.title)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .foregroundStyle(.textOnAccent)
            }
            .frame(width: max(actionWidth, width))
        }
    }
    
    private func executeAction(_ action: SwipeAction) {
        DS.Haptics.medium() // Haptic on swipe action trigger
        withAnimation(.spring(response: 0.3)) {
            offset = action.color == trailingAction?.color ? -500 : 500
            isDeleting = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(0.2))
            action.action()
        }
    }
    
    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                handleDragChanged(value)
            }
            .onEnded { value in
                handleDragEnded(value)
            }
    }
    
    private func handleDragChanged(_ value: DragGesture.Value) {
        let x = value.translation.width
        let y = value.translation.height
        
        // Only respond to horizontal swipes
        guard abs(x) > abs(y) else { return }
        
        // Haptic when crossing threshold
        let wasAboveThreshold = abs(offset) >= triggerThreshold
        
        if x > 0 && leadingAction != nil {
            withAnimation(.interactiveSpring()) {
                offset = min(150, x)
            }
        } else if x < 0 && trailingAction != nil {
            withAnimation(.interactiveSpring()) {
                offset = max(-150, x)
            }
        }
        
        // Trigger haptic when crossing threshold
        let isAboveThreshold = abs(offset) >= triggerThreshold
        if isAboveThreshold && !wasAboveThreshold {
            DS.Haptics.light()
        }
    }
    
    private func handleDragEnded(_ value: DragGesture.Value) {
        let velocity = value.predictedEndTranslation.width
        
        if let trailing = trailingAction, (offset < -triggerThreshold || velocity < -velocityThreshold) {
            executeAction(trailing)
        } else if let leading = leadingAction, (offset > triggerThreshold || velocity > velocityThreshold) {
            executeAction(leading)
        } else if offset < -50 && trailingAction != nil {
            withAnimation(.spring(response: 0.3)) { offset = -actionWidth }
        } else if offset > 50 && leadingAction != nil {
            withAnimation(.spring(response: 0.3)) { offset = actionWidth }
        } else {
            withAnimation(.spring(response: 0.3)) { offset = 0 }
        }
    }
}

// MARK: - View Extension
extension View {
    /// Makes the view swipeable with optional leading and trailing actions
    func swipeable(
        leading: SwipeAction? = nil,
        trailing: SwipeAction? = nil
    ) -> some View {
        modifier(SwipeableModifier(leadingAction: leading, trailingAction: trailing))
    }
    
    /// Convenience: swipe to delete only
    func swipeToDelete(action: @escaping () -> Void) -> some View {
        swipeable(trailing: SwipeAction(
            icon: "trash.fill",
            title: L10n.delete,
            color: Color.accentRed,
            action: action
        ))
    }
    
    /// Convenience: swipe to complete and delete
    func swipeToCompleteOrDelete(
        canComplete: Bool = true,
        onComplete: @escaping () -> Void,
        onDelete: @escaping () -> Void
    ) -> some View {
        swipeable(
            leading: canComplete ? SwipeAction(
                icon: "checkmark.circle.fill",
                title: L10n.done,
                color: Color.accentGreen,
                action: onComplete
            ) : nil,
            trailing: SwipeAction(
                icon: "trash.fill",
                title: L10n.delete,
                color: Color.accentRed,
                action: onDelete
            )
        )
    }
}

// MARK: - Preview
#Preview {
    VStack(spacing: 16) {
        // Delete only
        Text(L10n.swipeDeleteHint)
            .frame(maxWidth: .infinity)
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.backgroundCard))
            .swipeToDelete { print("Deleted") }
        
        // Complete and delete
        Text(L10n.swipeCompleteDeleteHint)
            .frame(maxWidth: .infinity)
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.backgroundCard))
            .swipeToCompleteOrDelete(
                onComplete: { print("Completed") },
                onDelete: { print("Deleted") }
            )
    }
    .padding()
    .background(Color.backgroundPrimary)
}
