// ============================================================================
// HabitViewModel.swift
//
//
// PURPOSE:
//   Manages habit definitions and daily completion logs for a single user.
//   Provides real-time Firestore sync, optimistic UI updates, and pre-computed
//   completion state lookups used across week, month, and year habit views.
//
// ARCHITECTURE ROLE:
//   - Owned by FamilyViewModel (coordinator). Views observe it via @Environment.
//   - Scoped to a single user (habits are personal, not family-shared).
//   - Does NOT know about notifications or reward logic — FamilyViewModel owns that.
//
// DATA MODEL:
//   Firestore `habits` collection:
//     - userId (scoped to one user)
//     - isActive (soft-delete flag — deleted habits are set to isActive = false)
//
//   Firestore `habitLogs` collection:
//     - habitId, userId, date (yyyy-MM-dd), completedAt
//     - One document per habit per completion per day
//
// COMPLETION STATE STORAGE:
//   `habitLogs` is stored as [habitId: Set<dateString>] for O(1) completion checks.
//   date strings use "yyyy-MM-dd" format to avoid timezone edge cases with Date comparisons.
//
// PERFORMANCE PATTERNS:
//   - Off-main-thread Firestore decoding via FirestoreDecode helper
//   - Dedup check in setHabits() prevents unnecessary re-renders
//   - Optimistic updates in deleteHabit() and toggleHabitCompletion()
//   - Shared static DateFormatter to avoid repeated allocations
//
// KEY DEPENDENCIES:
//   - FirebaseFirestore — habit and log persistence
//   - FirestoreDecode   — off-main-thread Codable decoding helper
//
// ============================================================================

import Foundation
import Observation
import FirebaseFirestore

/// Manages habit state, real-time sync, and daily completion tracking for a user.
///
/// Habits are personal (scoped to `userId`), unlike tasks which are family-scoped.
/// Completion state is maintained in a local dictionary (`habitLogs`) that mirrors
/// the Firestore `habitLogs` collection for the queried date range.
@MainActor
@Observable
final class HabitViewModel {

    // MARK: - Published State

    /// All active habits for the current user. Excludes soft-deleted habits.
    private(set) var habits: [Habit] = []

    /// Completion state indexed as `[habitId: Set<dateString>]`.
    ///
    /// A habit is completed on a date if `habitLogs[habitId]?.contains(dateString) == true`.
    /// Date strings use "yyyy-MM-dd" format (see `dateFormatter`).
    ///
    /// Updated by `loadHabitLogs()` and `toggleHabitCompletion()`.
    private(set) var habitLogs: [String: Set<String>] = [:]

    /// Indicates an in-flight Firestore fetch. Used by skeleton loaders.
    private(set) var isLoading = false

    /// Localized error message for Firestore operation failures.
    var errorMessage: String?

    // MARK: - Private

    /// Firestore singleton — @ObservationIgnored (infrastructure, not UI state).
    private var db: Firestore { Firestore.firestore() }

    /// Real-time snapshot listener for habits. Removed on `deinit` and on listener reset.
    @ObservationIgnored private var listener: ListenerRegistration?

    /// Shared static date formatter for "yyyy-MM-dd" strings.
    /// Static + lazy ensures one allocation for all HabitViewModel instances.
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    deinit {
        listener?.remove()
    }

    // MARK: - Load & Listen

