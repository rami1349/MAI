//
//  ProofCaptureView.swift
//  FamilyHub
//
//  ENHANCED: Vision preprocessing + Smart auto-verify (homework only)
//
//  - Chores: Upload → Parent manually approves (no AI cost)
//  - Homework: Upload → AI auto-verifies → Parent sees result
//

import SwiftUI
import PhotosUI
import AVKit
import PDFKit
import UniformTypeIdentifiers
import QuickLook
import UniformTypeIdentifiers

// MARK: - Proof Item Model

enum ProofItemType: String, Codable {
    case image
    case video
    case pdf
    case document
    
    var icon: String {
        switch self {
        case .image: return "photo.fill"
        case .video: return "video.fill"
        case .pdf: return "doc.fill"
        case .document: return "doc.text.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .image: return .blue
        case .video: return .purple
        case .pdf: return .red
        case .document: return .orange
        }
    }
}

struct ProofItem: Identifiable {
    let id = UUID()
    let type: ProofItemType
    let data: Data
    let fileName: String?
    let thumbnail: UIImage?
    let localURL: URL?
    
    // Preprocessing metadata
    var wasEnhanced: Bool = false
    var qualityScore: Float = 0.5
    var hasTextDetected: Bool = true
    
    var displayName: String {
        fileName ?? "\(type.rawValue.capitalized) \(id.uuidString.prefix(4))"
    }
    
    var fileSizeString: String {
        let bytes = Double(data.count)
        if bytes < 1024 {
            return "\(Int(bytes)) B"
        } else if bytes < 1024 * 1024 {
            return String(format: "%.1f KB", bytes / 1024)
        } else {
            return String(format: "%.1f MB", bytes / (1024 * 1024))
        }
    }
}

// MARK: - Video Transferable (for PhotosPicker video support)

struct VideoTransferable: Transferable {
    let url: URL
    
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}

// MARK: - Main View

struct ProofCaptureView: View {
    @Environment(\.dismiss) var dismiss
    @Environment(FamilyViewModel.self) var familyViewModel
    @Environment(AuthViewModel.self) var authViewModel
    let task: FamilyTask
    
    @State private var proofItems: [ProofItem] = []
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showCamera = false
    @State private var showDocumentPicker = false
    @State private var isUploading = false
    @State private var uploadProgress: Double = 0
    @State private var errorMessage: String?
    @State private var selectedPreviewItem: ProofItem?
    @State private var showFullPreview = false
    
    // Preprocessing state
    @State private var isProcessingImage = false
    @State private var processingMessage = "Enhancing image..."
    @State private var showNoTextWarning = false
    
    // MARK: - Size Budget (replaces item count limit)
    // A byte budget is fairer than a fixed item count — a single 4K video
    // could be 80 MB while 6 compressed homework photos might total 3 MB.
    
    private let maxTotalBytes: Int = 100 * 1024 * 1024   // 100 MB total budget
    private let maxSingleFileBytes: Int = 25 * 1024 * 1024 // 25 MB per file
    
    private var currentTotalBytes: Int {
        proofItems.reduce(0) { $0 + $1.data.count }
    }
    
    private var remainingBytes: Int {
        max(0, maxTotalBytes - currentTotalBytes)
    }
    
    private var canAddMore: Bool {
        remainingBytes > 0
    }
    
    // Check if this is a homework task that will auto-verify
    private var willAutoVerify: Bool {
        task.shouldAutoVerify
    }
    
    // All proof source types are always available — no more gating by ProofType
    
    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackgroundView()
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    ScrollView {
                        VStack(spacing: DS.Spacing.xl) {
                            taskInfoSection
                            
                            if proofItems.isEmpty {
                                emptyStateView
                            } else {
                                proofPreviewSection
                            }
                            
                            if canAddMore {
                                addProofSection
                            }
                        }
                        .padding(.vertical, DS.Spacing.lg)
                    }
                    
