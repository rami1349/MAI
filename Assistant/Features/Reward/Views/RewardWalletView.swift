//
//  RewardWalletView.swift
//  FamilyHub
//
//  UNICORN REDESIGN - Unified Reward System
//
//  INDIVIDUAL PAYOUT REQUESTS:
//  - Request payout → Targets specific person
//  - Each request is independent per assigner
//

import SwiftUI

struct RewardWalletView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    @Environment(RewardViewModel.self) var rewardVM
    @Environment(NotificationViewModel.self) var notificationVM
    
    private var currentUser: FamilyUser? { authViewModel.currentUser }
    private var myId: String { currentUser?.id ?? "" }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.themeSurfacePrimary
                    .ignoresSafeArea()
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: DS.Spacing.xl) {
                        balanceCard
                        
                        if !requestsToMe.isEmpty {
                            payoutRequestsSection
                        }
                        
                        if !whoOwesYou.isEmpty {
                            whoOwesYouSection
                        }
                        
                        if !recentEarnings.isEmpty {
                            recentEarningsSection
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.horizontal, DS.Spacing.screenH)
                    .padding(.top, DS.Spacing.lg)
                }
            }
            .navigationTitle(L10n.rewardWallet)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.close) { dismiss() }
                        .foregroundStyle(Color.textSecondary)
                }
            }
        }
    }
    
    // MARK: - Computed Data
    
    private var balance: Double { currentUser?.balance ?? 0 }
    
    private var recentEarnings: [RewardTransaction] {
        rewardVM.transactions
            .filter { $0.userId == myId && $0.amount > 0 }
            .prefix(5)
            .map { $0 }
    }
    
    private var totalTasksCompleted: Int {
        rewardVM.transactions.filter { $0.userId == myId && $0.amount > 0 }.count
    }
    
    private var whoOwesYou: [OwedByPerson] {
        let earnings = rewardVM.transactions.filter { $0.userId == myId && $0.amount > 0 }
        
        var earningsByAssigner: [String: Double] = [:]
        for earning in earnings {
            earningsByAssigner[earning.createdBy, default: 0] += earning.amount
        }
        
        let totalEarned = earningsByAssigner.values.reduce(0, +)
        let remainingBalance = balance
        
        var pendingByTarget: [String: Bool] = [:]
        for request in rewardVM.pendingWithdrawals where request.userId == myId {
            if let targetId = parseTargetId(from: request.note) {
                pendingByTarget[targetId] = true
            }
        }
        
        var result: [OwedByPerson] = []
        for (assignerId, earned) in earningsByAssigner {
            guard assignerId != myId else { continue }
            
            let proportion = totalEarned > 0 ? earned / totalEarned : 0
            let owedAmount = remainingBalance * proportion
            
            guard owedAmount > 0.5 else { continue }
            
            let member = familyMemberVM.familyMembers.first { $0.id == assignerId }
            
            result.append(OwedByPerson(
                odId: assignerId,
                userName: member?.displayName ?? L10n.someone,
                user: member,
                amount: owedAmount,
                hasPendingRequest: pendingByTarget[assignerId] == true
            ))
        }
        
        return result.sorted { $0.amount > $1.amount }
    }
    
    private var requestsToMe: [WithdrawalRequest] {
        rewardVM.pendingWithdrawals.filter { request in
            guard request.userId != myId else { return false }
            if let targetId = parseTargetId(from: request.note) {
                return targetId == myId
            }
            return false
        }
    }
    
    private var pendingRequestsFromMe: [WithdrawalRequest] {
        rewardVM.pendingWithdrawals.filter { $0.userId == myId }
    }
    
    private func parseTargetId(from note: String?) -> String? {
        guard let note = note, note.hasPrefix("target:") else { return nil }
        let content = String(note.dropFirst(7))
        if let pipeIndex = content.firstIndex(of: "|") {
            return String(content[..<pipeIndex])
        }
        return content
    }
    
    // MARK: - Balance Card
    
    private var balanceCard: some View {
        VStack(spacing: DS.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.2))
                    .frame(width: 64, height: 64)
                Text("💰")
                    .font(DS.Typography.displayMedium())
            }
            
            VStack(spacing: DS.Spacing.xs) {
                Text("\(Int(balance))")
                    .font(DS.Typography.displayLarge()) // was .rounded
                    .foregroundStyle(.white)
                
                if totalTasksCompleted > 0 {
                    Text(L10n.earnedFromTasks(totalTasksCompleted))
                        .font(DS.Typography.body())
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            
            if !pendingRequestsFromMe.isEmpty {
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "clock.fill")
                        .font(DS.Typography.bodySmall())
                    Text(L10n.payoutRequested)
                        .font(DS.Typography.caption())
                }
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, DS.Spacing.md)
                .padding(.vertical, DS.Spacing.sm)
                .background(Capsule().fill(Color.white.opacity(0.2)))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xxl)
        .padding(.horizontal, DS.Spacing.xl)
        .background(
            LinearGradient(
                colors: [Color.accentPrimary, Color.accentPrimary.opacity(0.8)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xxl))
    }
    
    // MARK: - Payout Requests TO You
    
    private var payoutRequestsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Image(systemName: "bell.badge.fill")
                   .foregroundStyle(Color.accentOrange)
                Text(L10n.payoutRequestsToYou)
                    .font(DS.Typography.subheading())
                    .foregroundStyle(Color.textPrimary)
                
                Spacer()
                
                Text("\(requestsToMe.count)")
                    .font(DS.Typography.badge())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.accentOrange))
            }
            
            VStack(spacing: DS.Spacing.md) {
                ForEach(requestsToMe) { request in
                    PayoutRequestCard(request: request)
                }
            }
        }
    }
    
    // MARK: - Who Owes You
    
    private var whoOwesYouSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            Text(L10n.whoOwesYou)
                .font(DS.Typography.subheading())
                .foregroundStyle(Color.textPrimary)
            
            VStack(spacing: DS.Spacing.md) {
                ForEach(whoOwesYou, id: \.odId) { owed in
                    WhoOwesYouCard(owed: owed)
                }
            }
        }
    }
    
    // MARK: - Recent Earnings
    
    private var recentEarningsSection: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.sm) {
                Text("🎉")
                    .font(DS.Typography.heading())
                Text(L10n.recentEarnings)
                    .font(DS.Typography.subheading())
                    .foregroundStyle(Color.textPrimary)
            }
            
            VStack(spacing: 0) {
                ForEach(Array(recentEarnings.enumerated()), id: \.element.id) { index, transaction in
                    if index > 0 {
                        Divider().padding(.leading, 48)
                    }
                    EarningRow(transaction: transaction)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .fill(Color.themeCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(Color.themeCardBorder, lineWidth: 0.5)
            )
        }
    }
}