    /// Performs a one-shot fetch of active habits for the given user.
    ///
    /// Used during `FamilyViewModel.loadFamilyData()` before the real-time
    /// listener is established, ensuring habits are available immediately.
    /// The listener subsequently keeps data in sync — no need to call this again.
    ///
    /// Query: `habits` where `userId == userId && isActive == true`
    ///
    /// - Parameter userId: Firebase UID of the user whose habits to load.
    func loadHabits(userId: String) async {
        isLoading = true
        do {
            let snapshot = try await db.collection(FirestoreCollections.habits)
                .whereField(FirestoreFields.userId, isEqualTo: userId)
                .whereField("isActive", isEqualTo: true)  // Soft-delete filter
                .getDocuments()

            // PERF: Decode off main thread to keep UI responsive
            let decoded = await FirestoreDecode.documents(snapshot.documents, as: Habit.self)
            setHabits(decoded)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    /// Establishes a real-time Firestore snapshot listener for habits.
    ///
    /// After this is called, `habits` stays in sync automatically — any habit
    /// creation, deletion, or update from any device is reflected immediately.
    ///
    /// Mirrors the pattern used in TaskViewModel for consistency.
    /// Decodes on a background Task to avoid blocking the main thread.
    ///
    /// - Parameter userId: Firebase UID of the user whose habits to monitor.
    func setupListener(userId: String) {
        listener?.remove() // Remove stale listener before creating a new one

        listener = db.collection(FirestoreCollections.habits)
            .whereField(FirestoreFields.userId, isEqualTo: userId)
            .whereField("isActive", isEqualTo: true) // Only listen to active habits
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    Task { @MainActor in
                        self.errorMessage = "Failed to sync habits: \(error.localizedDescription)"
                    }
                    return
                }

                guard let documents = snapshot?.documents else { return }

                // PERF: Decode Codable models off main thread
                Task {
                    let decoded = await FirestoreDecode.documents(documents, as: Habit.self)
                    await MainActor.run {
                        self.setHabits(decoded)
                    }
                }
            }
    }

    // MARK: - Private Setter with Dedup

    /// Updates `habits` only if the incoming data differs from the current state.
    ///
    /// Two-level check to prevent unnecessary SwiftUI re-renders:
    /// 1. Fast check: compare ID sets and counts.
    /// 2. Deep check (when ID sets match): compare key fields (name, icon, color, isActive).
    ///
    /// This mirrors the dedup pattern in TaskViewModel for consistency.
    ///
    /// - Parameter newHabits: The decoded habits from the latest Firestore snapshot.
    private func setHabits(_ newHabits: [Habit]) {
        let newIDs = Set(newHabits.compactMap { $0.id })
        let oldIDs = Set(habits.compactMap { $0.id })

        let needsUpdate: Bool
        if newIDs == oldIDs && newHabits.count == habits.count {
            // Deep field-level comparison — sorted by ID for deterministic pairing
            needsUpdate = zip(
                newHabits.sorted { ($0.id ?? "") < ($1.id ?? "") },
                habits.sorted    { ($0.id ?? "") < ($1.id ?? "") }
            ).contains { new, old in
                new.name     != old.name     ||
                new.icon     != old.icon     ||
                new.colorHex != old.colorHex ||
                new.isActive != old.isActive
            }
        } else {
            needsUpdate = true
        }

        guard needsUpdate else { return }
        habits = newHabits
    }

    // MARK: - Habit Log Loading