                    VStack(spacing: DS.Spacing.md) {
                        if let error = errorMessage {
                            errorBanner(error)
                        }
                        
                        if isUploading {
                            uploadProgressView
                        }
                        
                        submitButton
                    }
                    .padding(DS.Spacing.lg)
                    .background(Color.backgroundPrimary)
                }
                
                // Processing overlay
                if isProcessingImage {
                    ImageProcessingOverlay(message: processingMessage)
                }
            }
            .navigationTitle("Submit Proof")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isUploading || isProcessingImage)
                }
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                Task { await loadPhotoPickerItems(newItems) }
            }
            .fullScreenCover(isPresented: $showCamera) {
                ProofCameraView { imageData in
                    addImageProofEnhanced(imageData)
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                ProofDocumentPicker(
                    allowedTypes: [.pdf, .image,  .jpeg,  .png,   .heic, .movie, .quickTimeMovie,.mpeg4Movie, .text,.plainText,  .rtf ]
                ) { url in
                    Task { await loadDocument(from: url) }
                }
            }
            .sheet(isPresented: $showFullPreview) {
                if let item = selectedPreviewItem {
                    ProofPreviewSheet(item: item)
                }
            }
            .alert("No Text Detected", isPresented: $showNoTextWarning) {
                Button("Use Anyway") { }
                Button("Retake", role: .cancel) {
                    if let lastItem = proofItems.last {
                        proofItems.removeAll { $0.id == lastItem.id }
                    }
                }
            } message: {
                Text("This image may not contain readable homework. The AI might have trouble verifying it.")
            }
        }
    }
    
    // MARK: - Task Info Section
    
    private var taskInfoSection: some View {
        VStack(spacing: DS.Spacing.sm) {
            // Task type badge
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: task.taskType?.icon ?? "checklist")
                Text(task.taskType?.displayName ?? "Task")
            }
            .font(.caption)
            .fontWeight(.medium)
            .foregroundStyle(task.taskType == .homework ? .accentPrimary : .textSecondary)
            .padding(.horizontal, DS.Spacing.md)
            .padding(.vertical, DS.Spacing.xs)
            .background(
                Capsule().fill(
                    task.taskType == .homework
                    ? Color.accentPrimary.opacity(0.15)
                    : Color.backgroundSecondary
                )
            )
            
            Text(task.title)
                .font(.title3)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
            
            if task.hasReward, let amount = task.rewardAmount {
                HStack(spacing: DS.Spacing.xs) {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundStyle(.accentGreen)
                    Text("Earn \(amount.currencyString)")
                        .fontWeight(.medium)
                }
                .font(.subheadline)
                .foregroundStyle(.accentGreen)
            }
            
            // Show what will happen after submit
            verificationInfoBadge
            
            HStack(spacing: DS.Spacing.xs) {
                Image(systemName: "paperclip")
                Text("\(proofItems.count) file\(proofItems.count == 1 ? "" : "s") · \(formatBytes(currentTotalBytes)) / \(formatBytes(maxTotalBytes))")
            }
            .font(.caption)
            .foregroundStyle(.textSecondary)
        }
        .padding(.horizontal)
    }
    
    // MARK: - Verification Info Badge
    
    private var verificationInfoBadge: some View {
        HStack(spacing: DS.Spacing.xs) {
            if willAutoVerify {
                Image("samy")
                    .resizable()
                    .scaledToFit()
                    .frame(width: DS.IconSize.md, height: DS.IconSize.md)
                Text("MAI will check your work")
            } else {
                Image(systemName: "person.fill")
                Text("Parent will review")
            }
        }
        .font(.caption)
        .foregroundStyle(willAutoVerify ? .purple : .textSecondary)
        .padding(.horizontal, DS.Spacing.md)
        .padding(.vertical, DS.Spacing.xs)
        .background(
            Capsule().fill(
                willAutoVerify
                ? Color.purple.opacity(0.1)
                : Color.backgroundSecondary
            )
        )
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: DS.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.accentPrimary.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "doc.badge.plus")
                    .font(DS.Typography.displayLarge())
                    .foregroundStyle(.accentPrimary)
            }
            
            VStack(spacing: DS.Spacing.xs) {
                Text("Add Proof of Completion")
                    .font(.headline)
                
                Text("Upload photos, videos, or documents to show your work")
                    .font(.subheadline)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            
            // Tips for homework photos (only show for homework)
            if task.taskType == .homework {
                VStack(spacing: DS.Spacing.xs) {
                    Text("Tips for homework photos:")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.textSecondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        tipRow("Good lighting – avoid shadows")
                        tipRow("Flat surface – lay paper flat")
                        tipRow("Full page – capture all work")
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: DS.Radius.card)
                        .fill(Color.accentPrimary.opacity(0.05))
                )
                .padding(.horizontal)
            }
            
            HStack(spacing: DS.Spacing.lg) {
                ForEach([ProofItemType.image, .video, .pdf, .document], id: \.self) { type in
                    VStack(spacing: 4) {
                        Image(systemName: type.icon)
                            .font(.title3)
                            .foregroundStyle(type.color)
                        Text(type.rawValue.capitalized)
                            .font(.caption2)
                            .foregroundStyle(.textSecondary)
                    }
                }
            }
            .padding(.top, DS.Spacing.sm)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Spacing.xxl)
        .padding(.horizontal)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(Color.backgroundCard)
        )
        .padding(.horizontal)
    }
    
    private func tipRow(_ text: String) -> some View {
        HStack(spacing: DS.Spacing.xs) {
            Image(systemName: "checkmark.circle.fill")
                .font(.caption2)
                .foregroundStyle(.accentGreen)
            Text(text)
                .font(.caption)
                .foregroundStyle(.textSecondary)
        }
    }
    
    // MARK: - Proof Preview Section
    
    private var proofPreviewSection: some View {
        VStack(spacing: DS.Spacing.md) {
            ForEach(proofItems) { item in
                ProofPreviewCard(
                    item: item,
                    onTap: {
                        selectedPreviewItem = item
                        showFullPreview = true
                    },
                    onRemove: {
                        proofItems.removeAll { $0.id == item.id }
                    },
                    showQualityBadge: item.type == .image && task.taskType == .homework
                )
            }
        }
        .padding(.horizontal)
    }
    
    // MARK: - Add Proof Section
    
    // MARK: - Add Proof Section
    
    private var addProofSection: some View {
        VStack(spacing: DS.Spacing.md) {
            Text("Add More")
                .font(.subheadline)
                .foregroundStyle(.textSecondary)
            
            HStack(spacing: DS.Spacing.lg) {
                // Camera (captures photo or video)
                Button { showCamera = true } label: {
                    ProofActionButtonContent(
                        icon: "camera.fill",
                        title: "Camera",
                        color: .blue
                    )
                }
                
                // Photo Library (images + videos)
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 10,
                    matching: .any(of: [.images, .videos])
                ) {
                    ProofActionButtonContent(
                        icon: "photo.on.rectangle",
                        title: "Photos",
                        color: .green
                    )
                }
                
                // Files App (iOS Files, iCloud, etc.)
                Button { showDocumentPicker = true } label: {
                    ProofActionButtonContent(
                        icon: "folder.fill",
                        title: "Files",
                        color: .orange
                    )
                }
            }
            
            // Size budget indicator
            Text("\(formatBytes(remainingBytes)) remaining")
                .font(.caption2)
                .foregroundStyle(.textTertiary)
        }
        .padding(.horizontal)
    }
    // MARK: - Submit Button
    
    private var submitButton: some View {
        Button {
            Task { await submitProof() }
        } label: {
            HStack(spacing: DS.Spacing.sm) {
                if isUploading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                }
                Text(isUploading ? "Uploading..." : "Submit Proof")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.card)
                    .fill(proofItems.isEmpty ? Color.gray : Color.accentPrimary)
            )
            .foregroundStyle(.textOnAccent)
        }
        .disabled(proofItems.isEmpty || isUploading || isProcessingImage)
    }
    
    // MARK: - Upload Progress
    
    private var uploadProgressView: some View {
        VStack(spacing: DS.Spacing.sm) {
            ProgressView(value: uploadProgress)
                .tint(Color.accentPrimary)
            Text("\(Int(uploadProgress * 100))% uploaded")
                .font(.caption)
                .foregroundStyle(.textSecondary)
        }
    }
    
    // MARK: - Error Banner
    
    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: DS.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.statusError)
            Text(message)
                .font(.caption)
                .foregroundStyle(.statusError)
            Spacer()
            Button {
                errorMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.caption)
                    .foregroundStyle(.statusError)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md)
                .fill(Color.red.opacity(0.1))
        )
    }
    
    // MARK: - Enhanced Image Proof (with Vision preprocessing for homework)
    
    private func addImageProofEnhanced(_ data: Data) {
        guard let image = UIImage(data: data) else { return }
        
        // Only use Vision preprocessing for homework tasks
        guard task.taskType == .homework else {
            // Chores: simple compression, no fancy preprocessing
            addImageProofSimple(image, originalData: data)
            return
        }
        
        // Homework: full Vision preprocessing
        Task {
            await MainActor.run {
                isProcessingImage = true
                processingMessage = "Enhancing image..."
            }
            
            do {
                let result = try await image.preprocessedForVerification(options: .default)
                
#if DEBUG
                print("[ProofCapture] \(result)")
#endif
                
                await MainActor.run {
                    processingMessage = "Checking for text..."
                }
                
                let thumbnail = result.processedImage.preparingThumbnail(
                    of: CGSize(width: 200, height: 200)
                )
                
                await MainActor.run {
                    var item = ProofItem(
                        type: .image,
                        data: result.processedData,
                        fileName: nil,
                        thumbnail: thumbnail,
                        localURL: nil
                    )
                    item.wasEnhanced = result.wasEnhanced || result.hasPerspectiveCorrection
                    item.qualityScore = result.qualityScore
                    item.hasTextDetected = result.hasTextDetected
                    
                    let accepted = validateAndAddItem(item)
                    isProcessingImage = false
                    
                    guard accepted else { return }
                    
                    if !result.hasTextDetected {
                        showNoTextWarning = true
                    }
                    
                    if result.qualityScore >= 0.8 {
                        DS.Haptics.success()
                    } else if result.qualityScore < 0.5 {
                        DS.Haptics.warning()
                    }
                }
                
            } catch {
                print("[ProofCapture] Preprocessing failed: \(error)")
                await MainActor.run {
                    addImageProofSimple(image, originalData: data)
                    isProcessingImage = false
                }
            }
        }
    }
    
    // Simple image processing for chores (no Vision framework)
    private func addImageProofSimple(_ image: UIImage, originalData: Data) {
        let thumbnail = image.preparingThumbnail(of: CGSize(width: 200, height: 200))
        let compressedData = image.jpegData(compressionQuality: 0.75) ?? originalData
        
        let item = ProofItem(
            type: .image,
            data: compressedData,
            fileName: nil,
            thumbnail: thumbnail,
            localURL: nil
        )
        let _ = validateAndAddItem(item)
    }
    
    // MARK: - Load Photo Picker Items
    
    private func loadPhotoPickerItems(_ items: [PhotosPickerItem]) async {
        for item in items {
            guard canAddMore else { break }
            
            // Try loading as video first, then fall back to image
            if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
                await MainActor.run {
                    let videoData = (try? Data(contentsOf: movie.url)) ?? Data()
                    let proofItem = ProofItem(
                        type: .video,
                        data: videoData,
                        fileName: movie.url.lastPathComponent,
                        thumbnail: nil,
                        localURL: movie.url
                    )
                    let _ = validateAndAddItem(proofItem)
                }
            } else if let data = try? await item.loadTransferable(type: Data.self) {
                await MainActor.run {
                    addImageProofEnhanced(data)
                }
            }
        }
        
        await MainActor.run {
            selectedPhotoItems = []
        }
    }
    
    // MARK: - Load Document
    
    private func loadDocument(from url: URL) async {
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try Data(contentsOf: url)
            let fileName = url.lastPathComponent
            
            let type: ProofItemType
            let uti = UTType(filenameExtension: url.pathExtension)
            
            if uti?.conforms(to: .pdf) == true {
                type = .pdf
            } else if uti?.conforms(to: .image) == true {
                await MainActor.run {
                    addImageProofEnhanced(data)
                }
                return
            } else if uti?.conforms(to: .movie) == true {
                type = .video
            } else {
                type = .document
            }
            
            let thumbnail: UIImage? = {
                if type == .pdf, let doc = PDFDocument(data: data),
                   let page = doc.page(at: 0) {
                    let bounds = page.bounds(for: .mediaBox)
                    let scale: CGFloat = 200 / max(bounds.width, bounds.height)
                    return page.thumbnail(of: CGSize(
                        width: bounds.width * scale,
                        height: bounds.height * scale
                    ), for: .mediaBox)
                }
                return nil
            }()
            
            await MainActor.run {
                let item = ProofItem(
                    type: type,
                    data: data,
                    fileName: fileName,
                    thumbnail: thumbnail,
                    localURL: url
                )
                let _ = validateAndAddItem(item)
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load file: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Submit Proof
    
    private func submitProof() async {
        guard !proofItems.isEmpty else { return }
        
        isUploading = true
        uploadProgress = 0
        errorMessage = nil
        
        do {
            var uploadedURLs: [String] = []
            
            for (index, item) in proofItems.enumerated() {
                let url = try await familyViewModel.uploadProofFile(
                    data: item.data,
                    taskId: task.id ?? "",
                    fileType: item.type.rawValue,
                    fileName: item.fileName
                )
                uploadedURLs.append(url)
                uploadProgress = Double(index + 1) / Double(proofItems.count)
            }
            
            // SMART AUTO-VERIFY: Only trigger AI for homework
            await familyViewModel.submitProofWithSmartVerify(
                task: task,
                proofURLs: uploadedURLs,
                userId: authViewModel.currentUser?.id ?? ""
            )
            
            isUploading = false
            DS.Haptics.success()
            dismiss()
            
        } catch {
            isUploading = false
            errorMessage = "Upload failed: \(error.localizedDescription)"
            DS.Haptics.error()
        }
    }
    // MARK: - Size Budget Helpers
    
    private func formatBytes(_ bytes: Int) -> String {
        let mb = Double(bytes) / (1024 * 1024)
        if mb >= 1 {
            return String(format: "%.1f MB", mb)
        } else {
            let kb = Double(bytes) / 1024
            return String(format: "%.0f KB", kb)
        }
    }
    
    /// Validates a file against the size budget. Returns true if accepted.
    private func validateAndAddItem(_ item: ProofItem) -> Bool {
        if item.data.count > maxSingleFileBytes {
            errorMessage = "\(item.displayName) is too large (\(item.fileSizeString)). Max per file: \(formatBytes(maxSingleFileBytes))."
            return false
        }
        if currentTotalBytes + item.data.count > maxTotalBytes {
            errorMessage = "Adding this file would exceed the \(formatBytes(maxTotalBytes)) total budget. Remove some files first."
            return false
        }
        proofItems.append(item)
        return true
    }
}

struct ImageProcessingOverlay: View {
    let message: String
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()
            
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
                
                Text(message)
                    .font(.headline)
                    .foregroundStyle(.textOnAccent)
                
                Text("Optimizing for MAI")
                    .font(.caption)
                    .foregroundStyle(.textOnAccent.opacity(0.8))
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color.black.opacity(0.7))
            )
        }
    }
}

