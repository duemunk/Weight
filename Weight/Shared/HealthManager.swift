//
//  HealthManager.swift
//  Weight
//
//  Created by Tobias Due Munk on 21/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import Foundation
import HealthKit
import Interstellar

extension Notification.Name {
    static let HealthPreferencesDidChange = "HealthPreferencesDidChangeNotification" as NSNotification.Name
    static let HealthDataDidChange = "HealthDataDidChangeNotification" as NSNotification.Name
}

class HealthManager {
    static let instance = HealthManager()
    
    enum Error: ErrorProtocol {
        case noResults
        case noSuccessDespiteNoError
        case wrongInput
        case wrongConversion
    }

    enum ErrorAuth: ErrorProtocol {
        case denied
    }

    struct WeightPoint {
        let kg: Double
    }
    
    let healthStore = HKHealthStore()

    let weightType = HKObjectType.quantityType(forIdentifier: .bodyMass)!
    private(set) var massUnit: HKUnit = .gramUnit(with: .kilo) { // Default to [kg]
        didSet {
            guard massUnit != oldValue else { return }
            massFormatterUnit = HKUnit.massFormatterUnit(from: massUnit)
            NotificationCenter.default().post(name: .HealthPreferencesDidChange, object: nil)
        }
    }
    private(set) var massFormatterUnit = HKUnit.massFormatterUnit(from: .gramUnit(with: .kilo))

    init() {
        
        if !HKHealthStore.isHealthDataAvailable() {
            print("No Health data available")
            return
        }
        
        // Observe and propagate user changes from other apps
        NotificationCenter.default().addObserver(forName: .HKUserPreferencesDidChange, object: nil, queue: nil) { [weak self] notification in
            self?.updatePreferredUnits()
        }
        
        // Setup access
        checkHealthKitAuthorization()
            .then {
                self.updatePreferredUnits()
            }
            .error { print($0) }
            .flatMap(Queue.main)
            .next {
                NotificationCenter.default().post(name: .HealthDataDidChange, object: nil)
            }


        // Initial setup of preferred units
        updatePreferredUnits()
    }
    
    deinit {
//        NotificationCenter.default().unob.unobserve(self)
    }
    
    private func updatePreferredUnits() {
        healthStore.preferredUnit(forQuantityType: weightType)
            .then { unit in
                self.massUnit = unit
            }
            .error { print($0) }
    }

    func save(weight: Weight) -> Observable<Result<Weight>> {
        let sample = weight.hkQuantitySample
        let observer = Observable<Result<Bool>>()
        healthStore.save(sample, withCompletion: completionToObservable(observer: observer))
        return observer
            .then {
                guard $0 else {
                    print("No success, but no error")
                    return .error(Error.noSuccessDespiteNoError)
                }
                print("Yay, stored \(sample) to HealthKit!")
                WeightsLocalStore.instance.lastWeight = weight
                return .success(sample.weight)
        }
    }

    private func castToSubType<T, U>(t: T) -> Result<U> {
        guard let u = t as? U else {
            print("Not of type \(U.self)")
            return .error(Error.wrongConversion)
        }
        return .success(u)
    }
    private func sampleToQuantitySample<T: HKSample, U: HKQuantitySample>(t: T) -> Result<U> {
        return castToSubType(t: t)
    }

    private func castToSubTypeInArray<T, U>(t: [T]) -> Result<[U]> {
        let casted = t
            .flatMap { $0 as? U }
        guard casted.count == t.count else {
            return .error(Error.wrongConversion)
        }
        return .success(casted)
    }
    private func sampleToQuanitySampleInArray<T: HKSample, U: HKQuantitySample>(t: [T]) -> Result<[U]> {
        return castToSubTypeInArray(t: t)
    }

    func getWeight(forceSource: Bool) -> Observable<Result<Weight>> {
        return healthStore.mostRecentSample(ofType: weightType)
            .then(sampleToQuantitySample)
            .then { $0.weight }
            .then { (source: Weight) -> Weight  in
                guard let cached = WeightsLocalStore.instance.lastWeight else {
                    return source
                }
                let useSource = forceSource || source.date > cached.date
                if useSource {
                    return source
                }
                return cached
            }.next {
                WeightsLocalStore.instance.lastWeight = $0
            }
    }

    func getWeights() -> Observable<Result<[Weight]>>{
        return healthStore.samples(ofType: weightType)
            .then(sampleToQuanitySampleInArray)
            .then { $0.map { $0.weight } }
    }
    
