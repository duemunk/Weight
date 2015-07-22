//
//  HealthStore_iOS.swift
//  Weight
//
//  Created by Tobias Due Munk on 21/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import Foundation
import HealthKit

extension HKHealthStore {
    
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
                result { throw AsyncError.NoSuccessDespiteNoError }
                return
            }
            // TODO
            print("Enabled background delivery for \(sampleType)")
        }
    }
}
