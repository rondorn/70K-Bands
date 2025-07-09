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
            // Only call makeKeyAndVisible on iPad to prevent crashes on iPhone
            if UIDevice.current.userInterfaceIdiom == .pad {
                self.window?.makeKeyAndVisible()
            }
            if let navigationController = splitViewController.viewControllers.last as? UINavigationController {
                splitViewController.delegate = self
                setupDefaults()
                
                // The following line crashes if topViewController is nil. Commenting out to prevent the crash.
                // navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
                
                if let masterNavigationController = splitViewController.viewControllers.first as? UINavigationController,
                   let controller = masterNavigationController.viewControllers.first as? MasterViewController {
                    controller.managedObjectContext = self.managedObjectContext
                } else {
                    print("Error: Could not get MasterViewController from navigation stack.")
                }
            } else {
                print("Error: Could not get UINavigationController from splitViewController.")
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
        


       Messaging.messaging().delegate = self

        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(
            options: authOptions,
            completionHandler: {_, _ in })

        Messaging.messaging().delegate = self

        printFCMToken()
        
        DispatchQueue.main.async{
            let iCloudHandle = iCloudDataHandler()
            
            // IMPORTANT: Check for old iCloud data format and migrate if needed
            // This must happen BEFORE reading iCloud data to prevent conflicts
            iCloudHandle.readAllPriorityData()
            iCloudHandle.readAllScheduleData()
            
            let notes = CustomBandDescription()
            notes.getAllDescriptions()
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
        
        // Force iCloud synchronization when app becomes active
        print("iCloud: App became active, forcing iCloud synchronization")
        NSUbiquitousKeyValueStore.default.synchronize()
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
        
        let userDataHandle = userDataHandler()
        let userDataReportHandle = firebaseUserWrite()
        userDataReportHandle.writeData()
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
        let localNotication = localNoticationHandler()
        localNotication.clearNotifications()
        localNotication.addNotifications()
        DispatchQueue.global(qos: .background).async {
            let iCloudHandle = iCloudDataHandler()
            iCloudHandle.writeAllPriorityData()
            iCloudHandle.writeAllScheduleData()
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
        
        // Force iCloud synchronization when app enters foreground
        print("iCloud: App entering foreground, forcing iCloud synchronization")
        NSUbiquitousKeyValueStore.default.synchronize()
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
        
        DispatchQueue.main.async {
            if iCloudDataisLoading || iCloudScheduleDataisLoading {
                print("iCloud: Skipping iCloud data sync because a read operation is already in progress.")
                return
            }
            let iCloudHandle = iCloudDataHandler()
            iCloudHandle.readAllPriorityData()
            iCloudHandle.readAllScheduleData()
            
            // Refresh the UI after loading new data
            print("iCloud: Sending GUI refresh")
            NotificationCenter.default.post(name: Notification.Name(rawValue: "iCloudRefresh"), object: nil)
            
            print("iCloud: External change processing completed")
        }
    }
    
    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.

        self.saveContext()
    }

    // MARK: - Split view

    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController:UIViewController, onto primaryViewController:UIViewController) -> Bool {
        if let secondaryAsNavController = secondaryViewController as? UINavigationController {
            if let topAsDetailController = secondaryAsNavController.topViewController as? DetailViewController {
                //if (topAsDetailController != nil){
                    if topAsDetailController.detailItem == nil {
                        // Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
                        return true
                    }
                //}
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
