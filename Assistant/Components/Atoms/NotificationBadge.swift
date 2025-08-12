//
//  NotificationBadge.swift
//  Assistant
//
//  Created by Ramiro  on 3/2/26.
//


//  Bell icon with notification count badge
//

import SwiftUI

struct NotificationBadge: View {
    @Binding var count: Int
    
    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: "bell.fill")
                .font(.title3)
                .foregroundColor(.textPrimary)
            
            if count > 0 {
                ZStack {
                    Circle()
                        .fill(Color.accentRed)
                        .frame(width: 18, height: 18)
                    
                    Text("\(min(count, 99))")
                        .font(.system(size: 10, weight: .bold)) // DT-exempt: badge counter
                        .foregroundColor(.white)
                }
                .offset(x: 8, y: -8)
            }
        }
        .frame(width: DS.Control.minTapTarget, height: DS.Control.minTapTarget)
    }
}

#Preview {
    HStack(spacing: 20) {
        NotificationBadge(count: .constant(0))
        NotificationBadge(count: .constant(5))
        NotificationBadge(count: .constant(99))
    }
    .padding()
}
