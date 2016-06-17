//
//  ViewController.swift
//  Weight
//
//  Created by Tobias Due Munk on 19/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import UIKit
import HealthKit
//import Cartography
import Interstellar


enum QuickActionType: String {
    case UpWeight, SameWeightAsLast, DownWeight, CustomWeight
}
let directWeightKey = "DirectWeightKey"

class ViewController: UIViewController {

    @IBOutlet weak var weightLabel: UILabel!
    @IBOutlet weak var weightDetailLabel: UILabel!
    @IBOutlet weak var weightPickerView: UIPickerView!
    @IBOutlet weak var chartView: Chart!
    @IBOutlet weak var saveButton: UIButton!
    
    let weightFormatter = MassFormatter.weightMediumFormatter()
    let dateFormatter = DateFormatter(dateStyle: .mediumStyle, timeStyle: .shortStyle)
    let dateShortFormatter = DateFormatter(dateStyle: .shortStyle, timeStyle: .shortStyle)
    let dateOnlyFormatter = DateFormatter(dateStyle: .mediumStyle, timeStyle: .noStyle)
    let dateWithOutYearFormatter = DateFormatter(template: "MMMd")
    var pickerWeights: [HKQuantity] {
        return HealthManager.instance.humanWeightOptions()
    }
    private let healthDataChange = NotificationCenter_(name: .HealthDataDidChange)
    private let healthPreferencesChange = NotificationCenter_(name: .HealthPreferencesDidChange)
    private let userActivityChange = NotificationCenter_(name: .UserActivity)
    private let updateUIObservable = Observable<Void>()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.

        updateUIObservable.subscribe { _ in
            // TODO: Throttle/debounce
            self.updateUI()
        }
        healthDataChange.observer?.subscribe { _ in
            self.updateUIObservable.update()
        }
        healthPreferencesChange.observer?.subscribe { _ in
            self.updateUIObservable.update()
        }

        userActivityChange.observer?.subscribe { notification in
            guard let
                userActivity = notification.object as? NSUserActivity,
                userInfo = userActivity.userInfo as? [String: AnyObject],
                temporaryWeightInKg = userInfo["TemporaryWeightKg"] as? Double else {
                return
            }
            let weightType = HealthManager.instance.weightType
            let massUnit = HKUnit.gramUnit(with: .kilo)
            let quantity = HKQuantity(unit: massUnit, doubleValue: temporaryWeightInKg)
            let date = Date()
            let sample = HKQuantitySample(type: weightType, quantity: quantity, start: date, end: date)
            self.updateToWeight(forceWeight: sample)
        }
        
        setupWeightObserver()

