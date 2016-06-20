//
//  Weight.swift
//  Weight
//
//  Created by Tobias Due Munk on 20/06/16.
//  Copyright © 2016 Tobias Due Munk. All rights reserved.
//

import Foundation
import HealthKit


struct Weight {
    let kg: Double
    let date: Date
}


extension Weight {
    var hkQuantitySample: HKQuantitySample {
        let type = HKObjectType.quantityType(forIdentifier: .bodyMass)!
        let unit = HKUnit.gramUnit(with: .kilo)
        let quantity = HKQuantity(unit: unit, doubleValue: kg)
        return HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
    }

    var newWeightUserInfo: [String : AnyObject] {
        return [
            Keys.newWeightKg : kg,
            Keys.date : date
        ]
    }

    static func newWeight(from userInfo: [String : AnyObject]) -> Weight? {
        guard
            let weight = userInfo[Keys.newWeightKg] as? Double,
            let date = userInfo[Keys.date] as? Date
         else {
            return nil
        }
        return Weight(kg: weight, date: date)
    }

    var temporaryWeightUserInfo: [String : AnyObject] {
        return [
            Keys.temporaryWeightKg : kg,
            Keys.date : date
        ]
    }

    static func temporaryNewWeight(from userInfo: [String : AnyObject]) -> Weight? {
        guard
            let weight = userInfo[Keys.temporaryWeightKg] as? Double,
            let date = userInfo[Keys.date] as? Date
            else {
                return nil
        }
        return Weight(kg: weight, date: date)
    }
}


extension HKQuantitySample {
    var weight: Weight {
        let unit = HKUnit.gramUnit(with: .kilo)
        let weight = quantity.doubleValue(for: unit)
        let date = startDate
        return Weight(kg: weight, date: date)
    }
}
