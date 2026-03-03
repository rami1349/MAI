//
//  RewardViewModel.swift
//  FamilyHub
//
//  Manages reward transactions (ledger) and withdrawal requests.
//  Handles: transaction history, manual rewards, withdrawal lifecycle.
//  #SOUND: Plays sounds on reward payouts and withdrawal approvals
//

import Foundation
import Observation
import FirebaseFirestore

@MainActor
@Observable
class RewardViewModel {
    // MARK: - Published State
    private(set) var transactions: [RewardTransaction] = []
    private(set) var pendingWithdrawals: [WithdrawalRequest] = []
    private(set) var allWithdrawals: [WithdrawalRequest] = []
    private(set) var isLoading = false
    var errorMessage: String?
    
    // MARK: - Private
    @ObservationIgnored private var _db: Firestore?
    private var db: Firestore {
        if _db == nil { _db = Firestore.firestore() }
        return _db!
    }
    private var transactionListener: ListenerRegistration?
    private var withdrawalListener: ListenerRegistration?
    
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
    
    // MARK: - Record Task Reward
    
    /// Called when a task with reward is completed (from TaskViewModel).
    /// Records the transaction in the ledger.
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
        let transaction = RewardTransaction(
            familyId: familyId,
            userId: userId,
            amount: amount,
            type: .taskReward,
            status: .completed,
            description: taskTitle,
            taskId: taskId,
            createdBy: createdBy,
            createdByName: createdByName,
            recipientName: recipientName,
            createdAt: Date()
        )
        
        do {
            try db.collection("rewardTransactions").addDocument(from: transaction)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    // MARK: - Withdrawal Requests
    
    /// Parent pays out a member's balance (full or partial).
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
            let batch = db.batch()
            
            // Deduct from member's balance
            let userRef = db.collection("users").document(memberId)
            batch.updateData([
                "balance": FieldValue.increment(-amount)
            ], forDocument: userRef)
            
            // Record withdrawal transaction in ledger
            let transaction = RewardTransaction(
                familyId: familyId,
                userId: memberId,
                amount: -amount,
                type: .withdrawal,
                status: .approved,
                description: note ?? "Paid out by \(paidByName)",
                createdBy: paidBy,
                createdByName: paidByName,
                recipientName: member.displayName,
                createdAt: Date(),
                reviewedBy: paidBy,
                reviewedAt: Date()
            )
            let txRef = db.collection("rewardTransactions").document()
            try batch.setData(from: transaction, forDocument: txRef)
            
            try await batch.commit()
            
            // #SOUND: Play success sound for the payer
            SoundManager.shared.playRewardEarned()
        } catch {
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
    
    /// Parent approves a withdrawal request.
    func approveWithdrawal(
        _ request: WithdrawalRequest,
        reviewerId: String,
        reviewerName: String
    ) async {
        guard let id = request.id else { return }
        
        do {
            let batch = db.batch()
            
            // Update request status
            let requestRef = db.collection("withdrawalRequests").document(id)
            batch.updateData([
                "status": WithdrawalRequest.RequestStatus.approved.rawValue,
                "reviewedBy": reviewerId,
                "reviewedByName": reviewerName,
                "reviewedAt": Timestamp(date: Date())
            ], forDocument: requestRef)
            
            // Deduct from user balance
            let userRef = db.collection("users").document(request.userId)
            batch.updateData([
                "balance": FieldValue.increment(-request.amount)
            ], forDocument: userRef)
            
            // Record withdrawal transaction in ledger
            let transaction = RewardTransaction(
                familyId: request.familyId,
                userId: request.userId,
                amount: -request.amount,
                type: .withdrawal,
                status: .approved,
                description: request.note ?? "Withdrawal",
                createdBy: request.userId,
                createdByName: request.userName,
                recipientName: request.userName,
                createdAt: Date(),
                reviewedBy: reviewerId,
                reviewedAt: Date()
            )
            let txRef = db.collection("rewardTransactions").document()
            try batch.setData(from: transaction, forDocument: txRef)
            
            try await batch.commit()
            
            // #SOUND: Play success sound for the approver
            SoundManager.shared.playTaskCompleted()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    /// Parent rejects a withdrawal request.
    func rejectWithdrawal(
        _ request: WithdrawalRequest,
        reviewerId: String,
        reviewerName: String,
        reason: String?
    ) async {
        guard let id = request.id else { return }
        
        do {
            try await db.collection("withdrawalRequests").document(id).updateData([
                "status": WithdrawalRequest.RequestStatus.rejected.rawValue,
                "reviewedBy": reviewerId,
                "reviewedByName": reviewerName,
                "reviewedAt": Timestamp(date: Date()),
                "rejectionReason": (reason ?? "") as String
            ])
            
            // #SOUND: Subtle confirmation for rejection
            SoundManager.shared.playConfirm()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
