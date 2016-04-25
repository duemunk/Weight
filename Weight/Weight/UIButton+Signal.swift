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
    public var tapSignal: Signal<Int> {
        let signal: Signal<Int>
        if let handle = objc_getAssociatedObject(self, &ButtonSignalHandle) as? Signal<Int> {
            signal = handle
        } else {
            signal = Signal()
            addTarget(self, action: #selector(UIButton.didTapButton(_:)), forControlEvents: .TouchUpInside)
            objc_setAssociatedObject(self, &ButtonSignalHandle, signal, objc_AssociationPolicy.OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        return signal
    }

    public func didTapButton(sender: AnyObject) {
        tapSignal.update(0)
    }
}