//
//  NSDateFormatter.swift
//  Weight
//
//  Created by Tobias Due Munk on 31/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import Foundation

extension NSDateFormatter {
    
    class func build(dateStyle dateStyle: NSDateFormatterStyle = .NoStyle, timeStyle: NSDateFormatterStyle = .NoStyle) -> NSDateFormatter {
        let formatter = NSDateFormatter()
        formatter.dateStyle = dateStyle
        formatter.timeStyle = timeStyle
        return formatter
    }
}
