//
//  ProgressRing.swift
//  FamilyHub
//
//  Circular progress indicator
//

import SwiftUI

struct ProgressRing: View {
    let progress: Double
    var size: CGFloat = DS.IconSize.jumbo
    var lineWidth: CGFloat = DS.ProgressBar.standard
    var color: Color = Color.accentPrimary
    var showPercentage = true
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            
            Circle()
                .trim(from: 0, to: min(progress / 100, 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            if showPercentage {
                Text("\(Int(progress))%")
                    .font(.system(size: size * 0.25, weight: .bold)) // DT-exempt: proportional sizing
                    .foregroundStyle(color == .white ? .textOnAccent : .textPrimary)
            }
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.6), value: progress)
    }
}

#Preview {
    HStack(spacing: 20) {
        ProgressRing(progress: 25, size: 60, color: Color.accentPrimary)
        ProgressRing(progress: 50, size: 80, color: Color.accentSecondary)
        ProgressRing(progress: 75, size: 100, color: Color.accentTertiary)
    }
    .padding()
}
