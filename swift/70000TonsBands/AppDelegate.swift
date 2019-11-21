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
    
    let gcmMessageIDKey = "gcm.message_id"
    
    var bandPriorityStorage = [String:Int]()
    
    var bandDescriptions = CustomBandDescription()
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions:
        
        [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        let splitViewController = self.window!.rootViewController as! UISplitViewController
        let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1] as! UINavigationController
        navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem
        splitViewController.delegate = self

        //icloud code
        // Register for notification of iCloud key-value changes
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(AppDelegate.iCloudKeysChanged(_:)),
                                               name: NSUbiquitousKeyValueStore.didChangeExternallyNotification, object: NSUbiquitousKeyValueStore.default)
        
        // Start iCloud key-value updates
        NSUbiquitousKeyValueStore.default.synchronize()

        let masterNavigationController = splitViewController.viewControllers[0] as! UINavigationController
        let controller = masterNavigationController.topViewController as! MasterViewController
        controller.managedObjectContext = self.managedObjectContext
    
        setupCurrentYearUrls()
        
        setupDefaults()
        
        // [END register_for_notifications]
       FirebaseApp.configure()
               
       // [START set_messaging_delegate]
       Messaging.messaging().delegate = self as! MessagingDelegate
       //Messaging.messaging().remoteMessageDelegate = self
       // [END set_messaging_delegate]
       
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
               Messaging.messaging().delegate = self
            print ("FCM Registerd via IOS10")
           
       } else {
           let settings: UIUserNotificationSettings =
               UIUserNotificationSettings(types: [.alert, .badge, .sound], categories: nil)
           application.registerUserNotificationSettings(settings)
       }
              
        UIApplication.shared.registerForRemoteNotifications()
        
       NotificationCenter.default.addObserver(self, selector:
       #selector(tokenRefreshNotification), name:
       NSNotification.Name.InstanceIDTokenRefresh, object: nil)
       printFCMToken()
               
        
        //generate user data
        let userDataHandle = firebaseUserWrite()
        userDataHandle.writeData()
        
 
        bandDescriptions.getDescriptionMapFile();
        
        application.registerForRemoteNotifications()
        
        return true
    
    }
    

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        print("FCM Firebase registration token: \(fcmToken)")
         
        let dataDict:[String: String] = ["token": fcmToken]
        NotificationCenter.default.post(name: Notification.Name("FCMToken"), object: nil, userInfo: dataDict)
        // TODO: If necessary send token to application server.
        // Note: This callback is fired at each app startup and whenever a new token is generated.
    }
         
    func messaging(_ messaging: Messaging, didReceive remoteMessage: MessagingRemoteMessage){
        print("FCM \(remoteMessage.appData)")
                //let title = remoteMessage.appData[("data"): {"title"}]
               var title = "New Request"

                for value in remoteMessage.appData{
                    if let value = value as?  [AnyHashable:Any]{
                    print("FCM \(value)")
                    }
                }
                let message = "okay"
        print("FCM \(message)");
        
        if (remoteMessage != nil){
            if (remoteMessage.appData != nil){
                if (remoteMessage.appData["message"] != nil){
                    displayNotification(message: remoteMessage.appData["message"] as! String)
                }
            }
        }

    }
    
    func displayNotification (message: String){
        
        //if (notificationDisplayed == false){
        let alertCtrl = UIAlertController(title: "70K Bands", message: message, preferredStyle: UIAlertController.Style.alert)
        alertCtrl.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.default, handler: nil))
        
            // Find the presented VC...
            var presentedVC = self.window?.rootViewController
            while (presentedVC!.presentedViewController != nil)  {
                presentedVC = presentedVC!.presentedViewController}
        
            presentedVC!.present(alertCtrl, animated: true, completion: nil)
            notificationDisplayed = true;
        //}
        
    }
    
    @objc func tokenRefreshNotification(_ notification: Notification) {
        if let refreshedToken = InstanceID.instanceID().token() {
            print("InstanceID token: \(refreshedToken)")
            UIPasteboard.general.string =  "InstanceID token: \(refreshedToken)";
        }
        
        // Connect to FCM since connection may have failed when attempted before having a token.
        connectToFcm()
    }
    
    func setupCurrentYearUrls() {
        
        let filePath = defaultUrlConverFlagUrl.path
        if(FileManager.default.fileExists(atPath: filePath)){
            print ("Followup run of setupCurrentYearUrls routine")
            artistUrlDefault = UserDefaults.standard.string(forKey: "artistUrl") ?? defaultPrefsValue
            scheduleUrlDefault = UserDefaults.standard.string(forKey: "scheduleUrl") ?? defaultPrefsValue
        } else {
            print ("First run of setupCurrentYearUrls routine")
           artistUrlDefault = defaultPrefsValue
           scheduleUrlDefault = defaultPrefsValue
           let flag = ""
            do {
                try flag.write(to: defaultUrlConverFlagUrl, atomically: false, encoding: .utf8)
            }
            catch {print ("First run of setupCurrentYearUrls routine Failed!")}
        }
        
        if (artistUrlDefault == defaultPrefsValue){
            UserDefaults.standard.set(defaultPrefsValue, forKey: "artistUrl")
        }
        
        if (scheduleUrlDefault == defaultPrefsValue){
            UserDefaults.standard.set(defaultPrefsValue, forKey: "scheduleUrl")
        }
        
    }
    
    func printFCMToken() {
        if let token = InstanceID.instanceID().token() {
            print("Your FCM token is \(token)")
        } else {
            print("You don't yet have an FCM token.")
        }
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
                Messaging.messaging().subscribe(toTopic: subscriptionTopic)
                Messaging.messaging().subscribe(toTopic: subscriptionTopicTest)
                
                print("FCM - subscribed to " + subscriptionTopic)
                print("FCM - subscribed to " + subscriptionTopicTest)
                
                if (defaults.bool(forKey: "alertForUnofficalEvents") == true){
                    Messaging.messaging().subscribe(toTopic: subscriptionUnofficalTopic)
                    print("FCM - subscribed to " + subscriptionUnofficalTopic)
                } else {
                    Messaging.messaging().unsubscribe(fromTopic: subscriptionUnofficalTopic)
                }
                self.printFCMToken();
            }
            
             UIApplication.shared.registerForRemoteNotifications();

            print ("FCM - start")
            let token = InstanceID.instanceID().token()
            
            print ("FCM - Stop")
            //InstanceID.instanceID().setAPNSToken(deviceToken, type: .prod)
            
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

        print("fcm recieved background alert")
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
        
        NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
    }
    // [END connect_on_active]
        
    func extractAlertMessage (userInfo : Dictionary<String, AnyObject>){
        
        print("fcm sendLocalAlert! \(userInfo)")
        if let info = userInfo["aps"] as? Dictionary<String, AnyObject> {
            // Default printout of info = userInfo["aps"]
            print("fcm sendLocalAlert!  \n\(info)\n")
            
            for (key, value) in info {
                print("fcm sendLocalAlert! APS: \(key) —> \(value)")
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
    
    func applicationDidEnterBackground(_ application: UIApplication) {
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.

        //        let userDataHandle = firebaseUserWrite()
        //userDataHandle.writeData()
        
        let bandWrite  = filebaseBandDataWrite();
        bandWrite.writeData();
        
        let showWrite = firebaseEventDataWrite()
        showWrite.writeData();
        
        let localNotication = localNoticationHandler()
        localNotication.clearNotifications()
        localNotication.addNotifications()
        Messaging.messaging().disconnect()
        print("Disconnected from FCM.")
        
    }


    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        
    }


    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    @objc func iCloudKeysChanged(_ notification: Notification) {
        
        let iCloudHandle = iCloudDataHandler()
        iCloudHandle.readCloudData()
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
            print("sendLocalAlert! Message ID: \(messageID)")

            // Print full message.
            print("sendLocalAlert! 1 \(userInfo)")
            extractAlertMessage(userInfo: userInfo as! Dictionary<String, AnyObject>);
            completionHandler([])
        } else {
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
        completionHandler()
    }
 
}
// [END ios_10_message_handling]
extension AppDelegate : MessagingDelegate {
    // [START refresh_token]
    func messaging(_ messaging: Messaging, didRefreshRegistrationToken fcmToken: String) {
        print("Firebase registration token: \(fcmToken)")
        //let helpMessage = "Firebase registration token: \(fcmToken)"
        
        //let pasteBoard = UIPasteboard.general
        //pasteBoard.string = helpMessage
    }
    // [END refresh_token]
}