    func checkHealthKitAuthorization() -> Observable<Result<Void>> {

        switch healthStore.authorizationStatus(for: weightType) {
            case .sharingDenied:
                print("HealthKit access denied")
                return Observable(.error(ErrorAuth.denied))
            case .notDetermined:
                print("HealthKit access undetermined")
                break
            case .sharingAuthorized:
                return Observable(.success())
        }

        let observer = Observable<Result<Void>>()
        healthStore.requestAuthorizationTo(types: [weightType])
            .then { observer.update(.success($0)) }
            .error { observer.update(.error($0)) }
        return observer
    }

    func humanWeightUnitDivision() -> Int {
        switch massUnit {
        case HKUnit.stone(): return 28
        case HKUnit.pound(): return 2
        case HKUnit.gramUnit(with: .kilo): return 10
        default: return 10
        }
    }

    func humanWeightOptions() -> [WeightPoint] {
        let division = humanWeightUnitDivision()
        let (min, max): (Int, Int) = {
            switch massUnit {
                case HKUnit.stone(): return (0, 100)
                case HKUnit.pound(): return (0, 1400)
                case HKUnit.gramUnit(with: .kilo): return (50, 150)
                default: return (0, 1000)
            }
        }()
        var options = [Double]()
        for option in min*division...max*division {
            options.append(Double(option) / Double(division))
        }
        let kgUnit = HKUnit.gramUnit(with: .kilo)

        return options
            .map { HKQuantity(unit: massUnit, doubleValue: $0).doubleValue(for: kgUnit) }
            .map { WeightPoint(kg: $0) }
    }
}


extension Collection where Iterator.Element == Weight {

    func averages(_ unit: CalendarUnit) -> [Iterator.Element]? {

        let sorted = self.sorted { $0.date < $1.date }

        guard let
            first = sorted.first,
            lastDate = sorted.last?.date
            else {
            return nil
        }
        let firstDate = first.date
        guard let firstReferenceDay = firstDate.beginningOf(unit) else {
            return nil
        }
        var referenceDateInAverageUnit = [Date]()
        referenceDateInAverageUnit.append(firstReferenceDay)
        while let previousReference = referenceDateInAverageUnit.last where previousReference < lastDate {
            guard let nextReference = previousReference.add(unit) else {
                break
            }
            referenceDateInAverageUnit.append(nextReference)
        }

        let referenceCount = referenceDateInAverageUnit.count
        let startEndDates = Array(zip(referenceDateInAverageUnit[0..<referenceCount - 1], referenceDateInAverageUnit[1..<referenceCount]))
        let averages: [Weight] = startEndDates
            .flatMap { (startDate, endDate) in
                let inUnit = self.filter { startDate..<endDate ~= $0.date }
                let count = inUnit.count
                guard count > 0 else { return nil }
                let averageValue = inUnit
                    .reduce(0) { $0 + $1.kg }
                    / Double(count)
                return Weight(kg: averageValue, date: endDate)
            }
        return averages
    }
}


import UIKit
enum CalendarUnit {
    case year, month, week, day

    var timeInterval: TimeInterval {
        return Date().add(self)!.timeIntervalSince(Date())
    }
}
extension Date {

    func beginningOfDay() -> Date? {
        let calendar = Calendar.current()
        let unitFlags: Calendar.Unit = [.year, .month, .day, .hour, .minute, .second]
        var components = calendar.components(unitFlags, from: self)
        components.hour = 0
        components.minute = 0
        components.second = 0
        return calendar.date(from: components)
    }

    func endOfDay() -> Date? {
        let calendar = Calendar.current()
        let unitFlags: Calendar.Unit = [.year, .month, .day, .hour, .minute, .second]
        var components = calendar.components(unitFlags, from: self)
        components.hour = 23
        components.minute = 59
        components.second = 59
        return calendar.date(from: components)
    }

    func beginningOf(_ unit: CalendarUnit) -> Date? {
        let calendar = Calendar.current()
        let unitFlags: Calendar.Unit = [.year, .month, .weekday, .day, .hour, .minute, .second]
        var components = calendar.components(unitFlags, from: self)
        switch unit {
        case .year:
            components.month = 1
            components.day = 1
            components.hour = 0
            components.minute = 0
            components.second = 0
        case .month:
            components.day = 1
            components.hour = 0
            components.minute = 0
            components.second = 0
        case .week:
            components.day? -= components.weekday.flatMap { $0 - 1 } ?? 0
            components.hour = 0
            components.minute = 0
            components.second = 0
        case .day:
            components.hour = 0
            components.minute = 0
            components.second = 0
        }
        return calendar.date(from: components)
    }

    func add(_ unit: CalendarUnit, count: Int = 1) -> Date? {
        var components = DateComponents()
        switch unit {
        case .year:
            components.year = count
        case .month:
            components.month = count
        case .week:
            components.weekOfYear = count
        case .day:
            components.day = count
        }
        let calendar = Calendar.current()
        return calendar.date(byAdding: components, to: self, options: .matchFirst)
    }
}
