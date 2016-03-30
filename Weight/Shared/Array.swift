//
//  Array.swift
//  Weight
//
//  Created by Tobias Due Munk on 28/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

extension Array {
    subscript (safe index: Int) -> Element? {
        return indices ~= index ? self[index] : nil
    }
}
