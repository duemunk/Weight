//
//  ErrorHandling.swift
//  Weight
//
//  Created by Tobias Due Munk on 21/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import Foundation

enum AsyncError: ErrorProtocol {
    case noResults
    case noSuccessDespiteNoError
}

typealias AsyncEmptyResult = (() throws -> ()) -> ()

func optionalResult(_ asyncResult: () throws -> ()) {
    do {
        try asyncResult()
    } catch {
        print(error)
    }
}

func optionalResult<T>(_ asyncResult: () throws -> T) -> T? {
    do {
        let someAsyncResult = try asyncResult()
        return someAsyncResult
    } catch {
        print(error)
    }
    return nil
}

