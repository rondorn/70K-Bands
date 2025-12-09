//
//  SharedPreferencesImportHandler.swift
//  70K Bands
//
//  Handles importing shared preference files when opened in the app
//

import Foundation
import UIKit

class SharedPreferencesImportHandler {
    static let shared = SharedPreferencesImportHandler()
    
    private let sharingManager = SharedPreferencesManager.shared
    private var pendingImportSet: SharedPreferenceSet?
    
    private init() {}
    
    /// Handles an incoming file URL (called from AppDelegate)
    /// - Parameter url: URL of the file to import
    /// - Returns: true if handled successfully
    func handleIncomingFile(_ url: URL) -> Bool {
        print("📥 Handling incoming file: \(url.lastPathComponent)")
        print("📥 Full URL: \(url.absoluteString)")
        print("📥 Path: \(url.path)")
        print("📥 Is file URL: \(url.isFileURL)")
        
        // Start accessing security-scoped resource (needed for files from external sources)
        let shouldStopAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStopAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        // For files from external sources (like iMessage), we may need to copy to temp location
        var fileToRead = url
        var tempFile: URL?
        
        // Check if we can read the file directly
        if !FileManager.default.fileExists(atPath: url.path) {
            print("📥 File not directly accessible, may be in inbox")
            // File might be in app's Inbox - common for files opened from other apps
            let inboxPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("Inbox")
                .appendingPathComponent(url.lastPathComponent)
            
            if FileManager.default.fileExists(atPath: inboxPath.path) {
                print("📥 Found file in Inbox: \(inboxPath.path)")
                fileToRead = inboxPath
            }
        }
        
        // Copy to temporary location if needed for processing
        do {
            let tempDir = FileManager.default.temporaryDirectory
            tempFile = tempDir.appendingPathComponent(url.lastPathComponent)
            
            // Remove existing temp file if any
            try? FileManager.default.removeItem(at: tempFile!)
            
            // Copy to temp
            try FileManager.default.copyItem(at: fileToRead, to: tempFile!)
            print("📥 Copied file to temp location: \(tempFile!.path)")
            fileToRead = tempFile!
        } catch {
            print("⚠️ Could not copy to temp, using original: \(error)")
        }
        
        // Validate and parse the file
        guard let preferenceSet = sharingManager.validateImportedFile(at: fileToRead) else {
            showErrorAlert(message: "This file is not a valid 70K Bands share file.")
            
            // Clean up temp file
            if let tempFile = tempFile {
                try? FileManager.default.removeItem(at: tempFile)
            }
            
            return false
        }
        
        // Store temporarily and show import dialog
        pendingImportSet = preferenceSet
        
        // Schedule dialog to show after a brief delay to ensure UI is ready
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showImportDialog(preferenceSet: preferenceSet)
        }
        
        // Clean up temp file after delay
        if let tempFile = tempFile {
            DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
                try? FileManager.default.removeItem(at: tempFile)
            }
        }
        
        return true
    }
    
    /// Shows dialog to accept and name the imported share
    private func showImportDialog(preferenceSet: SharedPreferenceSet) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let topVC = windowScene.windows.first?.rootViewController else {
                return
            }
            
            let alert = UIAlertController(
                title: "Import Shared Preferences",
                message: "'\(preferenceSet.senderName)' wants to share their preferences with you.\n\n\(preferenceSet.priorities.count) band priorities\n\(preferenceSet.attendance.count) scheduled events\n\nChoose a name to save this share:",
                preferredStyle: .alert
            )
            
            alert.addTextField { textField in
                textField.placeholder = "e.g., \(preferenceSet.senderName)"
                textField.text = preferenceSet.senderName
                textField.autocapitalizationType = .words
            }
            
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel) { _ in
                self.pendingImportSet = nil
            })
            
            alert.addAction(UIAlertAction(title: "Import", style: .default) { [weak self] _ in
                guard let self = self,
                      let textField = alert.textFields?.first,
                      let customName = textField.text,
                      !customName.isEmpty else {
                    return
                }
                
                self.completeImport(customName: customName)
            })
            
            // Present from the top-most view controller
            var presenter = topVC
            while let presented = presenter.presentedViewController {
                presenter = presented
            }
            presenter.present(alert, animated: true)
        }
    }
    
    /// Completes the import with the user's chosen name
    private func completeImport(customName: String) {
        guard let preferenceSet = pendingImportSet else { return }
        
        if sharingManager.importPreferenceSet(preferenceSet, withName: customName) {
            print("✅ [IMPORT_HANDLER] Import successful, switching to imported profile")
            
            // CRITICAL: Switch to the imported profile (using UserID as the profile key)
            let profileKey = preferenceSet.senderUserId
            sharingManager.setActivePreferenceSource(profileKey)
            
            print("✅ [IMPORT_HANDLER] Switched to profile: \(profileKey)")
            
            showSuccessAlert(message: "Successfully imported '\(customName)'!\n\nShowing preferences from '\(customName)'.")
            
            // Refresh the UI - this will trigger a full data reload with the new profile
            NotificationCenter.default.post(name: Notification.Name("refreshGUI"), object: nil)
        } else {
            showErrorAlert(message: "Failed to import. The name '\(customName)' may already be in use. Please try a different name.")
            
            // Show dialog again with different name suggestion
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                var modifiedSet = preferenceSet
                // Create a new set with modified sender name to retry
                let retrySet = SharedPreferenceSet(
                    senderUserId: preferenceSet.senderUserId,
                    senderName: "\(customName) 2",
                    shareDate: preferenceSet.shareDate,
                    eventYear: preferenceSet.eventYear,
                    priorities: preferenceSet.priorities,
                    attendance: preferenceSet.attendance
                )
                self.pendingImportSet = retrySet
                self.showImportDialog(preferenceSet: retrySet)
            }
        }
        
        pendingImportSet = nil
    }
    
    /// Shows success alert
    private func showSuccessAlert(message: String) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let topVC = windowScene.windows.first?.rootViewController else {
                return
            }
            
            let alert = UIAlertController(
                title: "Import Successful",
                message: message,
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            var presenter = topVC
            while let presented = presenter.presentedViewController {
                presenter = presented
            }
            presenter.present(alert, animated: true)
        }
    }
    
    /// Shows error alert
    private func showErrorAlert(message: String) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let topVC = windowScene.windows.first?.rootViewController else {
                return
            }
            
            let alert = UIAlertController(
                title: "Import Failed",
                message: message,
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: "OK", style: .default))
            
            var presenter = topVC
            while let presented = presenter.presentedViewController {
                presenter = presented
            }
            presenter.present(alert, animated: true)
        }
    }
}

