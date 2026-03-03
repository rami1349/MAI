//
//  FamilyView.swift
//  FamilyHub
//
//  Family members and settings view
//  Features: Banner image, activity heatmap, progress trend
//
//  iPad Layout: 2-column design
//  - Full-width banner header
//  - Left column: User profile + Contribution map
//  - Right column: Reward wallet + Action buttons
//

import SwiftUI
import PhotosUI

struct FamilyView: View {
    @Environment(AuthViewModel.self) var authViewModel
    @Environment(FamilyViewModel.self) var familyViewModel

    @Environment(FamilyMemberViewModel.self) var familyMemberVM
    @Environment(TaskViewModel.self) var taskVM
    @Environment(HabitViewModel.self) var habitVM
    @Environment(RewardViewModel.self) var rewardVM
    @Environment(ThemeManager.self) var themeManager
    
    // MARK: - iPad Adaptation
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    private var isRegularWidth: Bool {
        horizontalSizeClass == .regular
    }
    
    @State private var showInviteCode = false
    @State private var showSettings = false
    @State private var showEditProfile = false
    @State private var showFamilyMembers = false
    @State private var showRewardWallet = false
    @State private var selectedMember: FamilyUser?
    @State private var selectedBannerPhoto: PhotosPickerItem?
    @State private var isUploadingBanner = false
    @State private var heatmapMonth: Date = Date()  // For heatmap month navigation
    