        saveButton.tap.subscribe { _ in
            let index = self.weightPickerView.selectedRow(inComponent: 0)
            guard let quantity = self.weightForPickerRow(index) else {
                return
            }
            HealthManager.instance.saveWeight(quantity)
                .then { _ in
                    self.updateQuickActions()
                }
                .error {
                    print($0)
                }
        }
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .lightContent
    }
    
    deinit {
        NotificationCenter.default().removeObserver(self)
    }
    
    func setupWeightObserver() {
        HealthManager.instance.healthStore.observe(ofType: HealthManager.instance.weightType)
            .next { systemCompletionHandler in
                self.updateUIObservable.update()
                systemCompletionHandler()
            }
            .error { print($0) }
    }
   
    func updateUI() {
        updateToWeight()
        updateQuickActions()
        updateChart()
    }

    // MARK: - Weight
    func updateToWeight(forceWeight: HKQuantitySample? = nil) {
        
        let quantitySampleBlock: (HKQuantitySample) -> () = { quantitySample in
            let quantity = quantitySample.quantity
            let massUnit = HealthManager.instance.massUnit
            let doubleValue = quantity.doubleValue(for: massUnit)
            guard let (_, index) = closest(self.pickerWeights.map { $0.doubleValue(for: massUnit) }, toValue: doubleValue) else {
                return
            }
            let massFormatterUnit = HealthManager.instance.massFormatterUnit
            self.weightLabel.text = self.weightFormatter.string(fromValue: doubleValue, unit: massFormatterUnit)
            self.weightDetailLabel.text = self.dateFormatter.string(from: quantitySample.startDate)
            self.weightPickerView.reloadAllComponents()
            self.weightPickerView.selectRow(index, inComponent: 0, animated: false)
        }
        
        if let forceWeight = forceWeight {
            quantitySampleBlock(forceWeight)
            return
        }
        
        HealthManager.instance.getWeight()
            .then { sample in
                Async.main {
                    quantitySampleBlock(sample)
                }
            }
            .error {
                print($0)
                Async.main {
                    self.weightLabel.text = self.weightFormatter.string(fromValue: 0, unit: HealthManager.instance.massFormatterUnit)
                    self.weightDetailLabel.text = "No existing historic data"
                    self.weightPickerView.selectRow(0, inComponent: 0, animated: true)
                }
            }
    }
    
    func weightForPickerRow(_ index: Int) -> HKQuantity? {
        let index = weightPickerView.selectedRow(inComponent: 0)
        guard let quantity = pickerWeights[safe: index] else {
            return nil
        }
        return quantity
    }

    // MARK: - Quick Actions
    func updateQuickActions() {
        HealthManager.instance.getWeights()
            .flatMap(Queue.background)
            .then { quantitySamples in
                let massUnit = HealthManager.instance.massUnit
                let values = quantitySamples.map { $0.quantity.doubleValue(for: massUnit) }

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
                                return self.sameWeightShortcut(for: latestSample)
                            } else if value > 0 {
                                return self.upWeightShortcut(for: doubleValue)
                            }
                            return self.downWeightShortcut(for: doubleValue)
                        }()
                        shortcuts.append(shortcut)
                    }
                    if bestValues.count == 0 {
                        let latestDoubleValue = latestSample.quantity.doubleValue(for: massUnit)
                        shortcuts.append(self.upWeightShortcut(for: latestDoubleValue + increment))
                        shortcuts.append(self.sameWeightShortcut(for: latestSample))
                        shortcuts.append(self.downWeightShortcut(for: latestDoubleValue - increment))
                    }
                    shortcuts.append(self.customWeightShortcut(with: "Other weight"))
                } else {
                    shortcuts.append(self.customWeightShortcut(with: "Add weight"))
                }
                return .success(shortcuts)
            }
            .flatMap(Queue.main)
            .then { shortcuts in
                UIApplication.shared().shortcutItems = shortcuts
            }
    }

    func sameWeightShortcut(for previousSample: HKQuantitySample) -> UIApplicationShortcutItem {
        let massUnit = HealthManager.instance.massUnit
        let formatter = HealthManager.instance.massFormatterUnit
        let doubleValue = previousSample.quantity.doubleValue(for: massUnit)
        let weightString = weightFormatter.string(fromValue: doubleValue, unit: formatter)
        return shortcut(for: .SameWeightAsLast,
                        imageName: "Same",
                        title: weightString,
                        subtitle: "Last: " + self.dateShortFormatter.string(from: previousSample.startDate),
                        value: doubleValue)
    }

    func upWeightShortcut(for doubleValue: Double) -> UIApplicationShortcutItem {
        let formatter = HealthManager.instance.massFormatterUnit
        let weightString = weightFormatter.string(fromValue: doubleValue, unit: formatter)
        return shortcut(for: .UpWeight,
                        imageName: "Up",
                        title: weightString,
                        value: doubleValue)
    }

    func downWeightShortcut(for doubleValue: Double) -> UIApplicationShortcutItem {
        let formatter = HealthManager.instance.massFormatterUnit
        let weightString = weightFormatter.string(fromValue: doubleValue, unit: formatter)
        return shortcut(for: .DownWeight,
                        imageName: "Down",
                        title: weightString,
                        value: doubleValue)
    }

    func customWeightShortcut(with title: String) -> UIApplicationShortcutItem {
        return
            UIApplicationShortcutItem(
            type: QuickActionType.CustomWeight.rawValue,
            localizedTitle: title,
            localizedSubtitle: nil,
            icon: UIApplicationShortcutIcon(templateImageName: "New"),
            userInfo: nil)
    }

    func shortcut(for type: QuickActionType, imageName: String, title: String, subtitle: String? = nil, value: Double) -> UIApplicationShortcutItem {
        return UIApplicationShortcutItem(
            type: type.rawValue,
            localizedTitle: title,
            localizedSubtitle: subtitle,
            icon: UIApplicationShortcutIcon(templateImageName: imageName),
            userInfo: [directWeightKey : value])
    }


    // MARK: - Chart
    func updateChart(_ average: CalendarUnit = .week, range: (unit: CalendarUnit, count: Int) = (.month, 6)) {
        chartView.isUserInteractionEnabled = false
        chartView.gridColor = UIColor.white().withAlphaComponent(0.3)
        chartView.labelColor = UIColor.white() //.colorWithAlphaComponent(0.5)
        chartView.lineWidth = 1.5
        chartView.dotSize = 1.5
        chartView.xLabelsFormatter = { (index, value) in
            (self.dateWithOutYearFormatter ?? self.dateOnlyFormatter)
                .string(from: Date(timeIntervalSince1970: Double(value)))
        }

        HealthManager.instance.getWeights()
            .flatMap(Queue.queue(DispatchQueue.global(attributes: .qosUserInitiated)))
            .then { quantitySamples in
                let massUnit = HealthManager.instance.massUnit

                guard let rangeStart = quantitySamples.last?.startDate.add(range.unit, count: -range.count) else {
                    return .error(NSError(domain: "", code: 0, userInfo: nil))
                }
                let rangedSamples = quantitySamples.filter { $0.startDate.isAfter(rangeStart) }

                let values: Array<(x: Double, y: Double)> = rangedSamples.map { ($0.startDate.timeIntervalSince1970, $0.quantity.doubleValue(for: massUnit)) }

                let individualSeries = ChartSeries(data: values)
                individualSeries.color = UIColor.white()//.colorWithAlphaComponent(0.5)
                individualSeries.line = false
                individualSeries.dots = true

                let valuesWeekly: Array<(x: Double, y: Double)>? = rangedSamples
                    .averages(average)?
                    .map { ($0.endDate.timeIntervalSince1970, $0.quantity.doubleValue(for: massUnit)) }
                let runningAverageSeries: ChartSeries? = valuesWeekly != nil ? ChartSeries(data: valuesWeekly!) : nil
                runningAverageSeries?.color = UIColor.white().withAlphaComponent(0.6)
                runningAverageSeries?.line = true

                return .success(individualSeries, runningAverageSeries, rangeStart, range)
            }
            .flatMap(Queue.main)
            .then { (individualSeries: ChartSeries, runningAverageSeries: ChartSeries?, rangeStart: Date, range: (unit: CalendarUnit, count: Int)) in
                self.chartView.removeSeries()
                self.chartView.addSeries(individualSeries)
                if let runningAverageSeries = runningAverageSeries {
                    self.chartView.addSeries(runningAverageSeries)
                }
                self.chartView.xLabels = stride(from: rangeStart.timeIntervalSince1970, through: Date().timeIntervalSince1970, by: range.unit.timeInterval)
                    .map(Float.init)
            }
    }
}

