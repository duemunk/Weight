//
//  NSMassFormatter.swift
//  Weight
//
//  Created by Tobias Due Munk on 31/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import Foundation


extension NSMassFormatter {
    
    class func weightShortFormatter() -> NSMassFormatter {
        let formatter = NSMassFormatter()
        formatter.forPersonMassUse = true
        formatter.unitStyle = .Short
        formatter.numberFormatter.numberStyle = .DecimalStyle
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter
    }
    
    class func weightMediumFormatter() -> NSMassFormatter {
        let formatter = NSMassFormatter()
        formatter.forPersonMassUse = true
        formatter.unitStyle = .Medium
        formatter.numberFormatter.numberStyle = .DecimalStyle
        formatter.numberFormatter.maximumFractionDigits = 2
        formatter.numberFormatter.minimumFractionDigits = 1
        return formatter
    }
    
    class func weightLongFormatter() -> NSMassFormatter {
        let formatter = NSMassFormatter()
        formatter.forPersonMassUse = true
        formatter.unitStyle = .Long
        formatter.numberFormatter.numberStyle = .DecimalStyle
        return formatter
    }
}


extension NSNumberFormatter {
    
    class func weightNoUnitFormatter() -> NSNumberFormatter {
        let formatter = NSNumberFormatter()
        formatter.numberStyle = .DecimalStyle
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 1
        return formatter
    }
    
    class func weightNoUnitShortFormatter() -> NSNumberFormatter {
        let formatter = NSNumberFormatter()
        formatter.numberStyle = .DecimalStyle
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter
    }
}