// MARK: - Data Model

private struct OwedByPerson {
    let odId: String
    let userName: String
    let user: FamilyUser?
    let amount: Double
    let hasPendingRequest: Bool
}

// MARK: - Earning Row

private struct EarningRow: View {
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    let transaction: RewardTransaction
    
    private var assignerName: String {
        if let member = familyMemberVM.familyMembers.first(where: { $0.id == transaction.createdBy }) {
            return member.displayName.components(separatedBy: " ").first ?? member.displayName
        }
        return transaction.createdByName.components(separatedBy: " ").first ?? transaction.createdByName
    }
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.accentGreen.opacity(0.1))
                    .frame(width: 36, height: 36)
                Image(systemName: "plus")
                    .font(DS.Typography.label())
                    .foregroundStyle(Color.accentGreen)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.description)
                    .font(DS.Typography.body())
                    .foregroundStyle(Color.textPrimary)
                    .lineLimit(1)
                
                Text(L10n.fromPerson(assignerName))
                    .font(DS.Typography.caption())
                    .foregroundStyle(Color.textTertiary)
            }
            
            Spacer()
            
            Text("+\(Int(transaction.amount))")
                .font(DS.Typography.body())
                .fontWeight(.semibold)
                .foregroundStyle(Color.accentGreen)
        }
        .padding(DS.Spacing.md)
    }
}

// MARK: - Who Owes You Card

private struct WhoOwesYouCard: View {
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(RewardViewModel.self) var rewardVM
    @Environment(NotificationViewModel.self) var notificationVM // ✅ Added
    
    let owed: OwedByPerson
    
    @State private var isRequesting = false
    @State private var showSuccess = false
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            if let user = owed.user {
                AvatarView(user: user, size: 44)
            } else {
                Circle()
                    .fill(Color.textTertiary.opacity(0.2))
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(Color.textTertiary)
                    )
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(owed.userName)
                    .font(DS.Typography.body())
                    .fontWeight(.medium)
                    .foregroundStyle(Color.textPrimary)
                
