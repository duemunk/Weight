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
    private let lastWeightDateKey = "lastWeightDateKey"
    let massUnit: HKUnit = .gramUnit(with: .kilo) // Always store in SI units
    
    private let weightType = HKObjectType.quantityType(forIdentifier: HKQuantityTypeIdentifier.bodyMass)!
    var lastWeight: HKQuantitySample? {
        get {
            guard let weight = weightsDefaults?.object(forKey: lastWeightKey) as? Double else {
                return nil
            }
            let quantity = HKQuantity(unit: massUnit, doubleValue: weight)
            let date = WeightsLocalStore.instance.lastWeightDate ?? Date()
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
            // Also store date
            lastWeightDate = weight.startDate
        }
    }

    private var lastWeightDate: Date? {
        get {
            return weightsDefaults?.object(forKey: lastWeightDateKey) as? Date
        }
        set {
            guard let date = newValue else {
                return
            }
            weightsDefaults?.set(date, forKey: lastWeightDateKey)
            weightsDefaults?.synchronize()
        }
    }
}
