//
//  AppDelegate.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/2/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import UIKit
import CoreData
import UserNotifications
import Firebase
import FirebaseCore
import FirebaseMessaging
import FirebaseAnalytics
import Foundation

let appDelegate : AppDelegate? = UIApplication.shared.delegate as? AppDelegate

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
    
    
    var window: UIWindow?
    var registrationToken: String?
    var registrationOptions = [String: AnyObject]()
    
    var notificationDisplayed = false;
    let registrationKey = "onRegistrationCompleted"
    let messageKey = "onMessageReceived"
    
    let gcmMessageIDKey = "gcm.message_id"
    

    
    var bandDescriptions = CustomBandDescription()
    var dataHandle = dataHandler()
    
    // Flag to track if pointer file download has been attempted on this launch
    private var hasAttemptedPointerDownloadOnLaunch = false
    
    // Flag to track if Firebase has been configured
    // Must be static so it can be accessed from other classes
    static var isFirebaseConfigured = false
    
    /**
     Downloads the pointer file to a temporary location, and if successful, replaces the existing pointer file
     and forces a reload of in-memory data. This should only be called on app launch.
     
     This function implements a robust download and update mechanism that:
     1. Downloads the pointer file to a temporary location first
     2. Validates the downloaded content to ensure it's valid pointer data
     3. Only if the download is successful, deletes the existing pointer file and replaces it
     4. Clears in-memory cache and forces a reload of pointer data
     5. Notifies the app that pointer data has been updated
     
     Safety features:
     - Only runs once per app launch
     - Requires internet connectivity
     - Validates downloaded content format
     - Has timeout limits (30s request, 60s resource)
     - Has size limits (1MB max)
     - Cleans up temporary files on failure
     - Uses atomic file operations to prevent corruption
     */
    private func resolvePointerUrlForCurrentPreference() -> String {
        // Ensure we pick up any Settings.bundle changes
        UserDefaults.standard.synchronize()
        
        let pointerUrlPref = UserDefaults.standard.string(forKey: "PointerUrl") ?? "NOT_SET"
        if pointerUrlPref == testingSetting {
            return FestivalConfig.current.defaultStorageUrlTest
        }
        return FestivalConfig.current.defaultStorageUrl
    }
    
    private func downloadAndUpdatePointerFile(reason: String, enforceOncePerLaunch: Bool, completion: ((Bool) -> Void)? = nil) {
        if enforceOncePerLaunch {
            guard !hasAttemptedPointerDownloadOnLaunch else {
                print("downloadAndUpdatePointerFile(\(reason)): Already attempted download on this launch, skipping")
                completion?(false)
                return
            }
            hasAttemptedPointerDownloadOnLaunch = true
        }
        
        print("downloadAndUpdatePointerFile(\(reason)): Starting pointer file download and update")
        
        // POLICY: Pointer file network download is only allowed on startup and pull-to-refresh.
        // This function is the ONLY code path that should download the pointer file.
        
        guard Reachability.isConnectedToNetwork() else {
            print("downloadAndUpdatePointerFile(\(reason)): No internet connection available, skipping download")
            completion?(false)
            return
        }
        
        // Ensure defaultStorageUrl matches current preference before downloading.
        defaultStorageUrl = resolvePointerUrlForCurrentPreference()
        
        // Create temporary file path
        let documentsPath = getDocumentsDirectory()
        let tempPointerFile = documentsPath.appendingPathComponent("tempPointerData.txt")
        let cachedPointerFile = documentsPath.appendingPathComponent("cachedPointerData.txt")
        
        guard let url = URL(string: defaultStorageUrl) else {
            print("downloadAndUpdatePointerFile(\(reason)): Invalid URL: \(defaultStorageUrl)")
            completion?(false)
            return
        }
        
        // Set a timeout for the download
        let configuration = URLSessionConfiguration.default
        // Android parity: 10s on GUI thread, 60s in background.
        let timeout = NetworkTimeoutPolicy.timeoutIntervalForCurrentThread()
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        let session = URLSession(configuration: configuration)
        
        let task = session.dataTask(with: url) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("downloadAndUpdatePointerFile(\(reason)): Download error: \(error)")
                DispatchQueue.main.async { completion?(false) }
                return
            }
            
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("downloadAndUpdatePointerFile(\(reason)): Invalid response or no data")
                DispatchQueue.main.async { completion?(false) }
                return
            }
            
            // Check if the downloaded data is not too large (safety check)
            let maxSize = 1024 * 1024 // 1MB limit
            guard data.count <= maxSize else {
                print("downloadAndUpdatePointerFile(\(reason)): Downloaded data too large (\(data.count) bytes), aborting")
                DispatchQueue.main.async { completion?(false) }
                return
            }
            
            do {
                try data.write(to: URL(fileURLWithPath: tempPointerFile))
                print("downloadAndUpdatePointerFile(\(reason)): Successfully downloaded pointer file to temp location")
                
                guard let downloadedContent = String(data: data, encoding: .utf8),
                      !downloadedContent.isEmpty else {
                    print("downloadAndUpdatePointerFile(\(reason)): Downloaded content is empty or invalid")
                    DispatchQueue.main.async { completion?(false) }
                    return
                }
                
                // Validate it looks like pointer data
                let lines = downloadedContent.components(separatedBy: "\n")
                var validLineCount = 0
                for line in lines.prefix(10) {
                    if line.contains("::") && line.components(separatedBy: "::").count >= 3 {
                        validLineCount += 1
                        if validLineCount >= 2 { break }
                    }
                }
                guard validLineCount >= 2 else {
                    print("downloadAndUpdatePointerFile(\(reason)): Downloaded content does not appear to be valid pointer data")
                    DispatchQueue.main.async { completion?(false) }
                    return
                }
                
                let fileManager = FileManager.default
                
                if fileManager.fileExists(atPath: cachedPointerFile) {
                    do {
                        try fileManager.removeItem(atPath: cachedPointerFile)
                        print("downloadAndUpdatePointerFile(\(reason)): Removed existing cached pointer file")
                    } catch {
                        print("downloadAndUpdatePointerFile(\(reason)): Failed to remove existing cached pointer file: \(error)")
                    }
                }
                
                do {
                    try fileManager.moveItem(atPath: tempPointerFile, toPath: cachedPointerFile)
                    print("downloadAndUpdatePointerFile(\(reason)): Successfully replaced cached pointer file")
                    
                    // Clear in-memory cache to force reload from disk
                    storePointerLock.sync() {
                        cacheVariables.storePointerData.removeAll()
                    }
                    print("downloadAndUpdatePointerFile(\(reason)): Cleared in-memory pointer cache")
                    
                    // Pre-warm common pointer values (disk-backed; no network)
                    DispatchQueue.global(qos: .background).async {
                        _ = getPointerUrlData(keyValue: "artistUrl")
                        _ = getPointerUrlData(keyValue: "scheduleUrl")
                        let resolvedEventYearString = getPointerUrlData(keyValue: "eventYear")
                        _ = getPointerUrlData(keyValue: "reportUrl")
                        
                        print("downloadAndUpdatePointerFile(\(reason)): Forced reload of pointer data completed")
                        
                        // Update global eventYear if user is on "Current".
                        // Respect explicit user year choices (e.g. "2025") by not overriding them.
                        let yearPreference = getScheduleUrl()
                        if yearPreference == "Current" {
                            if let y = Int(resolvedEventYearString), y > 2000 {
                                DispatchQueue.main.async {
                                    eventYear = y
                                    print("downloadAndUpdatePointerFile(\(reason)): Updated global eventYear to \(y) (Current)")
                                }
                            }
                        } else if yearPreference.isYearString, let y = Int(yearPreference), y > 2000 {
                            DispatchQueue.main.async {
                                eventYear = y
                                print("downloadAndUpdatePointerFile(\(reason)): Preserved explicit year preference, eventYear=\(y)")
                            }
                        }
                        
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: Notification.Name("PointerDataUpdated"), object: nil)
                            completion?(true)
                        }
                    }
                    
                } catch {
                    print("downloadAndUpdatePointerFile(\(reason)): Failed to move temp file to final location: \(error)")
                    if fileManager.fileExists(atPath: tempPointerFile) {
                        try? fileManager.removeItem(atPath: tempPointerFile)
                    }
                    DispatchQueue.main.async { completion?(false) }
                }
            } catch {
                print("downloadAndUpdatePointerFile(\(reason)): Failed to write downloaded data to temp file: \(error)")
                DispatchQueue.main.async { completion?(false) }
            }
        }
        
        task.resume()
    }
    
    func refreshPointerFileForUserInitiatedRefresh(completion: ((Bool) -> Void)? = nil) {
        downloadAndUpdatePointerFile(reason: "pull-to-refresh", enforceOncePerLaunch: false, completion: completion)
    }
    
    private func downloadAndUpdatePointerFileOnLaunch() {
        downloadAndUpdatePointerFile(reason: "startup", enforceOncePerLaunch: true, completion: nil)
    }

    /**
     Called when the application has finished launching. Sets up the main window, root view controller, and various app-wide settings.
     - Parameter application: The singleton app object.
     - Parameter launchOptions: A dictionary indicating the reason the app was launched (if any).
     - Returns: true if the app launched successfully, false otherwise.
     */
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions:
        
        [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        let launchTime = Date()
        print("🚀 [TIMING] didFinishLaunchingWithOptions CALLED at \(launchTime.timeIntervalSince1970)")
        print("🚀 [MDF_DEBUG] AppDelegate.didFinishLaunchingWithOptions CALLED")
        print("🚀 [MDF_DEBUG] Festival Config: \(FestivalConfig.current.festivalShortName)")
        print("🚀 [MDF_DEBUG] App Name: \(FestivalConfig.current.appName)")
        print("🚀 [MDF_DEBUG] Bundle ID: \(FestivalConfig.current.bundleIdentifier)")
    
        // MIGRATION: Perform one-time migration from Core Data to SQLite
        // This is safe to call every launch - it only runs once
        print("🔄 Checking for Core Data to SQLite migration...")
        CoreDataToSQLiteMigrationHelper.shared.performMigrationIfNeeded()
        print("✅ Migration check complete")
        
        // Manually create the window and set the root view controller from the storyboard.
        self.window = UIWindow(frame: UIScreen.main.bounds)
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            // iPad: Use split view controller for optimal experience
            if let splitViewController = storyboard.instantiateInitialViewController() as? UISplitViewController {
                self.window?.rootViewController = splitViewController
                
                // Set up split view controller
                splitViewController.delegate = self
                splitViewController.preferredDisplayMode = .oneBesideSecondary
                
                self.window?.makeKeyAndVisible()
                
                // Set up master view controller
                if let masterNavigationController = splitViewController.viewControllers.first as? UINavigationController,
                   let controller = masterNavigationController.viewControllers.first as? MasterViewController {
                    controller.managedObjectContext = self.managedObjectContext
                    setupDefaults()
                } else {
                    print("Error: Could not get MasterViewController from navigation stack.")
                }
                
                // Set up detail view controller - create placeholder for iPad initially
                let placeholderDetailController = createPlaceholderDetailViewController()
                let detailNavigationController = UINavigationController(rootViewController: placeholderDetailController)
                
                // Configure navigation controller to be completely transparent to avoid white bar
                detailNavigationController.navigationBar.isTranslucent = true
                detailNavigationController.navigationBar.backgroundColor = UIColor.clear
                detailNavigationController.navigationBar.barTintColor = UIColor.clear
                detailNavigationController.navigationBar.shadowImage = UIImage()
                detailNavigationController.navigationBar.setBackgroundImage(UIImage(), for: .default)
                detailNavigationController.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]
                
                // If there's already a detail view controller, replace it
                if splitViewController.viewControllers.count > 1 {
                    splitViewController.viewControllers = [splitViewController.viewControllers[0], detailNavigationController]
                } else {
                    splitViewController.viewControllers.append(detailNavigationController)
                }
                
                // Auto-selection now happens after data is loaded in refreshBandList
            } else {
                print("Error: Could not instantiate UISplitViewController from storyboard.")
            }
        } else {
            // iPhone (including Max models): Use simple navigation controller to avoid split view issues
            if let splitViewController = storyboard.instantiateInitialViewController() as? UISplitViewController,
               let masterNavigationController = splitViewController.viewControllers.first as? UINavigationController,
               let masterViewController = masterNavigationController.viewControllers.first as? MasterViewController {
                
                // Extract the master view controller and use it as the root of a standard navigation controller
                let navigationController = UINavigationController(rootViewController: masterViewController)
                self.window?.rootViewController = navigationController
                
                // Configure the master view controller
                masterViewController.managedObjectContext = self.managedObjectContext
                setupDefaults()
                
                self.window?.makeKeyAndVisible()
                print("iPhone: Using standard navigation controller instead of split view for better experience")
            } else {
                print("Error: Could not extract MasterViewController from storyboard for iPhone setup.")
            }
        }
        
        // Register default UserDefaults values including iCloud setting
        let defaults = ["artistUrl": FestivalConfig.current.artistUrlDefault,
                        "scheduleUrl": FestivalConfig.current.scheduleUrlDefault,
                        "iCloud": "YES",
                        "mustSeeAlert": "YES", 
                        "mightSeeAlert": "YES",
                        "minBeforeAlert": "10", 
                        "alertForShows": "YES",
                        "alertForSpecial": "YES", 
                        "alertForMandG": "NO",
                        "alertForClinics": "NO", 
                        "alertForListening": "NO",
                        "validateScheduleFile": "NO",
                        "PointerUrl": "Prod"]
        UserDefaults.standard.register(defaults: defaults)
        print("🔧 [POINTER_DEBUG] Registered default PointerUrl = 'Prod'")
        
        // CRITICAL: Do NOT call iCloud operations on main thread during launch
        // purgeOldiCloudKeys() processes 795+ keys and takes 30+ seconds -> watchdog timeout
        // Move ALL iCloud setup to background thread
        print("iCloud: Deferring iCloud operations to background thread (non-blocking)...")
        
        DispatchQueue.global(qos: .utility).async {
            let iCloudHandle = iCloudDataHandler()
            
            // This can take 30+ seconds with 795+ keys - must be in background
            iCloudHandle.purgeOldiCloudKeys()
            
            let iCloudEnabled = iCloudHandle.checkForIcloud()
            print("iCloud: iCloud enabled status: \(iCloudEnabled)")
            
            // Test if we can read from iCloud
            let testValue = NSUbiquitousKeyValueStore.default.string(forKey: "testKey")
            print("iCloud: Test read from iCloud (testKey): \(testValue ?? "nil")")
            
            // Set a test value to verify write capability
            NSUbiquitousKeyValueStore.default.set("test-\(Date().timeIntervalSince1970)", forKey: "testKey")
            NSUbiquitousKeyValueStore.default.synchronize()
            print("iCloud: Test value written to iCloud")
        }

        // MIGRATION DISABLED: Old migration system interferes with new Core Data iCloud sync
        // The new CoreDataiCloudSync system handles all iCloud operations
        // iCloudHandle.detectAndMigrateOldPriorityData()
        // iCloudHandle.detectAndMigrateOldScheduleData()

        // Register for notification of iCloud key-value changes (lightweight, can stay on main thread)
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(AppDelegate.iCloudKeysChanged(_:)),
                                               name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: NSUbiquitousKeyValueStore.default)
        
        print("iCloud: Registered for iCloud KVS change notifications")
        
        // CRITICAL FIX: Defer ALL network operations until app is fully active
        // On first launch, iOS hasn't fully initialized network stack yet
        // Early network calls fail with error -9816 and timeout after 30 seconds
        // Deferring allows app UI to display immediately while network initializes
        // 3.5s delay ensures ALL network endpoints (not just Google) are ready
        print("🚀 [TIMING] Scheduling Firebase configuration for +3.5s from launch")
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
            let firebaseConfigTime = Date()
            print("🔥 [TIMING] Firebase configuration STARTING at \(firebaseConfigTime.timeIntervalSince1970)")
            print("⏳ Starting deferred network operations (app fully initialized)...")
            
            // Configure Firebase with festival-specific config file
            // MUST be deferred to avoid error -9816 on first launch
            if let path = Bundle.main.path(forResource: FestivalConfig.current.firebaseConfigFile, ofType: "plist"),
               let options = FirebaseOptions(contentsOfFile: path) {
                FirebaseApp.configure(options: options)
                print("🔥 [TIMING] Firebase configured with file: \(FestivalConfig.current.firebaseConfigFile)")
            } else {
                // Fallback to default configuration
                FirebaseApp.configure()
                print("🔥 [TIMING] Firebase configured with DEFAULT config")
            }
            FirebaseConfiguration.shared.setLoggerLevel(.min)
            
            // Explicitly disable Firebase Analytics data collection for privacy
            Analytics.setAnalyticsCollectionEnabled(false)
            print("🔒 Firebase Analytics explicitly DISABLED for privacy")
            
            // Set flag to indicate Firebase is now configured
            AppDelegate.isFirebaseConfigured = true
            let firebaseCompleteTime = Date()
            print("✅ [TIMING] Firebase configured COMPLETE at \(firebaseCompleteTime.timeIntervalSince1970)")
            print("✅ Firebase configured")
            
            setupCurrentYearUrls()
            self.downloadAndUpdatePointerFileOnLaunch()
            
            // Initialize Firebase Messaging after Firebase is configured
            // This prevents error -9816 (SSL connection failure) on first launch
            Messaging.messaging().delegate = self
            self.printFCMToken()
            print("✅ Firebase Messaging initialized")
            
            // Register for remote notifications after network stack is ready
            // APNs registration requires network connectivity
            application.registerForRemoteNotifications()
            print("✅ Remote notifications registered")
            
            print("✅ Deferred network operations started")
        }

        // Set up notification permissions immediately (doesn't require network)
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: {_, _ in })
        
        // Defer iCloud sync until after bands and schedule data are loaded
        // This ensures iCloud priority/attendance data is applied to already-loaded band/schedule data
        DispatchQueue.global(qos: .background).async {
            let isFirstLaunch = !UserDefaults.standard.bool(forKey: "hasLaunchedBefore")
            if isFirstLaunch {
                UserDefaults.standard.set(true, forKey: "hasLaunchedBefore")
                UserDefaults.standard.synchronize()
                print("First launch detected, proceeding with iCloud data loading...")
                // Removed unnecessary 20-second delay - the polling loops below ensure proper synchronization
            }
            
            // Wait for bands and schedule data to be loaded before syncing iCloud
            print("iCloud: Checking if core data is ready for iCloud sync...")
            
            // Check if we actually have band data before proceeding
            if !bandNamesHandler.shared.getBandNames().isEmpty && !isLoadingBandData {
                print("iCloud: Core data is ready, proceeding with iCloud sync...")
                
                // Wait for schedule data to be ready (not loading - empty schedule with headers only is valid)
                if !isLoadingSchedule {
                    print("iCloud: Bands and schedule loaded, now syncing iCloud data...")
                    
                    // Use new Core Data iCloud sync system
                    let sqliteiCloudSync = SQLiteiCloudSync()
                    
                    // Sync priorities from iCloud
                    sqliteiCloudSync.syncPrioritiesFromiCloud {
                        print("iCloud: Priority sync completed")
                    }
                    
                    // Sync attendance from iCloud
                    sqliteiCloudSync.syncAttendanceFromiCloud {
                        print("iCloud: Attendance sync completed")
                    }
                    
                    // Write local data to iCloud
                    sqliteiCloudSync.syncPrioritiesToiCloud()
                    sqliteiCloudSync.syncAttendanceToiCloud()
                    
                    print("iCloud: Launch sync completed, refreshing display...")
                    
                    // Refresh the display on the main thread
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
                    }
                } else {
                    print("iCloud: Schedule still loading, deferring iCloud sync to proper sequence")
                }
            } else {
                print("iCloud: Core data not ready yet, deferring iCloud sync to proper sequence")
                print("iCloud: This prevents the infinite waiting loop - iCloud will sync when data is actually available")
                print("iCloud: The proper loading sequence will handle iCloud sync after core data is loaded")
            }
        }
        

        //generate user data
        print ("Firebase, calling ")

        // DEFERRED NOTIFICATION SETUP: Set up notifications after app launch is complete
        // This prevents deadlock during launch by deferring the notification setup
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 2.0) {
            print("🔔 [NOTIFICATION_DEFER] Setting up deferred notifications after app launch")
            let localNotification = localNoticationHandler()
            localNotification.addNotifications()
            print("🔔 [NOTIFICATION_DEFER] Deferred notification setup completed")
        }

        return true
    
    }
    

    /**
     Handles the receipt of a new Firebase Cloud Messaging registration token.
     - Parameter messaging: The messaging instance.
     - Parameter fcmToken: The new registration token.
     */
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        print("FCM Firebase registration token: \(fcmToken)")
         
        let dataDict:[String: String] = ["token": fcmToken]
        NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: dataDict)
        // TODO: If necessary send token to application server.
        // Note: This callback is fired at each app startup and whenever a new token is generated.
    }
    

    /**
     Displays a notification alert with the given message.
     - Parameter message: The message to display in the alert.
     */
    func displayNotification (message: String){
        
        //if (notificationDisplayed == false){
        let alertCtrl = UIAlertController(title: FestivalConfig.current.appName, message: message, preferredStyle: UIAlertController.Style.alert)
        alertCtrl.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        
        var presentedVC = self.window?.rootViewController
        while let nextVC = presentedVC?.presentedViewController {
            presentedVC = nextVC
        }
        if let presentedVC = presentedVC {
            presentedVC.present(alertCtrl, animated: true, completion: nil)
            notificationDisplayed = true;
        } else {
            print("Error: No root view controller to present alert.")
        }
        //}
        
    }
    
    /**
     Handles the refresh of the FCM token.
     - Parameter notification: The notification object triggering the refresh.
     */
    @objc func tokenRefreshNotification(_ notification: Notification) {
        //if let refreshedToken = InstanceID.instanceID().token() {
        //    print("InstanceID token: \(refreshedToken)")
        //    UIPasteboard.general.string =  "InstanceID token: \(refreshedToken)";
        //}
        
        // Connect to FCM since connection may have failed when attempted before having a token.
        connectToFcm()
        
        // Debug Firebase setup (can be removed in production)
        debugFirebaseSetup()
    }
    
    
    /**
     Prints the current FCM token to the console.
     */
    func printFCMToken() {
        
        Messaging.messaging().token { token, error in
            print("Your FCM token is \(token)")
        }

    }
    
    /// Debug function to print Firebase configuration and subscription topics
    func debugFirebaseSetup() {
        print("=== Firebase Debug Info ===")
        print("App Name: \(FestivalConfig.current.appName)")
        print("Bundle ID: \(FestivalConfig.current.bundleIdentifier)")
        print("Firebase Config File: \(FestivalConfig.current.firebaseConfigFile)")
        print("Subscription Topics:")
        print("  - Main: \(subscriptionTopic)")
        print("  - Test: \(subscriptionTopicTest)")
        print("  - Unofficial: \(subscriptionUnofficalTopic)")
        
        Messaging.messaging().token { token, error in
            if let error = error {
                print("FCM Token Error: \(error)")
            } else if let token = token {
                print("FCM Token: \(token)")
            } else {
                print("FCM Token: nil")
            }
        }
        print("========================")
    }

    
    // [END refresh_token]
    // [START connect_to_fcm]
    /**
     Connects to Firebase Cloud Messaging if a token is available.
     */
    func connectToFcm() {
        // Won't connect since there is no token
        Messaging.messaging().token { token, error in
            if token == nil {
                return;
            }
        }
        Messaging.messaging().subscribe(toTopic: subscriptionTopic)
        Messaging.messaging().subscribe(toTopic: subscriptionTopicTest)
        
        print("FCM - subscribed to " + subscriptionTopic)
        print("FCM - subscribed to " + subscriptionTopicTest)
        if (getAlertForUnofficalEventsValue() == true){
            Messaging.messaging().subscribe(toTopic: subscriptionUnofficalTopic)
            print("FCM - subscribed to " + subscriptionUnofficalTopic)
        } else {
            Messaging.messaging().unsubscribe(fromTopic: subscriptionUnofficalTopic)
        }

    }
    // [END connect_to_fcm]

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("FCM Unable to register for remote notifications: \(error.localizedDescription)")
        
    }
    
    
    
    // This function is added here only for debugging purposes, and can be removed if swizzling is enabled.
    // If swizzling is disabled then this function must be implemented so that the APNs token can be paired to
    // the InstanceID token.
    func application(application: UIApplication,
                     didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        
        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("FCM APNs token retrieved: \(token)")
        
        //#if PROD_BUILD
        //InstanceID.instanceID().setAPNSToken(deviceToken, type: .prod)
        //InstanceID.instanceID().setAPNSToken(deviceToken, type: .prod)
        //#else
        //    InstanceID.instanceID().setAPNSToken(deviceToken, type: .sandbox)
            //InstanceID.instanceID().setAPNSToken(deviceToken, type: InstanceIDAPNSTokenType.sandbox)
       // #endif
        
        //InstanceID.instanceID().setAPNSToken(deviceToken, type: InstanceIDAPNSTokenType.unknown)
        
        Messaging.messaging().apnsToken = deviceToken

        print("FCM recieved background alert - \(deviceToken)")
    }
    
     // [START receive_message]
     func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any]) {
         
         if #available(iOS 10.0, *) {
             //exit without doing anything, this is handled in another routine
             return
         }
         // If you are receiving a notification message while your app is in the background,
         // this callback will not be fired till the user taps on the notification launching the application.
         // TODO: Handle data of notification
         // Print message ID.
         if let messageID = userInfo[gcmMessageIDKey] {
             print("FCM Message ID: \(messageID)")
         }
         
         // Print full message.
         print(userInfo)
         extractAlertMessage(userInfo: userInfo as! Dictionary<String, AnyObject>);
     }
    

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        if #available(iOS 10.0, *) {
            print("Firebase - didReceiveRemoteNotification encountered!!!")
            print("Firebase  - \(userInfo)")
            //exit without doing anything, this is handled in another routine
            return
        }
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        // TODO: Handle data of notification
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("FCM Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
        print ("FCM Test2")
        extractAlertMessage(userInfo: userInfo as! Dictionary<String, AnyObject>);
        completionHandler(UIBackgroundFetchResult.newData)
    }
    // [END receive_message]

 
    // [START connect_on_active]
    func applicationDidBecomeActive(_ application: UIApplication) {
        let becameActiveTime = Date()
        print("📱 [TIMING] applicationDidBecomeActive CALLED at \(becameActiveTime.timeIntervalSince1970)")
        print("📱 [TIMING] Firebase configured flag = \(AppDelegate.isFirebaseConfigured)")
        
        // SAFETY: Defer Firebase operations to ensure Firebase is configured
        // Firebase is configured with 3.5s delay in didFinishLaunching
        // If app becomes active quickly, we need to wait for Firebase to be ready
        // Increased to 5.0s to ensure Firebase is fully initialized
        print("📱 [TIMING] Scheduling Firebase operations for +5.0s from becameActive")
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 5.0) {
            let operationsTime = Date()
            print("🔥 [TIMING] Firebase operations STARTING at \(operationsTime.timeIntervalSince1970)")
            print("🔥 [TIMING] Firebase configured flag = \(AppDelegate.isFirebaseConfigured)")
            
            // Only connect to FCM after Firebase is definitely configured
            if AppDelegate.isFirebaseConfigured {
                self.connectToFcm()
            } else {
                print("⚠️ [TIMING] Firebase NOT configured yet, skipping FCM connection")
            }
            
            // Force iCloud synchronization when app becomes active
            print("iCloud: App became active, forcing iCloud synchronization in background")
            NSUbiquitousKeyValueStore.default.synchronize()
            
            // Perform network operations in background (Firebase now guaranteed to be configured)
            let userDataHandle = userDataHandler()
            
            // SAFETY: Only use Firebase if it's actually configured
            if AppDelegate.isFirebaseConfigured {
                print("🔥 [TIMING] About to create firebaseUserWrite instance")
                let userDataReportHandle = firebaseUserWrite()
                print("🔥 [TIMING] firebaseUserWrite instance created successfully")
                userDataReportHandle.writeData()
            } else {
                print("⚠️ [TIMING] Firebase NOT configured yet, skipping Firebase operations")
            }
            
            // Set up notifications when app becomes active (in case they weren't set up during launch)
            print("🔔 [NOTIFICATION_DEFER] Setting up notifications on app become active")
            let localNotification = localNoticationHandler()
            localNotification.addNotifications()
            
            // Post refresh notification on main thread after background operations complete
            DispatchQueue.main.async {
                print("iCloud: Background sync complete, posting refresh notification")
                NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
            }
        }
    }
    // [END connect_on_active]
        
    func extractAlertMessage (userInfo : Dictionary<String, AnyObject>){
        
        print("FCM sendLocalAlert! \(userInfo)")
        if let info = userInfo["aps"] as? Dictionary<String, AnyObject> {
            // Default printout of info = userInfo["aps"]
            print("FCM sendLocalAlert!  \n\(info)\n")
            
            for (key, value) in info {
                print("FCM sendLocalAlert! APS: \(key) —> \(value)")
                if (key == "alert"){
                    if (value is NSDictionary){
                        //displayNotification(message: value as! String);
                        displayNotification(message: value["body"] as! String) ;
                    } else {
                        displayNotification(message: value as! String);
                    }
                }
            }
        }

    }
    
    func application(_ application: UIApplication, handleActionWithIdentifier identifier: String?, forRemoteNotification userInfo: [AnyHashable: Any], completionHandler: @escaping () -> Void) {
        
        completionHandler()
    }
    
    //end push functions
    
    func reportData(){
        print("🔥 [APP_DELEGATE] reportData: ========== ENTRY ==========")
        print("🔥 [APP_DELEGATE] reportData: Called from thread: \(Thread.isMainThread ? "main" : "background")")
        
        internetAvailble = isInternetAvailable();
        print("🔥 [APP_DELEGATE] reportData: Internet available: \(internetAvailble)")
        
        print("🔥 [APP_DELEGATE] reportData: Creating firebaseBandDataWrite instance...")
        let bandWrite  = firebaseBandDataWrite();
        print("🔥 [APP_DELEGATE] reportData: Calling bandWrite.writeData()...")
        bandWrite.writeData();
        print("🔥 [APP_DELEGATE] reportData: bandWrite.writeData() call completed")
        
        print("🔥 [APP_DELEGATE] reportData: Creating firebaseEventDataWrite instance...")
        let showWrite = firebaseEventDataWrite()
        print("🔥 [APP_DELEGATE] reportData: Calling showWrite.writeData()...")
        showWrite.writeData();
        print("🔥 [APP_DELEGATE] reportData: showWrite.writeData() call completed")
        
        print("🔥 [APP_DELEGATE] reportData: ========== EXIT ==========")
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        print("🔄 App entering background - starting bulk loading process")
        print("🔍 DEBUG: App state: \(application.applicationState.rawValue)")
        print("🔍 DEBUG: Active scenes: \(UIApplication.shared.connectedScenes.count)")
        
        // Add safeguard: Only proceed if app is actually in background
        guard application.applicationState == .background else {
            print("⚠️ BLOCKED: applicationDidEnterBackground called but app state is not background (\(application.applicationState.rawValue))")
            return
        }
        
        // Additional check: Don't run bulk loading if there's a modal presented
        if let rootViewController = application.windows.first?.rootViewController {
            if rootViewController.presentedViewController != nil {
                print("⚠️ BLOCKED: Modal view controller is presented - not truly in background")
                return
            }
        }
        
        // Request background execution time from iOS for all bulk operations
        var backgroundTask: UIBackgroundTaskIdentifier = .invalid
        backgroundTask = application.beginBackgroundTask(withName: "BulkDataLoading") {
            // This block is called if the background task is about to expire
            print("⚠️ Background task time expired, ending task")
            if backgroundTask != .invalid {
                application.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
        }
        
        // Move notification processing to background to avoid blocking main thread
        DispatchQueue.global(qos: .utility).async {
            let localNotication = localNoticationHandler()
            localNotication.clearNotifications()
            localNotication.addNotifications()
            print("📱 Local notifications processing completed")
        }
        
        // iCloud data sync (using SQLiteiCloudSync - Default profile only)
        DispatchQueue.global(qos: .userInitiated).async {
            let sqliteiCloudSync = SQLiteiCloudSync()
            sqliteiCloudSync.syncPrioritiesToiCloud()
            sqliteiCloudSync.syncAttendanceToiCloud()
            print("☁️ iCloud sync completed (Default profile only)")
        }
        
        // Gate bulk operations behind network test - never run heavy operations in bad network
        print("🌐 GATED BULK OPERATIONS: Testing network before bulk downloads")
        self.performBulkOperationsWithNetworkGating()
        
        // End background task after a delay (give time for operations to complete)
        DispatchQueue.main.asyncAfter(deadline: .now() + 30) {
            if backgroundTask != .invalid {
                print("🔄 Ending background task")
                application.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
        }
        
        //Messaging.messaging().disconnect()
        print("Disconnected from FCM.")
        // reportData() is now gated behind network test in performBulkOperationsWithNetworkGating()
    }

    // MARK: - Network-Gated Bulk Operations
    
    /// Performs network test first, then executes bulk operations (images, notes, Firebase) only if network is good
    /// This prevents heavy operations from running in poor network conditions and consuming resources
    private func performBulkOperationsWithNetworkGating() {
        print("🌐 NETWORK GATING: Starting REAL network test before bulk operations")
        
        // Run network test on background queue to never block
        DispatchQueue.global(qos: .utility).async {
            print("🌐 NETWORK GATING: Performing real HTTP request to test network quality")
            
            // ROBUST NETWORK TEST: Do actual HTTP request instead of relying on cached values
            let isNetworkGood = self.performRobustNetworkTest()
            
            print("🌐 NETWORK GATING: Robust network test completed - result: \(isNetworkGood)")
            
            if isNetworkGood {
                print("🌐 NETWORK GATING: ✅ Network is good - proceeding with bulk operations")
                self.performBulkImageDownload()
                self.performBulkDescriptionDownload()
                self.performFirebaseReporting()
            } else {
                print("🌐 NETWORK GATING: ❌ Network is poor/down - skipping ALL bulk operations")
                print("🌐 NETWORK GATING: This should prevent bulk operations in 100% packet loss scenarios")
            }
        }
    }
    
    /// Performs a robust network test with actual HTTP request - not cached values
    /// This properly detects 100% packet loss and poor network conditions
    /// - Returns: true if network is good enough for bulk operations, false otherwise
    private func performRobustNetworkTest() -> Bool {
        print("🌐 ROBUST TEST: Starting real HTTP request to test network")
        
        // Test with a lightweight, fast endpoint
        guard let url = URL(string: "https://www.google.com/generate_204") else {
            print("🌐 ROBUST TEST: ❌ Invalid test URL")
            return false
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 5.0 // 5 second timeout for bulk operations test
        request.cachePolicy = .reloadIgnoringLocalAndRemoteCacheData // Force fresh request
        
        let semaphore = DispatchSemaphore(value: 0)
        var testResult = false
        
        print("🌐 ROBUST TEST: Making HTTP request to \(url.absoluteString)")
        let startTime = Date()
        
        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            let duration = Date().timeIntervalSince(startTime)
            
            if let error = error {
                print("🌐 ROBUST TEST: ❌ Network error after \(String(format: "%.2f", duration))s: \(error.localizedDescription)")
                if error.localizedDescription.contains("timed out") {
                    print("🌐 ROBUST TEST: ❌ TIMEOUT - This indicates poor network or 100% packet loss")
                }
                testResult = false
            } else if let httpResponse = response as? HTTPURLResponse {
                print("🌐 ROBUST TEST: ✅ HTTP response received after \(String(format: "%.2f", duration))s: \(httpResponse.statusCode)")
                // Google's generate_204 returns 204 No Content on success
                testResult = (httpResponse.statusCode == 204 || httpResponse.statusCode == 200)
                if testResult {
                    print("🌐 ROBUST TEST: ✅ Network is good for bulk operations")
                } else {
                    print("🌐 ROBUST TEST: ❌ Unexpected HTTP status: \(httpResponse.statusCode)")
                }
            } else {
                print("🌐 ROBUST TEST: ❌ No response received")
                testResult = false
            }
            
            semaphore.signal()
        }
        
        task.resume()
        
        // Wait for test to complete with timeout
        let timeoutResult = semaphore.wait(timeout: .now() + 6.0)
        if timeoutResult == .timedOut {
            print("🌐 ROBUST TEST: ❌ SEMAPHORE TIMEOUT - Network test took too long, assuming bad network")
            task.cancel()
            testResult = false
        }
        
        print("🌐 ROBUST TEST: Final result: \(testResult ? "NETWORK GOOD" : "NETWORK BAD/DOWN")")
        return testResult
    }
    
    /// Performs bulk image download - only called after network test passes
    private func performBulkImageDownload() {
        print("🖼️ BULK IMAGE DOWNLOAD: Starting image download (network verified)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            print("🖼️ Image loading background queue started")
            
            // Use a dedicated imageHandler instance for background processing
            let imageHandlerInstance = imageHandler()
            let combinedImageList = CombinedImageListHandler.shared.combinedImageList
            print("🖼️ Starting bulk image loading with \(combinedImageList.count) images")
            
            if combinedImageList.isEmpty {
                print("⚠️ Combined image list is empty - forcing regeneration")
                
                // Use singleton handlers for image list generation
                let bandNameHandle = bandNamesHandler.shared
                let scheduleHandle = scheduleHandler.shared
                
                CombinedImageListHandler.shared.generateCombinedImageList(
                    bandNameHandle: bandNameHandle,
                    scheduleHandle: scheduleHandle
                ) {
                    let updatedList = CombinedImageListHandler.shared.combinedImageList
                    print("🖼️ After regeneration: \(updatedList.count) images available")
                    
                    // Proceed with bulk loading after regeneration
                    print("🖼️ Calling getAllImages() for bulk download...")
                    imageHandlerInstance.getAllImages()
                    print("🖼️ getAllImages() call completed")
                }
            } else {
                // Proceed directly with bulk loading if list already exists
                print("🖼️ Calling getAllImages() for bulk download...")
                imageHandlerInstance.getAllImages()
                print("🖼️ getAllImages() call completed")
            }
            
            print("🖼️ Background image loading completed")
        }
    }
    
    /// Performs bulk description/notes download - only called after network test passes
    private func performBulkDescriptionDownload() {
        print("📝 BULK DESCRIPTION DOWNLOAD: Starting description download (network verified)")
        
        DispatchQueue.global(qos: .userInitiated).async {
            print("📝 Description loading background queue started")
            print("📝 Starting bulk description loading")
            
            // Download all missing descriptions and replace obsolete cached files
            self.bandDescriptions.downloadAllDescriptionsOnAppExit()
            
            // Since network was already verified, we can proceed directly
            print("📝 Network already verified - proceeding with description downloads")
            
            // Ensure description map is loaded before bulk loading
            print("📝 Loading description map file...")
            self.bandDescriptions.getDescriptionMapFile()
            print("📝 Parsing description map...")
            self.bandDescriptions.getDescriptionMap()
            
            print("📝 Description map contains \(self.bandDescriptions.bandDescriptionUrl.count) entries")
            if self.bandDescriptions.bandDescriptionUrl.isEmpty {
                print("⚠️ Description URL map is empty - bulk loading will be skipped")
                return
            }
            
            print("📝 Starting bulk download of \(self.bandDescriptions.bandDescriptionUrl.count) descriptions")
            print("📝 Calling getAllDescriptions() for allINotes bulk download...")
            self.bandDescriptions.getAllDescriptions()
            print("📝 getAllDescriptions() allINotes call completed")
        }
    }
    
    /// Performs Firebase reporting - only called after network test passes
    private func performFirebaseReporting() {
        print("🔥 FIREBASE REPORTING: Starting Firebase reporting (network verified)")
        
        DispatchQueue.global(qos: .utility).async {
            print("🔥 Firebase reporting background queue started")
            // Since network was already verified, we can proceed directly
            self.reportData()
            print("🔥 Firebase reporting completed")
        }
    }


    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        
    }


    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        
        print("AppDelegate: App entering foreground - using same robust refresh as pull-to-refresh")
        
        // CRITICAL: Synchronize UserDefaults to pick up any Settings.bundle changes (like PointerUrl)
        UserDefaults.standard.synchronize()
        print("🔧 [POINTER_DEBUG] UserDefaults synchronized in applicationWillEnterForeground")
        
        // Move all potentially blocking operations to background thread
        DispatchQueue.global(qos: .utility).async {
            // Force iCloud synchronization when app enters foreground
            print("iCloud: App entering foreground, forcing iCloud synchronization in background")
            NSUbiquitousKeyValueStore.default.synchronize()
            
            // Post foreground refresh notification on main thread after sync completes
            DispatchQueue.main.async {
                print("iCloud: Foreground sync complete, posting foreground refresh notification")
                NotificationCenter.default.post(name: Notification.Name("ForegroundRefresh"), object: nil)
            }
        }
    }

    @objc func iCloudKeysChanged(_ notification: Notification) {
        
        print("iCloud: *** EXTERNAL CHANGE DETECTED *** Starting iCloud data sync")
        print("iCloud: Notification received: \(notification)")
        print("iCloud: Notification name: \(notification.name)")
        print("iCloud: Notification object: \(String(describing: notification.object))")
        print("iCloud: Notification userInfo: \(String(describing: notification.userInfo))")
        
        // Check what specific keys changed if available
        if let changeReason = notification.userInfo?[NSUbiquitousKeyValueStoreChangeReasonKey] as? NSNumber {
            let reason = changeReason.intValue
            switch reason {
            case NSUbiquitousKeyValueStoreServerChange:
                print("iCloud: Change reason: Server change (data changed on another device)")
            case NSUbiquitousKeyValueStoreInitialSyncChange:
                print("iCloud: Change reason: Initial sync")
            case NSUbiquitousKeyValueStoreQuotaViolationChange:
                print("iCloud: Change reason: Quota violation")
            case NSUbiquitousKeyValueStoreAccountChange:
                print("iCloud: Change reason: Account change")
            default:
                print("iCloud: Change reason: Unknown (\(reason))")
            }
        }
        
        if let changedKeys = notification.userInfo?[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
            print("iCloud: Changed keys: \(changedKeys)")
        }
        
        // Move external iCloud change processing to background to avoid blocking main thread
        DispatchQueue.global(qos: .utility).async {
            if iCloudDataisLoading || iCloudScheduleDataisLoading {
                print("iCloud: Skipping iCloud data sync because a read operation is already in progress.")
                return
            }
            
            // NEW: Use Core Data iCloud sync system instead of old iCloudDataHandler
            let sqliteiCloudSync = SQLiteiCloudSync()
            
            // Sync priorities from iCloud
            sqliteiCloudSync.syncPrioritiesFromiCloud {
                print("iCloud: Priority sync completed from external change")
            }
            
            // Sync attendance from iCloud
            sqliteiCloudSync.syncAttendanceFromiCloud {
                print("iCloud: Attendance sync completed from external change")
            }
            
            // Write local data to iCloud
            sqliteiCloudSync.syncPrioritiesToiCloud()
            sqliteiCloudSync.syncAttendanceToiCloud()
            
            print("iCloud: External change processing completed, refreshing GUI...")
            
            // Refresh the UI on main thread after background processing
            DispatchQueue.main.async {
                print("iCloud: Sending GUI refresh")
                NotificationCenter.default.post(name: Notification.Name(rawValue: "iCloudRefresh"), object: nil)
            }
        }
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.

        self.saveContext()
        
        // Download all missing descriptions and replace obsolete cached files
        bandDescriptions.downloadAllDescriptionsOnAppExit()
    }

    // MARK: - Helper Methods
    
    private func createPlaceholderDetailViewController() -> UIViewController {
        let placeholderController = UIViewController()
        // Match the dark theme used in DetailView
        placeholderController.view.backgroundColor = UIColor.black
        
        // Add a label to show instructions
        let label = UILabel()
        label.text = NSLocalizedString("SelectBandMessage", comment: "Message shown in detail view when no band is selected")
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 18, weight: .medium)
        label.textColor = UIColor.white // White text on black background
        label.numberOfLines = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        
        placeholderController.view.addSubview(label)
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: placeholderController.view.safeAreaLayoutGuide.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: placeholderController.view.safeAreaLayoutGuide.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: placeholderController.view.safeAreaLayoutGuide.leadingAnchor, constant: 60),
            label.trailingAnchor.constraint(lessThanOrEqualTo: placeholderController.view.safeAreaLayoutGuide.trailingAnchor, constant: -60),
            label.widthAnchor.constraint(lessThanOrEqualToConstant: 300)
        ])
        
        placeholderController.title = "Band Details"
        return placeholderController
    }

    // MARK: - Split view

    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController:UIViewController, onto primaryViewController:UIViewController) -> Bool {
        // Since we're now using SwiftUI navigation instead of DetailViewController,
        // we can use a simpler approach for split view collapse behavior
        if let secondaryAsNavController = secondaryViewController as? UINavigationController {
            // If there's no meaningful content to show (placeholder or no controller), collapse the secondary view
            if secondaryAsNavController.topViewController == nil {
                return true
            }
            
            // If it's our placeholder controller, also collapse
            if secondaryAsNavController.topViewController?.title == "Band Details" &&
               secondaryAsNavController.topViewController?.children.isEmpty == true {
                return true
            }
        }
        return false
    }
    // MARK: - Core Data stack

    lazy var applicationDocumentsDirectory: URL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.rdorn._0000TonsBands" in the application's documents Application Support directory.
        let urls = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return urls[urls.count-1]
    }()

    lazy var managedObjectModel: NSManagedObjectModel = {
        let modelURL = Bundle.main.url(forResource: "_0000TonsBands", withExtension: "momd")
        guard let url = modelURL else {
            fatalError("Failed to find model URL for _0000TonsBands.momd")
        }
        guard let model = NSManagedObjectModel(contentsOf: url) else {
            fatalError("Failed to load managed object model from \(url)")
        }
        return model
    }()

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        let coordinator = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.appendingPathComponent("_0000TonsBands.sqlite")
        do {
            try coordinator.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
        } catch {
            print("Unresolved error adding persistent store: \(error)")
            return nil
        }
        return coordinator
    }()

    lazy var managedObjectContext: NSManagedObjectContext? = {
        // Returns the managed object context for the application (which is already bound to the persistent store coordinator for the application.) This property is optional since there are legitimate error conditions that could cause the creation of the context to fail.
        let coordinator = self.persistentStoreCoordinator
        if coordinator == nil {
            return nil
        }
        var managedObjectContext = NSManagedObjectContext()
        managedObjectContext.persistentStoreCoordinator = coordinator
        return managedObjectContext
    }()

    // MARK: - Core Data Saving support

    func saveContext () {
        if let moc = self.managedObjectContext {
            var error: NSError? = nil
            if moc.hasChanges {
                do {
                    try moc.save()
                } catch let error1 as NSError {
                    error = error1
                    // Replace this implementation with code to handle the error appropriately.
                    // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                    //NSLog("Unresolved error \(error), \(error!.userInfo)")
                    abort()
                }
            }
        }
    }
    
    // MARK: - Shared Preferences Import Support
    
    /// Check if the file extension is valid for THIS specific app (no cross-compatibility)
    private func isValidShareExtension(_ extension: String) -> Bool {
        // 70K Bands only accepts .70kshare, MDF only accepts .mdfshare
        let expectedExtension = FestivalConfig.current.isMDF() ? "mdfshare" : "70kshare"
        return `extension` == expectedExtension
    }
    
    /// Handles opening share files (iOS 9+) - app-specific extension only
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("📥 AppDelegate: Opening URL (iOS 9+): \(url)")
        
        // Check if this is a valid shared preferences file for THIS app
        if isValidShareExtension(url.pathExtension) {
            // Handle the import
            return SharedPreferencesImportHandler.shared.handleIncomingFile(url)
        } else {
            print("⚠️ Rejected file with extension .\(url.pathExtension) - not compatible with this app")
        }
        
        return false
    }
    
    /// Legacy method for opening URLs (iOS 4.2-9.0, still called by some apps)
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        print("📥 AppDelegate: Opening URL (Legacy): \(url)")
        
        // Check if this is a valid shared preferences file for THIS app
        if isValidShareExtension(url.pathExtension) {
            // Handle the import
            return SharedPreferencesImportHandler.shared.handleIncomingFile(url)
        } else {
            print("⚠️ Rejected file with extension .\(url.pathExtension) - not compatible with this app")
        }
        
        return false
    }
    
    /// Handle opening documents (alternative entry point)
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("📥 AppDelegate: willFinishLaunchingWithOptions")
        
        // Check if launched with a URL
        if let url = launchOptions?[.url] as? URL {
            print("📥 Launched with URL: \(url)")
            if isValidShareExtension(url.pathExtension) {
                // Delay handling to ensure UI is ready
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    _ = SharedPreferencesImportHandler.shared.handleIncomingFile(url)
                }
            } else {
                print("⚠️ Rejected file with extension .\(url.pathExtension) - not compatible with this app")
            }
        }
        
        return true
    }

}

