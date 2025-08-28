//
//  PreferencesHostingController.swift
//  70K Bands
//
//  Created by Assistant on 12/19/24.
//  Copyright (c) 2024 Ron Dorn. All rights reserved.
//

import UIKit
import SwiftUI

class PreferencesHostingController: UIHostingController<AnyView> {
    
    init() {
        // Determine if we need NavigationView based on device and presentation
        let rootView: AnyView
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad: Wrap in NavigationView for modal presentation
            rootView = AnyView(
                NavigationView {
                    PreferencesView()
                }
                .navigationViewStyle(StackNavigationViewStyle())
            )
        } else {
            // iPhone: Use plain view (will be pushed onto existing navigation stack)
            rootView = AnyView(PreferencesView())
        }
        
        super.init(rootView: rootView)
        setupController()
    }
    
    @MainActor required dynamic init?(coder aDecoder: NSCoder) {
        // Same logic for coder init
        let rootView: AnyView
        if UIDevice.current.userInterfaceIdiom == .pad {
            rootView = AnyView(
                NavigationView {
                    PreferencesView()
                }
                .navigationViewStyle(StackNavigationViewStyle())
            )
        } else {
            rootView = AnyView(PreferencesView())
        }
        
        super.init(coder: aDecoder, rootView: rootView)
        setupController()
    }
    
    private func setupController() {
        // Configure the hosting controller
        // Don't set modalPresentationStyle here - let the presentation method handle it
        
        // Force dark mode permanently
        overrideUserInterfaceStyle = .dark
        
        // Set up the navigation appearance to match the app's style
        if let navigationController = navigationController {
            navigationController.navigationBar.prefersLargeTitles = false
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("🎯 PreferencesHostingController viewDidLoad - SwiftUI preferences loading!")
        
        // Force dark mode appearance
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = UIColor.black
        
        // Listen for dismissal notification from SwiftUI
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dismissPreferences),
            name: Notification.Name("DismissPreferencesScreen"),
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(dismissPreferences),
            name: Notification.Name("DismissPreferencesScreenAfterYearChange"),
            object: nil
        )
    }
    
    @objc private func dismissPreferences() {
        print("🎯 Dismissing preferences screen via notification")
        
        // Handle both modal and push presentation
        if presentingViewController != nil {
            // Modal presentation - dismiss
            dismiss(animated: true)
        } else {
            // Push presentation - pop
            navigationController?.popViewController(animated: true)
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // Trigger data refresh when preferences are closed
        DispatchQueue.global(qos: .background).async {
            masterView.bandNameHandle.gatherData()
            masterView.schedule.DownloadCsv()
            masterView.schedule.populateSchedule(forceDownload: false)
            
            // Update UI on main thread
            DispatchQueue.main.async {
                masterView.refreshData(isUserInitiated: true)
            }
        }
    }
}

// MARK: - Convenience Methods
extension PreferencesHostingController {
    
    /// Creates and presents the preferences screen modally
    static func presentPreferences(from viewController: UIViewController) {
        let preferencesController = PreferencesHostingController()
        
        // Present modally
        viewController.present(preferencesController, animated: true)
    }
    
    /// Creates and pushes the preferences screen onto the navigation stack
    /// Note: This method is now deprecated in favor of in-frame presentation
    static func pushPreferences(from viewController: UIViewController) {
        let preferencesController = PreferencesHostingController()
        
        // Use push navigation for both iPhone and iPad
        preferencesController.modalPresentationStyle = .none
        viewController.navigationController?.pushViewController(preferencesController, animated: true)
        
        // Ensure dark mode is applied
        preferencesController.overrideUserInterfaceStyle = .dark
    }
}
