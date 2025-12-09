//
//  SharingView.swift
//  70K Bands
//
//  SwiftUI view for managing shared preferences
//

import SwiftUI

struct SharingView: View {
    @StateObject private var viewModel = SharingViewModel()
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            Form {
                exportSection
                importedSharesSection
            }
            .navigationTitle("Share Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .preferredColorScheme(.dark)
            .sheet(isPresented: $viewModel.showShareSheet) {
                if let fileURL = viewModel.exportedFileURL {
                    ActivityViewController(
                        activityItems: [fileURL],
                        fileName: fileURL.lastPathComponent
                    )
                }
            }
            .alert("Name Your Share", isPresented: $viewModel.showNamePrompt) {
                TextField("e.g., My Favorites", text: $viewModel.shareName)
                Button("Cancel", role: .cancel) { }
                Button("Share") {
                    viewModel.exportPreferences()
                }
            } message: {
                Text("Give this share a name so the recipient can identify it.")
            }
            .alert("Export Failed", isPresented: $viewModel.showExportError) {
                Button("OK") { }
            } message: {
                Text("Failed to export preferences. Please try again.")
            }
            .alert("Share Tip", isPresented: $viewModel.showShareTip) {
                Button("OK") { }
            } message: {
                Text("Tip: In Messages, your file will appear as an attachment. Recipients can tap to download and open in 70K Bands.")
            }
        }
    }
    
    private var exportSection: some View {
        Section {
            Button(action: {
                viewModel.showNamePrompt = true
            }) {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundColor(.blue)
                    Text("Share Default")
                        .foregroundColor(.primary)
                    Spacer()
                }
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text("Share your Must/Might/Won't priorities and event schedule with other users.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        } header: {
            Text("Export")
        }
    }
    
    private var importedSharesSection: some View {
        Section {
            if viewModel.importedShares.isEmpty {
                Text("No imported shares yet")
                    .foregroundColor(.secondary)
                    .font(.caption)
            } else {
                ForEach(viewModel.importedShares, id: \.userId) { share in
                    HStack {
                        // Color indicator
                        Circle()
                            .fill(colorFromHex(share.color))
                            .frame(width: 12, height: 12)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(share.label)
                                .font(.body)
                            Text("\(share.priorityCount) priorities • \(share.attendanceCount) events")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text("Imported \(formatDate(share.importDate))")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        // Check if this UserID is the active source
                        if viewModel.activeSource == share.userId {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        // Select using UserID (the profile key)
                        viewModel.selectSource(share.userId)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            // Delete using UserID (the profile key)
                            viewModel.deleteShare(share.userId)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
        } header: {
            Text("Imported Shares")
        } footer: {
            Text("Tap a share to view it in the Filters menu. Swipe left to delete.")
                .font(.caption)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    // Helper to convert hex string to SwiftUI Color
    private func colorFromHex(_ hex: String) -> Color {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        let r = Double((rgb & 0xFF0000) >> 16) / 255.0
        let g = Double((rgb & 0x00FF00) >> 8) / 255.0
        let b = Double((rgb & 0x0000FF)) / 255.0
        
        return Color(red: r, green: g, blue: b)
    }
}

// MARK: - View Model

class SharingViewModel: ObservableObject {
    @Published var shareName: String = ""
    @Published var showNamePrompt = false
    @Published var showShareSheet = false
    @Published var showExportError = false
    @Published var showShareTip = false
    @Published var exportedFileURL: URL?
    @Published var importedShares: [ProfileMetadata] = []
    @Published var activeSource: String = "Default"
    
    private let sharingManager = SharedPreferencesManager.shared
    private let profileManager = SQLiteProfileManager.shared
    
    init() {
        loadImportedShares()
        loadActiveSource()
    }
    
    func loadImportedShares() {
        // Get all profiles except Default
        importedShares = profileManager.getAllProfiles().filter { $0.userId != "Default" }
    }
    
    func loadActiveSource() {
        activeSource = sharingManager.getActivePreferenceSource()
    }
    
    func exportPreferences() {
        guard !shareName.isEmpty else {
            showExportError = true
            return
        }
        
        print("📤 Starting export with name: \(shareName)")
        
        if let fileURL = sharingManager.exportCurrentPreferences(shareName: shareName) {
            print("📤 Export successful, preparing to share...")
            print("📤 File URL: \(fileURL.absoluteString)")
            print("📤 File exists: \(FileManager.default.fileExists(atPath: fileURL.path))")
            
            // Verify file is readable
            if let fileData = try? Data(contentsOf: fileURL) {
                print("📤 File is readable, size: \(fileData.count) bytes")
            } else {
                print("❌ File exists but not readable!")
            }
            
            exportedFileURL = fileURL
            showShareSheet = true
            shareName = "" // Reset for next time
        } else {
            print("❌ Export failed")
            showExportError = true
        }
    }
    
    func selectSource(_ profileKey: String) {
        sharingManager.setActivePreferenceSource(profileKey)
        activeSource = profileKey
        
        // Refresh main view
        NotificationCenter.default.post(name: Notification.Name("refreshGUI"), object: nil)
    }
    
    func deleteShare(_ userId: String) {
        if sharingManager.deleteImportedSet(byUserId: userId) {
            loadImportedShares()
            loadActiveSource()
            
            // Refresh main view
            NotificationCenter.default.post(name: Notification.Name("refreshGUI"), object: nil)
        }
    }
}

// MARK: - UIKit Bridge for Share Sheet

struct ActivityViewController: UIViewControllerRepresentable {
    let activityItems: [Any]
    let fileName: String
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        // Create activity items with proper configuration
        var items: [Any] = []
        
        // Add descriptive text first (helps Messages understand this is a file share)
        let shareText = "70K Bands Shared Preferences: \(fileName.replacingOccurrences(of: ".70kshare", with: ""))"
        items.append(shareText)
        
        // Add file URL(s) with custom item source
        for item in activityItems {
            if let url = item as? URL {
                // For Messages/iMessage, we want the raw URL to appear as an attachment
                // Use custom item source for metadata but keep URL for compatibility
                items.append(url)
            } else {
                items.append(item)
            }
        }
        
        let controller = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )
        
        // Exclude activities that don't make sense for files
        controller.excludedActivityTypes = [
            .assignToContact,
            .addToReadingList,
            .postToVimeo,
            .postToFlickr,
            .postToWeibo,
            .postToTencentWeibo
        ]
        
        // Configure for better file sharing
        controller.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            if let error = error {
                print("❌ Share error: \(error)")
            } else if completed {
                print("✅ Share completed via: \(activityType?.rawValue ?? "unknown")")
            }
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {
        // No update needed
    }
}

// MARK: - Custom Activity Item Source

class FileActivityItemSource: NSObject, UIActivityItemSource {
    let fileURL: URL
    
    init(fileURL: URL) {
        self.fileURL = fileURL
        super.init()
    }
    
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        return fileURL
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, itemForActivityType activityType: UIActivity.ActivityType?) -> Any? {
        // Return the file URL for all activity types
        return fileURL
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, subjectForActivityType activityType: UIActivity.ActivityType?) -> String {
        // Provide a subject line for email/messages
        let fileName = fileURL.deletingPathExtension().lastPathComponent
        return "70K Bands Shared Preferences: \(fileName)"
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?) -> String {
        // Explicitly declare the UTI
        return "com.rdorn.70kbands.share"
    }
    
    func activityViewController(_ activityViewController: UIActivityViewController, thumbnailImageForActivityType activityType: UIActivity.ActivityType?, suggestedSize size: CGSize) -> UIImage? {
        // Optionally provide a thumbnail
        return nil
    }
}

// MARK: - Hosting Controller

class SharingHostingController: UIHostingController<SharingView> {
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder, rootView: SharingView())
    }
    
    init() {
        super.init(rootView: SharingView())
    }
}

#Preview {
    SharingView()
}