extension AppDelegate : UNUserNotificationCenterDelegate {
    
    // Receive displayed notifications for iOS 10 devices.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        if let messageID = userInfo[gcmMessageIDKey] {
            print("sendLocalAlert! Message ID: \(messageID)")
            print("sendLocalAlert! 1 \(userInfo)")
            extractAlertMessage(userInfo: userInfo as! Dictionary<String, AnyObject>);
            // Post notification for foreground push
            NotificationCenter.default.post(name: Notification.Name("PushNotificationReceived"), object: nil)
            completionHandler([])
        } else {
            Messaging.messaging().appDidReceiveMessage(userInfo)
            completionHandler([.alert, .badge, .sound])
        }
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse,
                                withCompletionHandler completionHandler: @escaping () -> Void) {
        
        let userInfo = response.notification.request.content.userInfo
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
        print("sendLocalAlert! 2 \(userInfo)")
        extractAlertMessage(userInfo: userInfo as! Dictionary<String, AnyObject>);
        Messaging.messaging().appDidReceiveMessage(userInfo)
        completionHandler()
    }
 
}
// [END ios_10_message_handling]
/*
extension AppDelegate : MessagingDelegate {
    // [START refresh_token]
    func messaging(_ messaging: Messaging, didRefreshRegistrationToken fcmToken: String) {
        print("FCM Firebase registration token: \(fcmToken)")
        //let helpMessage = "Firebase registration token: \(fcmToken)"
        
        //let pasteBoard = UIPasteboard.general
        //pasteBoard.string = helpMessage
    }
    // [END refresh_token]
}
*/

extension AppDelegate: MessagingDelegate {
  func messaging(
    _ messaging: Messaging,
    didReceiveRegistrationToken fcmToken: String?
  ) {
    print("FCM Firebase registration token: \(fcmToken)")
    let tokenDict = ["token": fcmToken ?? ""]
    NotificationCenter.default.post(
      name: Notification.Name("FCMToken"),
      object: nil,
      userInfo: tokenDict)
  }
}
