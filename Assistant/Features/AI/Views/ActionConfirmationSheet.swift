// ActionConfirmationSheet.swift
// Confirmation UI for AI-proposed actions
//
// Shows what the AI wants to do and requires user to Confirm or Cancel


import SwiftUI

struct ActionConfirmationSheet: View {
    let action: PendingAction
    let isConfirming: Bool
    let result: String?
    
    var onConfirm: () -> Void
    var onCancel: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Content
            ScrollView {
                VStack(spacing: 20) {
                    // Action Icon & Title
                    actionHeader
                    
                    // Details
                    detailsCard
                    
                    // Disclaimer
                    disclaimer
                }
                .padding()
                .constrainedWidth(.form)
            }
            
            Divider()
            
            // Buttons
            actionButtons
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            Button("cancel") {
                onCancel()
            }
            .foregroundStyle(.statusError)
            
            Spacer()
            
            Text("confirmAction")
                .font(.headline)
            
            Spacer()
            
            // Invisible button for balance
            Button("cancel") {}
                .opacity(0)
        }
        .padding()
    }
    
    // MARK: - Action Header
    
    private var actionHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(action.type.color.opacity(0.15))
                    .frame(width: 72, height: 72)
                
                Image(systemName: action.type.icon)
                    .font(DS.Typography.displayMedium())
                    .foregroundStyle(action.type.color)
            }
            
            Text(action.type.title)
                .font(.title2)
                .fontWeight(.semibold)
            
            Text(action.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - Details Card
    
    private var detailsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("details")
                .font(.headline)
            
            VStack(spacing: 8) {
                ForEach(displayItems, id: \.key) { item in
                    detailRow(label: item.key, value: item.value)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    
    private var displayItems: [(key: String, value: String)] {
        var items: [(String, String)] = []
        
        for (key, value) in action.display {
            let displayKey = formatKey(key)
            let displayValue = formatValue(value)
            if !displayValue.isEmpty {
                items.append((displayKey, displayValue))
            }
        }
        
        return items.sorted { $0.0 < $1.0 }
    }
    
    private func formatKey(_ key: String) -> String {
        // Convert camelCase to Title Case
        let words = key.replacingOccurrences(
            of: "([a-z])([A-Z])",
            with: "$1 $2",
            options: .regularExpression
        )
        return words.prefix(1).uppercased() + words.dropFirst()
    }
    
    private func formatValue(_ value: AnyCodable) -> String {
        if let string = value.stringValue {
            return string
        } else if let int = value.intValue {
            return "\(int)"
        } else if let double = value.doubleValue {
            return String(format: "%.2f", double)
        } else if let bool = value.boolValue {
            return bool ? "Yes" : "No"
        } else if let array = value.arrayValue as? [String] {
            return array.joined(separator: ", ")
        }
        return ""
    }
    
    private func detailRow(label: String, value: String) -> some View {
        HStack(alignment: .top) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .fontWeight(.medium)
            
            Spacer()
        }
        .font(.subheadline)
    }
    
    // MARK: - Disclaimer
    
    private var disclaimer: some View {
        HStack(spacing: 8) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(.statusInfo)
            
            Text("thisActionWillBePerformedAfterYouConfirm")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.blue.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
    }
    
    // MARK: - Action Buttons
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // Result message
            if let result = result {
                Text(result)
                    .font(.subheadline)
                    .foregroundStyle(result.contains("✅") ? .green : .red)
                    .multilineTextAlignment(.center)
            }
            
            HStack(spacing: 12) {
                Button {
                    onCancel()
                } label: {
                    Text("cancel")
                        .frame(maxWidth: .infinity)
                        .padding()
                }
                .buttonStyle(.bordered)
                .disabled(isConfirming)
                
                Button {
                    onConfirm()
                } label: {
                    if isConfirming {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding()
                    } else {
                        Text("confirm")
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isConfirming)
            }
        }
        .padding()
    }
}

// MARK: - Preview

#Preview {
    ActionConfirmationSheet(
        action: PendingAction(
            type: .createTask,
            summary: "Create task \"Math Homework\" for Emma",
            data: [:],
            display: [
                "title": AnyCodable("Math Homework"),
                "assignee": AnyCodable("Emma"),
                "dueDate": AnyCodable("Fri, Feb 14"),
                "priority": AnyCodable("Medium"),
                "reward": AnyCodable("$5")
            ]
        ),
        isConfirming: false,
        result: nil,
        onConfirm: {},
        onCancel: {}
    )
}