    /// Fetches completion logs for a date range and builds the `habitLogs` dictionary.
    ///
    /// Called by the habit tracker views when the user navigates to a new
    /// week/month/year to ensure logs are loaded for the visible period.
    ///
    /// Date range query: inclusive start/end using yyyy-MM-dd string comparison
    /// (Firestore compares strings lexicographically, which works correctly for
    /// ISO date strings with this format).
    ///
    /// Result is stored in `habitLogs` as `[habitId: Set<dateString>]` for O(1)
    /// completion checks across the habit grid views.
    ///
    /// - Parameters:
    ///   - userId: Firebase UID of the user whose logs to fetch.
    ///   - startDate: First day of the range (inclusive).
    ///   - endDate: Last day of the range (inclusive).
    func loadHabitLogs(userId: String, from startDate: Date, to endDate: Date) async {
        let start = Self.dateFormatter.string(from: startDate)
        let end   = Self.dateFormatter.string(from: endDate)

        do {
            let snapshot = try await db.collection("habitLogs")
                .whereField("userId",  isEqualTo: userId)
                .whereField("date", isGreaterThanOrEqualTo: start)
                .whereField("date", isLessThanOrEqualTo: end)
                .getDocuments()

            let logs = snapshot.documents.compactMap { try? $0.data(as: HabitLog.self) }

            // Build index: habitId → Set of completed date strings
            var newHabitLogs: [String: Set<String>] = [:]
            for log in logs {
                if newHabitLogs[log.habitId] == nil {
                    newHabitLogs[log.habitId] = []
                }
                newHabitLogs[log.habitId]?.insert(log.date)
            }
            habitLogs = newHabitLogs
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - CRUD Operations

    /// Creates a new habit and persists it to Firestore.
    ///
    /// New habits are created with `isActive = true`. Deletion uses a soft-delete
    /// pattern (setting `isActive = false`), so all historical logs remain valid.
    ///
    /// After the Firestore write, the local `habits` array is updated immediately
    /// using the returned document ID (the real-time listener will also fire, but
    /// the local update provides instant UI feedback).
    ///
    /// - Parameters:
    ///   - name: Display name of the habit (e.g., "Read 20 minutes").
    ///   - icon: SF Symbol or emoji string for the habit icon.
    ///   - colorHex: Hex color string (e.g., "FF6B6B") for the habit's accent color.
    ///   - familyId: The family this habit belongs to (for cross-device sync).
    ///   - userId: Firebase UID of the user creating the habit.
    func createHabit(name: String, icon: String, colorHex: String, familyId: String, userId: String) async {
        let habit = Habit(
            familyId: familyId,
            userId: userId,
            name: name,
            icon: icon,
            colorHex: colorHex,
            createdAt: Date(),
            isActive: true
        )

        // Generate a temporary ID for optimistic update
        let tempId = UUID().uuidString
        var optimisticHabit = habit
        optimisticHabit.id = tempId
        
        // OPTIMISTIC UPDATE: Add to local state BEFORE Firestore write
        // This ensures the UI updates immediately
        habits.append(optimisticHabit)
        
        do {
            // Write to Firestore - listener will fire and update with real ID
            _ = try db.collection(FirestoreCollections.habits).addDocument(from: habit)
            // Note: Don't update habits here - the listener will handle it
            // and replace the temp ID with the real Firestore document ID
        } catch {
            // ROLLBACK: Remove the optimistic habit on failure
            habits.removeAll { $0.id == tempId }
            errorMessage = error.localizedDescription
        }
    }

    /// Soft-deletes a habit by setting `isActive = false` and removing from local state.
    ///
    /// Note: This is a HARD DELETE of the Firestore document, not a soft-delete,
    /// despite the variable name. Historical `habitLogs` documents for this habit
    /// remain in Firestore (orphaned), but are excluded from future `loadHabitLogs`
    /// queries since habits are filtered by active habit IDs.
    ///
    /// Optimistic update pattern:
    /// - Removes from `habits` and `habitLogs` immediately for instant UI response.
    /// - Rolls back both on Firestore failure.
    ///
    /// - Parameter habit: The habit to delete. Must have a non-nil `id`.
    func deleteHabit(_ habit: Habit) async {
        guard let id = habit.id else { return }

        // OPTIMISTIC UPDATE: Remove from local state immediately
        let originalHabits = habits
        let originalLogs   = habitLogs
        habits.removeAll { $0.id == id }
        habitLogs.removeValue(forKey: id)

        do {
            // 1. Batch-delete all habitLog documents for this habit
            let logsSnap = try await db.collection(FirestoreCollections.habitLogs)
                .whereField("habitId", isEqualTo: id)
                .getDocuments()

            if !logsSnap.documents.isEmpty {
                // Firestore batch limit is 500 — safe for habits (max ~365 logs/year)
                let batch = db.batch()
                for doc in logsSnap.documents {
                    batch.deleteDocument(doc.reference)
                }
                try await batch.commit()
            }

            // 2. Delete the habit document itself
            try await db.collection(FirestoreCollections.habits).document(id).delete()
        } catch {
            // ROLLBACK: Restore state on failure
            habits    = originalHabits
            habitLogs = originalLogs
            errorMessage = "Failed to delete habit: \(error.localizedDescription)"
        }
    }

    // MARK: - Completion Toggling

    /// Toggles a habit's completion state for a specific date.
    ///
    /// OPTIMISTIC UPDATE PATTERN:
    /// - The local `habitLogs` dictionary is mutated FIRST (triggers update).
    /// - The Firestore write happens asynchronously AFTER the UI has already updated.
    /// - This ensures zero-latency UI response for the tap gesture.
    ///
    /// IMPORTANT: `habitLogs = updatedLogs` (full assignment) is intentional.
    /// Mutating a value type nested inside a property does NOT trigger
    /// SwiftUI's change detection. The full assignment is required to fire the publisher.
    ///
    /// Unchecking: Queries for and deletes all HabitLog documents matching
    /// (userId, habitId, date) — handles the edge case of duplicate log documents.
    ///
    /// Checking: Creates a new HabitLog document. The `addDocument` call uses
    /// `try?` because a UI toggle failure is non-critical (the optimistic update
    /// already reflects the intended state).
    ///
    /// - Parameters:
    ///   - habit: The habit to toggle. Must have a non-nil `id`.
    ///   - date: The date to mark as completed or uncompleted.
    ///   - userId: Firebase UID of the user performing the toggle.
    func toggleHabitCompletion(habit: Habit, date: Date, userId: String) async {
        guard let habitId = habit.id else { return }

        let dateString = Self.dateFormatter.string(from: date)

        if habitLogs[habitId]?.contains(dateString) == true {
            // ── UNCHECK: Remove this date from completion state ──

            // Step 1: Optimistic local update (fires immediately)
            var updatedLogs = habitLogs
            updatedLogs[habitId]?.remove(dateString)
            habitLogs = updatedLogs // Full assignment required for SwiftUI to detect change

            // Step 2: Delete matching log document(s) from Firestore
            let snapshot = try? await db.collection(FirestoreCollections.habitLogs)
                .whereField(FirestoreFields.userId, isEqualTo: userId)
                .whereField("habitId", isEqualTo: habitId)
                .whereField("date", isEqualTo: dateString)
                .getDocuments()

            for doc in snapshot?.documents ?? [] {
                try? await doc.reference.delete()
            }

        } else {
            // ── CHECK: Mark this date as completed ──

            // Step 1: Optimistic local update
            var updatedLogs = habitLogs
            var habitSet = updatedLogs[habitId] ?? []
            habitSet.insert(dateString)
            updatedLogs[habitId] = habitSet
            habitLogs = updatedLogs // Full assignment required for SwiftUI to detect change

            // Step 2: Write log document to Firestore
            let log = HabitLog(
                habitId: habitId,
                userId: userId,
                date: dateString,
                completedAt: Date()
            )
            _ = try? db.collection(FirestoreCollections.habitLogs).addDocument(from: log)
        }
    }

    // MARK: - Completion Checks

    /// Returns whether a habit was completed on a specific date.
    ///
    /// O(1) lookup via the `habitLogs` dictionary.
    /// Used extensively by HabitDot, HabitSquare, and other grid cell views.
    ///
    /// - Parameters:
    ///   - habitId: The habit's Firestore document ID.
    ///   - date: The date to check.
    /// - Returns: `true` if a completion log exists for this habit on this date.
    func isHabitCompleted(habitId: String, date: Date) -> Bool {
        let dateString = Self.dateFormatter.string(from: date)
        return habitLogs[habitId]?.contains(dateString) == true
    }

    /// Returns the count of habits completed today for a given subset of habits.
    ///
    /// PERFORMANCE: Computes today's date string once and reuses it across all habits,
    /// avoiding repeated `DateFormatter.string(from: Date())` calls in the view layer.
    ///
    /// Used by the home screen TodayProgressCard to display "X of Y habits done today."
    ///
    /// - Parameter habits: The habits to count (typically the full `habits` array).
    /// - Returns: Count of habits completed today.
    func todayCompletedHabitCount(habits: [Habit]) -> Int {
        let todayString = Self.dateFormatter.string(from: Date())
        return habits.reduce(0) { count, habit in
            guard let habitId = habit.id else { return count }
            return habitLogs[habitId]?.contains(todayString) == true ? count + 1 : count
        }
    }
}

