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
    
    var bandPriorityStorage = [String:Int]()
    
    var bandDescriptions = CustomBandDescription()
    var dataHandle = dataHandler()
    
    // Flag to track if pointer file download has been attempted on this launch
    private var hasAttemptedPointerDownloadOnLaunch = false
    
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
    private func downloadAndUpdatePointerFileOnLaunch() {
        // Ensure this function is only called once per app launch
        guard !hasAttemptedPointerDownloadOnLaunch else {
            print("downloadAndUpdatePointerFileOnLaunch: Already attempted download on this launch, skipping")
            return
        }
        hasAttemptedPointerDownloadOnLaunch = true
        
        print("downloadAndUpdatePointerFileOnLaunch: Starting pointer file download and update")
        
        // Check if we have internet connectivity
        guard Reachability.isConnectedToNetwork() else {
            print("downloadAndUpdatePointerFileOnLaunch: No internet connection available, skipping download")
            return
        }
        
        // Create temporary file path
        let documentsPath = getDocumentsDirectory()
        let tempPointerFile = documentsPath.appendingPathComponent("tempPointerData.txt")
        let cachedPointerFile = documentsPath.appendingPathComponent("cachedPointerData.txt")
        
        // Download pointer file to temporary location
        guard let url = URL(string: defaultStorageUrl) else {
            print("downloadAndUpdatePointerFileOnLaunch: Invalid URL: \(defaultStorageUrl)")
            return
        }
        
        // Set a timeout for the download
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30.0 // 30 second timeout
        configuration.timeoutIntervalForResource = 60.0 // 60 second timeout for the entire resource
        let session = URLSession(configuration: configuration)
        
        let task = session.dataTask(with: url) { [weak self] (data, response, error) in
            guard let self = self else { return }
            
            if let error = error {
                print("downloadAndUpdatePointerFileOnLaunch: Download error: \(error)")
                return
            }
            
            guard let data = data, let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                print("downloadAndUpdatePointerFileOnLaunch: Invalid response or no data")
                return
            }
            
            // Check if the downloaded data is not too large (safety check)
            let maxSize = 1024 * 1024 // 1MB limit
            guard data.count <= maxSize else {
                print("downloadAndUpdatePointerFileOnLaunch: Downloaded data too large (\(data.count) bytes), aborting")
                return
            }
            
            // Write downloaded data to temporary file
            do {
                try data.write(to: URL(fileURLWithPath: tempPointerFile))
                print("downloadAndUpdatePointerFileOnLaunch: Successfully downloaded pointer file to temp location")
                
                // Verify the downloaded data is valid by attempting to parse it
                guard let downloadedContent = String(data: data, encoding: .utf8),
                      !downloadedContent.isEmpty else {
                    print("downloadAndUpdatePointerFileOnLaunch: Downloaded content is empty or invalid")
                    return
                }
                
                // Parse a few lines to verify it's valid pointer data
                let lines = downloadedContent.components(separatedBy: "\n")
                var isValidPointerData = false
                var validLineCount = 0
                for line in lines.prefix(10) { // Check first 10 lines
                    if line.contains("::") && line.components(separatedBy: "::").count >= 3 {
                        validLineCount += 1
                        if validLineCount >= 2 { // Require at least 2 valid lines
                            isValidPointerData = true
                            break
                        }
                    }
                }
                
                guard isValidPointerData else {
                    print("downloadAndUpdatePointerFileOnLaunch: Downloaded content does not appear to be valid pointer data")
                    return
                }
                
                // If we reach here, the download was successful and data is valid
                // Now replace the existing pointer file with the new one
                let fileManager = FileManager.default
                
                // Remove existing cached pointer file if it exists
                if fileManager.fileExists(atPath: cachedPointerFile) {
                    do {
                        try fileManager.removeItem(atPath: cachedPointerFile)
                        print("downloadAndUpdatePointerFileOnLaunch: Removed existing cached pointer file")
                    } catch {
                        print("downloadAndUpdatePointerFileOnLaunch: Failed to remove existing cached pointer file: \(error)")
                    }
                }
                
                // Move temp file to final location
                do {
                    try fileManager.moveItem(atPath: tempPointerFile, toPath: cachedPointerFile)
                    print("downloadAndUpdatePointerFileOnLaunch: Successfully replaced cached pointer file")
                    
                    // Clear in-memory cache to force reload
                    storePointerLock.sync() {
                        cacheVariables.storePointerData.removeAll()
                    }
                    print("downloadAndUpdatePointerFileOnLaunch: Cleared in-memory pointer cache")
                    
                    // Force reload of pointer data by calling getPointerUrlData for key values
                    DispatchQueue.global(qos: .background).async {
                        // Pre-load common pointer values to ensure they're available
                        _ = getPointerUrlData(keyValue: "artistUrl")
                        _ = getPointerUrlData(keyValue: "scheduleUrl")
                        _ = getPointerUrlData(keyValue: "eventYear")
                        _ = getPointerUrlData(keyValue: "reportUrl")
                        
                        print("downloadAndUpdatePointerFileOnLaunch: Forced reload of pointer data completed")
                        
                        // Notify that pointer data has been updated
                        DispatchQueue.main.async {
                            NotificationCenter.default.post(name: Notification.Name("PointerDataUpdated"), object: nil)
                        }
                    }
                    
                } catch {
                    print("downloadAndUpdatePointerFileOnLaunch: Failed to move temp file to final location: \(error)")
                    // Clean up temp file if it still exists
                    if fileManager.fileExists(atPath: tempPointerFile) {
                        try? fileManager.removeItem(atPath: tempPointerFile)
                    }
                }
                
            } catch {
                print("downloadAndUpdatePointerFileOnLaunch: Failed to write downloaded data to temp file: \(error)")
            }
        }
        
        task.resume()
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
    
        // Manually create the window and set the root view controller from the storyboard.
        self.window = UIWindow(frame: UIScreen.main.bounds)
        let storyboard = UIStoryboard(name: "Main", bundle: nil)
        if let splitViewController = storyboard.instantiateInitialViewController() as? UISplitViewController {
            self.window?.rootViewController = splitViewController
            
            // Set up split view controller
            splitViewController.delegate = self
            splitViewController.preferredDisplayMode = .oneBesideSecondary
            
            // Only call makeKeyAndVisible on iPad to prevent crashes on iPhone
            if UIDevice.current.userInterfaceIdiom == .pad {
                self.window?.makeKeyAndVisible()
            }
            
            // Set up master view controller
            if let masterNavigationController = splitViewController.viewControllers.first as? UINavigationController,
               let controller = masterNavigationController.viewControllers.first as? MasterViewController {
                controller.managedObjectContext = self.managedObjectContext
                setupDefaults()
            } else {
                print("Error: Could not get MasterViewController from navigation stack.")
            }
            
            // Set up detail view controller - auto-select first band for iPad
            if UIDevice.current.userInterfaceIdiom == .pad {
                // Create a placeholder detail view controller for iPad initially
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
            }
        } else {
            print("Error: Could not instantiate UISplitViewController from storyboard.")
        }
        
        // Register default UserDefaults values including iCloud setting
        let defaults = ["artistUrl": "https://www.dropbox.com/s/5hcaxigzdj7fjrt/artistLineup.html?dl=1",
                        "scheduleUrl": "https://www.dropbox.com/s/tg9qgt48ezp7udv/Schedule.csv?dl=1",
                        "iCloud": "YES",
                        "mustSeeAlert": "YES", 
                        "mightSeeAlert": "YES",
                        "minBeforeAlert": "10", 
                        "alertForShows": "YES",
                        "alertForSpecial": "YES", 
                        "alertForMandG": "NO",
                        "alertForClinics": "NO", 
                        "alertForListening": "NO",
                        "validateScheduleFile": "NO"]
        UserDefaults.standard.register(defaults: defaults)
        
        FirebaseApp.configure()
        FirebaseConfiguration.shared.setLoggerLevel(.min)
        
        let iCloudHandle = iCloudDataHandler()
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

        // Migrate iCloud data before registering for notifications
        iCloudHandle.detectAndMigrateOldPriorityData()
        iCloudHandle.detectAndMigrateOldScheduleData()

        // Register for notification of iCloud key-value changes, but do an intial load
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(AppDelegate.iCloudKeysChanged(_:)),
                                               name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: NSUbiquitousKeyValueStore.default)
        
        // Start iCloud key-value updates
        NSUbiquitousKeyValueStore.default.synchronize()
        
        // Test iCloud availability and log status
        print("iCloud: Testing iCloud setup...")
        
        setupCurrentYearUrls()
        
        // Download and update pointer file on launch
        downloadAndUpdatePointerFileOnLaunch()


       Messaging.messaging().delegate = self

        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: {_, _ in })

        Messaging.messaging().delegate = self

        printFCMToken()
        
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
            print("iCloud: Waiting for bands and schedule data to load before syncing iCloud...")
            
            var waitTime: Double = 0
            let maxWaitTime: Double = 60 // Maximum 60 seconds wait
            
            // Wait for band names to be ready (not loading and has data)
            while isLoadingBandData || bandNamesHandler.shared.getBandNames().isEmpty {
                Thread.sleep(forTimeInterval: 0.5)
                waitTime += 0.5
                print("iCloud: Still waiting for band names to load... (\(waitTime)s)")
                
                if waitTime >= maxWaitTime {
                    print("iCloud: Timeout waiting for band names, proceeding with available data")
                    break
                }
            }
            
            waitTime = 0 // Reset for schedule wait
            
            // Wait for schedule data to be ready (not loading - empty schedule with headers only is valid)
            while isLoadingSchedule {
                Thread.sleep(forTimeInterval: 0.5)
                waitTime += 0.5
                print("iCloud: Still waiting for schedule data to load... (\(waitTime)s)")
                
                if waitTime >= maxWaitTime {
                    print("iCloud: Timeout waiting for schedule data, proceeding anyway")
                    break
                }
            }
            
            print("iCloud: Bands and schedule loaded, now syncing iCloud data...")
            
            let iCloudHandle = iCloudDataHandler()
            // IMPORTANT: Check for old iCloud data format and migrate if needed
            // This must happen BEFORE reading iCloud data to prevent conflicts
            iCloudHandle.readAllPriorityData()
            iCloudHandle.readAllScheduleData()
            
            print("iCloud: Launch sync completed, refreshing display...")
            
            // Refresh the display on the main thread
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
            }
        }
        
        application.registerForRemoteNotifications()
        

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
        let alertCtrl = UIAlertController(title: "70K Bands", message: message, preferredStyle: UIAlertController.Style.alert)
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
    }
    
    
    /**
     Prints the current FCM token to the console.
     */
    func printFCMToken() {
        
        Messaging.messaging().token { token, error in
            print("Your FCM token is \(token)")
        }

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
        connectToFcm()
        
        // Move all potentially blocking operations to background thread
        DispatchQueue.global(qos: .utility).async {
            // Force iCloud synchronization when app becomes active
            print("iCloud: App became active, forcing iCloud synchronization in background")
            NSUbiquitousKeyValueStore.default.synchronize()
            
            // Perform network operations in background
            let userDataHandle = userDataHandler()
            let userDataReportHandle = firebaseUserWrite()
            userDataReportHandle.writeData()
            
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
        
        internetAvailble = isInternetAvailable();
        let bandWrite  = firebaseBandDataWrite();
        bandWrite.writeData(dataHandle: dataHandle);
        let showWrite = firebaseEventDataWrite()
        showWrite.writeData();
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
        
        // iCloud data sync
        DispatchQueue.global(qos: .userInitiated).async {
            let iCloudHandle = iCloudDataHandler()
            iCloudHandle.writeAllPriorityData()
            iCloudHandle.writeAllScheduleData()
            print("☁️ iCloud sync completed")
        }
        
        // Bulk image loading - ensure this runs in parallel with other background tasks
        print("🔄 About to dispatch image loading to background queue")
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
        
        // Bulk description loading
        print("🔄 About to dispatch description loading to background queue")
        DispatchQueue.global(qos: .userInitiated).async {
            print("📝 Description loading background queue started")
            let noteHandle = CustomBandDescription()
            print("📝 Starting bulk description loading")
            
            // Check internet availability before proceeding
            let internetAvailable = isInternetAvailable()
            print("📝 Internet available: \(internetAvailable)")
            
            if !internetAvailable {
                print("⚠️ No internet available - waiting 5 seconds for network test to complete")
                sleep(5) // Wait for network test to complete
                let internetAfterWait = isInternetAvailable()
                print("📝 Internet available after wait: \(internetAfterWait)")
                
                if !internetAfterWait {
                    print("⚠️ Still no internet - skipping description bulk loading")
                    return
                }
            }
            
            // Ensure description map is loaded before bulk loading
            print("📝 Loading description map file...")
            noteHandle.getDescriptionMapFile()
            print("📝 Parsing description map...")
            noteHandle.getDescriptionMap()
            
            print("📝 Description map contains \(noteHandle.bandDescriptionUrl.count) entries")
            if noteHandle.bandDescriptionUrl.isEmpty {
                print("⚠️ Description URL map is empty - bulk loading will be skipped")
                return
            }
            
            print("📝 Starting bulk download of \(noteHandle.bandDescriptionUrl.count) descriptions")
            print("📝 Calling getAllDescriptions() for allINotes bulk download...")
            noteHandle.getAllDescriptions()
            print("📝 getAllDescriptions() allINotes call completed")
        }
        
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
        reportData()
    }


    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        
    }


    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
        
        print("AppDelegate: App entering foreground - performing background data refresh")
        
        // Move all potentially blocking operations to background thread
        DispatchQueue.global(qos: .utility).async {
            // Force iCloud synchronization when app enters foreground
            print("iCloud: App entering foreground, forcing iCloud synchronization in background")
            NSUbiquitousKeyValueStore.default.synchronize()
            
            // Post background data refresh notification on main thread after sync completes
            DispatchQueue.main.async {
                print("iCloud: Foreground sync complete, posting background data refresh notification")
                NotificationCenter.default.post(name: Notification.Name("BackgroundDataRefresh"), object: nil)
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
            let iCloudHandle = iCloudDataHandler()
            iCloudHandle.readAllPriorityData()
            iCloudHandle.readAllScheduleData()
            
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
            label.centerXAnchor.constraint(equalTo: placeholderController.view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: placeholderController.view.centerYAnchor),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: placeholderController.view.leadingAnchor, constant: 20),
            label.trailingAnchor.constraint(lessThanOrEqualTo: placeholderController.view.trailingAnchor, constant: -20)
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
