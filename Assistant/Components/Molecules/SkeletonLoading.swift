//
//  SkeletonLoading.swift
//  
//
//  Shimmer skeleton placeholders for smooth loading states.
//  Replaces jarring blank → content transitions.
//

import SwiftUI

// MARK: - Shimmer Effect

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0
    
    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(0.4),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width * 0.6)
                    .offset(x: -geometry.size.width * 0.3 + (geometry.size.width * 1.6 * phase))
                    .blendMode(.softLight)
                }
            )
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .onAppear {
                withAnimation(
                    .linear(duration: 1.2)
                    .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Base Shape

struct SkeletonShape: View {
    var width: CGFloat? = nil
    var height: CGFloat = 16
    var radius: CGFloat = DS.Radius.sm
    
    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(Color.textTertiary.opacity(0.12))
            .frame(width: width, height: height)
            .shimmer()
    }
}

// MARK: - Skeleton Circle

struct SkeletonCircle: View {
    var size: CGFloat = 40
    
    var body: some View {
        Circle()
            .fill(Color.textTertiary.opacity(0.12))
            .frame(width: size, height: size)
            .shimmer()
    }
}

// MARK: - Task Card Skeleton

struct TaskCardSkeleton: View {
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Checkbox placeholder
            SkeletonCircle(size: 24)
            
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                // Title
                SkeletonShape(width: 180, height: 14)
                
                // Subtitle
                SkeletonShape(width: 120, height: 12)
            }
            
            Spacer()
            
            // Badge placeholder
            SkeletonShape(width: 60, height: 24, radius: DS.Radius.badge)
        }
        .padding(DS.Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(Color.themeCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(Color.themeCardBorder, lineWidth: DS.Border.hairline)
        )
    }
}

// MARK: - Event Row Skeleton

struct EventRowSkeleton: View {
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            // Color dot
            SkeletonCircle(size: 8)
            
            // Icon
            SkeletonShape(width: 20, height: 20, radius: 4)
            
            // Title
            SkeletonShape(width: 140, height: 14)
            
            Spacer()
            
            // Countdown badge
            SkeletonShape(width: 50, height: 22, radius: DS.Radius.badge)
        }
        .padding(.vertical, DS.Spacing.xs)
    }
}

// MARK: - Stat Card Skeleton

struct StatCardSkeleton: View {
    var body: some View {
        VStack(spacing: DS.Spacing.sm) {
            SkeletonShape(width: 40, height: 28)
            SkeletonShape(width: 50, height: 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(Color.textTertiary.opacity(0.06))
        )
    }
}

// MARK: - Summary Card Skeleton

struct SummaryCardSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header row
            HStack {
                SkeletonShape(width: 120, height: 18)
                Spacer()
                SkeletonShape(width: 80, height: 14)
            }
            
            // Progress bar
            SkeletonShape(height: DS.ProgressBar.standard)
            
            // Stats row
            HStack(spacing: DS.Spacing.xl) {
                HStack(spacing: DS.Spacing.xs) {
                    SkeletonCircle(size: 16)
                    SkeletonShape(width: 60, height: 12)
                }
                HStack(spacing: DS.Spacing.xs) {
                    SkeletonCircle(size: 16)
                    SkeletonShape(width: 60, height: 12)
                }
            }
        }
        .padding(DS.Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(Color.themeCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(Color.themeCardBorder, lineWidth: DS.Border.hairline)
        )
    }
}

// MARK: - Habit Widget Skeleton

struct HabitWidgetSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DS.Spacing.md) {
            // Header
            HStack {
                SkeletonCircle(size: 20)
                SkeletonShape(width: 100, height: 16)
                Spacer()
            }
            
            // Habit rows
            VStack(spacing: DS.Spacing.sm) {
                ForEach(0..<3, id: \.self) { _ in
                    HStack(spacing: DS.Spacing.sm) {
                        SkeletonCircle(size: 32)
                        SkeletonShape(width: 100, height: 14)
                        Spacer()
                        // Week dots
                        HStack(spacing: DS.Spacing.xs) {
                            ForEach(0..<7, id: \.self) { _ in
                                SkeletonCircle(size: 12)
                            }
                        }
                    }
                }
            }
        }
        .padding(DS.Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(Color.themeCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(Color.themeCardBorder, lineWidth: DS.Border.hairline)
        )
    }
}

// MARK: - Group Card Skeleton

struct GroupCardSkeleton: View {
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            // Icon container
            SkeletonCircle(size: 44)
            
            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                SkeletonShape(width: 100, height: 14)
                SkeletonShape(width: 60, height: 12)
            }
            
            Spacer()
            
            // Progress ring
            SkeletonCircle(size: DS.Avatar.sm)
            
            // Chevron
            SkeletonShape(width: 8, height: 14)
        }
        .padding(DS.Spacing.cardPadding)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(Color.themeCardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .stroke(Color.themeCardBorder, lineWidth: DS.Border.hairline)
        )
    }
}

// MARK: - Home View Skeleton

