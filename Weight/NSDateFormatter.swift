//
//  NSDateFormatter.swift
//  Weight
//
//  Created by Tobias Due Munk on 31/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import Foundation

extension NSDateFormatter {
    
//    class func build(dateStyle dateStyle: NSDateFormatterStyle = .NoStyle, timeStyle: NSDateFormatterStyle = .NoStyle) -> NSDateFormatter {
//        let formatter = NSDateFormatter()
//        formatter.dateStyle = dateStyle
//        formatter.timeStyle = timeStyle
//        return formatter
//    }

    convenience init(dateStyle: NSDateFormatterStyle, timeStyle: NSDateFormatterStyle = .NoStyle){
        self.init()
        self.dateStyle = dateStyle
        self.timeStyle = timeStyle
    }


    convenience init?(template: String, options: Int = 0, locale: NSLocale? = nil) {
        guard let templateString = NSDateFormatter.dateFormatFromTemplate(template, options: options, locale: locale) else {
            return nil
        }
        self.init()
        self.setLocalizedDateFormatFromTemplate(templateString)
    }
}
