//
//  NSMassFormatter.swift
//  Weight
//
//  Created by Tobias Due Munk on 31/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import Foundation


extension MassFormatter {
    
    class func weightShortFormatter() -> MassFormatter {
        let formatter = MassFormatter()
        formatter.isForPersonMassUse = true
        formatter.unitStyle = .short
        formatter.numberFormatter.numberStyle = .decimal
        formatter.numberFormatter.maximumFractionDigits = 1
        return formatter
    }
    
    class func weightMediumFormatter() -> MassFormatter {
        let formatter = MassFormatter()
        formatter.isForPersonMassUse = true
        formatter.unitStyle = .medium
        formatter.numberFormatter.numberStyle = .decimal
        formatter.numberFormatter.maximumFractionDigits = 2
        formatter.numberFormatter.minimumFractionDigits = 1
        return formatter
    }
    
    class func weightLongFormatter() -> MassFormatter {
        let formatter = MassFormatter()
        formatter.isForPersonMassUse = true
        formatter.unitStyle = .long
        formatter.numberFormatter.numberStyle = .decimal
        return formatter
    }
}


extension NumberFormatter {
    
    class func weightNoUnitFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 1
        return formatter
    }
    
    class func weightNoUnitShortFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter
    }

    class func weightNoUnitUltraShortFormatter() -> NumberFormatter {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter
    }
}
