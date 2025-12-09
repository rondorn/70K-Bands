//
//  ProfilePickerViewController.swift
//  70K Bands
//
//  Custom profile picker with long-press gesture support
//

import UIKit

class ProfilePickerViewController: UITableViewController, UIPopoverPresentationControllerDelegate {
    
    private var profiles: [String] = []
    private var activeProfile: String = ""
    private let sharingManager = SharedPreferencesManager.shared
    private var dimView: UIView?
    
    weak var masterViewController: MasterViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        title = "Select Profile"
        
        // Setup table view with transparency
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "ProfileCell")
        tableView.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        tableView.separatorColor = UIColor.white.withAlphaComponent(0.3)
        
        // Make the table view rounded
        tableView.layer.cornerRadius = 12
        tableView.layer.masksToBounds = true
        
        // Make navigation bar transparent
        if let navBar = navigationController?.navigationBar {
            navBar.setBackgroundImage(UIImage(), for: .default)
            navBar.shadowImage = UIImage()
            navBar.isTranslucent = true
            navBar.backgroundColor = UIColor.black.withAlphaComponent(0.75)
            navBar.barTintColor = UIColor.black.withAlphaComponent(0.75)
        }
        
        // Add close button
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: self,
            action: #selector(dismissPicker)
        )
        
        // Add long-press gesture to the TABLE VIEW (not individual cells)
        // This prevents duplicate gestures on reused cells
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        tableView.addGestureRecognizer(longPress)
        
        // Load profiles
        loadProfiles()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Only apply custom positioning and dim overlay on iPhone
        // iPad uses popover which handles its own positioning
        if UIDevice.current.userInterfaceIdiom == .phone {
            // Add a subtle dim overlay behind the picker
            if let presentingView = presentingViewController?.view {
                let dim = UIView(frame: presentingView.bounds)
                dim.backgroundColor = UIColor.black.withAlphaComponent(0.25)
                dim.alpha = 0
                presentingView.addSubview(dim)
                dimView = dim
                
                UIView.animate(withDuration: 0.3) {
                    dim.alpha = 1
                }
            }
            
            // Position the view near the top center
            if let navController = navigationController {
                let width: CGFloat = 300
                let height: CGFloat = min(400, CGFloat(profiles.count * 60 + 100))
                
                navController.view.frame = CGRect(
                    x: (UIScreen.main.bounds.width - width) / 2,
                    y: 100, // Position below navigation bar/count label
                    width: width,
                    height: height
                )
                
                // Add rounded corners to the nav controller view
                navController.view.layer.cornerRadius = 12
                navController.view.layer.masksToBounds = true
            }
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Fade out the dim overlay
        UIView.animate(withDuration: 0.3, animations: {
            self.dimView?.alpha = 0
        }) { _ in
            self.dimView?.removeFromSuperview()
            self.dimView = nil
        }
    }
    
    private func loadProfiles() {
        profiles = sharingManager.getAvailablePreferenceSources()
        activeProfile = sharingManager.getActivePreferenceSource()
        tableView.reloadData()
    }
    
    @objc private func dismissPicker() {
        dismiss(animated: true)
    }
    
    // MARK: - Table View Data Source
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return profiles.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ProfileCell", for: indexPath)
        
        let profileKey = profiles[indexPath.row]
        let displayName = sharingManager.getDisplayName(for: profileKey)
        let color = ProfileColorManager.shared.getColor(for: profileKey)
        let isActive = (profileKey == activeProfile)
        
        // Create attributed string with colored dot
        let dotString = "● "
        let nameString = isActive ? "✓ \(displayName)" : displayName
        
        let attributedString = NSMutableAttributedString()
        
        // Add colored dot
        let dotAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: color,
            .font: UIFont.boldSystemFont(ofSize: 20)
        ]
        attributedString.append(NSAttributedString(string: dotString, attributes: dotAttributes))
        
        // Add profile name in white
        let nameAttributes: [NSAttributedString.Key: Any] = [
            .foregroundColor: UIColor.white,
            .font: UIFont.boldSystemFont(ofSize: 17)
        ]
        attributedString.append(NSAttributedString(string: nameString, attributes: nameAttributes))
        
        // Configure cell with transparency
        cell.textLabel?.attributedText = attributedString
        cell.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        cell.selectionStyle = .default
        
        // Make selection background also transparent
        let selectedBackgroundView = UIView()
        selectedBackgroundView.backgroundColor = UIColor.darkGray.withAlphaComponent(0.6)
        cell.selectedBackgroundView = selectedBackgroundView
        
        // Note: Long-press gesture is added to the table view in viewDidLoad, not to individual cells
        
        return cell
    }
    
    // MARK: - Table View Delegate
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        
        let profileKey = profiles[indexPath.row]
        let displayName = sharingManager.getDisplayName(for: profileKey)
        
        if profileKey != activeProfile {
            print("🔄 [PROFILE] Switching to profile: \(displayName) (\(profileKey))")
            sharingManager.setActivePreferenceSource(profileKey)
            
            // Force full refresh in master view controller
            masterViewController?.clearAllCachesAndRefresh()
            
            // Dismiss picker and show toast
            dismiss(animated: true) {
                // Show toast message on main view controller
                if let masterVC = self.masterViewController {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        let visibleLocation = CGRect(origin: masterVC.mainTableView.contentOffset, size: masterVC.mainTableView.bounds.size)
                        let nowViewingText = NSLocalizedString("Now Viewing Profile:", comment: "Now viewing profile toast")
                        ToastMessages("\(nowViewingText) \(displayName)").show(masterVC, cellLocation: visibleLocation, placeHigh: true)
                    }
                }
            }
        } else {
            print("🔄 [PROFILE] Profile already active")
        }
    }
    
    // MARK: - Long Press Gesture
    
    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }
        
        let point = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: point) else { return }
        
        let profileKey = profiles[indexPath.row]
        let displayName = sharingManager.getDisplayName(for: profileKey)
        
        print("🔍 [LONG_PRESS] Long press on profile: \(displayName) (\(profileKey))")
        
        // Show action menu
        showProfileActionMenu(for: profileKey, at: indexPath)
    }
    
    // MARK: - Profile Actions
    
    private func showProfileActionMenu(for profileKey: String, at indexPath: IndexPath) {
        let displayName = sharingManager.getDisplayName(for: profileKey)
        
        let alert = UIAlertController(
            title: displayName,
            message: NSLocalizedString("Choose an action", comment: "Choose action prompt"),
            preferredStyle: .actionSheet
        )
        
        // Configure popover for iPad
        if let popover = alert.popoverPresentationController {
            let cell = tableView.cellForRow(at: indexPath)
            popover.sourceView = cell
            popover.sourceRect = cell?.bounds ?? .zero
        }
        
        // 1) Rename
        let renameAction = UIAlertAction(title: NSLocalizedString("Rename This Entry", comment: "Rename action"), style: .default) { [weak self] _ in
            self?.showRenameDialog(for: profileKey)
        }
        alert.addAction(renameAction)
        
        // 2) Change Color
        let colorAction = UIAlertAction(title: NSLocalizedString("Change The Color", comment: "Change color action"), style: .default) { [weak self] _ in
            self?.showColorPicker(for: profileKey)
        }
        alert.addAction(colorAction)
        
        // 3) Make These Settings My Own (only for non-Default profiles)
        if profileKey != "Default" {
            let copyAction = UIAlertAction(title: NSLocalizedString("Make These Settings My Own", comment: "Copy to default action"), style: .default) { [weak self] _ in
                self?.confirmCopyToDefault(fromProfileKey: profileKey, displayName: displayName)
            }
            alert.addAction(copyAction)
        }
        
        // 4) Delete (only for non-Default profiles)
        if profileKey != "Default" {
            let deleteAction = UIAlertAction(title: NSLocalizedString("Delete this Entry", comment: "Delete action"), style: .destructive) { [weak self] _ in
                self?.confirmDeleteProfile(userId: profileKey)
            }
            alert.addAction(deleteAction)
        }
        
        // Cancel
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel button"), style: .cancel)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func showRenameDialog(for profileKey: String) {
        let currentName = sharingManager.getDisplayName(for: profileKey)
        
        let alert = UIAlertController(
            title: NSLocalizedString("Rename Profile", comment: "Rename dialog title"),
            message: NSLocalizedString("Enter a new name for this profile", comment: "Rename dialog message"),
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.text = currentName
            textField.placeholder = "Profile name"
            textField.autocapitalizationType = .words
        }
        
        let saveAction = UIAlertAction(title: NSLocalizedString("Save", comment: "Save button"), style: .default) { [weak self, weak alert] _ in
            guard let newName = alert?.textFields?.first?.text,
                  !newName.isEmpty else { return }
            
            print("✏️ [RENAME] Renaming '\(currentName)' to '\(newName)'")
            self?.sharingManager.renameProfile(userId: profileKey, newName: newName)
            self?.loadProfiles()
            
            // Update master view controller title if this is the active profile
            if profileKey == self?.activeProfile {
                self?.masterViewController?.updateTitleForActivePreferenceSource()
            }
        }
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel button"), style: .cancel)
        
        alert.addAction(saveAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func showColorPicker(for profileKey: String) {
        let displayName = sharingManager.getDisplayName(for: profileKey)
        
        let selectColorForText = NSLocalizedString("Select a color for", comment: "Select color for message")
        
        let alert = UIAlertController(
            title: NSLocalizedString("Choose Color", comment: "Choose color title"),
            message: "\(selectColorForText) '\(displayName)'",
            preferredStyle: .actionSheet
        )
        
        // Configure popover for iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // Get available colors - must match ProfileColorManager.swift
        // Using emoji circles that are already colored to avoid UIAlertAction limitations
        let colorOptions: [(name: String, emoji: String, hex: String)] = [
            ("Red", "🔴", "#FF3333"),
            ("Green", "🟢", "#33E633"),
            ("Orange", "🟠", "#FF9A1A"),
            ("Pink", "🩷", "#FF4DB8"),
            ("Teal", "🔵", "#1AE6E6"),
            ("Yellow", "🟡", "#FFE61A"),
        ]
        
        // Add white option for Default profile (not available for others)
        var allColorOptions = colorOptions
        if profileKey == "Default" {
            allColorOptions.insert(("White", "⚪", "#FFFFFF"), at: 0)
        }
        
        for colorOption in allColorOptions {
            // Create two-column layout: colored emoji dot on left, black text on right
            let title = "\(colorOption.emoji)  \(colorOption.name)"
            
            let action = UIAlertAction(title: title, style: .default) { [weak self] _ in
                print("🎨 [COLOR_CHANGE] Setting '\(displayName)' to \(colorOption.name)")
                
                // Update color in SQLite
                _ = SQLiteProfileManager.shared.updateColor(userId: profileKey, newColorHex: colorOption.hex)
                
                // Reload table
                self?.loadProfiles()
                
                // Update master view controller title if this is the active profile
                if profileKey == self?.activeProfile {
                    self?.masterViewController?.updateTitleForActivePreferenceSource()
                }
            }
            
            // Keep text black by NOT setting titleTextColor - emoji will be colored naturally
            alert.addAction(action)
        }
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel button"), style: .cancel)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func confirmDeleteProfile(userId: String) {
        let displayName = sharingManager.getDisplayName(for: userId)
        
        let sureToDeleteText = NSLocalizedString("Are you sure you want to delete", comment: "Delete confirmation message")
        let cannotUndoText = NSLocalizedString("This cannot be undone.", comment: "Cannot undo message")
        
        let alert = UIAlertController(
            title: NSLocalizedString("Delete Profile", comment: "Delete profile title"),
            message: "\(sureToDeleteText) '\(displayName)'? \(cannotUndoText)",
            preferredStyle: .alert
        )
        
        let deleteAction = UIAlertAction(title: NSLocalizedString("Delete", comment: "Delete button"), style: .destructive) { [weak self] _ in
            print("🗑️ [DELETE] Deleting profile: \(displayName) (\(userId))")
            
            // If deleting the active profile, switch to Default first
            if userId == self?.activeProfile {
                self?.sharingManager.setActivePreferenceSource("Default")
                self?.masterViewController?.clearAllCachesAndRefresh()
            }
            
            // Delete the profile
            self?.sharingManager.deleteImportedSet(byUserId: userId)
            
            // Reload profiles
            self?.loadProfiles()
            
            // If no more profiles, dismiss
            if (self?.profiles.count ?? 0) <= 1 {
                self?.dismiss(animated: true)
            }
        }
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel button"), style: .cancel)
        
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    /// Shows confirmation dialog before copying profile to Default
    private func confirmCopyToDefault(fromProfileKey: String, displayName: String) {
        let overwriteText = NSLocalizedString("This will overwrite all of your current Default profile settings with", comment: "Overwrite warning message")
        let lostText = NSLocalizedString("Your existing priorities and attended events will be permanently lost.", comment: "Data loss warning")
        let continueText = NSLocalizedString("Are you sure you want to continue?", comment: "Continue confirmation")
        
        let alert = UIAlertController(
            title: NSLocalizedString("Make These Settings Your Own", comment: "Copy to default title"),
            message: "\(overwriteText) '\(displayName)'.\n\n\(lostText)\n\n\(continueText)",
            preferredStyle: .alert
        )
        
        let copyAction = UIAlertAction(title: NSLocalizedString("Overwrite My Settings", comment: "Overwrite button"), style: .destructive) { [weak self] _ in
            self?.copyProfileToDefault(fromProfileKey: fromProfileKey, displayName: displayName)
        }
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: "Cancel button"), style: .cancel)
        
        alert.addAction(copyAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    /// Copies settings from a shared profile to Default profile
    private func copyProfileToDefault(fromProfileKey: String, displayName: String) {
        print("📋 [COPY] Copying profile '\(displayName)' to Default")
        
        // Get the current event year from global Constants
        let currentEventYear = eventYear
        
        // Get priorities and attendance from source profile
        let priorities = SQLitePriorityManager.shared.getAllPriorities(eventYear: currentEventYear, profileName: fromProfileKey)
        let attendanceData = SQLiteAttendanceManager.shared.getAllAttendanceDataByIndex(profileName: fromProfileKey)
        
        print("📋 [COPY] Source has \(priorities.count) priorities and \(attendanceData.count) attendance records")
        
        // Use a dispatch group to wait for both delete operations to complete
        let deleteGroup = DispatchGroup()
        
        // Delete all existing Default profile priorities
        deleteGroup.enter()
        SQLitePriorityManager.shared.deleteProfile(named: "Default") { success in
            if success {
                print("✅ [COPY] Cleared Default profile priorities")
            }
            deleteGroup.leave()
        }
        
        // Delete all existing Default profile attendance
        deleteGroup.enter()
        SQLiteAttendanceManager.shared.deleteProfile(named: "Default") { success in
            if success {
                print("✅ [COPY] Cleared Default profile attendance")
            }
            deleteGroup.leave()
        }
        
        // Wait for deletions to complete, then import new data
        deleteGroup.notify(queue: .main) {
            print("📋 [COPY] Deletions complete, starting import...")
            
            // Copy priorities to Default (async operation)
            SQLitePriorityManager.shared.importPriorities(
                for: "Default",
                priorities: priorities,
                eventYear: currentEventYear
            )
            
            // Convert attendance data to the format expected by importAttendance
            // importAttendance expects [[String: Any]], so extract just the data dictionaries
            var attendanceArray: [[String: Any]] = []
            for (_, data) in attendanceData {
                attendanceArray.append(data)
            }
            
            // Copy attendance to Default (async operation)
            SQLiteAttendanceManager.shared.importAttendance(
                for: "Default",
                attendanceData: attendanceArray
            )
            
            print("✅ [COPY] Import operations initiated for Default profile")
            
            // Give a moment for async import operations to complete
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                // Switch to Default profile
                self.sharingManager.setActivePreferenceSource("Default")
                
                // Refresh the UI
                self.masterViewController?.clearAllCachesAndRefresh()
                
                // Update profile list
                self.loadProfiles()
                
                // Dismiss picker and show success message
                self.dismiss(animated: true) {
                    if let masterVC = self.masterViewController {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            let visibleLocation = CGRect(origin: masterVC.mainTableView.contentOffset, size: masterVC.mainTableView.bounds.size)
                            let copiedText = NSLocalizedString("Copied", comment: "Copied message")
                            let toYourProfileText = NSLocalizedString("to Your Profile", comment: "To your profile message")
                            ToastMessages("\(copiedText) '\(displayName)' \(toYourProfileText)").show(masterVC, cellLocation: visibleLocation, placeHigh: true)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - UIPopoverPresentationControllerDelegate
    
    /// Ensures popover always shows as popover on iPad (doesn't adapt to full screen)
    func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
        return .none  // Always use popover, never adapt
    }
}

