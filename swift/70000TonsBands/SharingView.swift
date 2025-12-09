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
            .alert(NSLocalizedString("Name Your Share", comment: "Name share dialog title"), isPresented: $viewModel.showNamePrompt) {
                TextField("e.g., John's iPhone", text: $viewModel.shareName)
                Button(NSLocalizedString("Cancel", comment: "Cancel button"), role: .cancel) { }
                Button("Share") {
                    viewModel.exportPreferences()
                }
            } message: {
                Text(NSLocalizedString("Give this share a name so the recipient can identify you.", comment: "Name share dialog message"))
            }
            .alert(NSLocalizedString("Export Failed", comment: "Export error alert title"), isPresented: $viewModel.showExportError) {
                Button(NSLocalizedString("OK", comment: "OK button")) { }
            } message: {
                Text(NSLocalizedString("Failed to export preferences. Please try again.", comment: "Export error message"))
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
                        .font(.system(size: 24))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(NSLocalizedString("Share Your Preferences", comment: "Share feature title"))
                            .foregroundColor(.primary)
                            .font(.headline)
                        Text(NSLocalizedString("Share your Must/Might/Won't priorities and attended events with another user.", comment: "Share feature description"))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.leading, 8)
                    
                    Spacer()
                }
                .padding(.vertical, 8)
            }
        } header: {
            Text(NSLocalizedString("Export Your Profile", comment: "Section header for export"))
        } footer: {
            Text(NSLocalizedString("Your Default profile will be exported. Recipients can import it and view your preferences.", comment: "Export section footer"))
                .font(.caption)
        }
    }
}

// MARK: - View Model

class SharingViewModel: ObservableObject {
    @Published var shareName: String = ""
    @Published var showNamePrompt = false
    @Published var showShareSheet = false
    @Published var showExportError = false
    @Published var exportedFileURL: URL?
    
    private let sharingManager = SharedPreferencesManager.shared
    
    init() {
        // Pre-populate with device name
        shareName = UIDevice.current.name
    }
    
    func exportPreferences() {
        guard !shareName.isEmpty else {
            showExportError = true
            return
        }
        
        print("📤 Starting export with name: \(shareName)")
        
        // Always export from Default profile with sender's chosen name
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
            // Don't reset shareName - keep it for next time
        } else {
            print("❌ Export failed")
            showExportError = true
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
        let appName = FestivalConfig.current.appName
        let cleanFileName = fileName.replacingOccurrences(of: ".70kshare", with: "").replacingOccurrences(of: ".mdfshare", with: "")
        let shareText = "\(appName) Shared Preferences: \(cleanFileName)"
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

