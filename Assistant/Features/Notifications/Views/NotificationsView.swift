//
//  NotificationsView.swift
//  FamilyHub
//
//  Notifications list with swipe-to-delete
//

import SwiftUI

struct NotificationsView: View {
    @Environment(\.dismiss) var dismiss

    @Environment(NotificationViewModel.self) var notificationVM
    
    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackgroundView()
                
                if notificationVM.notifications.isEmpty {
                    emptyState
                } else {
                    notificationsList
                }
            }
            .navigationTitle(L10n.notifications)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack(spacing: DS.Spacing.sm) {
                        Button(L10n.done) { dismiss() }
                        
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !notificationVM.notifications.isEmpty {
                        Menu {
                            Button {
                                Task { await notificationVM.markAllAsRead() }
                            } label: {
                                Label(L10n.markAllRead, systemImage: "checkmark.circle")
                            }
                            
                            Button(role: .destructive) {
                                Task { await notificationVM.deleteAll() }
                            } label: {
                                Label(L10n.deleteAll, systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        EmptyStateView(
            icon: "bell.slash",
            title: L10n.noNotifications,
            message: L10n.noNotificationsMessage
        )
    }
    
    private var notificationsList: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: DS.Spacing.md) {
                ForEach(notificationVM.notifications) { notification in
                    NotificationCardView(notification: notification)
                        .swipeToDelete {
                            Task { await notificationVM.delete(notification) }
                        }
                        .onTapGesture {
                            Task { await notificationVM.markAsRead(notification) }
                        }
                }
            }
            .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
            .padding(.vertical, DS.Spacing.md)
            .constrainedWidth(.card)
        }
    }
}

// MARK: - Notification Card View
struct NotificationCardView: View {
    let notification: FamilyNotification
    
    private var icon: String {
        switch notification.type {
        case .taskAssigned: return "list.bullet.clipboard"
        case .taskCompleted: return "checkmark.circle"
        case .taskDeleted: return "trash"
        case .proofSubmitted: return "camera.fill"
        case .proofVerified: return "checkmark.seal"
        case .rewardReceived: return "dollarsign.circle"
        case .reminder: return "bell"
        case .familyInvite: return "person.badge.plus"
        case .eventCreated: return "calendar.badge.plus"
        case .taskOverdue: return "exclamationmark.triangle"
        case .dailySummary: return "chart.bar.doc.horizontal"
        case .eventUpdated: return "pencil"
        case .eventCanceled: return "trash"
        }
    }
    
    private var iconColor: Color {
        switch notification.type {
        case .taskAssigned: return Color.accentPrimary
        case .taskCompleted: return Color.statusCompleted
        case .taskDeleted: return Color.accentRed
        case .proofSubmitted: return Color.accentOrange
        case .proofVerified: return Color.accentGreen
        case .rewardReceived: return Color.accentGreen
        case .reminder: return Color.accentTertiary
        case .familyInvite: return Color.accentSecondary
        case .eventCreated: return Color.accentPrimary
        case .taskOverdue: return Color.accentRed
        case .dailySummary: return Color.accentTertiary
        case .eventUpdated: return Color.accentPrimary
        case .eventCanceled: return Color.accentRed
        }
    }
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: DS.IconContainer.lg, height: DS.IconContainer.lg)
                
                Image(systemName: icon)
                    .font(.system(size: DS.IconSize.md)) // DT-exempt: icon sizing
                    .foregroundStyle(iconColor)
            }
            
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(notification.title)
                    .font(.subheadline)
                    .fontWeight(notification.isRead ? .regular : .semibold)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                
                Text(notification.message)
                    .font(.caption)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(2)
                
                Text(notification.createdAt.timeAgo())
                    .font(.caption2)
                    .foregroundStyle(.textTertiary)
            }
            
            Spacer()
            
            if !notification.isRead {
                Circle()
                    .fill(Color.accentPrimary)
                    .frame(width: DS.IconSize.xs - 2, height: DS.IconSize.xs - 2)
            }
        }
        .padding(DS.Spacing.md + 2)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .fill(notification.isRead ? Color.backgroundCard : Color.backgroundCard)
                .overlay(
                    notification.isRead ? nil : RoundedRectangle(cornerRadius: DS.Radius.xl)
                        .fill(Color.accentPrimary.opacity(0.08))
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.xl)
                .stroke(notification.isRead ? Color.clear : Color.accentPrimary.opacity(0.2), lineWidth: 1)
        )
        .elevation1()
    }
}

#Preview {
    let familyVM = FamilyViewModel()
    NotificationsView()
        .environment(familyVM)
        .environment(familyVM.familyMemberVM)
        .environment(familyVM.taskVM)
        .environment(familyVM.calendarVM)
        .environment(familyVM.habitVM)
        .environment(familyVM.notificationVM)
}
