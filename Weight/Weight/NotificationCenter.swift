//
//  NotificationCenter.swift
//  Weight
//
//  Created by Tobias Due Munk on 19/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import UIKit

class NotificationCenter {
    
    class func post(name: String, object: AnyObject? = nil, userInfo: [NSObject : AnyObject]? = nil) {
        NSNotificationCenter.defaultCenter().postNotificationName(name, object: object, userInfo: userInfo)
    }
    
    class func observe(name: String, object: AnyObject? = nil, queue: NSOperationQueue? = nil, usingBlock block: NSNotification! -> ()) -> NSObjectProtocol {
        return NSNotificationCenter.defaultCenter().addObserverForName(name, object: object, queue: queue, usingBlock: block)
    }
    
    class func unobserve(observer: AnyObject, name: String? = nil, object: AnyObject? = nil) {
        NSNotificationCenter.defaultCenter().removeObserver(observer, name: name, object: object)
    }
}