// MARK: - Proof Preview Card

struct ProofPreviewCard: View {
    let item: ProofItem
    let onTap: () -> Void
    let onRemove: () -> Void
    var showQualityBadge: Bool = false
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Group {
                if let thumbnail = item.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    ZStack {
                        Color.backgroundSecondary
                        Image(systemName: item.type.icon)
                            .font(.title2)
                            .foregroundStyle(item.type.color)
                    }
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: DS.Radius.sm))
            .onTapGesture(perform: onTap)
            
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                HStack(spacing: DS.Spacing.xs) {
                    Text(item.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    if showQualityBadge {
                        ImageQualityBadge(score: item.qualityScore)
                    }
                }
                
                HStack(spacing: DS.Spacing.sm) {
                    Text(item.fileSizeString)
                        .font(.caption)
                        .foregroundStyle(.textSecondary)
                    
                    if item.wasEnhanced {
                        HStack(spacing: 2) {
                            Image(systemName: "sparkles")
                            Text("Enhanced")
                        }
                        .font(.caption2)
                        .foregroundStyle(.accentPrimary)
                    }
                }
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.textTertiary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.card)
                .fill(Color.backgroundCard)
        )
    }
}

// MARK: - Quality Badge

struct ImageQualityBadge: View {
    let score: Float
    
