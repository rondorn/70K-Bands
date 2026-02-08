//
//  DetailHostingController.swift
//  70K Bands
//
//  Created by Assistant on 1/14/25.
//  Copyright (c) 2025 Ron Dorn. All rights reserved.
//

import UIKit
import SwiftUI

class DetailHostingController: UIHostingController<AnyView> {
    
    private let bandName: String
    private let showCustomBackButton: Bool
    
    init(bandName: String, showCustomBackButton: Bool = false) {
        self.bandName = bandName
        self.showCustomBackButton = showCustomBackButton
        
        // Create the SwiftUI view
        let detailView = DetailView(bandName: bandName, showCustomBackButton: showCustomBackButton)
        let rootView = AnyView(detailView)
        
        super.init(rootView: rootView)
        setupController()
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        // Default band name for storyboard initialization
        self.bandName = "Unknown Band"
        self.showCustomBackButton = false
        
        let detailView = DetailView(bandName: self.bandName, showCustomBackButton: false)
        let rootView = AnyView(detailView)
        
        super.init(coder: aDecoder, rootView: rootView)
        setupController()
    }
    
    private func setupController() {
        // Force dark mode permanently
        overrideUserInterfaceStyle = .dark
        
        // Ensure back button always says "Back"
        let backItem = UIBarButtonItem()
        backItem.title = "Back"
        self.navigationItem.backBarButtonItem = backItem
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("🎯 DetailHostingController viewDidLoad - SwiftUI detail view loading for band: \(bandName)")
        
        // Force dark mode appearance
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = UIColor.black
        
        // Set navigation bar styling
        if let navigationController = navigationController {
            navigationController.navigationBar.barStyle = UIBarStyle.blackTranslucent
            navigationController.navigationBar.tintColor = UIColor.white
            navigationController.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
            
            // Disable interactive pop gesture recognizer
            navigationController.interactivePopGestureRecognizer?.isEnabled = false
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            splitViewController?.preferredDisplayMode = UISplitViewController.DisplayMode.allVisible
        }
        
        // Ensure back button always says "Back" when navigating from this view
        let backItem = UIBarButtonItem()
        backItem.title = "Back"
        self.navigationItem.backBarButtonItem = backItem
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Disable interactive pop gesture recognizer
        navigationController?.interactivePopGestureRecognizer?.isEnabled = false
        
        // Post notification when detail screen is dismissing
        // This allows MasterViewController to check orientation and show appropriate view
        NotificationCenter.default.post(
            name: Notification.Name("DetailScreenDismissing"),
            object: nil,
            userInfo: ["bandName": bandName]
        )
        
        // The SwiftUI view will handle saving notes in its onDisappear modifier
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    // MARK: - Public Methods
    
    /// Updates the band name and refreshes the view
    func updateBandName(_ newBandName: String) {
        // Create a new SwiftUI view with the updated band name, preserving showCustomBackButton
        let detailView = DetailView(bandName: newBandName, showCustomBackButton: self.showCustomBackButton)
        let rootView = AnyView(detailView)
        
        // Update the root view
        self.rootView = rootView
        
        print("🎯 Updated DetailHostingController with new band: \(newBandName)")
    }
    
    /// Sets the detail item (for compatibility with existing code)
    func setDetailItem(_ item: AnyObject?) {
        guard let bandName = item?.description, !bandName.isEmpty else {
            print("⚠️ Invalid detail item provided to DetailHostingController")
            return
        }
        
        updateBandName(bandName)
    }
    
    /// Gets the current band name being displayed
    func getCurrentBandName() -> String {
        return bandName
    }
    
    /// Refreshes the detail view (triggers SwiftUI view refresh)
    func refreshDetailView() {
        print("🔄 Refreshing DetailHostingController view for band: \(bandName)")
        
        // Ensure we're on the main thread
        DispatchQueue.main.async {
            // Create a completely new SwiftUI view with fresh data, preserving showCustomBackButton
            let detailView = DetailView(bandName: self.bandName, showCustomBackButton: self.showCustomBackButton)
            let rootView = AnyView(detailView)
            
            // Update the root view to trigger UI refresh
            self.rootView = rootView
            
            print("🔄 DetailHostingController refresh completed for band: \(self.bandName)")
        }
    }
    
    /// Alternative refresh method that triggers data reload
    func refreshDetailData() {
        print("🔄 Refreshing DetailHostingController data for band: \(bandName)")
        
        DispatchQueue.main.async {
            // Create a new SwiftUI view to ensure fresh UI state, preserving showCustomBackButton
            let detailView = DetailView(bandName: self.bandName, showCustomBackButton: self.showCustomBackButton)
            let rootView = AnyView(detailView)
            
            // Update the root view to trigger complete UI refresh with fresh data
            self.rootView = rootView
            
            // Send notification after the new view is created to ensure the new ViewModel receives it
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                print("🔄 Sending force refresh notification for band: \(self.bandName)")
                NotificationCenter.default.post(
                    name: Notification.Name("ForceDetailRefresh"), 
                    object: nil, 
                    userInfo: ["bandName": self.bandName]
                )
                print("🔄 Sent force refresh notification for band: \(self.bandName)")
            }
            
            print("🔄 DetailHostingController data refresh completed for band: \(self.bandName)")
        }
    }
}

// MARK: - Convenience Methods
extension DetailHostingController {
    
    /// Creates and presents the detail screen for a specific band
    static func presentDetail(for bandName: String, from viewController: UIViewController) {
        let detailController = DetailHostingController(bandName: bandName)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad: Present modally with larger size to accommodate band name and logo
            detailController.modalPresentationStyle = .formSheet
            // Set larger preferred content size to accommodate band name and logo
            // iPad Air 11-inch width is ~820pt, so use ~75% for comfortable viewing
            detailController.preferredContentSize = CGSize(width: 800, height: 900)
            viewController.present(detailController, animated: true)
        } else {
            // iPhone: Push onto navigation stack
            viewController.navigationController?.pushViewController(detailController, animated: true)
        }
    }
    
    /// Creates and pushes the detail screen onto the navigation stack
    static func pushDetail(for bandName: String, from viewController: UIViewController) {
        let detailController = DetailHostingController(bandName: bandName)
        
        // Ensure dark mode is applied
        detailController.overrideUserInterfaceStyle = .dark
        
        // Push onto navigation stack
        viewController.navigationController?.pushViewController(detailController, animated: true)
    }
}

// MARK: - Split View Controller Support

extension DetailHostingController {
    
    /// Configures the controller for split view presentation
    func configureSplitViewPresentation() {
        // Set up split view specific configurations
        if let splitViewController = splitViewController {
            navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
            navigationItem.leftItemsSupplementBackButton = true
        }
    }
}
