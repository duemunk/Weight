//
//  UIButton+Signal.swift
//  Weight
//
//  Created by Tobias Due Munk on 25/04/16.
//  Copyright © 2016 Tobias Due Munk. All rights reserved.
//

import UIKit


var ButtonSignalHandle: UInt8 = 0
extension UIButton {
    var tap: Observable<Void> {
        let observer: Observable<Void>
        if let handle = objc_getAssociatedObject(self, &ButtonSignalHandle) as? Observable<Void> {
            observer = handle
        } else {
            observer = Observable()
            addTarget(self, action: #selector(UIButton.didTapButton(_:)), for: .touchUpInside)
            objc_setAssociatedObject(self, &ButtonSignalHandle, observer, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
        }
        return observer
    }

    @objc func didTapButton(_ sender: AnyObject) {
        tap.update(())
    }
}
