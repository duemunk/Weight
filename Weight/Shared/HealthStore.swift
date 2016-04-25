//
//  HealthStore.swift
//  Weight
//
//  Created by Tobias Due Munk on 19/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import Foundation
import HealthKit

typealias AsyncSampleResult = (() throws -> HKSample) -> ()
typealias AsyncSamplesResult = (() throws -> [HKSample]) -> ()
typealias AsyncQuantityTypesUnitResult = (() throws -> [HKQuantityType : HKUnit]) -> ()
typealias AsyncUnitResult = (() throws -> HKUnit) -> ()
typealias AsyncObserverResult = (() throws -> HKObserverQueryCompletionHandler) -> ()

extension HKHealthStore {
    
    /// Convenience to request both share and read authorization for a set of types
    func requestAuthorizationTo(types types: Set<HKSampleType>, result: AsyncEmptyResult) {
        requestAuthorizationTo(shareTypes: types, readTypes: types, result: result)
    }
    
    func requestAuthorizationTo(shareTypes shareTypes: Set<HKSampleType>, readTypes: Set<HKSampleType>, result: AsyncEmptyResult) {
        requestAuthorizationToShareTypes(shareTypes, readTypes: readTypes) { success, error in
            if let error = error {
                print(error)
                result { throw error }
                return
            }
            guard success else {
                print("Couldn't get authorization request")
                result { throw AsyncError.NoSuccessDespiteNoError }
                return
            }
            result { }
        }
    }

    func samples(ofType sampleType: HKSampleType, predicate: NSPredicate? = nil, result: AsyncSamplesResult) {
        let timeSortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [timeSortDescriptor]) { query, results, error in
            if let error = error {
                result { throw error }
                return
            }
            guard let samples = results else {
                result { throw AsyncError.NoResults }
                return
            }
            result { samples }
        }
        executeQuery(query)
    }

    func mostRecentSample(ofType sampleType: HKSampleType, predicate: NSPredicate? = nil, result: AsyncSampleResult) {
        // Since we are interested in retrieving the user's latest sample, we sort the samples in descending order, and set the limit to 1. We are not filtering the data, and so the predicate is set to nil.
        let timeSortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
        let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: 1, sortDescriptors: [timeSortDescriptor]) { query, results, error in
            if let error = error {
                result { throw error }
                return
            }
            guard let sample = results?.first else {
                result { throw AsyncError.NoResults }
                return
            }
            result { sample }
        }
        executeQuery(query)
    }
    
    func preferredUnits(forQuantityTypes quantityTypes: Set<HKQuantityType>, result: AsyncQuantityTypesUnitResult) {
        preferredUnitsForQuantityTypes(quantityTypes) { types, error in
            if let error = error {
                result { throw error }
                return
            }
            result { types }
        }
    }
    
    
    func preferredUnit(forQuantityType type: HKQuantityType, result: AsyncUnitResult){
        let types: Set<HKQuantityType> = [type]
        preferredUnits(forQuantityTypes: types) { _result in
            do {
                let units = try _result()
                guard let unit = units[type] else {
                    print("Couldn't parse preferred units")
                    result { throw AsyncError.NoResults }
                    return
                }
                result { unit }
            } catch {
                print("Couldn't get preferred units")
            }
        }
    }
}