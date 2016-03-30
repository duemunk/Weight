//
//  AppDelegate.swift
//  Weight
//
//  Created by Tobias Due Munk on 19/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import UIKit

let UserActivityNotification = "userActivityNotification"

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(application: UIApplication, didFinishLaunchingWithOptions launchOptions: [NSObject: AnyObject]?) -> Bool {
        // Override point for customization after application launch.
        return true
    }

    func application(application: UIApplication, performActionForShortcutItem shortcutItem: UIApplicationShortcutItem, completionHandler: (Bool) -> Void) {
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
            HealthManager.instance.saveWeight(doubleValue) { result in
                do {
                    try result()
                    completionHandler(true)
                } catch {
                    print(error)
                    completionHandler(false)
                }
            }
        default:
            completionHandler(false)
        }
    }

    func applicationWillResignActive(application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(application: UIApplication) {
        // Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    func application(application: UIApplication, continueUserActivity userActivity: NSUserActivity, restorationHandler: ([AnyObject]?) -> Void) -> Bool {
        
        let userInfo = userActivity.userInfo
        print("Received a payload via handoff: \(userInfo)")
        NotificationCenter.post(UserActivityNotification, object: userActivity, userInfo: userActivity.userInfo)
        
        return true
    }
    
    func application(application: UIApplication, didUpdateUserActivity userActivity: NSUserActivity) {
        let userInfo = userActivity.userInfo
        print("Updated user activity: \(userActivity) : \(userInfo)")
    }
}