struct HomeViewSkeleton: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: DS.Spacing.sectionGap) {
                // Header skeleton
                HStack {
                    VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                        SkeletonShape(width: 120, height: 20)
                        SkeletonShape(width: 80, height: 16)
                    }
                    Spacer()
                    SkeletonCircle(size: 44)
                }
                .padding(.horizontal, DS.Spacing.screenH)
                
                // Date
                HStack {
                    SkeletonShape(width: 160, height: 14)
                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.screenH)
                
                // Summary card
                SummaryCardSkeleton()
                    .padding(.horizontal, DS.Spacing.screenH)
                
                // Habits widget
                HabitWidgetSkeleton()
                    .padding(.horizontal, DS.Spacing.screenH)
                
                // Events section
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HStack {
                        SkeletonCircle(size: 20)
                        SkeletonShape(width: 100, height: 16)
                        Spacer()
                    }
                    
                    ForEach(0..<3, id: \.self) { _ in
                        EventRowSkeleton()
                    }
                }
                .padding(DS.Spacing.cardPadding)
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.card)
                        .fill(Color.themeCardBackground)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DS.Radius.card)
                        .stroke(Color.themeCardBorder, lineWidth: DS.Border.hairline)
                )
                .padding(.horizontal, DS.Spacing.screenH)
                
                // Task list skeleton
                VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                    HStack {
                        SkeletonShape(width: 80, height: 16)
                        Spacer()
                        SkeletonShape(width: 100, height: 14)
                    }
                    
                    ForEach(0..<4, id: \.self) { _ in
                        TaskCardSkeleton()
                    }
                }
                .padding(.horizontal, DS.Spacing.screenH)
            }
            .padding(.top, DS.Spacing.md)
        }
    }
}

// MARK: - Tasks View Skeleton

struct TasksViewSkeleton: View {
    var body: some View {
        VStack(spacing: 0) {
            // Filter chips skeleton
            HStack(spacing: 0) {
                ForEach(0..<3, id: \.self) { _ in
                    SkeletonShape(height: 36)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(DS.Spacing.xxs)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.md)
                    .fill(Color.backgroundSecondary)
            )
            .padding(.horizontal, DS.Spacing.screenH)
            .padding(.bottom, DS.Spacing.md)
            
            // Stats section skeleton
            HStack(spacing: DS.Spacing.md) {
                StatCardSkeleton()
                StatCardSkeleton()
                StatCardSkeleton()
            }
            .padding(.horizontal, DS.Spacing.screenH)
            .padding(.bottom, DS.Spacing.lg)
            
            // Task list skeleton
            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: DS.Spacing.md) {
                    ForEach(0..<6, id: \.self) { _ in
                        TaskCardSkeleton()
                    }
                }
                .padding(.horizontal, DS.Spacing.screenH)
            }
        }
    }
}

// MARK: - Calendar View Skeleton

struct CalendarViewSkeleton: View {
    var body: some View {
        VStack(spacing: DS.Spacing.md) {
            // Month header
            HStack {
                SkeletonShape(width: 120, height: 20)
                Spacer()
                HStack(spacing: DS.Spacing.md) {
                    SkeletonCircle(size: 32)
                    SkeletonCircle(size: 32)
                }
            }
            .padding(.horizontal, DS.Spacing.screenH)
            
            // Week days header
            HStack(spacing: 0) {
                ForEach(0..<7, id: \.self) { _ in
                    SkeletonShape(width: 30, height: 12)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, DS.Spacing.screenH)
            
            // Calendar grid
            VStack(spacing: DS.Spacing.sm) {
                ForEach(0..<5, id: \.self) { _ in
                    HStack(spacing: 0) {
                        ForEach(0..<7, id: \.self) { _ in
                            SkeletonCircle(size: 36)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .padding(.horizontal, DS.Spacing.screenH)
            
            Spacer()
        }
        .padding(.top, DS.Spacing.md)
    }
}

// MARK: - Preview

#Preview("Skeletons") {
    ScrollView {
        VStack(spacing: 24) {
            Text("task").font(.caption).foregroundStyle(.textSecondary)
            TaskCardSkeleton()
            
            Text("summaryLabel").font(.caption).foregroundStyle(.textSecondary)
            SummaryCardSkeleton()
            
            Text("habitsLabel").font(.caption).foregroundStyle(.textSecondary)
            HabitWidgetSkeleton()
            
            Text("taskGroup").font(.caption).foregroundStyle(.textSecondary)
            GroupCardSkeleton()
            
            Text("statusLabel").font(.caption).foregroundStyle(.textSecondary)
            HStack(spacing: DS.Spacing.md) {
                StatCardSkeleton()
                StatCardSkeleton()
                StatCardSkeleton()
            }
        }
        .padding()
    }
    .background(Color.themeSurfacePrimary)
}

#Preview("Home Loading") {
    HomeViewSkeleton()
        .background(Color.themeSurfacePrimary)
}

#Preview("Tasks Loading") {
    TasksViewSkeleton()
        .background(Color.themeSurfacePrimary)
}
