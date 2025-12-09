//
//  ProfilePickerViewController.swift
//  70K Bands
//
//  Custom profile picker with long-press gesture support
//

import UIKit

class ProfilePickerViewController: UITableViewController {
    
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
        
        // Load profiles
        loadProfiles()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
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
        
        // Add long-press gesture
        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        cell.addGestureRecognizer(longPress)
        
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
                        ToastMessages("Now Viewing Profile: \(displayName)").show(masterVC, cellLocation: visibleLocation, placeHigh: true)
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
            message: "Choose an action",
            preferredStyle: .actionSheet
        )
        
        // Configure popover for iPad
        if let popover = alert.popoverPresentationController {
            let cell = tableView.cellForRow(at: indexPath)
            popover.sourceView = cell
            popover.sourceRect = cell?.bounds ?? .zero
        }
        
        // 1) Rename
        let renameAction = UIAlertAction(title: "Rename This Entry", style: .default) { [weak self] _ in
            self?.showRenameDialog(for: profileKey)
        }
        alert.addAction(renameAction)
        
        // 2) Change Color
        let colorAction = UIAlertAction(title: "Change The Color", style: .default) { [weak self] _ in
            self?.showColorPicker(for: profileKey)
        }
        alert.addAction(colorAction)
        
        // 3) Delete (only for non-Default profiles)
        if profileKey != "Default" {
            let deleteAction = UIAlertAction(title: "Delete this Entry", style: .destructive) { [weak self] _ in
                self?.confirmDeleteProfile(userId: profileKey)
            }
            alert.addAction(deleteAction)
        }
        
        // Cancel
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func showRenameDialog(for profileKey: String) {
        let currentName = sharingManager.getDisplayName(for: profileKey)
        
        let alert = UIAlertController(
            title: "Rename Profile",
            message: "Enter a new name for this profile",
            preferredStyle: .alert
        )
        
        alert.addTextField { textField in
            textField.text = currentName
            textField.placeholder = "Profile name"
            textField.autocapitalizationType = .words
        }
        
        let saveAction = UIAlertAction(title: "Save", style: .default) { [weak self, weak alert] _ in
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
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(saveAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func showColorPicker(for profileKey: String) {
        let displayName = sharingManager.getDisplayName(for: profileKey)
        
        let alert = UIAlertController(
            title: "Choose Color",
            message: "Select a color for '\(displayName)'",
            preferredStyle: .actionSheet
        )
        
        // Configure popover for iPad
        if let popover = alert.popoverPresentationController {
            popover.sourceView = view
            popover.sourceRect = CGRect(x: view.bounds.midX, y: view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        // Get available colors - must match ProfileColorManager.swift
        let colorOptions: [(name: String, color: UIColor, hex: String)] = [
            ("Red", UIColor(red: 1.0, green: 0.2, blue: 0.2, alpha: 1.0), "#FF3333"),
            ("Green", UIColor(red: 0.2, green: 0.9, blue: 0.2, alpha: 1.0), "#33E633"),
            ("Orange", UIColor(red: 1.0, green: 0.6, blue: 0.1, alpha: 1.0), "#FF9A1A"),
            ("Pink", UIColor(red: 1.0, green: 0.3, blue: 0.7, alpha: 1.0), "#FF4DB8"),
            ("Teal", UIColor(red: 0.1, green: 0.9, blue: 0.9, alpha: 1.0), "#1AE6E6"),
            ("Yellow", UIColor(red: 1.0, green: 0.9, blue: 0.1, alpha: 1.0), "#FFE61A"),
        ]
        
        // Add white option for Default profile (not available for others)
        var allColorOptions = colorOptions
        if profileKey == "Default" {
            allColorOptions.insert(("White", UIColor.white, "#FFFFFF"), at: 0)
        }
        
        for colorOption in allColorOptions {
            // Create title with colored dot prefix
            let dotAndName = "●  \(colorOption.name)"
            
            let action = UIAlertAction(title: dotAndName, style: .default) { [weak self] _ in
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
            
            // Color only the dot part (using titleTextColor colors the entire text)
            // Note: UIAlertAction doesn't support attributed text, so we color the whole action
            action.setValue(colorOption.color, forKey: "titleTextColor")
            alert.addAction(action)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
    
    private func confirmDeleteProfile(userId: String) {
        let displayName = sharingManager.getDisplayName(for: userId)
        
        let alert = UIAlertController(
            title: "Delete Profile",
            message: "Are you sure you want to delete '\(displayName)'? This cannot be undone.",
            preferredStyle: .alert
        )
        
        let deleteAction = UIAlertAction(title: "Delete", style: .destructive) { [weak self] _ in
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
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel)
        
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        
        present(alert, animated: true)
    }
}

