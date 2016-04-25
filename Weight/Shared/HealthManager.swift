//
//  HealthManager.swift
//  Weight
//
//  Created by Tobias Due Munk on 21/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import Foundation
import HealthKit

let HealthPreferencesDidChangeNotification = "HealthPreferencesDidChangeNotification"
let HealthDataDidChangeNotification = "HealthDataDidChangeNotification"

typealias AsyncQuantitySampleResult = (() throws -> HKQuantitySample) -> ()
typealias AsyncQuantitySamplesResult = (() throws -> [HKQuantitySample]) -> ()

class HealthManager {
    static let instance = HealthManager()
    
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
                NotificationCenter.post(HealthDataDidChangeNotification)
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
                
                NotificationCenter.post(HealthPreferencesDidChangeNotification)
            }
        }
    }

    func saveWeight(doubleValue: Double, result: AsyncQuantitySampleResult) {
        let quantity = HKQuantity(unit: massUnit, doubleValue: doubleValue)
        saveQuantity(quantity, type: weightType, result: result)
    }

    func saveWeight(quantity: HKQuantity, date: NSDate = NSDate(), result: AsyncQuantitySampleResult) {
        saveQuantity(quantity, type: weightType, date: date, result: result)
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
                WeightsLocalStore.instance.lastWeight = quantitySample
                result { quantitySample }
            } catch {
                result { throw error}
            }
        }
    }

    func getWeights(result: AsyncQuantitySamplesResult) {
        healthStore.samples(ofType: weightType) { _result in
            do {
                let samples = try _result()
                let quantitySamples = samples.flatMap { return $0 as? HKQuantitySample }
                result { quantitySamples }
            } catch {
                result { throw error}
            }
        }
    }
    
    private func saveQuantity(quantity: HKQuantity, type: HKQuantityType, date: NSDate = NSDate(), result: AsyncQuantitySampleResult) {
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
            result { sample }
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

    func humanWeightUnitDivision() -> Int {
        switch massUnit {
        case HKUnit.stoneUnit(): return 28
        case HKUnit.poundUnit(): return 2
        case HKUnit.gramUnitWithMetricPrefix(.Kilo): return 10
        default: return 10
        }
    }

    func humanWeightOptions() -> [HKQuantity] {
        let division = humanWeightUnitDivision()
        let (min, max): (Int, Int) = {
            switch massUnit {
                case HKUnit.stoneUnit(): return (0, 100)
                case HKUnit.poundUnit(): return (0, 1400)
                case HKUnit.gramUnitWithMetricPrefix(.Kilo): return (50, 150)
                default: return (0, 1000)
            }
        }()
        var options = [Double]()
        for option in min*division...max*division {
            options.append(Double(option) / Double(division))
        }
        return options.map { HKQuantity(unit: massUnit, doubleValue: $0) }
    }
}


extension CollectionType where Generator.Element == HKQuantitySample {

    func averages(unit: CalendarUnit) -> [Generator.Element]? {

        let sorted = self.sort { $0.startDate.isBefore($1.endDate) }

        guard let
            first = sorted.first,
            lastDate = sorted.last?.startDate
            else {
            return nil
        }
        let firstDate = first.startDate
        guard let firstReferenceDay = firstDate.beginningOf(unit) else {
            return nil
        }
        var referenceDateInAverageUnit = [NSDate]()
        referenceDateInAverageUnit.append(firstReferenceDay)
        while let previousReference = referenceDateInAverageUnit.last where previousReference.isBefore(lastDate) {
            guard let nextReference = previousReference.add(unit) else {
                break
            }
            referenceDateInAverageUnit.append(nextReference)
        }

        let massUnit = HealthManager.instance.massUnit
        let quantityType = first.quantityType

        let referenceCount = referenceDateInAverageUnit.count
        let startEndDates = Array(zip(referenceDateInAverageUnit[0..<referenceCount - 1], referenceDateInAverageUnit[1..<referenceCount]))
        let averages: [HKQuantitySample] = startEndDates
            .flatMap { (startDate, endDate) in
                let inUnit = self.filter { $0.startDate.isAfter(startDate) && $0.startDate.isBefore(endDate) }
                let count = inUnit.count
                guard count > 0 else { return nil }
                let averageValue = inUnit
                    .reduce(0) { $0 + $1.quantity.doubleValueForUnit(massUnit) }
                    / Double(count)
                let quantity = HKQuantity(unit: massUnit, doubleValue: averageValue)
                return HKQuantitySample(type: quantityType, quantity: quantity, startDate: startDate, endDate: endDate)
            }
        return averages
    }
}


import UIKit
enum CalendarUnit {
    case Year, Month, Week, Day

    var timeInterval: NSTimeInterval {
        return NSDate().add(self)!.timeIntervalSinceDate(NSDate())
    }
}
extension NSDate {

    func beginningOfDay() -> NSDate? {
        let calendar = NSCalendar.currentCalendar()
        let unitFlags: NSCalendarUnit = [.Year, .Month, .Day, .Hour, .Minute, .Second]
        let components = calendar.components(unitFlags, fromDate: self)
        components.hour = 0
        components.minute = 0
        components.second = 0
        return calendar.dateFromComponents(components)
    }

    func endOfDay() -> NSDate? {
        let calendar = NSCalendar.currentCalendar()
        let unitFlags: NSCalendarUnit = [.Year, .Month, .Day, .Hour, .Minute, .Second]
        let components = calendar.components(unitFlags, fromDate: self)
        components.hour = 23
        components.minute = 59
        components.second = 59
        return calendar.dateFromComponents(components)
    }

    func beginningOf(unit: CalendarUnit) -> NSDate? {
        let calendar = NSCalendar.currentCalendar()
        let unitFlags: NSCalendarUnit = [.Year, .Month, .Weekday, .Day, .Hour, .Minute, .Second]
        let components = calendar.components(unitFlags, fromDate: self)
        switch unit {
        case .Year:
            components.month = 1
            components.day = 1
            components.hour = 0
            components.minute = 0
            components.second = 0
        case .Month:
            components.day = 1
            components.hour = 0
            components.minute = 0
            components.second = 0
        case .Week:
            components.day -= components.weekday - 1
            components.hour = 0
            components.minute = 0
            components.second = 0
        case .Day:
            components.hour = 0
            components.minute = 0
            components.second = 0
        }
        return calendar.dateFromComponents(components)
    }

    func add(unit: CalendarUnit, count: Int = 1) -> NSDate? {
        let components = NSDateComponents()
        switch unit {
        case .Year:
            components.year = count
        case .Month:
            components.month = count
        case .Week:
            components.weekOfYear = count
        case .Day:
            components.day = count
        }
        let calendar = NSCalendar.currentCalendar()
        return calendar.dateByAddingComponents(components, toDate: self, options: .MatchFirst)
    }

    func isBefore(date: NSDate) -> Bool {
        return compare(date) == .OrderedAscending
    }
    func isSame(date: NSDate) -> Bool {
        return compare(date) == .OrderedSame
    }
    func isAfter(date: NSDate) -> Bool {
        return compare(date) == .OrderedDescending
    }
}