    var body: some View {
        contentView
            .navigationTitle(L10n.family)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showSettings = true } label: {
                        Image(systemName: "gearshape.fill").foregroundStyle(.textPrimary)
                    }
                }
            }
            .sheet(isPresented: $showInviteCode) {
                InviteCodeSheet()
                    .presentationBackground(Color.themeSurfacePrimary)
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
                    .presentationBackground(Color.themeSurfacePrimary)
            }
            .sheet(isPresented: $showEditProfile) {
                EditProfileSheet()
                    .presentationBackground(Color.themeSurfacePrimary)
            }
            .sheet(isPresented: $showFamilyMembers) {
                FamilyMembersListView()
                    .presentationBackground(Color.themeSurfacePrimary)
            }
            .sheet(isPresented: $showRewardWallet) {
                RewardWalletView()
                    .presentationBackground(Color.themeSurfacePrimary)
            }
            .sheet(item: $selectedMember) {
                MemberDetailView(member: $0)
                    .presentationBackground(Color.themeSurfacePrimary)
            }
            .onChange(of: selectedBannerPhoto) { _, newValue in
                loadBannerPhoto(newValue)
        }
        .onAppear {
            // Only reset heatmap when it's a new year (fresh start for new year)
            let calendar = Calendar.current
            let currentYear = calendar.component(.year, from: Date())
            let heatmapYear = calendar.component(.year, from: heatmapMonth)
            
            // If it's a new year, reset to current month (fresh start)
            if heatmapYear != currentYear {
                heatmapMonth = Date()
                Task {
                    await loadHabitLogsForMonth(heatmapMonth)
                }
            }
        }
        .task {
            // Load habit logs for the current month heatmap (habits auto-synced by listener)
            await loadHabitLogsForMonth(heatmapMonth)
        }
    }
    
    // MARK: - Content View (with theme-based id for refresh)
    private var contentView: some View {
        ZStack {
            AdaptiveBackgroundView()
            
            ScrollView(showsIndicators: false) {
                VStack(spacing: DS.Spacing.xxl) {
                    // Full-width banner header
                    familyBannerHeader
                    
                    // iPad: 2-column layout / iPhone: single column
                    if isRegularWidth {
                        iPadTwoColumnLayout
                    } else {
                        iPhoneSingleColumnLayout
                    }
                }
                .padding(.horizontal, DS.Layout.adaptiveScreenPadding)
                .padding(.bottom, DS.Spacing.jumbo)
            }
        }
        .id("\(themeManager.currentTheme.rawValue)-\(themeManager.appearanceMode.rawValue)")
    }
    
    // MARK: - iPad Two-Column Layout
    
    private var iPadTwoColumnLayout: some View {
        HStack(alignment: .top, spacing: DS.Spacing.xxl) {
            // Left Column: Contribution Map only
            VStack(spacing: DS.Spacing.xl) {
                MonthlyActivityHeatmap(
                    tasks: userTasks,
                    habitLogs: userHabitLogs,
                    displayMonth: $heatmapMonth,
                    onMonthChange: { newMonth in
                        Task {
                            await loadHabitLogsForMonth(newMonth)
                        }
                    }
                )
            }
            .frame(maxWidth: .infinity)
            
            // Right Column: Rewards Wallet + Actions
            VStack(spacing: DS.Spacing.lg) {
                // Reward Wallet Card (prominent)
                rewardWalletCard
                
                // Action Buttons
                VStack(spacing: DS.Spacing.md) {
                    ActionButton(title: L10n.inviteFamilyMember, icon: "person.badge.plus", color: .accentPrimary) {
                        showInviteCode = true
                    }
                    
                    ActionButton(title: "Family Members", icon: "person.3.fill", color: .accentTertiary) {
                        showFamilyMembers = true
                    }
                    
                    ActionButton(title: "Edit Profile", icon: "person.crop.circle", color: .accentSecondary) {
                        showEditProfile = true
                    }
                }
            }
            .frame(width: 360)
        }
    }
    
    // MARK: - iPhone Single-Column Layout
    
    private var iPhoneSingleColumnLayout: some View {
        VStack(spacing: DS.Spacing.xxl) {
            if let user = authViewModel.currentUser {
                currentUserCard(user: user)
            }
            
            actionsSection
        }
    }
    
    // MARK: - Reward Wallet Card (iPad - Prominent)
    
    private var rewardWalletCard: some View {
        Button(action: { showRewardWallet = true }) {
            VStack(spacing: DS.Spacing.lg) {
                // Header
                HStack {
                    Image(systemName: "dollarsign.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.accentGreen)
                    
                    Text("Reward Wallet")
                        .font(.headline)
                        .foregroundStyle(.textPrimary)
                    
                    Spacer()
                    
                    // Pending requests badge
                    let requestsForMe = rewardVM.pendingWithdrawals.filter {
                        $0.userId != authViewModel.currentUser?.id
                    }
                    if !requestsForMe.isEmpty {
                        Text("\(requestsForMe.count) pending")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.white)
                            .padding(.horizontal, DS.Spacing.sm)
                            .padding(.vertical, DS.Spacing.xs)
                            .background(Capsule().fill(Color.accentRed))
                    }
                }
                
                // Balance display
                if let user = authViewModel.currentUser {
                    HStack {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text("Your Balance")
                                .font(.caption)
                                .foregroundStyle(.textSecondary)
                            Text(user.balance.currencyString)
                                .font(DS.Typography.displayMedium()) // was .rounded
                                .foregroundStyle(.accentGreen)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .font(.title3)
                            .foregroundStyle(.textTertiary)
                    }
                }
            }
            .padding(DS.Spacing.xl)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.xxl)
                    .fill(Color.themeCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.xxl)
                    .stroke(Color.accentGreen.opacity(0.2), lineWidth: 1)
            )
            .elevation1()
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }
    
    // Helper function to load habit logs for a specific month
    private func loadHabitLogsForMonth(_ month: Date) async {
        let calendar = Calendar.current
        let startOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: month))!
        let endOfMonth = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: startOfMonth)!
        await familyViewModel.loadHabitLogs(from: startOfMonth, to: endOfMonth)
    }
    
    // MARK: - Family Banner Header
    private var familyBannerHeader: some View {
        ZStack(alignment: .bottomTrailing) {
            // Banner Background
            ZStack {
                if let bannerURL = familyMemberVM.family?.bannerURL,
                   let url = URL(string: bannerURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                        case .failure(_):
                            defaultBannerGradient
                        case .empty:
                            defaultBannerGradient
                                .overlay(ProgressView().tint(.white))
                        @unknown default:
                            defaultBannerGradient
                        }
                    }
                } else {
                    defaultBannerGradient
                }
                
                // Upload loading overlay
                if isUploadingBanner {
                    Color.black.opacity(0.5)
                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                            .scaleEffect(1.2)
                        Text(L10n.uploading)
                            .font(.caption)
                            .foregroundStyle(.white)
                    }
                }
            }
            .frame(height: isRegularWidth ? 200 : 160)
            .frame(maxWidth: .infinity)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xxl))
            .overlay(
                // Gradient overlay for text readability
                LinearGradient(
                    colors: [.clear, .black.opacity(0.5)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xxl))
            )
            .overlay(
                // Family Name and Members - Centered
                VStack(spacing: DS.Spacing.xs) {
                    Text(familyMemberVM.family?.name ?? L10n.family)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundStyle(.white)
                        .elevation3()
                    
                    Text(L10n.xMembers(familyMemberVM.familyMembers.count))
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                        .elevation3()
                }
                .padding(.bottom, DS.Spacing.xl)
                .opacity(isUploadingBanner ? 0.5 : 1)
                , alignment: .bottom
            )
            
            // Edit Banner Button
            if !isUploadingBanner {
                PhotosPicker(selection: $selectedBannerPhoto, matching: .images) {
                    Image(systemName: "camera.fill")
                        .font(.caption)
                        .foregroundStyle(.white)
                        .padding(DS.Spacing.sm)
                        .background(Circle().fill(Color.black.opacity(0.5)))
                }
                .padding(DS.Spacing.md)
            }
        }
        .elevation1()
    }
    
    private var defaultBannerGradient: some View {
        LinearGradient(
            colors: [Color.accentPrimary, Color.accentPrimary.opacity(0.7), Color.accentTertiary],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
    
    // MARK: - Current User Card (iPhone)
    private func currentUserCard(user: FamilyUser) -> some View {
        VStack(spacing: DS.Spacing.xl) {
            // Profile Section with Edit Button
            HStack(spacing: DS.Spacing.lg) {
                // Avatar with Edit Button
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(user: user, size: 70)
                    
                    Button(action: { showEditProfile = true }) {
                        Image(systemName: "pencil")
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(DS.Spacing.sm)
                            .background(Circle().fill(Color.accentPrimary))
                    }
                    .offset(x: 4, y: 4)
                }
                
                VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                    Text(user.displayName).font(.headline)
                    
                    HStack(spacing: DS.Spacing.sm) {
                        RoleBadge(role: user.role)
                        if user.isAdult {
                            Text(L10n.adult).font(.caption).foregroundStyle(.textSecondary)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: DS.Spacing.xs) {
                    Text(L10n.balance).font(.caption).foregroundStyle(.textSecondary)
                    Text(user.balance.currencyString)
                        .font(.title3).fontWeight(.bold).foregroundStyle(.accentGreen)
                }
            }
            
            // Year Goal Section
            if let goal = user.goal, !goal.isEmpty {
                HStack(alignment: .top, spacing: DS.Spacing.sm) {
                    Image(systemName: "target")
                        .font(.subheadline)
                        .foregroundStyle(.accentPrimary)
                    
                    VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                        Text(L10n.goalForYear(currentYear))
                            .font(.caption)
                            .foregroundStyle(.textSecondary)
                        Text(goal)
                            .font(.subheadline)
                            .foregroundStyle(.textPrimary)
                            .lineLimit(2)
                    }
                    
                    Spacer()
                }
                .padding(DS.Spacing.md)
                .background(RoundedRectangle(cornerRadius: DS.Radius.card).fill(Color.accentPrimary.opacity(0.05)))
            }
            
            // Monthly Activity Heatmap
            MonthlyActivityHeatmap(
                tasks: userTasks,
                habitLogs: userHabitLogs,
                displayMonth: $heatmapMonth,
                onMonthChange: { newMonth in
                    Task {
                        await loadHabitLogsForMonth(newMonth)
                    }
                }
            )
        }
        .padding(DS.Spacing.xl)
        .background(RoundedRectangle(cornerRadius: DS.Radius.xxl).fill(Color.themeCardBackground))
        .elevation1()
    }
    
    private var currentYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy"
        return formatter.string(from: Date())
    }
    
    // Tasks that belong to the current user (assigned to them OR created by them with no assignee)
    private var userTasks: [FamilyTask] {
        guard let userId = authViewModel.currentUser?.id else { return [] }
        return taskVM.allTasks.filter { task in
            task.assignedTo == userId || (task.assignedTo == nil && task.assignedBy == userId)
        }
    }
    
    // Habit logs for the current user (for the current month)
    private var userHabitLogs: [String: Set<String>] {
        habitVM.habitLogs
    }
    
    // MARK: - Actions Section (iPhone)
    private var actionsSection: some View {
        VStack(spacing: DS.Spacing.md) {
            // Reward Wallet (with pending badge for parents)
            ZStack(alignment: .topTrailing) {
                ActionButton(title: "Reward Wallet", icon: "dollarsign.circle.fill", color: .accentGreen) {
                    showRewardWallet = true
                }
                
                let requestsForMe = rewardVM.pendingWithdrawals.filter {
                    $0.userId != authViewModel.currentUser?.id
                }
                if !requestsForMe.isEmpty {
                    Text("\(requestsForMe.count)")
                        .font(DS.Typography.micro())
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Circle().fill(Color.accentRed))
                        .offset(x: -8, y: -4)
                }
            }
            
            ActionButton(title: L10n.inviteFamilyMember, icon: "person.badge.plus", color: .accentPrimary) {
                showInviteCode = true
            }
            
            ActionButton(title: "Family Members", icon: "person.3.fill", color: .accentTertiary) {
                showFamilyMembers = true
            }
        }
    }
    
    // MARK: - Banner Photo Handler
    private func loadBannerPhoto(_ item: PhotosPickerItem?) {
        guard let item = item else { return }
        
        isUploadingBanner = true
        
        Task {
            defer {
                Task { @MainActor in
                    isUploadingBanner = false
                    selectedBannerPhoto = nil // Reset picker
                }
            }
            
            do {
                // Load as Data first, then convert to UIImage for proper handling
                if let data = try await item.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    // Compress and resize for upload
                    let resizedImage = resizeImage(uiImage, maxWidth: 1200)
                    if let jpegData = resizedImage.jpegData(compressionQuality: 0.8) {
                        await familyViewModel.updateFamilyBanner(imageData: jpegData)
                    }
                }
            } catch {
                // Photo loading failed - UI will reset via defer block
            }
        }
    }
    
    // Helper to resize image
    private func resizeImage(_ image: UIImage, maxWidth: CGFloat) -> UIImage {
        let ratio = maxWidth / image.size.width
        if ratio >= 1 { return image }
        
        let newSize = CGSize(width: maxWidth, height: image.size.height * ratio)
        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: CGRect(origin: .zero, size: newSize))
        let resizedImage = UIGraphicsGetImageFromCurrentImageContext() ?? image
        UIGraphicsEndImageContext()
        return resizedImage
    }
}

