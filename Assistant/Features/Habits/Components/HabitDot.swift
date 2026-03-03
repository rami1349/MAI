//
//  HabitDot.swift
//  Assistant
//
//  Created by Ramiro  on 3/2/26.
//


//  Circular habit completion indicator for week view
//

import SwiftUI

struct HabitDot: View {
    let color: Color
    let isCompleted: Bool
    let isToday: Bool
    var isSelected: Bool = false
    var size: CGFloat = 24
    
    var body: some View {
        ZStack {
            Circle()
                .fill(isCompleted ? color : color.opacity(0.15))
                .frame(width: size, height: size)
            
            if isSelected {
                Circle()
                    .stroke(Color.primary, lineWidth: 2)
                    .frame(width: size, height: size)
            } else if isToday && !isCompleted {
                Circle()
                    .stroke(color, lineWidth: 1.5)
                    .frame(width: size, height: size)
            }
            
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.4, weight: .bold))
                    .foregroundColor(.white)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
}