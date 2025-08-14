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
    
    init(bandName: String) {
        self.bandName = bandName
        
        // Create the SwiftUI view
        let detailView = DetailView(bandName: bandName)
        let rootView = AnyView(detailView)
        
        super.init(rootView: rootView)
        setupController()
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        // Default band name for storyboard initialization
        self.bandName = "Unknown Band"
        
        let detailView = DetailView(bandName: self.bandName)
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
        
        // The SwiftUI view will handle saving notes in its onDisappear modifier
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    // MARK: - Public Methods
    
    /// Updates the band name and refreshes the view
    func updateBandName(_ newBandName: String) {
        // Create a new SwiftUI view with the updated band name
        let detailView = DetailView(bandName: newBandName)
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
}

// MARK: - Convenience Methods
extension DetailHostingController {
    
    /// Creates and presents the detail screen for a specific band
    static func presentDetail(for bandName: String, from viewController: UIViewController) {
        let detailController = DetailHostingController(bandName: bandName)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad: Present modally or in split view
            let navigationController = UINavigationController(rootViewController: detailController)
            navigationController.modalPresentationStyle = .formSheet
            viewController.present(navigationController, animated: true)
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
