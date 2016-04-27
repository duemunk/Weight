//
//  UIButton+Signal.swift
//  Weight
//
//  Created by Tobias Due Munk on 25/04/16.
//  Copyright © 2016 Tobias Due Munk. All rights reserved.
//

import UIKit
import Interstellar


var ButtonSignalHandle: UInt8 = 0
extension UIButton {
    var tap: Observable<Int> {
        let observer: Observable<Int>
        if let handle = objc_getAssociatedObject(self, &ButtonSignalHandle) as? Observable<Int> {
            observer = handle
        } else {
            observer = Observable()
            addTarget(self, action: #selector(UIButton.didTapButton(_:)), forControlEvents: .TouchUpInside)
            objc_setAssociatedObject(self, &ButtonSignalHandle, observer, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        return observer
    }

    public func didTapButton(sender: AnyObject) {
        tap.update(0)
    }
}