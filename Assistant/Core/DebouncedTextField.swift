//
//  DebouncedTextField.swift
//  Assistant
//
//  Created by Ramiro  on 2/2/26.
//
//  High-performance text field that debounces updates to parent state
//  Prevents full view hierarchy re-renders on every keystroke
//
//  USAGE:
//  DebouncedTextField("Placeholder", text: $title, debounce: 0.2)
//

import SwiftUI

// MARK: - Debounced TextField
struct DebouncedTextField: View {
    let placeholder: String
    @Binding var text: String
    let debounce: TimeInterval
    let axis: Axis?
    let onEditingChanged: ((Bool) -> Void)?
    
    // Local state for immediate UI updates
    @State private var localText: String = ""
    @State private var debounceTask: Task<Void, Never>?
    
    // Track if we're currently editing (to avoid sync loops)
    @State private var isEditing = false
    
    init(
        _ placeholder: String = "",
        text: Binding<String>,
        debounce: TimeInterval = 0.2,
        axis: Axis? = nil,
        onEditingChanged: ((Bool) -> Void)? = nil
    ) {
        self.placeholder = placeholder
        self._text = text
        self.debounce = debounce
        self.axis = axis
        self.onEditingChanged = onEditingChanged
    }
    
    var body: some View {
        Group {
            if let axis = axis {
                TextField(placeholder, text: $localText, axis: axis)
            } else {
                TextField(placeholder, text: $localText)
            }
        }
        .onAppear {
            localText = text
        }
        .onChange(of: localText) { _, newValue in
            // Cancel previous debounce
            debounceTask?.cancel()
            
            // Schedule debounced update to parent
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(debounce * 1_000_000_000))
                if !Task.isCancelled {
                    await MainActor.run {
                        if text != newValue {
                            text = newValue
                        }
                    }
                }
            }
        }
        .onChange(of: text) { _, newValue in
            // Sync from parent (e.g., clear button, programmatic change)
            if !isEditing && localText != newValue {
                localText = newValue
            }
        }
        // Track editing state to prevent sync loops
        .onSubmit {
            isEditing = false
            // Flush immediately on submit
            debounceTask?.cancel()
            text = localText
        }
    }
}

// MARK: - Debounced TextEditor (for multi-line)
struct DebouncedTextEditor: View {
    @Binding var text: String
    let debounce: TimeInterval
    let placeholder: String?
    
    @State private var localText: String = ""
    @State private var debounceTask: Task<Void, Never>?
    
    init(
        text: Binding<String>,
        debounce: TimeInterval = 0.3,
        placeholder: String? = nil
    ) {
        self._text = text
        self.debounce = debounce
        self.placeholder = placeholder
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: $localText)
                .scrollContentBackground(.hidden)
            
            // Placeholder
            if let placeholder = placeholder, localText.isEmpty {
                Text(placeholder)
                    .foregroundStyle(.textTertiary)
                    .padding(.leading, 4)
                    .padding(.top, 8)
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            localText = text
        }
        .onChange(of: localText) { _, newValue in
            debounceTask?.cancel()
            debounceTask = Task {
                try? await Task.sleep(nanoseconds: UInt64(debounce * 1_000_000_000))
                if !Task.isCancelled {
                    await MainActor.run {
                        if text != newValue {
                            text = newValue
                        }
                    }
                }
            }
        }
        .onChange(of: text) { _, newValue in
            if localText != newValue {
                localText = newValue
            }
        }
    }
}

// MARK: - Debounced Number Field
struct DebouncedNumberField: View {
    let placeholder: String
    @Binding var value: Double
    let debounce: TimeInterval
    let format: NumberFormatter
    
    @State private var localText: String = ""
    @State private var debounceTask: Task<Void, Never>?
    
    init(
        _ placeholder: String = "0.00",
        value: Binding<Double>,
        debounce: TimeInterval = 0.3,
        formatter: NumberFormatter? = nil
    ) {
        self.placeholder = placeholder
        self._value = value
        self.debounce = debounce
        self.format = formatter ?? {
            let f = NumberFormatter()
            f.numberStyle = .decimal
            f.minimumFractionDigits = 0
            f.maximumFractionDigits = 2
            return f
        }()
    }
    
    var body: some View {
        TextField(placeholder, text: $localText)
            .keyboardType(.decimalPad)
            .onAppear {
                if value > 0 {
                    localText = format.string(from: NSNumber(value: value)) ?? ""
                }
            }
            .onChange(of: localText) { _, newValue in
                debounceTask?.cancel()
                debounceTask = Task {
                    try? await Task.sleep(nanoseconds: UInt64(debounce * 1_000_000_000))
                    if !Task.isCancelled {
                        await MainActor.run {
                            let parsed = Double(newValue.replacingOccurrences(of: ",", with: "")) ?? 0
                            if value != parsed {
                                value = parsed
                            }
                        }
                    }
                }
            }
            .onChange(of: value) { _, newValue in
                let expected = format.string(from: NSNumber(value: newValue)) ?? ""
                let current = Double(localText.replacingOccurrences(of: ",", with: "")) ?? 0
                if abs(current - newValue) > 0.001 {
                    localText = newValue > 0 ? expected : ""
                }
            }
    }
}

// MARK: - Preview
#Preview {
    struct PreviewWrapper: View {
        @State private var text = ""
        @State private var number: Double = 0
        @State private var multiline = ""
        
        var body: some View {
            VStack(spacing: 20) {
                // Single line
                DebouncedTextField(L10n.taskTitle, text: $text)
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                
                Text("Bound value: \(text)")
                    .font(.caption)
                
                // Number
                HStack {
                    Text("$")
                    DebouncedNumberField(value: $number)
                }
                .padding()
                .background(Color.green.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
                
                Text("Bound value: \(number, specifier: "%.2f")")
                    .font(.caption)
                
                // Multi-line
                DebouncedTextEditor(text: $multiline, placeholder: L10n.description)
                    .frame(height: 100)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            }
            .padding()
        }
    }
    
    return PreviewWrapper()
}
