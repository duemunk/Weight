//
//  Observable+Result.swift
//  Interstellar
//
//  Created by Jens Ravens on 11/12/15.
//  Copyright © 2015 nerdgeschoss GmbH. All rights reserved.
//

public extension Observable where T : ResultType {
    @discardableResult
    public func then<U>(_ transform: (T.Value) -> Result<U>) -> Observable<Result<U>> {
        return map { $0.result.flatMap(transform) }
    }
    
    @discardableResult
    public func then<U>(_ transform: (T.Value) -> U) -> Observable<Result<U>> {
        return map { $0.result.map(transform) }
    }
    
    @discardableResult
    public func then<U>(_ transform: (T.Value) throws -> U) -> Observable<Result<U>> {
        return map { $0.result.flatMap(transform) }
    }
    
    @discardableResult
    public func next(_ block: (T.Value) -> Void) -> Observable<T> {
        subscribe { result in
            if let value = result.value {
                block(value)
            }
        }
        return self
    }
    
    @discardableResult
    public func error(_ block: (Error) -> Void) -> Observable<T> {
        subscribe { result in
            if let error = result.error {
                block(error)
            }
        }
        return self
    }
    
    public func peekValue() -> T.Value? {
        return peek()?.value
    }
}
