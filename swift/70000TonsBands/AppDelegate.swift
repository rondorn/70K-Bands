//
//  AppDelegate.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/2/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import UIKit
import CoreData

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UISplitViewControllerDelegate {
    
    var window: UIWindow?
    
    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        let splitViewController = self.window!.rootViewController as! UISplitViewController
        let navigationController = splitViewController.viewControllers[splitViewController.viewControllers.count-1] as! UINavigationController
        navigationController.topViewController!.navigationItem.leftBarButtonItem = splitViewController.displayModeButtonItem()
        splitViewController.delegate = self

        let masterNavigationController = splitViewController.viewControllers[0] as! UINavigationController
        let controller = masterNavigationController.topViewController as! MasterViewController
        controller.managedObjectContext = self.managedObjectContext
    
        
        //icloud code
        // Register for notification of iCloud key-value changes
        NSNotificationCenter.defaultCenter().addObserver(self,
        selector: "iCloudKeysChanged:",
        name: NSUbiquitousKeyValueStoreDidChangeExternallyNotification, object: nil)
        
        // Start iCloud key-value updates
        NSUbiquitousKeyValueStore.defaultStore().synchronize()
        updateBandFromICloud()

        
        //register Application Defaults
        let defaults = ["artistUrl": artistUrlDefault,
            "scheduleUrl": scheduleUrlDefault,
            "mustSeeAlert": mustSeeAlertDefault, "mightSeeAlert": mightSeeAlertDefault,
            "minBeforeAlert": minBeforeAlertDefault, "alertForShows": alertForShowsDefault,
            "alertForSpecial": alertForSpecialDefault, "alertForMandG": alertForMandGDefault,
            "alertForClinics": alertForClinicsDefault, "alertForListening": alertForListeningDefault,
            "validateScheduleFile": validateScheduleFileDefault]
        
        NSUserDefaults.standardUserDefaults().registerDefaults(defaults)
        
        // Sets up Mobile Push Notification
        let readAction = UIMutableUserNotificationAction()
        readAction.identifier = "READ_IDENTIFIER"
        readAction.title = "Read"
        readAction.activationMode = UIUserNotificationActivationMode.Foreground
        readAction.destructive = false
        readAction.authenticationRequired = true
        
        let deleteAction = UIMutableUserNotificationAction()
        deleteAction.identifier = "DELETE_IDENTIFIER"
        deleteAction.title = "Delete"
        deleteAction.activationMode = UIUserNotificationActivationMode.Foreground
        deleteAction.destructive = true
        deleteAction.authenticationRequired = true
        
        let ignoreAction = UIMutableUserNotificationAction()
        ignoreAction.identifier = "IGNORE_IDENTIFIER"
        ignoreAction.title = "Ignore"
        ignoreAction.activationMode = UIUserNotificationActivationMode.Foreground
        ignoreAction.destructive = false
        ignoreAction.authenticationRequired = false
        
        let messageCategory = UIMutableUserNotificationCategory()
        messageCategory.identifier = "MESSAGE_CATEGORY"
        messageCategory.setActions([readAction, deleteAction], forContext: UIUserNotificationActionContext.Minimal)
        messageCategory.setActions([readAction, deleteAction, ignoreAction], forContext: UIUserNotificationActionContext.Default)
        
        
        let notificationSettings = UIUserNotificationSettings(forTypes: [.Alert, .Sound, .Badge], categories: nil)
        //let types = UIUserNotificationType.Badge | UIUserNotificationType.Sound | UIUserNotificationType.Alert
        //let notificationSettings = UIUserNotificationSettings(forTypes: types, categories: NSSet(object: messageCategory))
        
        UIApplication.sharedApplication().registerForRemoteNotifications()
        UIApplication.sharedApplication().registerUserNotificationSettings(notificationSettings)
        
        // Sets up the AWS Mobile SDK for iOS
        let credentialsProvider = AWSCognitoCredentialsProvider(
            regionType: CognitoRegionType,
            identityPoolId: CognitoIdentityPoolId)
        let defaultServiceConfiguration = AWSServiceConfiguration(
            region: DefaultServiceRegionType,
            credentialsProvider: credentialsProvider)
        AWSServiceManager.defaultServiceManager().defaultServiceConfiguration = defaultServiceConfiguration
        
        //end push notification

        readFile()
        return true
    
    }
    
    // push functions
    func subscribe(token : String, completionHandler : ((NSError?) -> ())? = nil) {
        let credentialsProvider : AWSStaticCredentialsProvider = AWSStaticCredentialsProvider(accessKey: AWSaccessKey, secretKey: AWSsecretKey)
        let defaultServiceConfiguration : AWSServiceConfiguration = AWSServiceConfiguration(region: DefaultServiceRegionType, credentialsProvider: credentialsProvider)
        
        AWSServiceManager.defaultServiceManager().defaultServiceConfiguration = defaultServiceConfiguration
        
        let sns = AWSSNS.defaultSNS()
        let createPlatformEndpointInput = AWSSNSCreatePlatformEndpointInput()
        createPlatformEndpointInput.token = token
        createPlatformEndpointInput.platformApplicationArn = SNSPlatformApplicationArn
        
        sns.createPlatformEndpoint(createPlatformEndpointInput).continueWithBlock {
                (task) -> AnyObject! in
                if task.error != nil {
                    print("Error creating platform endpoint: \(task.error)")
                    completionHandler?(task.error)
                    return nil
                }
                let result = task.result as! AWSSNSCreateEndpointResponse
                let subscribeInput = AWSSNSSubscribeInput()
                subscribeInput.topicArn = SNSTopicARN
                subscribeInput.endpoint = result.endpointArn
                print("Endpoint arn: \(result.endpointArn)")
                subscribeInput.protocols = "application"
                sns.subscribe(subscribeInput).continueWithBlock
                    {
                        (task) -> AnyObject! in
                        if task.error != nil
                        {
                            completionHandler?(task.error)
                            print("Error subscribing: \(task.error)")
                            return nil
                        }
                        print("Subscribed succesfully")
                        let subscriptionConfirmInput = AWSSNSConfirmSubscriptionInput()
                        subscriptionConfirmInput.token = token
                        subscriptionConfirmInput.topicArn = SNSTopicARN
                        sns.confirmSubscription(subscriptionConfirmInput).continueWithBlock{
                                (task) -> AnyObject! in
                                if task.error != nil {
                                    print("Confirmed subscription")
                                } else {
                                    print ("Error during Subscribed");
                                    print (task.error)
                                }
                                completionHandler?(task.error)
                                return nil
                        }
                        return nil
                }
                return nil
        }
    }
    
    func sendMessage(message : String, type : String = "alert", sound : String = "default", badges : Int = 1, completionHandler : ((NSError?) -> ())? = nil) {
        let credentialsProvider : AWSStaticCredentialsProvider = AWSStaticCredentialsProvider(accessKey: AWSaccessKey, secretKey: AWSsecretKey)
        let defaultServiceConfiguration : AWSServiceConfiguration = AWSServiceConfiguration(region: DefaultServiceRegionType, credentialsProvider: credentialsProvider)
        AWSServiceManager.defaultServiceManager().defaultServiceConfiguration = defaultServiceConfiguration
        
        
        let sns = AWSSNS.defaultSNS()
        let request = AWSSNSPublishInput()
        request.messageStructure = "json"
        
        let dict = ["default": message, AWSenvironment: "{\"aps\":{\"\(type)\": \"\(message)\",\"sound\":\"\(sound)\", \"badge\":\"\(badges)\"} }"]
        
        do {
            let jsonData = try NSJSONSerialization.dataWithJSONObject(dict, options: NSJSONWritingOptions.PrettyPrinted)
            request.message = (NSString(data: jsonData, encoding: NSUTF8StringEncoding) as? String)
            request.topicArn = SNSTopicARN
            
            sns.publish(request).continueWithBlock
                {
                    (task) -> AnyObject! in
                    if task.error != nil
                    {
                        print("Error sending mesage: \(task.error)")
                    }
                    else
                    {
                        print("Success sending message")
                    }
                    completionHandler?(task.error)
                    return nil
            }
        }
        catch {
            print("Error on json serialization: \(error)")
        }
        
    }
    
    func application(application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: NSData) {
        let deviceTokenString = "\(deviceToken)"
            .stringByTrimmingCharactersInSet(NSCharacterSet(charactersInString:"<>"))
            .stringByReplacingOccurrencesOfString(" ", withString: "")
        print("deviceTokenString: \(deviceTokenString)")
        NSUserDefaults.standardUserDefaults().setObject(deviceTokenString, forKey: "deviceToken")
        
        let sns = AWSSNS.defaultSNS()
        let request = AWSSNSCreatePlatformEndpointInput()
        request.token = deviceTokenString
        request.platformApplicationArn = SNSPlatformApplicationArn
        sns.createPlatformEndpoint(request).continueWithExecutor(AWSExecutor.mainThreadExecutor(), withBlock: { (task: AWSTask!) -> AnyObject! in
            if task.error != nil {
                print("Error: \(task.error)")
            } else {
                let createEndpointResponse = task.result as! AWSSNSCreateEndpointResponse
                let endPointAWS = createEndpointResponse.endpointArn
                print("endpointArn: \(endPointAWS)")
                NSUserDefaults.standardUserDefaults().setObject(endPointAWS, forKey: "endpointArn")
                
            }
        
            return nil
        })
        self.subscribe(deviceTokenString)
        
    }
    
    func application(application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: NSError) {
        print("Failed to register with error: \(error)")
    }
    
    func application(application: UIApplication, didReceiveRemoteNotification userInfo: [NSObject : AnyObject], fetchCompletionHandler completionHandler: (UIBackgroundFetchResult) -> Void) {
        // display the userInfo
        if let notification = userInfo["aps"] as? NSDictionary,
            let alert = notification["alert"] as? String {
            let alertCtrl = UIAlertController(title: "70K Bands", message: alert as String, preferredStyle: UIAlertControllerStyle.Alert)
            alertCtrl.addAction(UIAlertAction(title: "OK", style: UIAlertActionStyle.Default, handler: nil))

            // Find the presented VC...
            var presentedVC = self.window?.rootViewController
            while (presentedVC!.presentedViewController != nil)  {
                presentedVC = presentedVC!.presentedViewController
            }
            presentedVC!.presentViewController(alertCtrl, animated: true, completion: nil)
            
            // call the completion handler
            // -- pass in NoData, since no new data was fetched from the server.
            completionHandler(UIBackgroundFetchResult.NoData)
        }
    }
    
    func application(application: UIApplication, handleActionWithIdentifier identifier: String?, forRemoteNotification userInfo: [NSObject : AnyObject], completionHandler: () -> Void) {
        
        completionHandler()
    }
    
    //end push functions
    
    //iCloud functions
    
    
    func applicationDidEnterBackground(application: UIApplication) {
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        writeFiltersFile()
        writeFile()
        
        //push notification
        //self.connectedToGCM = false
    }
    
    func applicationDidBecomeActive( application: UIApplication){
        
        NSNotificationCenter.defaultCenter().postNotificationName("RefreshDisplay", object: nil)
        
    }
    
    func iCloudKeysChanged(notification: NSNotification) {
        updateBandFromICloud()
    }

    private func updateBandFromICloud() {
        let bandInfo = NSUbiquitousKeyValueStore.defaultStore().dictionaryRepresentation
        if (bandInfo.count >= 1) {
            getPriorityDataFromiCloud()
        }
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
        writeFiltersFile()
        writeFile()
        
    }


    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }


    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        // Saves changes in the application's managed object context before the application terminates.
        writeFiltersFile()
        writeFile()
        self.saveContext()
    }

    // MARK: - Split view

    func splitViewController(splitViewController: UISplitViewController, collapseSecondaryViewController secondaryViewController:UIViewController, ontoPrimaryViewController primaryViewController:UIViewController) -> Bool {
        if let secondaryAsNavController = secondaryViewController as? UINavigationController {
            if let topAsDetailController = secondaryAsNavController.topViewController as? DetailViewController {
                if topAsDetailController.detailItem == nil {
                    // Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
                    return true
                }
            }
        }
        return false
    }
    // MARK: - Core Data stack

    lazy var applicationDocumentsDirectory: NSURL = {
        // The directory the application uses to store the Core Data store file. This code uses a directory named "com.rdorn._0000TonsBands" in the application's documents Application Support directory.
        let urls = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)
        return urls[urls.count-1] 
    }()

    lazy var managedObjectModel: NSManagedObjectModel = {
        // The managed object model for the application. This property is not optional. It is a fatal error for the application not to be able to find and load its model.
        let modelURL = NSBundle.mainBundle().URLForResource("_0000TonsBands", withExtension: "momd")!
        return NSManagedObjectModel(contentsOfURL: modelURL)!
    }()

    lazy var persistentStoreCoordinator: NSPersistentStoreCoordinator? = {
        // The persistent store coordinator for the application. This implementation creates and return a coordinator, having added the store for the application to it. This property is optional since there are legitimate error conditions that could cause the creation of the store to fail.
        // Create the coordinator and store
        var coordinator: NSPersistentStoreCoordinator? = NSPersistentStoreCoordinator(managedObjectModel: self.managedObjectModel)
        let url = self.applicationDocumentsDirectory.URLByAppendingPathComponent("_0000TonsBands.sqlite")
        var error: NSError? = nil
        var failureReason = "There was an error creating or loading the application's saved data."
        do {
            try coordinator!.addPersistentStoreWithType(NSSQLiteStoreType, configuration: nil, URL: url, options: nil)
        } catch var error1 as NSError {
            error = error1
            coordinator = nil
            // Report any error we got.
            var dict = [String: AnyObject]()
            dict[NSLocalizedDescriptionKey] = "Failed to initialize the application's saved data"
            dict[NSLocalizedFailureReasonErrorKey] = failureReason
            dict[NSUnderlyingErrorKey] = error
            error = NSError(domain: "YOUR_ERROR_DOMAIN", code: 9999, userInfo: dict)
            // Replace this with code to handle the error appropriately.
            // abort() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
            NSLog("Unresolved error \(error), \(error!.userInfo)")
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

