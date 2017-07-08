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
import FirebaseInstanceID

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
    
    var window: UIWindow?
    var registrationToken: String?
    var registrationOptions = [String: AnyObject]()
    
    var notificationDisplayed = false;
    let registrationKey = "onRegistrationCompleted"
    let messageKey = "onMessageReceived"
    let subscriptionTopic1 = "/topics/IOStesting"
    let subscriptionTopic2 = "/topics/global"
    let subscriptionTopic3 = "/topics/version20170706"
    
    let gcmMessageIDKey = "gcm.message_id"
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let splitViewController = self.window!.rootViewController as! UISplitViewController
        let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1] as! UINavigationController
        navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
        splitViewController.delegate = self

        let masterNavigationController = splitViewController.viewControllers[0] as! UINavigationController
        let controller = masterNavigationController.topViewController as! MasterViewController
        controller.managedObjectContext = self.managedObjectContext
    
        
        //icloud code
        // Register for notification of iCloud key-value changes
        NotificationCenter.default.addObserver(self,
        selector: #selector(AppDelegate.iCloudKeysChanged(_:)),
        name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: nil)
        
        // Start iCloud key-value updates
        NSUbiquitousKeyValueStore.default().synchronize()
        updateBandFromICloud()
        
        //register Application Defaults
        let defaults = ["artistUrl": artistUrlDefault,
            "scheduleUrl": scheduleUrlDefault,
            "mustSeeAlert": mustSeeAlertDefault, "mightSeeAlert": mightSeeAlertDefault,
            "minBeforeAlert": minBeforeAlertDefault, "alertForShows": alertForShowsDefault,
            "alertForSpecial": alertForSpecialDefault, "alertForMandG": alertForMandGDefault,
            "alertForClinics": alertForClinicsDefault, "alertForListening": alertForListeningDefault,
            "validateScheduleFile": validateScheduleFileDefault, "showSpecial": showSpecialDefault,
            "showMandG": showMandGDefault, "showClinics": showClinicsDefault,
            "showListening": showListeningDefault, "showPoolShows": showPoolShowsDefault,
            "showTheaterShows": showTheaterShowsDefault, "showRinkShows": showRinkShowsDefault,
            "showLoungeShows": showLoungeShowsDefault, "showOtherShows": showOtherShowsDefault]
        
        
        UserDefaults.standard.register(defaults: defaults)
        
        readFile()
        

        // Register for remote notifications. This shows a permission dialog on first run, to
        // show the dialog at a more appropriate time move this registration accordingly.
        // [START register_for_notifications]
        if #available(iOS 10.0, *) {
            // For iOS 10 display notification (sent via APNS)
            UNUserNotificationCenter.current().delegate = self
            
            let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
            UNUserNotificationCenter.current().requestAuthorization(
                options: authOptions,
                completionHandler: {_, _ in })
                Messaging.messaging().remoteMessageDelegate = self
            
        } else {
            let settings: UIUserNotificationSettings =
                UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
            application.registerUserNotificationSettings(settings)
        }
        
        application.registerForRemoteNotifications()
        
        // [END register_for_notifications]
        FirebaseApp.configure()
        
        // [START set_messaging_delegate]
        Messaging.messaging().delegate = self as! MessagingDelegate
        //Messaging.messaging().remoteMessageDelegate = self
        // [END set_messaging_delegate]
        
        NotificationCenter.default.addObserver(self, selector:
        #selector(tokenRefreshNotification), name:
        NSNotification.Name.InstanceIDTokenRefresh, object: nil)
        printFCMToken()
        
        return true
    
    }
    
    func printFCMToken() {
        if let token = InstanceID.instanceID().token() {
            print("Your FCM token is \(token)")
        } else {
            print("You don't yet have an FCM token.")
        }
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
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
        extractAlertMessage(userInfo: userInfo as! Dictionary<String, AnyObject>);
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any],
                     fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        
        if #available(iOS 10.0, *) {
            //exit without doing anything, this is handled in another routine
            return
        }
        // If you are receiving a notification message while your app is in the background,
        // this callback will not be fired till the user taps on the notification launching the application.
        // TODO: Handle data of notification
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
        print ("Test2")
        extractAlertMessage(userInfo: userInfo as! Dictionary<String, AnyObject>);
        completionHandler(UIBackgroundFetchResult.newData)
    }
    
    func tokenRefreshNotification(_ notification: Notification) {
        if let refreshedToken = InstanceID.instanceID().token() {
            print("InstanceID token: \(refreshedToken)")
            UIPasteboard.general.string =  "InstanceID token: \(refreshedToken)";
        }
        
        // Connect to FCM since connection may have failed when attempted before having a token.
        connectToFcm()
    }
    // [END refresh_token]
    // [START connect_to_fcm]
    func connectToFcm() {
        // Won't connect since there is no token
        guard InstanceID.instanceID().token() != nil else {
            return
        }
        
        // Disconnect previous FCM connection if it exists.
        Messaging.messaging().disconnect()
        
        Messaging.messaging().connect { (error) in
            if error != nil {
                print("Unable to connect with FCM. \(error?.localizedDescription ?? "")")
            } else {
                print("Connected to FCM.")
                print("Token Connected to FCM.")
                Messaging.messaging().subscribe(toTopic: self.subscriptionTopic1)
                Messaging.messaging().subscribe(toTopic: self.subscriptionTopic2)
                Messaging.messaging().subscribe(toTopic: self.subscriptionTopic3)
            }
        }
        
    }
    // [END connect_to_fcm]

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Unable to register for remote notifications: \(error.localizedDescription)")
    }
    
    // This function is added here only for debugging purposes, and can be removed if swizzling is enabled.
    // If swizzling is disabled then this function must be implemented so that the APNs token can be paired to
    // the InstanceID token.
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {

        let token = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("APNs token retrieved: \(token)")
        
        //#if PROD_BUILD
            InstanceID.instanceID().setAPNSToken(deviceToken, type: .prod)
            //InstanceID.instanceID().setAPNSToken(deviceToken, type: InstanceIDAPNSTokenType.prod)
        //#else
            //InstanceID.instanceID().setAPNSToken(deviceToken, type: .sandbox)
            //InstanceID.instanceID().setAPNSToken(deviceToken, type: InstanceIDAPNSTokenType.sandbox)
        //#endif
        
    }
    
    // [START connect_on_active]
    func applicationDidBecomeActive(_ application: UIApplication) {
        connectToFcm()
        NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
    }
    // [END connect_on_active]
    
    func displayNotification (message: String){
        
        //if (notificationDisplayed == false){
            let alertCtrl = UIAlertController(title: "70K Bands", message: message, preferredStyle: UIAlertControllerStyle.alert)
            alertCtrl.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.default, handler: nil))
        
            // Find the presented VC...
            var presentedVC = self.window?.rootViewController
            while (presentedVC!.presentedViewController != nil)  {
                presentedVC = presentedVC!.presentedViewController}
        
            presentedVC!.present(alertCtrl, animated: true, completion: nil)
            notificationDisplayed = true;
        //}
        
    }
    
    func extractAlertMessage (userInfo : Dictionary<String, AnyObject>){
        
        if let info = userInfo["aps"] as? Dictionary<String, AnyObject> {
            // Default printout of info = userInfo["aps"]
            print("All of info: \n\(info)\n")
            
            for (key, value) in info {
                print("APS: \(key) —> \(value)")
                if (key == "alert"){
                    if (value is NSDictionary){
                        displayNotification(message: value["body"] as! String);
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
    
    //iCloud functions
    
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        writeFiltersFile()
        writeFile()
        
        Messaging.messaging().disconnect()
        print("Disconnected from FCM.")
    }

    func iCloudKeysChanged(_ notification: Notification) {
        updateBandFromICloud()
    }

    fileprivate func updateBandFromICloud() {
        let bandInfo = NSUbiquitousKeyValueStore.default().dictionaryRepresentation
        if (bandInfo.count >= 1) {
            getPriorityDataFromiCloud()
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        writeFiltersFile()
        writeFile()
        
    }


    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }


    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        writeFiltersFile()
        writeFile()
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
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = Bundle.main.url(forResource: "_0000TonsBands", withExtension: "momd")!
        return NSManagedObjectModel(contentsOf: modelURL)!
    }()

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        var coordinator: NSPersistentStoreCoordinator? = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.appendingPathComponent("_0000TonsBands.sqlite")
        var error: NSError? = nil
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            try coordinator!.addPersistentStore(ofType: NSSQLiteStoreType, configurationName: nil, at: url, options: nil)
        } catch var error1 as NSError {
            error = error1
            coordinator = nil
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data" as AnyObject
            dict[NSLocalizedFailureReasonErrorKey] = failureReason as AnyObject
            dict[NSUnderlyingErrorKey] = error
            error = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            //NSLog("Unresolved error \(error ?? <#default value#>), \(error!.userInfo)")
            abort()
        } catch {
            fatalError()
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
                    NSLog("Unresolved error \(error), \(error!.userInfo)")
                    abort()
                }
            }
        }
    }

}

// [START ios_10_message_handling]
@available(iOS 10, *)
extension AppDelegate : UNUserNotificationCenterDelegate {
    
    // Receive displayed notifications for iOS 10 devices.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        let userInfo = notification.request.content.userInfo
        // Print message ID.
        if let messageID = userInfo[gcmMessageIDKey] {
            print("Message ID: \(messageID)")
        }
        
        // Print full message.
        print(userInfo)
        print ("Test3")
        extractAlertMessage(userInfo: userInfo as! Dictionary<String, AnyObject>);
        completionHandler([])
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
        print ("Test4")
        extractAlertMessage(userInfo: userInfo as! Dictionary<String, AnyObject>);
        completionHandler()
    }
 
}
// [END ios_10_message_handling]

extension AppDelegate : MessagingDelegate {
    // [START refresh_token]
    func messaging(_ messaging: Messaging, didRefreshRegistrationToken fcmToken: String) {
        print("Firebase registration token: \(fcmToken)")
    }
    // [END refresh_token]
}

