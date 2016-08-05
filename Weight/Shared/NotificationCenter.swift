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

class NotificationCenter_: NSObject {
    var observer: Observable<Notification> = Observable<Notification>(options: .noInitialValue)
    private var notificationObserver: NSObjectProtocol!

    init(name: NSNotification.Name) {
        super.init()
        notificationObserver = NotificationCenter.default.addObserver(forName: name, object: nil, queue: nil) { [weak self] notification in
            self?.observer.update(notification)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(notificationObserver)
    }

//    class func post(_ name: String, object: AnyObject? = nil, userInfo: [NSObject : AnyObject]? = nil) {
//        Foundation.NotificationCenter.default().post(name: Notification.Name(rawValue: name), object: object, userInfo: userInfo)
//    }
//    
//    class func observe(_ name: String, object: AnyObject? = nil, queue: OperationQueue? = nil, usingBlock block: (Notification!) -> ()) -> NSObjectProtocol {
//        return Foundation.NotificationCenter.default().addObserver(forName: NSNotification.Name(rawValue: name), object: object, queue: queue, using: block)
//    }
//    
//    class func unobserve(_ observer: AnyObject, name: String? = nil, object: AnyObject? = nil) {
//        Foundation.NotificationCenter.default().removeObserver(observer, name: name.map { NSNotification.Name(rawValue: $0) }, object: object)
//    }
}


