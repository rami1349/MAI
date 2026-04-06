// ============================================================================
// HomeGroupsSection.swift
//
// SLOT 5: My Folders — macOS Finder-style folder cards
//
// Horizontal scroll of folder-shaped cards that mimic the classic macOS
// Finder folder icon: two-layer body (back + front panel) with a
// protruding tab at the top-left corner.
//
// ============================================================================

import SwiftUI

struct HomeGroupsSection: View {
    let groups: [TaskGroup]
    let onSelectGroup: (TaskGroup) -> Void
    var onDropTask: ((String, String) async -> Void)? = nil
    
    var body: some View {
        if !groups.isEmpty {
            VStack(alignment: .leading, spacing: DS.Spacing.md) {
                // Header
                HStack(spacing: DS.Spacing.sm) {
                    Image(systemName: "folder.fill")
                        .font(DS.Typography.label())
                        .foregroundStyle(.accentPrimary)
                        .frame(width: 28, height: 28)
                        .background(Circle().fill(Color.accentPrimary.opacity(0.1)))
                    
                    Text("task_groups")
                        .font(DS.Typography.subheading())
                        .foregroundStyle(.textPrimary)
                    
                    Spacer()
                }
                .padding(.horizontal, DS.Spacing.screenH)
                
                // Horizontal scroll of Finder folder cards
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DS.Spacing.lg) {
                        ForEach(groups) { group in
                            FinderFolder(
                                group: group,
                                onTap: { onSelectGroup(group) },
                                onDropTask: onDropTask
                            )
                        }
                    }
                    .padding(.horizontal, DS.Spacing.screenH)
                    .padding(.vertical, DS.Spacing.xs)
                }
            }
        }
    }
}

// MARK: - Finder Folder Card

private struct FinderFolder: View {
    let group: TaskGroup
    let onTap: () -> Void
    var onDropTask: ((String, String) async -> Void)? = nil
    
    @State private var isDropTargeted = false
    
    private var groupColor: Color { Color(hex: group.color) }
    private let folderWidth: CGFloat = 110
    private let folderHeight: CGFloat = 88
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: DS.Spacing.sm) {
                // Folder shape with content
                folderShape
                    .frame(width: folderWidth, height: folderHeight)
                    .overlay(alignment: .bottom) {
                        VStack(spacing: 2) {
                            Image(systemName: group.icon)
                                .font(.system(size: 20, weight: .light))
                                .foregroundStyle(groupColor.opacity(0.85))
                            
                            Text("\(group.taskCount)")
                                .font(DS.Typography.micro())
                                .foregroundStyle(groupColor.opacity(0.6))
                        }
                        .padding(.bottom, 14)
                    }
                
                // Name
                Text(group.name)
                    .font(DS.Typography.caption())
                    .foregroundStyle(.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: folderWidth)
            }
        }
        .buttonStyle(FolderPressStyle())
        .dropDestination(for: String.self) { stableIds, _ in
            guard let stableId = stableIds.first,
                  let gid = group.id,
                  let onDropTask
            else { return false }
            Task { await onDropTask(stableId, gid) }
            DS.Haptics.success()
            return true
        } isTargeted: { targeted in
            withAnimation(.easeInOut(duration: 0.15)) {
                isDropTargeted = targeted
            }
        }
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: DS.Radius.lg)
                    .stroke(groupColor, lineWidth: 2)
                    .padding(-4)
            }
        }
    }
    
    // MARK: - Two-Layer Folder Shape
    
    private var folderShape: some View {
        ZStack(alignment: .top) {
            // Layer 1: Back panel + tab (darker)
            FinderBackPanel()
                .fill(groupColor.opacity(0.18))
            FinderBackPanel()
                .stroke(groupColor.opacity(0.12), lineWidth: 0.5)
            
            // Layer 2: Front panel (lighter, overlaps bottom ~62%)
            FinderFrontPanel()
                .fill(groupColor.opacity(0.10))
            FinderFrontPanel()
                .stroke(groupColor.opacity(0.10), lineWidth: 0.5)
            
            // Top edge highlight on front panel
            FinderFrontPanelEdge()
                .fill(groupColor.opacity(0.22))
        }
    }
}

// MARK: - Button Style

private struct FolderPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.94 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

// MARK: - Back Panel Shape (full folder with tab at top-left)

private struct FinderBackPanel: Shape {
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 8
        let tabW = rect.width * 0.35
        let tabH: CGFloat = 12
        let tabR: CGFloat = 5
        let bodyTop = tabH
        
        var p = Path()
        
        p.move(to: CGPoint(x: 0, y: tabR))
        p.addArc(center: CGPoint(x: tabR, y: tabR),
                 radius: tabR,
                 startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.addLine(to: CGPoint(x: tabW - tabR, y: 0))
        p.addArc(center: CGPoint(x: tabW - tabR, y: tabR),
                 radius: tabR,
                 startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: tabW, y: bodyTop))
        p.addLine(to: CGPoint(x: rect.width - r, y: bodyTop))
        p.addArc(center: CGPoint(x: rect.width - r, y: bodyTop + r),
                 radius: r, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.width, y: rect.height - r))
        p.addArc(center: CGPoint(x: rect.width - r, y: rect.height - r),
                 radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: r, y: rect.height))
        p.addArc(center: CGPoint(x: r, y: rect.height - r),
                 radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        
        p.closeSubpath()
        return p
    }
}

// MARK: - Front Panel Shape (overlaps bottom ~62%, creating the "pocket")

private struct FinderFrontPanel: Shape {
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 8
        let topY = rect.height * 0.38
        
        var p = Path()
        
        p.move(to: CGPoint(x: 0, y: topY + r))
        p.addArc(center: CGPoint(x: r, y: topY + r),
                 radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.addLine(to: CGPoint(x: rect.width - r, y: topY))
        p.addArc(center: CGPoint(x: rect.width - r, y: topY + r),
                 radius: r, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.width, y: rect.height - r))
        p.addArc(center: CGPoint(x: rect.width - r, y: rect.height - r),
                 radius: r, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: r, y: rect.height))
        p.addArc(center: CGPoint(x: r, y: rect.height - r),
                 radius: r, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        
        p.closeSubpath()
        return p
    }
}

// MARK: - Front Panel Top Edge (subtle highlight strip for depth)

private struct FinderFrontPanelEdge: Shape {
    func path(in rect: CGRect) -> Path {
        let r: CGFloat = 8
        let topY = rect.height * 0.38
        let stripH: CGFloat = 4
        
        var p = Path()
        
        p.move(to: CGPoint(x: 0, y: topY + r))
        p.addArc(center: CGPoint(x: r, y: topY + r),
                 radius: r, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
        p.addLine(to: CGPoint(x: rect.width - r, y: topY))
        p.addArc(center: CGPoint(x: rect.width - r, y: topY + r),
                 radius: r, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
        p.addLine(to: CGPoint(x: rect.width, y: topY + stripH + r))
        p.addLine(to: CGPoint(x: 0, y: topY + stripH + r))
        
        p.closeSubpath()
        return p
    }
}
