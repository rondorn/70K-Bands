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
            showErrorAlert(message: NSLocalizedString("This file is not a valid 70K Bands share file.", comment: "Invalid file error"))
            
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
    
    /// Shows dialog to accept and name the imported share (only for new profiles)
    private func showImportDialog(preferenceSet: SharedPreferenceSet) {
        DispatchQueue.main.async {
            // Check if this UserID already exists
            if let existingProfile = SQLiteProfileManager.shared.getProfile(userId: preferenceSet.senderUserId) {
                // Profile exists - update silently without prompting
                print("📥 [IMPORT] Updating existing profile: \(existingProfile.label) (\(preferenceSet.senderUserId))")
                
                // Use existing label/name
                self.completeImport(customName: existingProfile.label, isUpdate: true)
                return
            }
            
            // New profile - prompt for name
            print("📥 [IMPORT] New profile, prompting for name")
            
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let topVC = windowScene.windows.first?.rootViewController else {
                return
            }
            
            let title = NSLocalizedString("Import Shared Preferences", comment: "Import dialog title")
            let newProfileText = NSLocalizedString("New profile received!", comment: "New profile message")
            let bandPrioritiesText = NSLocalizedString("band priorities", comment: "Band priorities label")
            let scheduledEventsText = NSLocalizedString("scheduled events", comment: "Scheduled events label")
            let chooseNameText = NSLocalizedString("Choose a name for this profile:", comment: "Choose name prompt")
            let alertWarning = NSLocalizedString("Note: Event alerts will be based on your Default profile settings, not this imported profile.", comment: "Alert settings warning")
            
            let alert = UIAlertController(
                title: title,
                message: "\(newProfileText)\n\n\(preferenceSet.priorities.count) \(bandPrioritiesText)\n\(preferenceSet.attendance.count) \(scheduledEventsText)\n\n⚠️ \(alertWarning)\n\n\(chooseNameText)",
                preferredStyle: .alert
            )
            
            alert.addTextField { textField in
                textField.placeholder = "e.g., Friend's Picks"
                textField.text = preferenceSet.senderName.isEmpty ? "Shared Profile" : preferenceSet.senderName
                textField.autocapitalizationType = .words
            }
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel button"), style: .cancel) { _ in
                self.pendingImportSet = nil
            })
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("Import", comment: "Import button"), style: .default) { [weak self] _ in
                guard let self = self,
                      let textField = alert.textFields?.first,
                      let customName = textField.text,
                      !customName.isEmpty else {
                    return
                }
                
                self.completeImport(customName: customName, isUpdate: false)
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
    private func completeImport(customName: String, isUpdate: Bool) {
        guard let preferenceSet = pendingImportSet else { return }
        
        if sharingManager.importPreferenceSet(preferenceSet, withName: customName) {
            print("✅ [IMPORT_HANDLER] Import successful, switching to imported profile")
            
            // CRITICAL: Switch to the imported profile (using UserID as the profile key)
            let profileKey = preferenceSet.senderUserId
            sharingManager.setActivePreferenceSource(profileKey)
            
            print("✅ [IMPORT_HANDLER] Switched to profile: \(profileKey)")
            
            // Different message for update vs new import
            let message: String
            if isUpdate {
                let updatedText = NSLocalizedString("Updated", comment: "Updated status")
                let withNewDataText = NSLocalizedString("with new data!", comment: "With new data message")
                let showingPrefsText = NSLocalizedString("Showing preferences from", comment: "Showing preferences message")
                message = "\(updatedText) '\(customName)' \(withNewDataText)\n\n\(showingPrefsText) '\(customName)'."
            } else {
                let successText = NSLocalizedString("Successfully imported", comment: "Success message")
                let showingPrefsText = NSLocalizedString("Showing preferences from", comment: "Showing preferences message")
                message = "\(successText) '\(customName)'!\n\n\(showingPrefsText) '\(customName)'."
            }
            
            showSuccessAlert(message: message, isNewProfile: !isUpdate)
            
            // Refresh the UI - this will trigger a full data reload with the new profile
            NotificationCenter.default.post(name: Notification.Name("refreshGUI"), object: nil)
        } else {
            showErrorAlert(message: NSLocalizedString("Failed to import. Please try again.", comment: "Import failed message"))
            
            // Only retry for new profiles, not updates
            if !isUpdate {
                // Show dialog again with different name suggestion
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
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
        }
        
        pendingImportSet = nil
    }
    
    /// Shows success alert
    private func showSuccessAlert(message: String, isNewProfile: Bool) {
        DispatchQueue.main.async {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let topVC = windowScene.windows.first?.rootViewController else {
                return
            }
            
            let title = isNewProfile ? NSLocalizedString("Import Successful", comment: "Import success title") : NSLocalizedString("Profile Updated", comment: "Profile updated title")
            
            let alert = UIAlertController(
                title: title,
                message: message,
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK button"), style: .default) { _ in
                // Show tutorial overlay only for NEW profiles (not updates)
                if isNewProfile {
                    self.showProfileSwitchTutorial()
                }
            })
            
            var presenter = topVC
            while let presented = presenter.presentedViewController {
                presenter = presented
            }
            presenter.present(alert, animated: true)
        }
    }
    
    /// Shows tutorial overlay pointing to the profile switcher
    private func showProfileSwitchTutorial() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let topVC = windowScene.windows.first?.rootViewController else {
                return
            }
            
            // Find the MasterViewController
            var targetVC: UIViewController? = topVC
            if let navController = topVC as? UINavigationController {
                targetVC = navController.viewControllers.first
            } else if let splitVC = topVC as? UISplitViewController {
                targetVC = splitVC.viewControllers.first
                if let navController = targetVC as? UINavigationController {
                    targetVC = navController.viewControllers.first
                }
            }
            
            // Show tutorial on the found view controller
            if let viewController = targetVC {
                ProfileTutorialOverlay.show(on: viewController)
            }
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
                title: NSLocalizedString("Import Failed", comment: "Import failed title"),
                message: message,
                preferredStyle: .alert
            )
            
            alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: "OK button"), style: .default))
            
            var presenter = topVC
            while let presented = presenter.presentedViewController {
                presenter = presented
            }
            presenter.present(alert, animated: true)
        }
    }
}

