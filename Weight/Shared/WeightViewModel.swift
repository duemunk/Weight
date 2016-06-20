//
//  WeightViewModel.swift
//  Weight
//
//  Created by Tobias Due Munk on 20/06/16.
//  Copyright © 2016 Tobias Due Munk. All rights reserved.
//

import Foundation
import HealthKit

struct WeightViewModel {
    let weight: Weight
    let unit: HKUnit
    let formatterUnit: MassFormatter.Unit

    init(weight: Weight, massUnit: HKUnit) {
        self.weight = weight
        self.unit = massUnit
        self.formatterUnit = HKUnit.massFormatterUnit(from: massUnit)
    }

    func userValue() -> Double {
        return weight.hkQuantitySample.quantity.doubleValue(for: unit)
    }
}
