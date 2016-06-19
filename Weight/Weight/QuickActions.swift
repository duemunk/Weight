//
//  QuickActions.swift
//  Weight
//
//  Created by Tobias Due Munk on 19/06/16.
//  Copyright © 2016 Tobias Due Munk. All rights reserved.
//

import UIKit
import Interstellar
import HealthKit


enum QuickActionsHelper {

    static func update(with quantitySamples: [HKQuantitySample], weightFormatter: MassFormatter, dateFormatter: DateFormatter) -> [UIApplicationShortcutItem] {
        let massUnit = HealthManager.instance.massUnit
        let values = quantitySamples
            .map { $0.quantity.doubleValue(for: massUnit) }

        let increment = 1 / Double(HealthManager.instance.humanWeightUnitDivision())

        var previousValue = values.first ?? 0
        var aggregate: [Int: Int] = [:]
        for value in values {
            let change = value - previousValue
            previousValue = value
            let index = Int(round(change / increment))
            aggregate[index] = {
                if let current = aggregate[index] {
                    return current + 1
                } else {
                    return 1
                }
            }()
        }
        let sortedValues = aggregate.sorted { $0.1 > $1.1 }.map { $0.0 }
        var shortcuts = [UIApplicationShortcutItem]()
        // Take 3 most usual changes to weight
        let bestValues = sortedValues[0..<min(3, sortedValues.count)]
        if let latestSample = quantitySamples.last {
            for value in bestValues {
                let doubleValue = Double(value) * increment + latestSample.quantity.doubleValue(for: massUnit)
                let shortcut: UIApplicationShortcutItem = {
                    if value == 0 {
                        return self.sameWeightShortcut(for: latestSample, weightFormatter: weightFormatter, dateFormatter: dateFormatter)
                    } else if value > 0 {
                        return self.upWeightShortcut(for: doubleValue, weightFormatter: weightFormatter)
                    }
                    return self.downWeightShortcut(for: doubleValue, weightFormatter: weightFormatter)
                }()
                shortcuts.append(shortcut)
            }
            if bestValues.count == 0 {
                let latestDoubleValue = latestSample.quantity.doubleValue(for: massUnit)
                shortcuts.append(self.upWeightShortcut(for: latestDoubleValue + increment, weightFormatter: weightFormatter))
                shortcuts.append(self.sameWeightShortcut(for: latestSample, weightFormatter: weightFormatter, dateFormatter: dateFormatter))
                shortcuts.append(self.downWeightShortcut(for: latestDoubleValue - increment, weightFormatter: weightFormatter))
            }
            shortcuts.append(self.customWeightShortcut(with: "Other weight"))
        } else {
            shortcuts.append(self.customWeightShortcut(with: "Add weight"))
        }
        return shortcuts
    }
}

private extension QuickActionsHelper {

    static func sameWeightShortcut(for previousSample: HKQuantitySample, weightFormatter: MassFormatter, dateFormatter: DateFormatter) -> UIApplicationShortcutItem {
        let massUnit = HealthManager.instance.massUnit
        let formatter = HealthManager.instance.massFormatterUnit
        let doubleValue = previousSample.quantity.doubleValue(for: massUnit)
        let weightString = weightFormatter.string(fromValue: doubleValue, unit: formatter)
        return shortcut(for: .SameWeightAsLast,
                        imageName: "Same",
                        title: weightString,
                        subtitle: "Last: " + dateFormatter.string(from: previousSample.startDate),
                        value: doubleValue)
    }

    static func upWeightShortcut(for doubleValue: Double, weightFormatter: MassFormatter) -> UIApplicationShortcutItem {
        let formatter = HealthManager.instance.massFormatterUnit
        let weightString = weightFormatter.string(fromValue: doubleValue, unit: formatter)
        return shortcut(for: .UpWeight,
                        imageName: "Up",
                        title: weightString,
                        value: doubleValue)
    }

    static func downWeightShortcut(for doubleValue: Double, weightFormatter: MassFormatter) -> UIApplicationShortcutItem {
        let formatter = HealthManager.instance.massFormatterUnit
        let weightString = weightFormatter.string(fromValue: doubleValue, unit: formatter)
        return shortcut(for: .DownWeight,
                        imageName: "Down",
                        title: weightString,
                        value: doubleValue)
    }

    static func customWeightShortcut(with title: String) -> UIApplicationShortcutItem {
        return
            UIApplicationShortcutItem(
                type: QuickActionType.CustomWeight.rawValue,
                localizedTitle: title,
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(templateImageName: "New"),
                userInfo: nil)
    }

    static func shortcut(for type: QuickActionType, imageName: String, title: String, subtitle: String? = nil, value: Double) -> UIApplicationShortcutItem {
        return UIApplicationShortcutItem(
            type: type.rawValue,
            localizedTitle: title,
            localizedSubtitle: subtitle,
            icon: UIApplicationShortcutIcon(templateImageName: imageName),
            userInfo: [directWeightKey : value])
    }
}