// MARK: - Monthly Activity Heatmap (Yearly Contribution Tracker)
struct MonthlyActivityHeatmap: View {
    let tasks: [FamilyTask]
    let habitLogs: [String: Set<String>]
    @Binding var displayMonth: Date
    var onMonthChange: ((Date) -> Void)?
    
    private let calendar = Calendar.current
    private let dayNames = ["S", "M", "T", "W", "T", "F", "S"]
    
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
    
    // Current display info
    private var displayYear: Int {
        calendar.component(.year, from: displayMonth)
    }
    
    private var displayMonthNum: Int {
        calendar.component(.month, from: displayMonth)
    }
    
    private var currentMonthName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter.string(from: displayMonth)
    }
    
    // Navigation bounds
    private var currentYear: Int {
        calendar.component(.year, from: Date())
    }
    
    private var currentMonth: Int {
        calendar.component(.month, from: Date())
    }
    
    private var canGoBack: Bool {
        // Can go back to January of the display year
        displayMonthNum > 1
    }
    
    private var canGoForward: Bool {
        // Can't go forward past current month of current year
        if displayYear < currentYear {
            return displayMonthNum < 12
        } else if displayYear == currentYear {
            return displayMonthNum < currentMonth
        }
        return false
    }
    
    private var completedTasks: [FamilyTask] {
        tasks.filter { $0.status == .completed && $0.completedAt != nil }
    }
    
    // Year-to-date stats
    private var yearToDateCompleted: Int {
        let yearStart = calendar.date(from: DateComponents(year: displayYear, month: 1, day: 1))!
        let yearEnd = calendar.date(from: DateComponents(year: displayYear, month: 12, day: 31))!
        
        // Count tasks completed this year
        let taskCount = completedTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return completedAt >= yearStart && completedAt <= yearEnd
        }.count
        
        // Count habit completions this year
        let yearPrefix = "\(displayYear)-"
        let habitCount = habitLogs.values.reduce(0) { total, dates in
            total + dates.filter { $0.hasPrefix(yearPrefix) }.count
        }
        
        return taskCount + habitCount
    }
    
    // Current month stats
    private var monthCompleted: Int {
        var total = 0
        for week in monthData {
            for date in week {
                if let date = date {
                    total += completedCount(for: date)
                }
            }
        }
        return total
    }
    
    // Get the days of the display month organized by weeks
    private var monthData: [[Date?]] {
        let range = calendar.range(of: .day, in: .month, for: displayMonth)!
        let numDays = range.count
        
        let components = calendar.dateComponents([.year, .month], from: displayMonth)
        guard let firstOfMonth = calendar.date(from: components) else { return [] }
        
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth) - 1
        
        var weeks: [[Date?]] = []
        var currentWeek: [Date?] = Array(repeating: nil, count: firstWeekday)
        
        for day in 1...numDays {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: firstOfMonth) {
                currentWeek.append(date)
                
                if currentWeek.count == 7 {
                    weeks.append(currentWeek)
                    currentWeek = []
                }
            }
        }
        
        if !currentWeek.isEmpty {
            while currentWeek.count < 7 {
                currentWeek.append(nil)
            }
            weeks.append(currentWeek)
        }
        
        return weeks
    }
    
    private func completedCount(for date: Date) -> Int {
        let taskCount = completedTasks.filter { task in
            guard let completedAt = task.completedAt else { return false }
            return calendar.isDate(completedAt, inSameDayAs: date)
        }.count
        
        let dateString = Self.dateFormatter.string(from: date)
        let habitCount = habitLogs.values.reduce(0) { count, dates in
            count + (dates.contains(dateString) ? 1 : 0)
        }
        
        return taskCount + habitCount
    }
    
    private func intensityColor(count: Int) -> Color {
        switch count {
        case 0:
            return Color.surfaceColor
        case 1:
            return Color.accentGreen.opacity(0.25)
        case 2:
            return Color.accentGreen.opacity(0.40)
        case 3:
            return Color.accentGreen.opacity(0.55)
        case 4:
            return Color.accentGreen.opacity(0.70)
        case 5:
            return Color.accentGreen.opacity(0.85)
        default:
            return Color.accentGreen
        }
    }
    
    private func textColor(count: Int) -> Color {
        count >= 4 ? .white : .textSecondary
    }
    
    var body: some View {
        VStack(spacing: DS.Spacing.lg) {
            // Header with year and navigation
            VStack(spacing: DS.Spacing.md) {
                // Year indicator
                HStack {
                    Text(verbatim: "\(displayYear) Contributions")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.textPrimary)
                    
                    Spacer()
                    
                    // Year total
                    HStack(spacing: 4) {
                        Image(systemName: "flame.fill")
                            .font(DS.Typography.bodySmall())
                            .foregroundStyle(.accentOrange)
                        Text(L10n.thisYearCount(yearToDateCompleted))
                            .font(.caption)
                            .foregroundStyle(.textSecondary)
                    }
                }
                
                // Month navigation
                HStack {
                    Button(action: goToPreviousMonth) {
                        Image(systemName: "chevron.left")
                            .font(DS.Typography.label())
                            .foregroundStyle(canGoBack ? .accentPrimary : .textTertiary)
                            .frame(width: DS.Avatar.sm, height: DS.Avatar.sm)
                            .background(Circle().fill(canGoBack ? Color.accentPrimary.opacity(0.1) : Color.clear))
                    }
                    .disabled(!canGoBack)
                    
                    Spacer()
                    
                    Text(currentMonthName)
                        .font(.headline)
                        .foregroundStyle(.textPrimary)
                    
                    Spacer()
                    
                    Button(action: goToNextMonth) {
                        Image(systemName: "chevron.right")
                            .font(DS.Typography.label())
                            .foregroundStyle(canGoForward ? .accentPrimary : .textTertiary)
                            .frame(width: DS.Avatar.sm, height: DS.Avatar.sm)
                            .background(Circle().fill(canGoForward ? Color.accentPrimary.opacity(0.1) : Color.clear))
                    }
                    .disabled(!canGoForward)
                }
            }
            
            // Calendar grid
            VStack(spacing: DS.Spacing.sm) {
                // Day headers
                HStack(spacing: DS.Spacing.xs) {
                    ForEach(0..<dayNames.count, id: \.self) { index in
                        Text(dayNames[index])
                            .font(DS.Typography.micro())
                            .foregroundStyle(.textTertiary)
                            .frame(maxWidth: .infinity)
                    }
                }
                
                // Week rows
                ForEach(Array(monthData.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: DS.Spacing.xs) {
                        ForEach(0..<7, id: \.self) { dayIndex in
                            if let date = week[dayIndex] {
                                let count = completedCount(for: date)
                                let dayNum = calendar.component(.day, from: date)
                                let isToday = calendar.isDateInToday(date)
                                let isFuture = date > Date()
                                
                                ZStack {
                                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                                        .fill(isFuture ? Color.surfaceColor : intensityColor(count: count))
                                    
                                    Text("\(dayNum)")
                                        .font(DS.Typography.micro()).fontWeight(isToday ? .bold : .regular)
                                        .foregroundStyle(isFuture ? .textTertiary : textColor(count: count))
                                }
                                .frame(maxWidth: .infinity)
                                .aspectRatio(1, contentMode: .fit)
                                .overlay(
                                    RoundedRectangle(cornerRadius: DS.Radius.sm)
                                        .stroke(isToday ? Color.accentPrimary : Color.clear, lineWidth: DS.Border.emphasized)
                                )
                            } else {
                                RoundedRectangle(cornerRadius: DS.Radius.sm)
                                    .fill(Color.clear)
                                    .frame(maxWidth: .infinity)
                                    .aspectRatio(1, contentMode: .fit)
                            }
                        }
                    }
                }
            }
            
            // Footer
            HStack {
                // Legend
                HStack(spacing: DS.Spacing.xs) {
                    Text(L10n.less)
                        .font(DS.Typography.micro())
                        .foregroundStyle(.textTertiary)
                    
                    ForEach([0, 1, 3, 5, 6], id: \.self) { level in
                        RoundedRectangle(cornerRadius: 3)
                            .fill(intensityColor(count: level))
                            .frame(width: DS.IconSize.xs, height: DS.IconSize.xs)
                    }
                    
                    Text(L10n.moreLabel)
                        .font(DS.Typography.micro())
                        .foregroundStyle(.textTertiary)
                }
                
                Spacer()
                
                // Month total
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(DS.Typography.micro())
                        .foregroundStyle(.accentGreen)
                    Text(L10n.thisMonthCount(monthCompleted))
                        .font(DS.Typography.micro())
                        .foregroundStyle(.textSecondary)
                }
            }
        }
        .padding(DS.Spacing.lg)
        .background(RoundedRectangle(cornerRadius: DS.Radius.xl).fill(Color.themeCardBackground))
    }
    
    private func goToPreviousMonth() {
        guard canGoBack else { return }
        if let newMonth = calendar.date(byAdding: .month, value: -1, to: displayMonth) {
            displayMonth = newMonth
            onMonthChange?(newMonth)
        }
    }
    
    private func goToNextMonth() {
        guard canGoForward else { return }
        if let newMonth = calendar.date(byAdding: .month, value: 1, to: displayMonth) {
            displayMonth = newMonth
            onMonthChange?(newMonth)
        }
    }
}