    private var color: Color {
        if score >= 0.8 { return .green }
        if score >= 0.6 { return .yellow }
        return .red
    }
    
    private var icon: String {
        if score >= 0.8 { return "checkmark.circle.fill" }
        if score >= 0.6 { return "exclamationmark.circle.fill" }
        return "xmark.circle.fill"
    }
    
    private var label: String {
        if score >= 0.8 { return "Good" }
        if score >= 0.6 { return "OK" }
        return "Poor"
    }
    
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
            Text(label)
        }
        .font(.caption2)
        .fontWeight(.medium)
        .foregroundStyle(.textOnAccent)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color)
        .clipShape(Capsule())
    }
}

// MARK: - Supporting Views

struct ProofActionButtonContent: View {
    let icon: String
    let title: String
    let color: Color
    
    var body: some View {
        VStack(spacing: DS.Spacing.xs) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.15))
                    .frame(width: 56, height: 56)
                
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)
            }
            
            Text(title)
                .font(.caption)
                .foregroundStyle(.textSecondary)
        }
    }
}

// MARK: - Document Picker (iOS Files App)

struct ProofDocumentPicker: UIViewControllerRepresentable {
    let allowedTypes: [UTType]
    let onPick: (URL) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: allowedTypes)
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        
        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                onPick(url)
            }
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            // User cancelled - do nothing
        }
    }
}

