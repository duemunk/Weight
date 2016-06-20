//
//  WeightsLocalStore.swift
//  Weight
//
//  Created by Tobias Due Munk on 28/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import Foundation

class WeightsLocalStore {
    static let instance = WeightsLocalStore()
    
    private let weightsDefaults = UserDefaults(suiteName: "group.weights")
    private let lastWeightKey = "lastWeightKey"
    private let lastWeightDateKey = "lastWeightDateKey"

    var lastWeight: Weight? {
        get {
            guard let weight = weightsDefaults?.object(forKey: lastWeightKey) as? Double else {
                return nil
            }
            let date = WeightsLocalStore.instance.lastWeightDate ?? Date()
            let sample = Weight(kg: weight, date: date)
            return sample
        }
        set {
            guard let weight = newValue else {
                return
            }
            weightsDefaults?.set(weight.kg, forKey: lastWeightKey)
            weightsDefaults?.synchronize()
            // Also store date
            lastWeightDate = weight.date
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
