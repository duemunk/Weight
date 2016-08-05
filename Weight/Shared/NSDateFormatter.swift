//
//  NSDateFormatter.swift
//  Weight
//
//  Created by Tobias Due Munk on 31/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import Foundation

extension DateFormatter {
    
//    class func build(dateStyle dateStyle: NSDateFormatterStyle = .NoStyle, timeStyle: NSDateFormatterStyle = .NoStyle) -> NSDateFormatter {
//        let formatter = NSDateFormatter()
//        formatter.dateStyle = dateStyle
//        formatter.timeStyle = timeStyle
//        return formatter
//    }

    convenience init(dateStyle: DateFormatter.Style, timeStyle: DateFormatter.Style = .none){
        self.init()
        self.dateStyle = dateStyle
        self.timeStyle = timeStyle
    }


    convenience init?(template: String, options: Int = 0, locale: Locale? = nil) {
        guard let templateString = DateFormatter.dateFormat(fromTemplate: template, options: options, locale: locale) else {
            return nil
        }
        self.init()
        self.setLocalizedDateFormatFromTemplate(templateString)
    }
}