                Text(L10n.owesYou)
                    .font(DS.Typography.caption())
                    .foregroundStyle(Color.textSecondary)
            }
            
            Spacer()
            
            Text("\(Int(owed.amount))")
                .font(DS.Typography.heading()) // was .rounded
                .foregroundStyle(Color.accentGreen)
            
            if owed.hasPendingRequest || showSuccess {
                Text(L10n.requested)
                    .font(DS.Typography.micro())
                   .foregroundStyle(Color.accentOrange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentOrange.opacity(0.12)))
            } else {
                Button(action: requestPayout) {
                    if isRequesting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(Color.accentPrimary)
                    } else {
                        Image(systemName: "hand.wave.fill")
                            .font(DS.Typography.body())
                            .foregroundStyle(Color.accentPrimary)
                    }
                }
                .frame(width: 36, height: 36)
                .background(Circle().fill(Color.accentPrimary.opacity(0.1)))
                .disabled(isRequesting)
            }
        }
        .padding(DS.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.themeCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(Color.themeCardBorder, lineWidth: 0.5)
        )
    }
    
    private func requestPayout() {
        guard let user = authViewModel.currentUser,
              let familyId = user.familyId,
              let odId = user.id else { return }
        
        isRequesting = true
        let targetNote = "target:\(owed.odId)|\(owed.userName)"
        
        Task {
            await rewardVM.requestWithdrawal(
                familyId: familyId,
                userId: odId,
                userName: user.displayName,
                amount: owed.amount,
                note: targetNote
            )
            
            await notificationVM.notifyPayoutRequested(
                requesterId: odId,
                requesterName: user.displayName,
                targetId: owed.odId,
                amount: owed.amount,
                familyId: familyId
            )
            
            isRequesting = false
            showSuccess = true
            DS.Haptics.success()
        }
    }
}

// MARK: - Payout Request Card

private struct PayoutRequestCard: View {
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    @Environment(RewardViewModel.self) var rewardVM
    @Environment(NotificationViewModel.self) var notificationVM // ✅ Added
    
    let request: WithdrawalRequest
    
    @State private var isPaying = false
    @State private var showSuccess = false
    
    private var requester: FamilyUser? {
        familyMemberVM.familyMembers.first { $0.id == request.userId }
    }
    
    private var relativeDate: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(request.createdAt) {
            return L10n.today
        } else if calendar.isDateInYesterday(request.createdAt) {
            return L10n.yesterday
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return formatter.string(from: request.createdAt)
        }
    }
    
    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            HStack(spacing: DS.Spacing.md) {
                if let user = requester {
                    AvatarView(user: user, size: 48)
                } else {
                    Circle()
                        .fill(Color.textTertiary.opacity(0.2))
                        .frame(width: 48, height: 48)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundStyle(Color.textTertiary)
                        )
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(request.userName)
                        .font(DS.Typography.body())
                        .fontWeight(.medium)
                        .foregroundStyle(Color.textPrimary)
                    
                    Text(L10n.requestedPayout)
                        .font(DS.Typography.caption())
                        .foregroundStyle(Color.textSecondary)
                    
                    Text(relativeDate)
                        .font(DS.Typography.micro())
                        .foregroundStyle(Color.textTertiary)
                }
                
                Spacer()
                
                Text("\(Int(request.amount))")
                    .font(DS.Typography.displayMedium()) // was .rounded
                   .foregroundStyle(Color.accentOrange)
            }
            
            Button(action: payOut) {
                HStack(spacing: DS.Spacing.sm) {
                    if isPaying {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else if showSuccess {
                        Image(systemName: "checkmark")
                            .font(DS.Typography.label())
                        Text(L10n.paid)
                    } else {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(DS.Typography.body())
                        Text(L10n.payAmount("\(Int(request.amount))"))
                    }
                }
                .font(DS.Typography.label())
                .fontWeight(.semibold)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, DS.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.lg)
                        .fill(showSuccess ? Color.accentGreen : Color.accentPrimary)
                )
            }
            .buttonStyle(.plain)
            .disabled(isPaying || showSuccess)
        }
        .padding(DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .fill(Color.themeCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.lg)
                .stroke(Color.accentOrange.opacity(0.3), lineWidth: 1.5)
        )
    }
    
    private func payOut() {
        guard let payerId = authViewModel.currentUser?.id,
              let payerName = authViewModel.currentUser?.displayName else { return }
        
        isPaying = true
        
        Task {
            await rewardVM.approveWithdrawal(
                request,
                reviewerId: payerId,
                reviewerName: payerName
            )
            
    
            await notificationVM.notifyPayoutApproved(
                requesterId: request.userId,
                payerName: payerName,
                amount: request.amount,
                familyId: request.familyId
            )
            
            isPaying = false
            showSuccess = true
            DS.Haptics.success()
        }
    }
}

// MARK: - Preview

#Preview {
    RewardWalletView()
        .environment(AuthViewModel())
        .environment({ let vm = FamilyViewModel(); return vm.familyMemberVM }())
        .environment({ let vm = FamilyViewModel(); return vm.rewardVM }())
        .environment({ let vm = FamilyViewModel(); return vm.notificationVM }())
}
