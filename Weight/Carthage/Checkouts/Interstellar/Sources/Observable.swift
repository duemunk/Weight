//
//  Observable.swift
//  Interstellar
//
//  Created by Jens Ravens on 10/12/15.
//  Copyright © 2015 nerdgeschoss GmbH. All rights reserved.
//

import Foundation

public struct ObservingOptions: OptionSet {
    public let rawValue: Int
    public init(rawValue: Int) { self.rawValue = rawValue }
    
    public static let noInitialValue = ObservingOptions(rawValue: 1)
    public static let once = ObservingOptions(rawValue: 2)
}

public final class Observable<T> {
    private typealias Observer = (T)->Void
    private typealias ObserverTokenType = ObserverToken<T>
    private var observers = [ObserverTokenType: Observer]()
    private var lastValue: T?
    public let options: ObservingOptions
    private let mutex = Mutex()
    
    public init(options: ObservingOptions = []) {
        self.options = options
    }
    
    public init(_ value: T, options: ObservingOptions = []) {
        self.options = options
        if !options.contains(.noInitialValue){
            lastValue = value
        }
    }
    
    @discardableResult
    public func subscribe(_ observer: (T) -> Void) -> ObserverToken<T> {
        var token: ObserverToken<T>!
        mutex.lock {
            let newHashValue = nextTokenHash()
            token = ObserverToken(hashValue: newHashValue, observable: self)
            if !(options.contains(.once) && lastValue != nil) {
                observers[token] = observer
            }
            if let value = lastValue, !options.contains(.noInitialValue) {
                observer(value)
            }
        }
        return token
    }
    
    public func update(_ value: T) {
        mutex.lock {
            if !options.contains(.noInitialValue) {
                lastValue = value
            }
            for observe in observers.values {
                observe(value)
            }
            if options.contains(.once) {
                observers.removeAll()
            }
        }
    }
    
    public func peek() -> T? {
        return lastValue
    }
    
    private func nextTokenHash() -> Int {
        return (observers.keys.map({$0.hashValue}).max() ?? -1) + 1
    }

    private func unsubscribe(_ token: ObserverToken<T>) {
        mutex.lock {
            observers[token] = nil
        }
    }
}

public final class ObserverToken<T>: Hashable {
    public let hashValue: Int
    private weak var observable: Observable<T>?

    // Private to avoid instantiation outside this file.
    private init (hashValue: Int, observable: Observable<T>?) {
        self.hashValue = hashValue
        self.observable = observable
    }

    public func unsubscribe() {
        observable?.unsubscribe(self)
    }
}

public func ==<T>(lhs: ObserverToken<T>, rhs: ObserverToken<T>) -> Bool {
    return lhs.hashValue == rhs.hashValue
}

extension Observable {
    @discardableResult
    public func map<U>(_ transform: (T) -> U) -> Observable<U> {
        let observable = Observable<U>(options: options)
        subscribe { observable.update(transform($0)) }
        return observable
    }
    
    @discardableResult
    public func map<U>(_ transform: (T) throws -> U) -> Observable<Result<U>> {
        let observable = Observable<Result<U>>(options: options)
        subscribe { value in
            observable.update(Result(block: { return try transform(value) }))
        }
        return observable
    }
    
    @discardableResult
    public func flatMap<U>(_ transform: (T) -> Observable<U>) -> Observable<U> {
        let observable = Observable<U>(options: options)
        subscribe { transform($0).subscribe(observable.update) }
        return observable
    }
}
