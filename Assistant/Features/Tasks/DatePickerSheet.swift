//
//  DatePickerSheet.swift
//
//
//  Reusable date picker modal
//  UPDATED: Uses transparent blur background instead of solid theme color
//

import SwiftUI

struct DatePickerSheet: View {
    @Environment(\.dismiss) var dismiss
    @Binding var selectedDate: Date
    var title: String = AppStrings.localized("date")
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
                        in: ...Date.now,
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
                    Button("done") {
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
    @State private var tempTime = Date.now
    
    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "time",
                    selection: $tempTime,
                    displayedComponents: .hourAndMinute
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                
                Button("clear_time") {
                    hasTime = false
                    selectedTime = nil
                    dismiss()
                }
                .foregroundStyle(.accentRed)
                .padding()
                
                Spacer()
            }
            .padding()
            .navigationTitle("select_time")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("done") {
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
            tempTime = selectedTime ?? Date.now
        }
    }
}

#Preview {
    DatePickerSheet(selectedDate: .constant(Date()))
}
