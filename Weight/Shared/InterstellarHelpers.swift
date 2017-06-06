//
//  InterstellarHelpers.swift
//  Weight
//
//  Created by Tobias Due Munk on 16/06/16.
//  Copyright © 2016 Tobias Due Munk. All rights reserved.
//

import Foundation


extension Observable where T: ResultType  {
    typealias U = Result<T.Value>

//    func completion<U>() -> ((t: T.Value, error: ErrorProtocol?) -> Swift.Void) {
//
//
//
//        self.update(.error(NSError(domain: "", code: 0, userInfo: nil)))
//
//        return { (t: T, error: ErrorProtocol?) in
//            if let error = error {
//                self.update(.error(error))
//                return
//            }
//            self.update(.success(t))
//        }
//    }
}

public func completionToObservable<T>(observer: Observable<Result<T>>) -> ((T, Error?) -> Swift.Void) {
    return { (t: T, error: Error?) in
        if let error = error {
            observer.update(.error(error))
            return
        }
        observer.update(.success(t))
    }
}

public func completionToObservable<T, U>(observer: Observable<Result<(T, U)>>) -> ((T, U, Error?) -> Swift.Void) {
    return { (t: T, u: U, error: Error?) in
        if let error = error {
            observer.update(.error(error))
            return
        }
        observer.update(.success((t, u)))
    }
}

public func completionToObservable<T, U ,V>(observer: Observable<Result<(T, U, V)>>) -> ((T, U, V, Error?) -> Swift.Void) {
    return { (t: T, u: U, v: V, error: Error?) in
        if let error = error {
            observer.update(.error(error))
            return
        }
        observer.update(.success((t, u, v)))
    }
}
