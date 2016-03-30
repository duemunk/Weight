//
//  WeightsLocalStore.swift
//  Weight
//
//  Created by Tobias Due Munk on 28/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import Foundation
import HealthKit

class WeightsLocalStore {
    static let instance = WeightsLocalStore()
    
    private let weightsDefaults = NSUserDefaults(suiteName: "group.weights")
    private let lastWeightKey = "lastWeightKey"
    let massUnit: HKUnit = .gramUnitWithMetricPrefix(.Kilo) // Always store in SI units
    
    private let weightType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMass)!
    var lastWeight: HKQuantitySample? {
        get {
            guard let weight = weightsDefaults?.objectForKey(lastWeightKey) as? Double else {
                return nil
            }
            let quantity = HKQuantity(unit: massUnit, doubleValue: weight)
            let date = NSDate()
            let sample = HKQuantitySample(type: weightType, quantity: quantity, startDate: date, endDate: date)
            return sample
        }
        set {
            guard let weight = newValue else {
                return
            }
            let doubleValue = weight.quantity.doubleValueForUnit(massUnit)
            weightsDefaults?.setObject(doubleValue, forKey: lastWeightKey)
            weightsDefaults?.synchronize()
        }
    }
}