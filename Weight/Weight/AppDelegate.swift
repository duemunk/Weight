//
//  AppDelegate.swift
//  Weight
//
//  Created by Tobias Due Munk on 19/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import UIKit

extension Notification.Name {
    static let UserActivity = "userActivityNotification" as Notification.Name
}

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    func application(_ application: UIApplication, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: (Bool) -> Void) {
        print("Short cut")
        switch shortcutItem.type {
        case QuickActionType.CustomWeight.rawValue:
            completionHandler(true) // Do nothing. Default opening behaviour of app
        case QuickActionType.UpWeight.rawValue,
             QuickActionType.SameWeightAsLast.rawValue,
             QuickActionType.DownWeight.rawValue:

            guard let doubleValue = shortcutItem.userInfo?[directWeightKey] as? Double else {
                completionHandler(false)
                return
            }
            HealthManager.instance.saveWeight(doubleValue)
                .then { _ in
                    completionHandler(true)
                }
                .error {
                    print($0)
                    completionHandler(false)
                }
        default:
            completionHandler(false)
        }
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: ([AnyObject]?) -> Void) -> Bool {
        
        let userInfo = userActivity.userInfo
        print("Received a payload via handoff: \(userInfo)")
        NotificationCenter.default().post(name: .UserActivity, object: userActivity, userInfo: userActivity.userInfo)
        
        return true
    }
    
    func application(_ application: UIApplication, didUpdate userActivity: NSUserActivity) {
        let userInfo = userActivity.userInfo
        print("Updated user activity: \(userActivity) : \(userInfo)")
    }
}

