//
//  DatePickerSheet.swift
//  FamilyHub
//
//  Reusable date picker modal
//  UPDATED: Uses transparent blur background instead of solid theme color
//

import SwiftUI

struct DatePickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedDate: Date
    var title: String = L10n.date
    var allowFutureDates: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack {
                if allowFutureDates {
                    DatePicker(
                        title,
                        selection: $selectedDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                } else {
                    DatePicker(
                        title,
                        selection: $selectedDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.wheel)
                    .labelsHidden()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(.ultraThinMaterial)
    }
}

// MARK: - Time Picker Sheet
struct TimePickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedTime: Date?
    @Binding var hasTime: Bool
    @State private var tempTime = Date()
    
    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Time",
                    selection: $tempTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                
                Button(L10n.clearTime) {
                    hasTime = false
                    selectedTime = nil
                    dismiss()
                }
                .foregroundStyle(.accentRed)
                .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle(L10n.selectTime)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.cancel) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.done) {
                        hasTime = true
                        selectedTime = tempTime
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(.ultraThinMaterial)
        .onAppear {
            tempTime = selectedTime ?? Date()
        }
    }
}

#Preview {
    DatePickerSheet(selectedDate: .constant(Date()))
}