struct ProofCameraView: UIViewControllerRepresentable {
    @Environment(\.dismiss) var dismiss
    let onCapture: (Data) -> Void
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: ProofCameraView
        
        init(parent: ProofCameraView) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage,
               let data = image.jpegData(compressionQuality: 1.0) {
                parent.onCapture(data)
            }
            parent.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct ProofPreviewSheet: View {
    @Environment(\.dismiss) var dismiss
    let item: ProofItem
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                switch item.type {
                case .image:
                    if let image = UIImage(data: item.data) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    }
                    
                case .video:
                    if let url = item.localURL {
                        VideoPlayer(player: AVPlayer(url: url))
                    } else {
                        ProofVideoPreviewFromData(data: item.data)
                    }
                    
                case .pdf:
                    ProofPDFPreviewView(data: item.data)
                    
                case .document:
                    VStack(spacing: DS.Spacing.lg) {
                        Image(systemName: "doc.fill")
                            .font(DS.Typography.displayLarge())
                            .foregroundStyle(.textOnAccent)
                        Text(item.displayName)
                            .foregroundStyle(.textOnAccent)
                        Text(item.fileSizeString)
                            .foregroundStyle(.gray)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                        .foregroundStyle(.textOnAccent)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

struct ProofVideoPreviewFromData: View {
    let data: Data
    @State private var player: AVPlayer?
    
    var body: some View {
        Group {
            if let player = player {
                VideoPlayer(player: player)
            } else {
                ProgressView()
            }
        }
        .onAppear {
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            try? data.write(to: tempURL)
            player = AVPlayer(url: tempURL)
        }
    }
}

struct ProofPDFPreviewView: UIViewRepresentable {
    let data: Data
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = PDFDocument(data: data)
        pdfView.autoScales = true
        pdfView.backgroundColor = .black
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {}
}
