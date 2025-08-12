//
//  ActionState.swift
//
//  Reusable helpers for write-action feedback:
//  • performAction()     — guards against double-taps, fires haptics, surfaces toast
//  • performItemAction() — per-item variant for list views
//
//  Toast display is handled by ToastBanner.swift's `.toastBanner(item:)` modifier.
//

import SwiftUI
import UIKit

// MARK: - Perform Action Helper

func performAction(
    inFlight: Binding<Bool>,
    toast: Binding<ToastMessage?>,
    successMessage: String? = nil,
    action: @escaping () async -> Void
) {
    guard !inFlight.wrappedValue else { return }
    inFlight.wrappedValue = true

    Task { @MainActor in
        await action()
        inFlight.wrappedValue = false

        if let msg = successMessage {
            toast.wrappedValue = .success(msg)
            DS.Haptics.success()
        }
    }
}

/// Variant that tracks per-item IDs for list views with multiple
/// concurrent actions (e.g. completing task A while deleting task B).
func performItemAction(
    id: String,
    inFlightIds: Binding<Set<String>>,
    toast: Binding<ToastMessage?>,
    successMessage: String? = nil,
    action: @escaping () async -> Void
) {
    guard !inFlightIds.wrappedValue.contains(id) else { return }
    inFlightIds.wrappedValue.insert(id)

    Task { @MainActor in
        await action()
        inFlightIds.wrappedValue.remove(id)

        if let msg = successMessage {
            toast.wrappedValue = .success(msg)
            DS.Haptics.success()
        }
    }
}
