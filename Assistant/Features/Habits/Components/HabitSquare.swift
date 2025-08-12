//
//  HabitSquare.swift
//  Assistant
//
//  Created by Ramiro  on 3/2/26.
//


//  Square habit completion indicator for month grid
//

import SwiftUI

struct HabitSquare: View {
    let color: Color
    let isCompleted: Bool
    let isToday: Bool
    var isSelected: Bool = false
    var size: CGFloat = 18
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 3)
                .fill(isCompleted ? color : color.opacity(0.2))
                .frame(width: size, height: size)
            
            if isSelected {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.primary, lineWidth: 2)
                    .frame(width: size, height: size)
            } else if isToday && !isCompleted {
                RoundedRectangle(cornerRadius: 3)
                    .stroke(color, lineWidth: 1.5)
                    .frame(width: size, height: size)
            }
            
            if isCompleted {
                Image(systemName: "checkmark")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(.white)
            }
        }
    }
}

#Preview {

}