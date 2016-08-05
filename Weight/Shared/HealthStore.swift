//
//  HealthStore.swift
//  Weight
//
//  Created by Tobias Due Munk on 19/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import Foundation
import HealthKit
import Interstellar

extension HKHealthStore {
    
    /// Convenience to request both share and read authorization for a set of types
    func requestAuthorizationTo(types: Set<HKSampleType>) -> Observable<Result<Void>> {
        return requestAuthorizationTo(shareTypes: types, readTypes: types)
    }
    
    func requestAuthorizationTo(shareTypes: Set<HKSampleType>, readTypes: Set<HKSampleType>) -> Observable<Result<Void>> {
        let observer = Observable<Result<Bool>>()
        requestAuthorization(toShare: shareTypes, read: readTypes, completion: completionToObservable(observer: observer))
        return observer
            .then {
                guard $0 else {
                    print("Couldn't get authorization request")
                    return .error(AsyncError.noSuccessDespiteNoError)
                }
                return .success()
            }
    }

    func samples(ofType sampleType: HKSampleType, predicate: NSPredicate? = nil) -> Observable<Result<[HKSample]>> {
        let timeSortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let observer = Observable<Result<(HKSampleQuery, [HKSample]?)>>()
        let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [timeSortDescriptor], resultsHandler: completionToObservable(observer: observer))
        execute(query)
        return observer
            .then {
                guard let samples = $0.1 else {
                    return .error(AsyncError.noResults)
                }
                return .success(samples)
            }
    }

    func mostRecentSample(ofType sampleType: HKSampleType, predicate: NSPredicate? = nil) -> Observable<Result<HKSample>> {
        // Since we are interested in retrieving the user's latest sample, we sort the samples in descending order, and set the limit to 1. We are not filtering the data, and so the predicate is set to nil.
        let timeSortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let observer = Observable<Result<(HKSampleQuery, [HKSample]?)>>()
        let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: 1, sortDescriptors: [timeSortDescriptor], resultsHandler: completionToObservable(observer: observer))
        execute(query)
        return observer
            .then {
                guard let sample = $0.1?.first else {
                    return .error(AsyncError.noResults)
                }
                return .success(sample)
            }
    }
    
    func preferredUnits(forQuantityTypes quantityTypes: Set<HKQuantityType>) -> Observable<Result<[HKQuantityType : HKUnit]>> {
        let observer = Observable<Result<[HKQuantityType : HKUnit]>>()
        preferredUnits(for: quantityTypes, completion: completionToObservable(observer: observer))
        return observer
    }
    
    
    func preferredUnit(forQuantityType type: HKQuantityType) -> Observable<Result<HKUnit>> {
        let types: Set<HKQuantityType> = [type]
        return preferredUnits(forQuantityTypes: types)
            .then {
                guard let unit = $0[type] else {
                    print("Couldn't parse preferred units")
                    return .error(AsyncError.noResults)
                }
                return .success(unit)
            }
    }
}



