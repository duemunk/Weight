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
    
    private let weightsDefaults = UserDefaults(suiteName: "group.weights")
    private let lastWeightKey = "lastWeightKey"
    let massUnit: HKUnit = .gramUnit(with: .kilo) // Always store in SI units
    
    private let weightType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bodyMass)!
    var lastWeight: HKQuantitySample? {
        get {
            guard let weight = weightsDefaults?.object(forKey: lastWeightKey) as? Double else {
                return nil
            }
            let quantity = HKQuantity(unit: massUnit, doubleValue: weight)
            let date = Date()
            let sample = HKQuantitySample(type: weightType, quantity: quantity, start: date, end: date)
            return sample
        }
        set {
            guard let weight = newValue else {
                return
            }
            let doubleValue = weight.quantity.doubleValue(for: massUnit)
            weightsDefaults?.set(doubleValue, forKey: lastWeightKey)
            weightsDefaults?.synchronize()
        }
    }
}