extension ViewController: UIPickerViewDataSource {
    
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerWeights.count
    }
}

extension ViewController: UIPickerViewDelegate {
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> AttributedString? {
        let quantity = pickerWeights[safe: row]
        let massUnit = HealthManager.instance.massUnit
        let massFormatterUnit = HealthManager.instance.massFormatterUnit
        let weight = quantity?.doubleValue(for: massUnit) ?? 0
        let title = weightFormatter.string(fromValue: weight, unit: massFormatterUnit)
        let attributedTitle = AttributedString(string: title, attributes: [NSForegroundColorAttributeName : UIColor.white()])
        return attributedTitle
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        guard let tempWeight = weightForPickerRow(row) else {
            return
        }
        let activityDictionary: [NSObject: AnyObject] = ["TemporaryWeight" : tempWeight]
        if let userActivity = self.userActivity {
            userActivity.addUserInfoEntries(from: activityDictionary)
            self.userActivity?.needsSave = true
        } else {
            let activityType = "dk.developmunk.weight.updatingWeight"
            let activityTitle = "Updating to weight \(tempWeight)"
            let activity = NSUserActivity(activityType: activityType)
            activity.title = activityTitle
            activity.userInfo = activityDictionary
            self.userActivity = activity
            self.userActivity?.becomeCurrent()
        }
    }
}
