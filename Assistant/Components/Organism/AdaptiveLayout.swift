//  AdaptiveLayout.swift
//  FamilyHub
//
//  Comprehensive adaptive layout system for iPhone, iPad, and macOS.
//  Provides: Size class detection, adaptive spacing, keyboard shortcuts,
//  hover effects, context menus, and platform-specific UI adaptations.
//

import SwiftUI

// MARK: - Device Type Detection

enum DeviceType {
    case iPhone
    case iPad
    case mac
    
    static var current: DeviceType {
        #if os(macOS)
        return .mac
        #else
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .iPad
        }
        return .iPhone
        #endif
    }
    
    var isCompact: Bool { self == .iPhone }
    var isRegular: Bool { self != .iPhone }
}

// MARK: - Adaptive Layout Environment

struct AdaptiveLayoutKey: EnvironmentKey {
    static let defaultValue = AdaptiveLayout()
}

extension EnvironmentValues {
    var adaptiveLayout: AdaptiveLayout {
        get { self[AdaptiveLayoutKey.self] }
        set { self[AdaptiveLayoutKey.self] = newValue }
    }
}

struct AdaptiveLayout {
    var horizontalSizeClass: UserInterfaceSizeClass = .compact
    var verticalSizeClass: UserInterfaceSizeClass = .regular
    
    var isCompact: Bool { horizontalSizeClass == .compact }
    var isRegular: Bool { horizontalSizeClass == .regular }
    var isLandscape: Bool { verticalSizeClass == .compact }
    
    // MARK: - Adaptive Spacing
    
    var screenPadding: CGFloat {
        isRegular ? 40 : DS.Spacing.screenH
    }
    
    var sectionSpacing: CGFloat {
        isRegular ? 32 : DS.Spacing.sectionGap
    }
    
    var cardPadding: CGFloat {
        isRegular ? 20 : DS.Spacing.cardPadding
    }
    
    var gridColumns: Int {
        isRegular ? 2 : 1
    }
    
    // MARK: - Content Width
    
    var maxContentWidth: CGFloat {
        switch DeviceType.current {
        case .iPhone: return .infinity
        case .iPad: return 800
        case .mac: return 900
        }
    }
    
    // MARK: - Navigation Style
    
    var usesSplitView: Bool {
        isRegular && DeviceType.current != .iPhone
    }
    
    var prefersPopovers: Bool {
        DeviceType.current != .iPhone
    }
}

// MARK: - Adaptive Layout Modifier

struct AdaptiveLayoutModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    
    func body(content: Content) -> some View {
        content
            .environment(\.adaptiveLayout, AdaptiveLayout(
                horizontalSizeClass: horizontalSizeClass ?? .compact,
                verticalSizeClass: verticalSizeClass ?? .regular
            ))
    }
}

extension View {
    func adaptiveLayout() -> some View {
        modifier(AdaptiveLayoutModifier())
    }
}

// MARK: - Adaptive Padding Modifier

struct AdaptivePaddingModifier: ViewModifier {
    @Environment(\.adaptiveLayout) private var layout
    let edges: Edge.Set
    let compactValue: CGFloat?
    let regularValue: CGFloat?
    
    func body(content: Content) -> some View {
        let value = layout.isRegular
            ? (regularValue ?? layout.screenPadding)
            : (compactValue ?? DS.Spacing.screenH)
        
        return content.padding(edges, value)
    }
}

extension View {
    /// Adaptive padding that increases for iPad/Mac
    func adaptivePadding(_ edges: Edge.Set = .all, compact: CGFloat? = nil, regular: CGFloat? = nil) -> some View {
        modifier(AdaptivePaddingModifier(edges: edges, compactValue: compact, regularValue: regular))
    }
    
    /// Horizontal screen padding (16 iPhone, 40 iPad)
    func adaptiveHorizontalPadding() -> some View {
        modifier(AdaptivePaddingModifier(edges: .horizontal, compactValue: DS.Spacing.screenH, regularValue: 40))
    }
}

// MARK: - Adaptive Grid

struct AdaptiveGrid<Content: View>: View {
    @Environment(\.adaptiveLayout) private var layout
    
    let minColumnWidth: CGFloat
    let spacing: CGFloat
    @ViewBuilder let content: () -> Content
    
    init(minColumnWidth: CGFloat = 300, spacing: CGFloat = DS.Spacing.md, @ViewBuilder content: @escaping () -> Content) {
        self.minColumnWidth = minColumnWidth
        self.spacing = spacing
        self.content = content
    }
    
    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: minColumnWidth), spacing: spacing)],
            spacing: spacing,
            content: content
        )
    }
}

// MARK: - Two Column Layout (iPad Sidebar + Detail)

struct TwoColumnLayout<Sidebar: View, Detail: View>: View {
    @Environment(\.adaptiveLayout) private var layout
    
    let sidebar: Sidebar
    let detail: Detail
    
    init(@ViewBuilder sidebar: () -> Sidebar, @ViewBuilder detail: () -> Detail) {
        self.sidebar = sidebar()
        self.detail = detail()
    }
    
    var body: some View {
        if layout.usesSplitView {
            HStack(spacing: 0) {
                sidebar
                    .frame(width: 320)
                    .background(Color.themeSurfacePrimary)
                
                Divider()
                
                detail
                    .frame(maxWidth: .infinity)
            }
        } else {
            detail
        }
    }
}

// MARK: - Keyboard Shortcuts

struct KeyboardShortcutsModifier: ViewModifier {
    let onNewTask: () -> Void
    let onNewEvent: () -> Void
    let onNewHabit: () -> Void
    let onSearch: () -> Void
    let onRefresh: () -> Void
    
