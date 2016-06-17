//
//  InterstellarHelpers.swift
//  Weight
//
//  Created by Tobias Due Munk on 16/06/16.
//  Copyright © 2016 Tobias Due Munk. All rights reserved.
//

import Foundation
import Interstellar


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

public func completionToObservable<T>(observer: Observable<Result<T>>) -> ((t: T, e: ErrorProtocol?) -> Swift.Void) {
    return { (t: T, error: ErrorProtocol?) in
        if let error = error {
            observer.update(.error(error))
            return
        }
        observer.update(.success(t))
    }
}

public func completionToObservable<T, U>(observer: Observable<Result<(T, U)>>) -> ((t: T, u: U, e: ErrorProtocol?) -> Swift.Void) {
    return { (t: T, u: U, error: ErrorProtocol?) in
        if let error = error {
            observer.update(.error(error))
            return
        }
        observer.update(.success(t, u))
    }
}

public func completionToObservable<T, U ,V>(observer: Observable<Result<(T, U, V)>>) -> ((t: T, u: U, v: V, e: ErrorProtocol?) -> Swift.Void) {
    return { (t: T, u: U, v: V, error: ErrorProtocol?) in
        if let error = error {
            observer.update(.error(error))
            return
        }
        observer.update(.success(t, u, v))
    }
}
