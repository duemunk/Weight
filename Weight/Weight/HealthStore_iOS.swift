//
//  HealthStore_iOS.swift
//  Weight
//
//  Created by Tobias Due Munk on 21/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import Foundation
import HealthKit
import Interstellar


extension HKHealthStore {
    
    func observe(ofType sampleType: HKSampleType, predicate: Predicate? = nil) -> Observable<Result<HKObserverQueryCompletionHandler>> {
        let observer = Observable<Result<(HKObserverQuery, HKObserverQueryCompletionHandler)>>()
        let observerQuery = HKObserverQuery(sampleType: sampleType, predicate: predicate, updateHandler: completionToObservable(observer: observer))
        execute(observerQuery)

        let backgroundObserver = Observable<Result<Bool>>()
        enableBackgroundDelivery(for: sampleType, frequency: .immediate, withCompletion: completionToObservable(observer: backgroundObserver))
        backgroundObserver
            .next { success in
                guard success else {
                    observer.update(.error(AsyncError.noSuccessDespiteNoError))
                    return
                }
                print("Enabled background delivery for \(sampleType)")
            }
            .error {
                observer.update(.error($0))
            }

        return observer
            .then {
                return .success($0.1)
            }
    }
}
