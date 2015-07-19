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
typealias AsyncQuantityTypeUnitResult = (() throws -> [HKQuantityType : HKUnit]) -> ()
typealias AsyncObserverResult = (() throws -> HKObserverQueryCompletionHandler) -> ()

extension HKHealthStore {
    
    enum Error: ErrorType {
        case NoResults
        case NoSuccessDespiteNoError
    }
    
    func mostRecentSample(ofType sampleType: HKSampleType, predicate: NSPredicate? = nil, result: AsyncSampleResult) {
        // Since we are interested in retrieving the user's latest sample, we sort the samples in descending order, and set the limit to 1. We are not filtering the data, and so the predicate is set to nil.
        let timeSortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        let query = HKSampleQuery(sampleType: sampleType, predicate: predicate, limit: 1, sortDescriptors: [timeSortDescriptor]) { query, results, error in
            if let error = error {
                result { throw error }
                return
            }
            guard let sample = results?.first else {
                result { throw Error.NoResults }
                return
            }
            result { sample }
        }
        executeQuery(query)
    }
    
    func observe(ofType sampleType: HKSampleType, predicate: NSPredicate? = nil, result: AsyncObserverResult) {
        let observerQuery = HKObserverQuery(sampleType: sampleType, predicate: predicate) { observerQuery, observerQueryCompletionHandler, error in
            if let error = error {
                result { throw error }
                return
            }
            result { observerQueryCompletionHandler }
        }
        executeQuery(observerQuery)
        enableBackgroundDeliveryForType(sampleType, frequency: .Immediate) { success, error in
            if let error = error {
                result { throw error }
                return
            }
            guard success else {
                result { throw Error.NoSuccessDespiteNoError }
                return
            }
            // TODO
            print("Enabled background delivery for \(sampleType)")
        }
    }
    
    func preferredUnits(forQuantityTypes quantityTypes: Set<HKQuantityType>, result: AsyncQuantityTypeUnitResult) {
        preferredUnitsForQuantityTypes(quantityTypes) { types, error in
            if let error = error {
                result { throw error }
                return
            }
            result { types }
        }
    }
}