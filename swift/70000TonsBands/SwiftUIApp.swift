//
//  SwiftUIApp.swift
//  70000TonsBands
//
//  Created by Assistant on 12/19/24.
//  Copyright (c) 2024 Ron Dorn. All rights reserved.
//

import SwiftUI
import CoreData

struct BandsApp: View {
    @StateObject private var appState = AppState()
    
    var body: some View {
        Group {
            if UIDevice.current.userInterfaceIdiom == .pad {
                // iPad: Use NavigationSplitView for iOS 16+ or NavigationView for older versions
                if #available(iOS 16.0, *) {
                    NavigationSplitView {
                        MasterView()
                            .environmentObject(appState)
                    } detail: {
                        if let selectedBand = appState.selectedBand {
                            DetailView(bandName: selectedBand)
                                .environmentObject(appState)
                        } else {
                            Text("Select a band to see details")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black.edgesIgnoringSafeArea(.all))
                        }
                    }
                    .navigationSplitViewStyle(.balanced)
                } else {
                    // Fallback for iOS 15 and earlier - use NavigationView
                    NavigationView {
                        MasterView()
                            .environmentObject(appState)
                        
                        if let selectedBand = appState.selectedBand {
                            DetailView(bandName: selectedBand)
                                .environmentObject(appState)
                        } else {
                            Text("Select a band to see details")
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .background(Color.black.edgesIgnoringSafeArea(.all))
                        }
                    }
                    .navigationViewStyle(DoubleColumnNavigationViewStyle())
                }
            } else {
                // iPhone: Use standard NavigationView
                NavigationView {
                    MasterView()
                        .environmentObject(appState)
                }
                .navigationViewStyle(StackNavigationViewStyle())
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            setupAppearance()
        }
    }
    
    private func setupAppearance() {
        // Configure navigation bar appearance globally
        let appearance = UINavigationBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = .black
        appearance.titleTextAttributes = [.foregroundColor: UIColor.white]
        appearance.largeTitleTextAttributes = [.foregroundColor: UIColor.white]
        
        UINavigationBar.appearance().standardAppearance = appearance
        UINavigationBar.appearance().scrollEdgeAppearance = appearance
        UINavigationBar.appearance().compactAppearance = appearance
        
        // Configure tab bar appearance if needed
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithOpaqueBackground()
        tabBarAppearance.backgroundColor = .black
        
        UITabBar.appearance().standardAppearance = tabBarAppearance
        UITabBar.appearance().scrollEdgeAppearance = tabBarAppearance
        
        // Configure other UI elements
        UITableView.appearance().backgroundColor = .black
        UITableViewCell.appearance().backgroundColor = .black
    }
}

class AppState: ObservableObject {
    @Published var selectedBand: String?
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    // Core Data context (if needed)
    lazy var managedObjectContext: NSManagedObjectContext = {
        return (UIApplication.shared.delegate as! AppDelegate).managedObjectContext!
    }()
    
    func selectBand(_ bandName: String) {
        selectedBand = bandName
    }
    
    func clearSelection() {
        selectedBand = nil
    }
    
    func showError(_ message: String) {
        errorMessage = message
    }
    
    func clearError() {
        errorMessage = nil
    }
}

// MARK: - SwiftUI App Integration

/// Hosting controller to integrate SwiftUI app with existing UIKit infrastructure
class SwiftUIAppHostingController: UIHostingController<BandsApp> {
    
    init() {
        let rootView = BandsApp()
        super.init(rootView: rootView)
        setupController()
    }
    
    required dynamic init?(coder aDecoder: NSCoder) {
        let rootView = BandsApp()
        super.init(coder: aDecoder, rootView: rootView)
        setupController()
    }
    
    private func setupController() {
        // Force dark mode permanently
        overrideUserInterfaceStyle = .dark
        
        // Configure the hosting controller
        view.backgroundColor = UIColor.black
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        print("🎯 SwiftUIAppHostingController viewDidLoad - SwiftUI app loading!")
        
        // Force dark mode appearance
        overrideUserInterfaceStyle = .dark
        view.backgroundColor = UIColor.black
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Hide navigation bar since SwiftUI will handle navigation
        navigationController?.setNavigationBarHidden(true, animated: false)
    }
}

// MARK: - Convenience Methods for AppDelegate Integration

extension SwiftUIAppHostingController {
    
    /// Creates and returns the SwiftUI app as the root view controller
    static func createRootViewController() -> UIViewController {
        let hostingController = SwiftUIAppHostingController()
        return hostingController
    }
    
    /// Creates a split view controller with SwiftUI content (for iPad)
    static func createSplitViewController() -> UISplitViewController? {
        // For iPad, we can still use UISplitViewController if needed
        // But the SwiftUI NavigationSplitView should handle this automatically
        return nil
    }
}

#Preview {
    BandsApp()
}
