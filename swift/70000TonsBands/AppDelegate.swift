//
//  AppDelegate.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/2/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import UIKit
import UserNotifications
import Firebase
import FirebaseCore
import FirebaseMessaging
import Foundation

/// Resolved at use time — must not call `UIApplication.shared` during module load (crashes before UIApplicationMain).
var appDelegate: AppDelegate? {
    UIApplication.shared.delegate as? AppDelegate
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
    
    
    var window: UIWindow?
    /// Dedupes the same inbound share URL when both SceneDelegate and AppDelegate receive it.
    private var lastHandledShareURL: URL?
    private var lastHandledShareAt: Date?
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
    
    /// Prevents duplicate Firebase sync when both AppDelegate and SceneDelegate receive background callbacks.
    private var lastBackgroundSyncTrigger: Date?
    private let backgroundSyncDebounceSeconds: TimeInterval = 2.0
    private var lastForegroundRecoveryTrigger: Date?
    private let foregroundRecoveryDebounceSeconds: TimeInterval = 2.0
    /// True after a real scene/app background. Consumed on foreground so details/preferences
    /// navigation (which never backgrounds the scene) does not start a core CSV refresh.
    private var hasEnteredBackgroundForCoreRefresh = false
    private var lastCoreRefreshFromBackgroundAt: Date?
    private let coreRefreshFromBackgroundMinInterval: TimeInterval = 5.0
    private let coreRefreshLock = NSLock()
    private var firebaseSyncInFlight = false
    private var bulkDownloadInFlight = false
    private let bulkDownloadLock = NSLock()
    /// Ignores a second bulk start if the previous pass just finished (quick app-switch bounce).
    private let bulkRapidRetriggerInterval: TimeInterval = 30
    private var lastBulkStartedAt: Date?
    private var lastBulkFinishedAt: Date?
    private let firebaseSyncLock = NSLock()
    
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
        
        // Check for custom pointer URL first
        let customPointerUrl = UserDefaults.standard.string(forKey: "CustomPointerUrl") ?? ""
        let trimmedCustomUrl = customPointerUrl.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedCustomUrl.isEmpty {
            return trimmedCustomUrl
        }
        
        // Otherwise use default based on preference
        let pointerUrlPref = UserDefaults.standard.string(forKey: "PointerUrl") ?? "NOT_SET"
        if pointerUrlPref == testingSetting {
            return FestivalConfig.current.defaultStorageUrlTest
        }
        return FestivalConfig.current.defaultStorageUrl
    }
    
    private func downloadAndUpdatePointerFile(reason: String, enforceOncePerLaunch: Bool, completion: ((Bool) -> Void)? = nil) {
        if enforceOncePerLaunch {
            guard !hasAttemptedPointerDownloadOnLaunch else {
                debugLog("downloadAndUpdatePointerFile(\(reason)): Already attempted download on this launch, skipping")
                completion?(false)
                return
            }
            hasAttemptedPointerDownloadOnLaunch = true
        }
        
        debugLog("downloadAndUpdatePointerFile(\(reason)): Starting pointer file download and update")
        
        // POLICY: Pointer file network download is only allowed on startup and pull-to-refresh.
        // This function is the ONLY code path that should download the pointer file.
        
        guard Reachability.isConnectedToNetwork() else {
            debugWarning("downloadAndUpdatePointerFile(\(reason)): No internet connection available, skipping download")
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
            debugError("downloadAndUpdatePointerFile(\(reason)): Invalid URL: \(defaultStorageUrl)")
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
                debugError("downloadAndUpdatePointerFile(\(reason)): Download error: \(error)")
                
                // If using custom pointer URL and it fails, show error message once per launch
                let customPointerUrl = UserDefaults.standard.string(forKey: "CustomPointerUrl") ?? ""
                let usingCustomUrl = !customPointerUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                
                if usingCustomUrl {
                    let errorKey = "CustomPointerUrlErrorShown"
                    let alreadyShown = UserDefaults.standard.bool(forKey: errorKey)
                    
                    if !alreadyShown {
                        UserDefaults.standard.set(true, forKey: errorKey)
                        DispatchQueue.main.async {
                            // Show error alert
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let rootViewController = windowScene.windows.first?.rootViewController {
                                let alert = UIAlertController(
                                    title: "Pointer URL Error",
                                    message: "Failed to load data from Custom Pointer URL. Please check the URL or clear it to use the default.",
                                    preferredStyle: .alert
                                )
                                alert.addAction(UIAlertAction(title: "OK", style: .default))
                                rootViewController.present(alert, animated: true)
                            }
                        }
                    }
                }
                
                DispatchQueue.main.async { completion?(false) }
                return
            }
            
            guard let data = data,
                  let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                debugError("downloadAndUpdatePointerFile(\(reason)): Invalid response or no data")
                
                // If using custom pointer URL and it fails, show error message once per launch
                let customPointerUrl = UserDefaults.standard.string(forKey: "CustomPointerUrl") ?? ""
                let usingCustomUrl = !customPointerUrl.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                
                if usingCustomUrl {
                    let errorKey = "CustomPointerUrlErrorShown"
                    let alreadyShown = UserDefaults.standard.bool(forKey: errorKey)
                    
                    if !alreadyShown {
                        UserDefaults.standard.set(true, forKey: errorKey)
                        DispatchQueue.main.async {
                            // Show error alert
                            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let rootViewController = windowScene.windows.first?.rootViewController {
                                let alert = UIAlertController(
                                    title: "Pointer URL Error",
                                    message: "Failed to load data from Custom Pointer URL. Please check the URL or clear it to use the default.",
                                    preferredStyle: .alert
                                )
                                alert.addAction(UIAlertAction(title: "OK", style: .default))
                                rootViewController.present(alert, animated: true)
                            }
                        }
                    }
                }
                
                DispatchQueue.main.async { completion?(false) }
                return
            }
            
            // Check if the downloaded data is not too large (safety check)
            let maxSize = 1024 * 1024 // 1MB limit
            guard data.count <= maxSize else {
                debugError("downloadAndUpdatePointerFile(\(reason)): Downloaded data too large (\(data.count) bytes), aborting")
                DispatchQueue.main.async { completion?(false) }
                return
            }
            
            do {
                try data.write(to: URL(fileURLWithPath: tempPointerFile))
                debugLog("downloadAndUpdatePointerFile(\(reason)): Successfully downloaded pointer file to temp location")
                
                guard let downloadedContent = String(data: data, encoding: .utf8),
                      !downloadedContent.isEmpty else {
                    debugError("downloadAndUpdatePointerFile(\(reason)): Downloaded content is empty or invalid")
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
                    debugError("downloadAndUpdatePointerFile(\(reason)): Downloaded content does not appear to be valid pointer data")
                    DispatchQueue.main.async { completion?(false) }
                    return
                }
                
                let fileManager = FileManager.default
                
                if fileManager.fileExists(atPath: cachedPointerFile) {
                    do {
                        try fileManager.removeItem(atPath: cachedPointerFile)
                        debugLog("downloadAndUpdatePointerFile(\(reason)): Removed existing cached pointer file")
                    } catch {
                        debugWarning("downloadAndUpdatePointerFile(\(reason)): Failed to remove existing cached pointer file: \(error)")
                    }
                }
                
                do {
                    try fileManager.moveItem(atPath: tempPointerFile, toPath: cachedPointerFile)
                    debugLog("downloadAndUpdatePointerFile(\(reason)): Successfully replaced cached pointer file")
                    
                    // Clear in-memory cache to force reload from disk
                    storePointerLock.sync() {
                        cacheVariables.storePointerData.removeAll()
                    }
                    debugLog("downloadAndUpdatePointerFile(\(reason)): Cleared in-memory pointer cache")
                    
                    // Pre-warm common pointer values (disk-backed; no network)
                    DispatchQueue.global(qos: .background).async {
                        _ = getPointerUrlData(keyValue: "artistUrl")
                        _ = getPointerUrlData(keyValue: "scheduleUrl")
                        let resolvedEventYearString = getPointerUrlData(keyValue: "eventYear")
                        _ = getPointerUrlData(keyValue: "reportUrl")
                        
                        debugLog("downloadAndUpdatePointerFile(\(reason)): Forced reload of pointer data completed")
                        
                        // Update global eventYear if user is on "Current".
                        // Respect explicit user year choices (e.g. "2025") by not overriding them.
                        let yearPreference = getScheduleUrl()
                        if yearPreference == "Current" {
                            if let y = Int(resolvedEventYearString), y > 2000 {
                                DispatchQueue.main.async {
                                    eventYear = y
                                    debugLog("downloadAndUpdatePointerFile(\(reason)): Updated global eventYear to \(y) (Current)")
                                }
                            }
                        } else if yearPreference.isYearString, let y = Int(yearPreference), y > 2000 {
                            DispatchQueue.main.async {
                                eventYear = y
                                debugLog("downloadAndUpdatePointerFile(\(reason)): Preserved explicit year preference, eventYear=\(y)")
                            }
                        }
                        
                        DispatchQueue.main.async {
                            SharedCommentsSettings.loadEnableSharedComments()
                            NotificationCenter.default.post(name: Notification.Name("PointerDataUpdated"), object: nil)
                            completion?(true)
                        }
                    }
                    
                } catch {
                    debugError("downloadAndUpdatePointerFile(\(reason)): Failed to move temp file to final location: \(error)")
                    if fileManager.fileExists(atPath: tempPointerFile) {
                        try? fileManager.removeItem(atPath: tempPointerFile)
                    }
                    DispatchQueue.main.async { completion?(false) }
                }
            } catch {
                debugError("downloadAndUpdatePointerFile(\(reason)): Failed to write downloaded data to temp file: \(error)")
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
    
        // Core Data migration removed - all data now uses SQLite directly
        
        // Reset custom pointer URL error flag on app launch
        UserDefaults.standard.set(false, forKey: "CustomPointerUrlErrorShown")
        UserDefaults.standard.synchronize()
        
        // Window and root view controller are configured in SceneDelegate.configureMainWindow(for:).
        
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
            
            // Set flag to indicate Firebase is now configured
            AppDelegate.isFirebaseConfigured = true
            let firebaseCompleteTime = Date()
            print("✅ [TIMING] Firebase configured COMPLETE at \(firebaseCompleteTime.timeIntervalSince1970)")
            print("✅ Firebase configured")
            
            setupCurrentYearUrls()
            SharedCommentsSettings.loadEnableSharedComments()
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
                    
                    // Launch policy: read from iCloud only.
                    let pullGroup = DispatchGroup()
                    pullGroup.enter()
                    sqliteiCloudSync.syncPrioritiesFromiCloud {
                        print("iCloud: Priority pull completed")
                        pullGroup.leave()
                    }
                    pullGroup.enter()
                    sqliteiCloudSync.syncAttendanceFromiCloud {
                        print("iCloud: Attendance pull completed")
                        pullGroup.leave()
                    }
                    pullGroup.notify(queue: .main) {
                        print("iCloud: Launch read sync completed, refreshing display...")
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
        
        var presentedVC = keyWindowRootViewController
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

        // Retry deferred Firebase sync and local alert rebuilds after foreground return.
        recoverDeferredBackgroundWorkOnForeground()
        
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
                print("🔥 [TIMING] Scheduling Firebase user write with jitter")
                firebaseUserWrite.scheduleWriteIfNeeded()
            } else {
                print("⚠️ [TIMING] Firebase NOT configured yet, skipping Firebase user write")
            }
            
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
    
    func reportData(completion: (() -> Void)? = nil, prioritizeBandFirst: Bool = false){
        print("🔥 [APP_DELEGATE] reportData: ========== ENTRY ==========")
        print("🔥 [APP_DELEGATE] reportData: Called from thread: \(Thread.isMainThread ? "main" : "background")")
        
        internetAvailble = isInternetAvailable();
        print("🔥 [APP_DELEGATE] reportData: Internet available: \(internetAvailble)")
        
        let runBand = FirebaseWriteMonitor.shared.shouldRunBandSync()
        let runShow = FirebaseWriteMonitor.shared.shouldRunShowSync()
        
        if prioritizeBandFirst && runBand && runShow {
            FirebaseSyncTrace.log("reportData sequential", "band then show")
            let bandWrite = firebaseBandDataWrite()
            bandWrite.writeData {
                let showWrite = firebaseEventDataWrite()
                showWrite.writeData {
                    print("🔥 [APP_DELEGATE] reportData: ========== EXIT ==========")
                    completion?()
                }
            }
            return
        }
        
        let group = DispatchGroup()
        
        if runBand {
            group.enter()
            print("🔥 [APP_DELEGATE] reportData: Creating firebaseBandDataWrite instance...")
            let bandWrite = firebaseBandDataWrite()
            print("🔥 [APP_DELEGATE] reportData: Calling bandWrite.writeData()...")
            bandWrite.writeData {
                print("🔥 [APP_DELEGATE] reportData: bandWrite.writeData() finished")
                group.leave()
            }
        } else {
            print("⏭️ [APP_DELEGATE] reportData: No pending band sync — skipping bandData upload")
        }
        
        if runShow {
            group.enter()
            print("🔥 [APP_DELEGATE] reportData: Creating firebaseEventDataWrite instance...")
            let showWrite = firebaseEventDataWrite()
            print("🔥 [APP_DELEGATE] reportData: Calling showWrite.writeData()...")
            showWrite.writeData {
                print("🔥 [APP_DELEGATE] reportData: showWrite.writeData() finished")
                group.leave()
            }
        } else {
            print("⏭️ [APP_DELEGATE] reportData: No pending show sync — skipping showData upload")
        }
        
        group.notify(queue: DispatchQueue.global(qos: .utility)) {
            print("🔥 [APP_DELEGATE] reportData: ========== EXIT ==========")
            completion?()
        }
    }
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        handleAppEnteringBackground(application: application)
    }

    /// Shared background handler — called from AppDelegate and SceneDelegate.
    func handleAppEnteringBackground(application: UIApplication) {
        coreRefreshLock.lock()
        hasEnteredBackgroundForCoreRefresh = true
        coreRefreshLock.unlock()

        if let lastTrigger = lastBackgroundSyncTrigger,
           Date().timeIntervalSince(lastTrigger) < backgroundSyncDebounceSeconds {
            FirebaseSyncTrace.log("SKIP handleAppEnteringBackground", "debounced")
            return
        }
        lastBackgroundSyncTrigger = Date()

        FirebaseSyncTrace.snapshot("enterBackground-start")
        print("🔄 App entering background — marking true background for core refresh on return")
        print("🔍 DEBUG: App state: \(application.applicationState.rawValue)")
        print("🔍 DEBUG: Active scenes: \(UIApplication.shared.connectedScenes.count)")
        
        // Local schedule alerts: own background task — never gated on Firebase.
        LocalNotificationRebuildCoordinator.shared.runBackgroundRebuildIfNeeded(
            application: application,
            reason: "applicationDidEnterBackground"
        )
        
        // iCloud data sync (using SQLiteiCloudSync - Default profile only)
        DispatchQueue.global(qos: .userInitiated).async {
            let sqliteiCloudSync = SQLiteiCloudSync()
            sqliteiCloudSync.syncPrioritiesToiCloud()
            sqliteiCloudSync.syncAttendanceToiCloud()
            print("☁️ iCloud sync completed (Default profile only)")
        }
        
        firebaseUserWrite.flushPendingWriteOnBackground()
        startFirebaseSyncIfNeeded(application: application)
        
        //Messaging.messaging().disconnect()
        print("Disconnected from FCM.")
    }

    /// Retries Firebase sync and local alert rebuilds after foreground return.
    func recoverDeferredBackgroundWorkOnForeground() {
        recoverPendingFirebaseSyncOnForeground()
        LocalNotificationRebuildCoordinator.shared.recoverLocalAlertsOnForeground()
    }

    /// Bulk image/note prefetch readiness — intentionally NOT tied to local-alert rebuild gates.
    /// Alert rebuild requires schedule + current year; offline note/image cache must still run
    /// when browsing another year or before schedule is fully in memory.
    private static func bulkDownloadReadinessSnapshot() -> String {
        if MasterViewController.isYearChangeInProgress {
            return "yearChangeInProgress"
        }
        // Soft diagnostic only — do not block. CSV can stick true; notes/images must still prefetch.
        if MasterViewController.isCsvDownloadInProgress {
            return "ready-with-csv-in-progress"
        }
        if scheduleHandler.shared.schedulingData.isEmpty {
            return "ready-with-empty-schedule"
        }
        let alertSnapshot = LocalNotificationRebuildCoordinator.rebuildReadinessSnapshot()
        if alertSnapshot != "ready" {
            return "ready-alerts-would-block:\(alertSnapshot)"
        }
        return "ready"
    }

    private static func canRunBulkDownloadNow() -> Bool {
        // Only hard-block during year change (caches/URLs unstable).
        !MasterViewController.isYearChangeInProgress
    }

    /// Prefetch band images and notes after pointer, artists, schedule, and description map are loaded.
    func startBulkDownloadOnLaunchIfNeeded(reason: String) {
        let normalized = reason.lowercased()
        let allowRapidRetrigger = normalized.contains("pull-to-refresh")
        startBulkDownloadWork(context: "prefetch:\(reason)", allowRapidRetrigger: allowRapidRetrigger)
    }

    @discardableResult
    private func startBulkDownloadWork(context: String, allowRapidRetrigger: Bool = false) -> Bool {
        let readiness = Self.bulkDownloadReadinessSnapshot()
        guard Self.canRunBulkDownloadNow() else {
            print("📦 [BULK_DOWNLOAD] skip bulk (\(context)) — not ready: \(readiness)")
            return false
        }
        if readiness != "ready" {
            print("📦 [BULK_DOWNLOAD] proceeding despite soft condition (\(context)): \(readiness)")
        }

        bulkDownloadLock.lock()
        if bulkDownloadInFlight {
            let elapsed = lastBulkStartedAt.map { Int(Date().timeIntervalSince($0)) } ?? 0
            bulkDownloadLock.unlock()
            print("📦 [BULK_DOWNLOAD] skip (\(context)) — already in flight for \(elapsed)s (will resume if the app was briefly backgrounded)")
            return false
        }
        if !allowRapidRetrigger,
           let finished = lastBulkFinishedAt,
           Date().timeIntervalSince(finished) < bulkRapidRetriggerInterval {
            bulkDownloadLock.unlock()
            print("📦 [BULK_DOWNLOAD] skip (\(context)) — previous pass finished \(Int(Date().timeIntervalSince(finished)))s ago (rapid foreground bounce)")
            return false
        }
        bulkDownloadInFlight = true
        lastBulkStartedAt = Date()
        bulkDownloadLock.unlock()

        print("📦 [BULK_DOWNLOAD] starting bulk downloads (\(context))")
        DispatchQueue.global(qos: .utility).async { [weak self] in
            defer {
                self?.bulkDownloadLock.lock()
                self?.bulkDownloadInFlight = false
                self?.lastBulkFinishedAt = Date()
                self?.bulkDownloadLock.unlock()
            }
            self?.performBulkOperationsWithNetworkGating()
        }
        return true
    }

    /// Start sync while app is still active/inactive (Home button) — avoids tight iOS background time limits.
    func startFirebaseSyncEarlyIfNeeded() {
        LocalNotificationRebuildCoordinator.shared.startLocalAlertsEarlyIfNeeded()
        guard FirebaseWriteMonitor.shared.shouldRunFullSync() else { return }
        FirebaseSyncTrace.log("early sync on resignActive", "before background suspension")
        startFirebaseSyncIfNeeded(application: nil)
    }

    /// Retries band/show upload after foreground return when background sync did not finish.
    func recoverPendingFirebaseSyncOnForeground() {
        guard FirebaseWriteMonitor.shared.shouldRunFullSync() else { return }

        if let lastTrigger = lastForegroundRecoveryTrigger,
           Date().timeIntervalSince(lastTrigger) < foregroundRecoveryDebounceSeconds {
            FirebaseSyncTrace.log("SKIP foreground recovery", "debounced")
            return
        }
        lastForegroundRecoveryTrigger = Date()

        FirebaseSyncTrace.snapshot("foreground-recovery-start")

        // A background attempt may still be marked in-flight after iOS suspended the app — allow a fresh run.
        firebaseSyncLock.lock()
        if firebaseSyncInFlight {
            FirebaseSyncTrace.log("foreground recovery", "resetting stale in-flight sync")
            firebaseSyncInFlight = false
        }
        firebaseSyncLock.unlock()

        let startSync = { [weak self] in
            guard let self = self else { return }
            guard FirebaseWriteMonitor.shared.shouldRunFullSync() else { return }
            FirebaseSyncTrace.log("foreground recovery", "starting sync")
            self.startFirebaseSyncIfNeeded(application: nil)
        }

        if AppDelegate.isFirebaseConfigured {
            startSync()
        } else {
            FirebaseSyncTrace.log("foreground recovery", "deferring 5s until Firebase configured")
            DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 5.0) {
                guard AppDelegate.isFirebaseConfigured else {
                    FirebaseSyncTrace.log("foreground recovery", "aborted — Firebase still not configured")
                    return
                }
                startSync()
            }
        }
    }

    /// Starts band/show Firebase sync on a dedicated background task and queue.
    /// Does not block notifications, iCloud, or bulk downloads.
    func startFirebaseSyncIfNeeded(application: UIApplication? = nil) {
        FirebaseSyncTrace.snapshot("startFirebaseSyncIfNeeded-entry")
        guard FirebaseWriteMonitor.shared.shouldRunFullSync() else {
            FirebaseSyncTrace.log("SKIP startFirebaseSyncIfNeeded", "shouldRunFullSync=false")
            return
        }

        firebaseSyncLock.lock()
        if firebaseSyncInFlight {
            firebaseSyncLock.unlock()
            FirebaseSyncTrace.log("SKIP startFirebaseSyncIfNeeded", "sync already in flight")
            return
        }
        firebaseSyncInFlight = true
        firebaseSyncLock.unlock()
        
        FirebaseSyncTrace.log("START Firebase sync task", application == nil ? "foreground-recovery" : "background")
        var firebaseBackgroundTask: UIBackgroundTaskIdentifier = .invalid
        if let application = application {
            firebaseBackgroundTask = application.beginBackgroundTask(withName: "FirebaseSync") { [weak self] in
                FirebaseSyncTrace.log("WARNING Firebase background task EXPIRING")
                print("⚠️ Firebase sync background task expiring")
                if FirebaseWriteMonitor.shared.hasPendingBandChanges() {
                    FirebaseWriteMonitor.shared.recordWriteFailure(context: "band_batch_bg_expired")
                }
                if FirebaseWriteMonitor.shared.hasPendingShowChanges() {
                    FirebaseWriteMonitor.shared.recordWriteFailure(context: "event_batch_bg_expired")
                }
                self?.firebaseSyncLock.lock()
                self?.firebaseSyncInFlight = false
                self?.firebaseSyncLock.unlock()
                FirebaseSyncTrace.log("foreground recovery", "will retry on next becomeActive")
            }
        }
        
        let isBackground = application != nil
        let hasDirtyChanges = FirebaseWriteMonitor.shared.hasPendingLocalChanges()
        DispatchQueue.global(qos: hasDirtyChanges ? .userInitiated : .utility).async { [weak self] in
            defer {
                if firebaseBackgroundTask != .invalid, let application = application {
                    application.endBackgroundTask(firebaseBackgroundTask)
                }
                self?.firebaseSyncLock.lock()
                self?.firebaseSyncInFlight = false
                self?.firebaseSyncLock.unlock()
            }
            guard let self = self else { return }
            if hasDirtyChanges {
                FirebaseSyncTrace.log("SKIP network test", "dirty sync")
            } else if !self.performRobustNetworkTest() {
                FirebaseSyncTrace.log("BLOCKED network test failed")
                print("🔥 FIREBASE REPORTING: Skipped — network test failed")
                return
            } else {
                FirebaseSyncTrace.log("network test passed — calling performFirebaseReporting")
            }
            self.performFirebaseReporting(isBackground: isBackground)
            FirebaseSyncTrace.snapshot("startFirebaseSyncIfNeeded-done")
        }
    }

    // MARK: - Network-Gated Bulk Operations
    
    /// Performs network test first, then executes bulk image/description downloads if network is good.
    /// Firebase sync is intentionally separate — see `startFirebaseSyncIfNeeded`.
    /// Image and notes run sequentially on this queue so both complete before bulk in-flight clears.
    /// The progress indicator is shown only when at least one image or note actually needs downloading.
    private func performBulkOperationsWithNetworkGating(includeDescriptionBulkDownload: Bool = true) {
        print("🌐 NETWORK GATING: Starting REAL network test before bulk operations (description bulk: \(includeDescriptionBulkDownload))")
        
        print("🌐 NETWORK GATING: Performing real HTTP request to test network quality")
        let isNetworkGood = self.performRobustNetworkTest()
        print("🌐 NETWORK GATING: Robust network test completed - result: \(isNetworkGood)")
        
        guard isNetworkGood else {
            print("🌐 NETWORK GATING: ❌ Network is poor/down - skipping ALL bulk operations")
            print("🌐 NETWORK GATING: This should prevent bulk operations in 100% packet loss scenarios")
            return
        }
        
        print("🌐 NETWORK GATING: ✅ Network is good - proceeding with bulk operations")
        self.ensureCombinedImageListReadyForBulk()
        
        let imageHandlerInstance = imageHandler()
        let pendingImages = imageHandlerInstance.countImagesNeedingDownload()
        let pendingNotes = includeDescriptionBulkDownload
            ? self.bandDescriptions.countMissingDescriptionsForBulk()
            : 0
        print("📦 [BULK_DOWNLOAD] pending work — images: \(pendingImages), notes: \(pendingNotes)")
        
        guard pendingImages > 0 || pendingNotes > 0 else {
            print("📦 [BULK_DOWNLOAD] all images and notes are up to date — skipping indicator")
            return
        }
        
        BulkDownloadProgressIndicator.shared.beginSession()
        if pendingImages > 0 {
            imageHandlerInstance.getAllImages()
        } else {
            print("🖼️ BULK IMAGE DOWNLOAD: All images cached, skipping")
        }
        if includeDescriptionBulkDownload {
            if pendingNotes > 0 {
                self.performBulkDescriptionDownload()
            } else {
                print("📝 BULK DESCRIPTION DOWNLOAD: All notes cached, skipping")
            }
        } else {
            print("🌐 NETWORK GATING: Skipping bulk description download (not requested for this entry point)")
        }
        BulkDownloadProgressIndicator.shared.finishAll()
        print("🌐 NETWORK GATING: Bulk image + notes pass finished")
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
    
    /// Regenerates the combined image list when it is empty so bulk counting sees real entries.
    private func ensureCombinedImageListReadyForBulk() {
        let combinedImageList = CombinedImageListHandler.shared.combinedImageList
        guard combinedImageList.isEmpty else { return }
        
        print("⚠️ Combined image list is empty - forcing regeneration before bulk download")
        let bandNameHandle = bandNamesHandler.shared
        let scheduleHandle = scheduleHandler.shared
        let regenSemaphore = DispatchSemaphore(value: 0)
        CombinedImageListHandler.shared.generateCombinedImageList(
            bandNameHandle: bandNameHandle,
            scheduleHandle: scheduleHandle
        ) {
            let updatedList = CombinedImageListHandler.shared.combinedImageList
            print("🖼️ After regeneration: \(updatedList.count) images available")
            regenSemaphore.signal()
        }
        _ = regenSemaphore.wait(timeout: .now() + 60)
    }
    
    /// Performs bulk description/notes download - only called after network test passes.
    /// Loads the description map on this AppDelegate instance, then downloads every missing current-marker note.
    /// Runs on the caller’s queue (already background from bulk work).
    private func performBulkDescriptionDownload() {
        print("📝 BULK DESCRIPTION DOWNLOAD: Starting description download (network verified)")
        self.bandDescriptions.downloadAllMissingDescriptionsForBulk()
        print("📝 BULK DESCRIPTION DOWNLOAD: Completed")
    }
    
    /// Performs Firebase reporting - only called after network test passes
    private static let bandEventSyncMaxJitterMs = 20_000
    private static let bandEventSyncBackgroundMaxJitterMs = 5_000

    private func performFirebaseReporting(isBackground: Bool = false) {
        let started = Date()
        FirebaseSyncTrace.snapshot("performFirebaseReporting-start")
        print("🔥 FIREBASE REPORTING: Starting Firebase reporting (network verified, background=\(isBackground))")
        
        let hasDirtyChanges = FirebaseWriteMonitor.shared.hasPendingLocalChanges()
        let uid = UIDevice.current.identifierForVendor?.uuidString ?? ""
        let maxJitterMs: Int
        if hasDirtyChanges {
            maxJitterMs = 0
        } else {
            maxJitterMs = isBackground ? Self.bandEventSyncBackgroundMaxJitterMs : Self.bandEventSyncMaxJitterMs
        }
        let delayMs = maxJitterMs > 0 ? FirebaseConnectionHelper.jitterDelayMs(for: uid, maxJitterMs: maxJitterMs) : 0
        FirebaseSyncTrace.log("jitter scheduled", "delayMs=\(delayMs) background=\(isBackground) dirty=\(hasDirtyChanges)")
        if delayMs > 0 {
            print("🔥 FIREBASE REPORTING: Waiting \(delayMs)ms deterministic jitter before band/show sync")
            Thread.sleep(forTimeInterval: Double(delayMs) / 1000.0)
        }

        print("🔥 Firebase reporting sync started")
        FirebaseWriteMonitor.shared.beginFullSyncAttempt()
        
        let syncSemaphore = DispatchSemaphore(value: 0)
        let prioritizeBandFirst = FirebaseWriteMonitor.shared.hasPendingBandChanges()
            && FirebaseWriteMonitor.shared.shouldRunShowSync()
        reportData(completion: {
            syncSemaphore.signal()
        }, prioritizeBandFirst: prioritizeBandFirst)
        let waitResult = syncSemaphore.wait(timeout: .now() + 60)
        if waitResult == .timedOut {
            FirebaseSyncTrace.log("TIMEOUT waiting for reportData completion", "waited=60s")
            print("⚠️ FIREBASE REPORTING: Timed out waiting for band/show writes to finish")
            if FirebaseWriteMonitor.shared.hasPendingBandChanges() {
                FirebaseWriteMonitor.shared.recordWriteFailure(context: "band_batch_timeout")
            }
            if FirebaseWriteMonitor.shared.hasPendingShowChanges() {
                FirebaseWriteMonitor.shared.recordWriteFailure(context: "event_batch_timeout")
            }
        } else {
            FirebaseSyncTrace.log("reportData completed", "elapsedMs=\(Int(Date().timeIntervalSince(started) * 1000))")
        }
        
        let finalized = FirebaseWriteMonitor.shared.finalizeFullSyncAttempt()
        FirebaseSyncTrace.log("finalizeFullSyncAttempt", "clearedFailures=\(finalized)")
        FirebaseSyncTrace.snapshot("performFirebaseReporting-end")
        print("🔥 Firebase reporting sync completed")
    }


    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        
    }


    func applicationWillEnterForeground(_ application: UIApplication) {
        handleAppReturningFromBackground()
    }

    /// True background → foreground (Home, app switcher, lock/unlock). Not details or preferences.
    /// Scene-based apps get this from SceneDelegate; AppDelegate is a deduped fallback.
    func handleAppReturningFromBackground() {
        recoverDeferredBackgroundWorkOnForeground()

        UserDefaults.standard.synchronize()

        coreRefreshLock.lock()
        let cameFromBackground = hasEnteredBackgroundForCoreRefresh
        hasEnteredBackgroundForCoreRefresh = false
        let lastRefresh = lastCoreRefreshFromBackgroundAt
        coreRefreshLock.unlock()

        guard cameFromBackground else {
            print("📦 [FOREGROUND_REFRESH] skip — not a true background return (launch, details, or preferences)")
            return
        }

        if let lastRefresh,
           Date().timeIntervalSince(lastRefresh) < coreRefreshFromBackgroundMinInterval {
            print("📦 [FOREGROUND_REFRESH] skip — core refresh started \(Int(Date().timeIntervalSince(lastRefresh)))s ago")
            return
        }

        coreRefreshLock.lock()
        lastCoreRefreshFromBackgroundAt = Date()
        coreRefreshLock.unlock()

        print("📦 [FOREGROUND_REFRESH] true background return — pointer, artists, schedule, description map, then bulk")
        DispatchQueue.global(qos: .utility).async {
            NSUbiquitousKeyValueStore.default.synchronize()
        }
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: Notification.Name("ForegroundRefresh"), object: nil)
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
                print("iCloud: Change reason: Quota violation - skipping sync to prevent infinite loop")
                // CRITICAL FIX: Don't try to sync more data when quota is exceeded - this prevents infinite loop
                return
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
            
            let pullGroup = DispatchGroup()
            pullGroup.enter()
            sqliteiCloudSync.syncPrioritiesFromiCloud {
                print("iCloud: Priority pull completed from external change")
                pullGroup.leave()
            }
            pullGroup.enter()
            sqliteiCloudSync.syncAttendanceFromiCloud {
                print("iCloud: Attendance pull completed from external change")
                pullGroup.leave()
            }
            pullGroup.notify(queue: .global(qos: .utility)) {
                let pushGroup = DispatchGroup()
                pushGroup.enter()
                sqliteiCloudSync.syncPrioritiesToiCloud {
                    pushGroup.leave()
                }
                pushGroup.enter()
                sqliteiCloudSync.syncAttendanceToiCloud {
                    pushGroup.leave()
                }
                pushGroup.notify(queue: .main) {
                    print("iCloud: External change processing completed, refreshing GUI...")
                    print("iCloud: Sending GUI refresh")
                    NotificationCenter.default.post(name: Notification.Name(rawValue: "iCloudRefresh"), object: nil)
                }
            }
        }
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // SQLite automatically persists data, no manual save needed
        
        // Best-effort sync bulk notes before process exit (map load + missing current-marker files).
        // Prefer background entry for a fuller download window; this is a last-chance safety net.
        print("📝 [TERMINATE] Starting best-effort bulk description download")
        bandDescriptions.downloadAllMissingDescriptionsForBulk()
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
    // Core Data stack removed - all data now uses SQLite directly
    
    // MARK: - Shared Preferences Import Support
    
    private func handleIncomingShareFile(url: URL, delay: TimeInterval = 0) -> Bool {
        let ext = url.pathExtension
        let config = FestivalConfig.current

        if config.isValidShareFileExtension(pathExtension: ext) {
            let now = Date()
            if lastHandledShareURL == url, let last = lastHandledShareAt, now.timeIntervalSince(last) < 2 {
                print("📥 Ignoring duplicate share URL: \(url.lastPathComponent)")
                return true
            }
            lastHandledShareURL = url
            lastHandledShareAt = now

            let importBlock = {
                _ = SharedPreferencesImportHandler.shared.handleIncomingFile(url)
            }
            if delay > 0 {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: importBlock)
            } else {
                importBlock()
            }
            return true
        }

        if config.isOtherFestivalShareFile(pathExtension: ext) {
            print("⚠️ Rejected cross-festival share file: .\(ext)")
            showIncompatibleShareFileAlert()
        } else {
            print("⚠️ Rejected file with extension .\(ext) - not a share file for this app")
        }
        return false
    }

    private func showIncompatibleShareFileAlert() {
        let appName = FestivalConfig.current.appName
        let message = String(
            format: NSLocalizedString(
                "This file is not compatible with %@. Please use the correct app to open this file.",
                comment: "Wrong festival share file"
            ),
            appName
        )

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
    
    /// Handles opening share files and schedule QR guide deep links.
    /// SceneDelegate forwards incoming document URLs here (iOS 13+ scene lifecycle).
    func handleIncomingOpenURL(_ url: URL, delay: TimeInterval = 0) -> Bool {
        if ScheduleQRGuideLink.handleIncomingURL(url) {
            return true
        }
        return handleIncomingShareFile(url: url, delay: delay)
    }

    /// Handles opening share files and schedule QR guide deep links.
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        print("📥 AppDelegate: Opening URL (iOS 9+): \(url)")
        return handleIncomingOpenURL(url)
    }
    
    /// Legacy method for opening URLs (iOS 4.2-9.0, still called by some apps)
    func application(_ application: UIApplication, open url: URL, sourceApplication: String?, annotation: Any) -> Bool {
        print("📥 AppDelegate: Opening URL (Legacy): \(url)")
        return handleIncomingOpenURL(url)
    }
    
    /// Handle opening documents (alternative entry point)
    func application(_ application: UIApplication, willFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("📥 AppDelegate: willFinishLaunchingWithOptions")
        
        if let url = launchOptions?[.url] as? URL {
            print("📥 Launched with URL: \(url)")
            _ = handleIncomingOpenURL(url, delay: 1.0)
        }
        
        return true
    }

    // MARK: - UIScene lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    /// Creates the main window and split-view hierarchy for the given scene.
    func configureMainWindow(for windowScene: UIWindowScene) {
        window = UIWindow(windowScene: windowScene)
        let storyboard = UIStoryboard(name: "Main", bundle: nil)

        // Use split view controller on all devices. System collapses to one column when
        // horizontal size class is compact (e.g. iPhone portrait); regular width (e.g. iPad,
        // iPhone 17 Pro Max landscape) shows master/detail side-by-side.
        if let splitViewController = storyboard.instantiateInitialViewController() as? UISplitViewController {
            window?.rootViewController = splitViewController

            splitViewController.delegate = self
            splitViewController.preferredDisplayMode = .oneBesideSecondary

            window?.makeKeyAndVisible()

            if let masterNavigationController = splitViewController.viewControllers.first as? UINavigationController,
               masterNavigationController.viewControllers.first is MasterViewController {
                setupDefaults()
            } else {
                print("Error: Could not get MasterViewController from navigation stack.")
            }

            let placeholderDetailController = createPlaceholderDetailViewController()
            let detailNavigationController = UINavigationController(rootViewController: placeholderDetailController)

            detailNavigationController.navigationBar.isTranslucent = true
            detailNavigationController.navigationBar.backgroundColor = UIColor.clear
            detailNavigationController.navigationBar.barTintColor = UIColor.clear
            detailNavigationController.navigationBar.shadowImage = UIImage()
            detailNavigationController.navigationBar.setBackgroundImage(UIImage(), for: .default)
            detailNavigationController.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor: UIColor.white]

            if splitViewController.viewControllers.count > 1 {
                splitViewController.viewControllers = [splitViewController.viewControllers[0], detailNavigationController]
            } else {
                splitViewController.viewControllers.append(detailNavigationController)
            }
        } else {
            print("Error: Could not instantiate UISplitViewController from storyboard.")
        }
    }

    private var keyWindowRootViewController: UIViewController? {
        if let rootViewController = window?.rootViewController {
            return rootViewController
        }
        return UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }?
            .rootViewController
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
