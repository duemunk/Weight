//
//  HealthManager.swift
//  Weight
//
//  Created by Tobias Due Munk on 21/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import Foundation
import HealthKit

let HealthDataOrPreferencesDidChangeNotification = "HealthDataOrPreferencesDidChangeNotification"

typealias AsyncQuantitySampleResult = (() throws -> HKQuantitySample) -> ()

class HealthManager {
    
    enum Error: ErrorType {
        case NoResults
        case NoSuccessDespiteNoError
        case WrongInput
    }
    
    let healthStore = HKHealthStore()
    
    let weightType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMass)!
    var massUnit: HKUnit = .gramUnitWithMetricPrefix(.Kilo)  // Default to [kg]
    var massFormatterUnit = HKUnit.massFormatterUnitFromUnit(.gramUnitWithMetricPrefix(.Kilo))
    
    init() {
        
        if !HKHealthStore.isHealthDataAvailable() {
            print("No Health data available")
            return
        }
        
        // Observe and propagate user changes from other apps
        NotificationCenter.observe(HKUserPreferencesDidChangeNotification) { [weak self] notification in
            self?.updatePreferredUnits()
            NotificationCenter.post(HealthDataOrPreferencesDidChangeNotification)
        }
        
        // Setup access
        checkHealthKitAuthorization { [weak self] result in
            do {
                try result()
                self?.updatePreferredUnits()
            } catch {
                print(error)
            }
            defer {
                NotificationCenter.post(HealthDataOrPreferencesDidChangeNotification)
            }
        }
        
        // Initial setup of preferred units
        updatePreferredUnits()
    }
    
    deinit {
        NotificationCenter.unobserve(self)
    }
    
    private func updatePreferredUnits() {
        healthStore.preferredUnit(forQuantityType: weightType) { result in
            if let unit = optionalResult(result) {
                self.massUnit = unit
                self.massFormatterUnit = HKUnit.massFormatterUnitFromUnit(unit)
                
                NotificationCenter.post(HealthDataOrPreferencesDidChangeNotification)
            }
        }
    }
    
    func saveWeight(doubleValue: Double, date: NSDate = NSDate(), result: AsyncEmptyResult) {
        saveQuantity(doubleValue, type: weightType, unit: massUnit, date: date, result: result)
    }
    
    func getWeight(result: AsyncQuantitySampleResult) {
        healthStore.mostRecentSample(ofType: weightType) { _result in
            do {
                let sample = try _result()
                guard let quantitySample = sample as? HKQuantitySample else {
                    print("Not of type HKQuantitySample")
                    result { throw Error.NoSuccessDespiteNoError }
                    return
                }
                result { quantitySample }
            } catch {
                result { throw error}
            }
        }
    }
    
    private func saveQuantity(doubleValue: Double, type: HKQuantityType, unit: HKUnit, date: NSDate = NSDate(), result: AsyncEmptyResult) {
        guard type.isCompatibleWithUnit(unit) else {
            print("\(type) is not compatible with unit \(unit)")
            result { Error.WrongInput }
            return
        }
        let quantity = HKQuantity(unit: unit, doubleValue: doubleValue)
        let sample = HKQuantitySample(type: type, quantity: quantity, startDate: date, endDate: date)
        healthStore.saveObject(sample) { success, error in
            if let error = error {
                print(error)
                result { throw error }
                return
            }
            guard success else {
                print("No success, but no error")
                result { throw Error.NoSuccessDespiteNoError }
                return
            }
            result {}
            print("Yay, stored \(sample) to HealthKit!")
        }
    }
    
    func checkHealthKitAuthorization(result: AsyncEmptyResult) {
        
        switch healthStore.authorizationStatusForType(weightType) {
            case .SharingDenied:
                print("HealthKit access denied")
                return
            case .NotDetermined:
                print("HealthKit access undetermined")
                break
            case .SharingAuthorized:
                return
        }
        
        healthStore.requestAuthorizationTo(types: [weightType]) { _result in
            result { try _result() }
        }
    }
    
    func humanWeightOptions() -> [Double] {
        let (min, max, division): (Int, Int, Int) = {
            switch massUnit {
                case HKUnit.stoneUnit(): return (0, 100, 28)
                case HKUnit.poundUnit(): return (0, 1400, 2)
                case HKUnit.gramUnitWithMetricPrefix(.Kilo): return (0, 635, 10)
                default: return (0, 1000, 10)
            }
        }()
        var options = [Double]()
        for option in min...max*division {
            options.append(Double(option) / Double(division))
        }
        return options
    }
}