// MARK: - Supporting Views

struct StatItem: View {
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            Text(value).font(DS.Typography.heading()).foregroundStyle(.textPrimary)
            Text(label).font(DS.Typography.bodySmall()).foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct RoleBadge: View {
    let role: FamilyUser.UserRole
    
    private var color: Color {
        switch role {
        case .admin: return .accentOrange
        case .adult: return .accentPrimary
        case .member: return .accentTertiary
        }
    }
    
    var body: some View {
        Text(role.rawValue.capitalized)
            .font(.caption).fontWeight(.medium)
            .foregroundStyle(color)
            .padding(.horizontal, DS.Spacing.sm).padding(.vertical, DS.Spacing.xs)
            .background(Capsule().fill(color.opacity(0.1)))
    }
}

struct ActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DS.Spacing.md) {
                Image(systemName: icon)
                    .font(.title3).foregroundStyle(color)
                    .frame(width: DS.Avatar.md, height: DS.Avatar.md)
                    .background(Circle().fill(color.opacity(0.1)))
                
                Text(title).font(DS.Typography.label()).foregroundStyle(.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.textTertiary)
            }
            .padding(DS.Spacing.lg)
            .background(RoundedRectangle(cornerRadius: DS.Radius.xl).fill(Color.themeCardBackground))
            .elevation1()
        }
        .buttonStyle(.plain)
        .hoverEffect()
    }
}

struct SectionHeader: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: icon).foregroundStyle(.accentPrimary)
            Text(title).font(DS.Typography.heading()).foregroundStyle(.textPrimary)
        }
    }
}

#Preview {
    FamilyView()
        .environment(AuthViewModel())
        .environment({ let vm = FamilyViewModel(); return vm }())
        .environment({ let vm = FamilyViewModel(); return vm.familyMemberVM }())
        .environment({ let vm = FamilyViewModel(); return vm.taskVM }())
        .environment({ let vm = FamilyViewModel(); return vm.calendarVM }())
        .environment({ let vm = FamilyViewModel(); return vm.habitVM }())
        .environment({ let vm = FamilyViewModel(); return vm.notificationVM }())
        .environment({ let vm = FamilyViewModel(); return vm.rewardVM }())
        .environment(ThemeManager.shared)
}
