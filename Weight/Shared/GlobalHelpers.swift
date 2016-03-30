//
//  GlobalHelpers.swift
//  Weight
//
//  Created by Tobias Due Munk on 22/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import Foundation

func closest(values: [Double], toValue value: Double) -> (closestValue: Double, index: Int)? {
    let diffs = values.map { abs($0 - value) }
    guard let someDiffValue = diffs.first else {
        return nil
    }
    let minimumDiff = diffs.reduce(someDiffValue) { min($0, $1) }
    guard let index = diffs.indexOf(minimumDiff) else {
        return nil
    }
    return (values[index], index)
}