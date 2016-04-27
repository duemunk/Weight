//
//  NotificationCenter.swift
//  Weight
//
//  Created by Tobias Due Munk on 19/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import UIKit
import Interstellar


//extension Observable where T : NSNotification {
//
//    convenience init(name: String) {
//        self.init()
//
//        NSNotificationCenter
//            .defaultCenter()
//            .addObserverForName(name, object: nil, queue: nil) { [weak self] (notification: NSNotification) in
////                self?.update(notification)
//                if let _self = self,
//                    __self = _self as? Observable<NSNotification> {
//                    __self.update(notification)
//                }
//        }
//        NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(Observable.update(notification:)), name: NSUserDefaultsDidChangeNotification, object: nil)
//        return
//    }
//
//    func update(notification notification: NSNotification) {
//        if let _self = self as? Observable<NSNotification> {
//            _self.update(notification)
//        }
//    }
//}

class NotificationCenter: NSObject {
    var observer: Observable<NSNotification>? = Observable<NSNotification>(options: .NoInitialValue) {
        didSet {
            if observer == nil,
                let notificationObserver = notificationObserver {
                NotificationCenter.unobserve(notificationObserver)
                self.notificationObserver = nil
            }
        }
    }
    private var notificationObserver: NSObjectProtocol?

    init(name: String) {
        super.init()
        notificationObserver = NSNotificationCenter.defaultCenter().addObserverForName(name, object: nil, queue: nil) { [weak self] notification in
            self?.observer?.update(notification)
        }
    }

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


