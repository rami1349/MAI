//
//  RewardViewModel.swift
//
//
//  Manages reward transactions (ledger) and withdrawal requests.
//  Handles: transaction history, manual rewards, withdrawal lifecycle.
//  #SOUND: Plays sounds on reward payouts and withdrawal approvals
//

import Foundation
import Observation
import FirebaseFirestore
import FirebaseFunctions
import os

@MainActor
@Observable
final class RewardViewModel {
    // MARK: - Published State
    private(set) var transactions: [RewardTransaction] = []
    private(set) var pendingWithdrawals: [WithdrawalRequest] = []
    private(set) var allWithdrawals: [WithdrawalRequest] = []
    private(set) var isLoading = false
    var errorMessage: String?
    
    // MARK: - Private
    private var db: Firestore { Firestore.firestore() }
    @ObservationIgnored private let functions = Functions.functions(region: "us-west1")
    @ObservationIgnored private var transactionListener: ListenerRegistration?
    @ObservationIgnored private var withdrawalListener: ListenerRegistration?
    
    deinit {
        transactionListener?.remove()
        withdrawalListener?.remove()
    }
    
    // MARK: - Setup Listeners
    
    func setupListeners(familyId: String) {
        setupTransactionListener(familyId: familyId)
        setupWithdrawalListener(familyId: familyId)
    }
    
    private func setupTransactionListener(familyId: String) {
        transactionListener?.remove()
        
        transactionListener = db.collection("rewardTransactions")
            .whereField("familyId", isEqualTo: familyId)
            .order(by: "createdAt", descending: true)
            .limit(to: 100)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let docs = snapshot?.documents else { return }
                Task { @MainActor in
                    self.transactions = await FirestoreDecode.documents(docs, as: RewardTransaction.self)
                }
            }
    }
    
    private func setupWithdrawalListener(familyId: String) {
        withdrawalListener?.remove()
        
        withdrawalListener = db.collection("withdrawalRequests")
            .whereField("familyId", isEqualTo: familyId)
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let docs = snapshot?.documents else { return }
                Task { @MainActor in
                    let all = await FirestoreDecode.documents(docs, as: WithdrawalRequest.self)
                    self.allWithdrawals = all
                    self.pendingWithdrawals = all.filter { $0.status == .pending }
                }
            }
    }
    
    // MARK: - Transaction History
    
    /// Returns transactions where the user received a reward OR assigned the rewarded task.
    func transactionsFor(userId: String) -> [RewardTransaction] {
        transactions.filter { $0.userId == userId || $0.createdBy == userId }
    }
    
    /// Returns pending withdrawals that a parent needs to review.
    func pendingWithdrawalsForReview(excludingUserId: String) -> [WithdrawalRequest] {
        pendingWithdrawals.filter { $0.userId != excludingUserId }
    }
    
    /// Returns withdrawal history for a specific user.
    func withdrawalsFor(userId: String) -> [WithdrawalRequest] {
        allWithdrawals.filter { $0.userId == userId }
    }
    
    // MARK: - Record Task Reward (via Cloud Function)
    
    /// Called when a task with reward is completed (from TaskViewModel).
    /// Records the transaction in the ledger via Cloud Function.
    ///
    /// C-6 FIX: rewardTransactions are now write-protected by Firestore Security Rules.
    /// Only Cloud Functions (admin SDK) can create ledger entries.
    func recordTaskReward(
        familyId: String,
        userId: String,
        amount: Double,
        taskTitle: String,
        taskId: String?,
        createdBy: String,
        createdByName: String,
        recipientName: String
    ) async {
        do {
            let _ = try await functions.httpsCallable("recordRewardPayout").call([
                "familyId": familyId,
                "userId": userId,
                "amount": amount,
                "taskTitle": taskTitle,
                "taskId": taskId ?? "",
                "createdBy": createdBy,
                "createdByName": createdByName,
                "recipientName": recipientName
            ] as [String: Any])
        } catch {
            Log.rewards.error("Failed to record task reward: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Withdrawal Requests
    
    /// Parent pays out a member's balance (full or partial) via Cloud Function.
    ///
    /// C-6 FIX: Balance deductions and ledger entries are now performed server-side.
    /// The Cloud Function validates:
    ///   - Caller is adult/admin in the same family
    ///   - Target member has sufficient balance
    ///   - Amount is positive and within limits
    func payOut(
        familyId: String,
        member: FamilyUser,
        amount: Double,
        note: String?,
        paidBy: String,
        paidByName: String
    ) async {
        guard let memberId = member.id else { return }
        
        do {
            let _ = try await functions.httpsCallable("pay_out_member").call([
                "memberId": memberId,
                "amount": amount,
                "note": note ?? "Paid out by \(paidByName)"
            ] as [String: Any])
            
            // #SOUND: Play success sound for the payer
            SoundManager.shared.playRewardEarned()
        } catch {
            Log.rewards.error("PayOut failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }
    
    /// Child submits a withdrawal request.
    func requestWithdrawal(
        familyId: String,
        userId: String,
        userName: String,
        amount: Double,
        note: String?
    ) async {
        let request = WithdrawalRequest(
            familyId: familyId,
            userId: userId,
            userName: userName,
            amount: amount,
            note: note,
            status: .pending,
            createdAt: Date()
        )
        
        do {
            try db.collection("withdrawalRequests").addDocument(from: request)
            
            // #SOUND: Subtle confirmation for the requester
            SoundManager.shared.playConfirm()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Parent approves a withdrawal request via Cloud Function.
    ///
    /// C-6 FIX: The Cloud Function validates:
    ///   - Request is still pending
    ///   - Caller is not the requester (can't self-approve)
    ///   - Caller is adult/admin in the same family
    ///   - Target user has sufficient balance
    /// Atomically: updates request status + deducts balance + writes ledger entry.
    func approveWithdrawal(
        _ request: WithdrawalRequest,
        reviewerId: String,
        reviewerName: String
    ) async {
        guard let id = request.id else { return }
        
        do {
            let _ = try await functions.httpsCallable("approve_withdrawal").call([
                "requestId": id
            ])
            
            // #SOUND: Play success sound for the approver
            SoundManager.shared.playTaskCompleted()
        } catch {
            Log.rewards.error("Approve withdrawal failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }
    
    /// Parent rejects a withdrawal request via Cloud Function.
    ///
    /// C-6 FIX: Status update goes through Cloud Function to prevent
    /// a user from rejecting their own request or modifying status directly.
    func rejectWithdrawal(
        _ request: WithdrawalRequest,
        reviewerId: String,
        reviewerName: String,
        reason: String?
    ) async {
        guard let id = request.id else { return }
        
        do {
            let _ = try await functions.httpsCallable("reject_withdrawal").call([
                "requestId": id,
                "reason": reason ?? ""
            ] as [String: Any])
            
            // #SOUND: Subtle confirmation for rejection
            SoundManager.shared.playConfirm()
        } catch {
            Log.rewards.error("Reject withdrawal failed: \(error.localizedDescription, privacy: .public)")
            errorMessage = error.localizedDescription
        }
    }
}