    func body(content: Content) -> some View {
        content
            .keyboardShortcut("n", modifiers: [.command]) // Cmd+N = New Task
            .background(
                Group {
                    Button("") { onNewTask() }
                        .keyboardShortcut("n", modifiers: [.command])
                        .hidden()
                    
                    Button("") { onNewEvent() }
                        .keyboardShortcut("e", modifiers: [.command, .shift])
                        .hidden()
                    
                    Button("") { onNewHabit() }
                        .keyboardShortcut("h", modifiers: [.command, .shift])
                        .hidden()
                    
                    Button("") { onSearch() }
                        .keyboardShortcut("f", modifiers: [.command])
                        .hidden()
                    
                    Button("") { onRefresh() }
                        .keyboardShortcut("r", modifiers: [.command])
                        .hidden()
                }
            )
    }
}

extension View {
    func keyboardShortcuts(
        onNewTask: @escaping () -> Void,
        onNewEvent: @escaping () -> Void = {},
        onNewHabit: @escaping () -> Void = {},
        onSearch: @escaping () -> Void = {},
        onRefresh: @escaping () -> Void = {}
    ) -> some View {
        modifier(KeyboardShortcutsModifier(
            onNewTask: onNewTask,
            onNewEvent: onNewEvent,
            onNewHabit: onNewHabit,
            onSearch: onSearch,
            onRefresh: onRefresh
        ))
    }
}

// MARK: - Hover Effect Modifier

struct HoverEffectModifier: ViewModifier {
    @State private var isHovered = false
    let scale: CGFloat
    let highlightColor: Color
    
    init(scale: CGFloat = 1.02, highlightColor: Color = .accentPrimary.opacity(0.1)) {
        self.scale = scale
        self.highlightColor = highlightColor
    }
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isHovered ? scale : 1.0)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .fill(isHovered ? highlightColor : Color.clear)
            )
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    isHovered = hovering
                }
            }
    }
}

extension View {
    /// Adds subtle hover effect for trackpad/mouse users
    func hoverEffect(scale: CGFloat = 1.02, highlight: Color = .accentPrimary.opacity(0.1)) -> some View {
        modifier(HoverEffectModifier(scale: scale, highlightColor: highlight))
    }
}

// MARK: - Context Menu Builder

struct TaskContextMenu: View {
    let task: FamilyTask
    let onEdit: () -> Void
    let onComplete: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Group {
            Button {
                onEdit()
            } label: {
                Label("Edit Task", systemImage: "pencil")
            }
            
            if task.status != .completed {
                Button {
                    onComplete()
                } label: {
                    Label("Mark Complete", systemImage: "checkmark.circle")
                }
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

struct EventContextMenu: View {
    let event: CalendarEvent
    let onEdit: () -> Void
    let onDelete: () -> Void
    
    var body: some View {
        Group {
            Button {
                onEdit()
            } label: {
                Label("Edit Event", systemImage: "pencil")
            }
            
            Divider()
            
            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Adaptive Sheet Presentation

struct AdaptiveSheetModifier<SheetContent: View>: ViewModifier {
    @Environment(\.adaptiveLayout) private var layout
    @Binding var isPresented: Bool
    let sheetContent: () -> SheetContent
    
    func body(content: Content) -> some View {
        if layout.prefersPopovers {
            content
                .popover(isPresented: $isPresented) {
                    sheetContent()
                        .frame(minWidth: 400, minHeight: 500)
                }
        } else {
            content
                .sheet(isPresented: $isPresented) {
                    sheetContent()
                }
        }
    }
}

extension View {
    /// Presents as popover on iPad/Mac, sheet on iPhone
    func adaptiveSheet<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        modifier(AdaptiveSheetModifier(isPresented: isPresented, sheetContent: content))
    }
}

// MARK: - Max Width Container (for readable content on large screens)

struct ReadableWidthContainer<Content: View>: View {
    @Environment(\.adaptiveLayout) private var layout
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        HStack {
            Spacer(minLength: 0)
            content
                .frame(maxWidth: layout.maxContentWidth)
            Spacer(minLength: 0)
        }
    }
}

// MARK: - Orientation Support

struct OrientationInfo {
    let isLandscape: Bool
    let isPortrait: Bool
    let isUpsideDown: Bool
}

struct OrientationKey: EnvironmentKey {
    static let defaultValue = OrientationInfo(isLandscape: false, isPortrait: true, isUpsideDown: false)
}

extension EnvironmentValues {
    var orientationInfo: OrientationInfo {
        get { self[OrientationKey.self] }
        set { self[OrientationKey.self] = newValue }
    }
}

// MARK: - Split View / Slide Over Support

struct MultitaskingModifier: ViewModifier {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    func body(content: Content) -> some View {
        content
            // Ensure minimum width for Slide Over
            .frame(minWidth: 320)
            // Adapt to size class changes (entering/exiting Split View)
            .animation(.easeInOut(duration: 0.3), value: horizontalSizeClass)
    }
}

extension View {
    func supportsMultitasking() -> some View {
        modifier(MultitaskingModifier())
    }
}

// MARK: - Preview Helpers

#Preview("Adaptive Grid - iPad") {
    AdaptiveGrid(minColumnWidth: 300) {
        ForEach(0..<6) { i in
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.accentPrimary.opacity(0.2))
                .frame(height: 100)
                .overlay(Text("Item \(i + 1)"))
        }
    }
    .padding()
}

#Preview("Hover Effect") {
    VStack(spacing: 20) {
        Text("Hover over me")
            .padding()
            .background(Color.themeCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
            .hoverEffect()
        
        Text("No hover effect")
            .padding()
            .background(Color.themeCardBackground)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
    }
    .padding()
}
