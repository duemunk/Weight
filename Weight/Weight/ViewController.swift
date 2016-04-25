//
//  ViewController.swift
//  Weight
//
//  Created by Tobias Due Munk on 19/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import UIKit
import HealthKit
import Cartography



enum QuickActionType: String {
    case UpWeight, SameWeightAsLast, DownWeight, CustomWeight
}
let directWeightKey = "DirectWeightKey"

class ViewController: UIViewController {

    @IBOutlet weak var weightLabel: UILabel!
    @IBOutlet weak var weightDetailLabel: UILabel!
    @IBOutlet weak var weightPickerView: UIPickerView!
    @IBOutlet weak var chartView: Chart!
    
    let weightFormatter = NSMassFormatter.weightMediumFormatter()
    let dateFormatter = NSDateFormatter.build(dateStyle: .MediumStyle, timeStyle: .ShortStyle)
    let dateShortFormatter = NSDateFormatter.build(dateStyle: .ShortStyle, timeStyle: .ShortStyle)
    let dateOnlyFormatter = NSDateFormatter.build(dateStyle: .MediumStyle, timeStyle: .NoStyle)
    var pickerWeights: [HKQuantity] {
        return HealthManager.instance.humanWeightOptions()
    }
    
    @IBAction func didTapSaveButton(sender: AnyObject) {
        let index = weightPickerView.selectedRowInComponent(0)
        guard let quantity = weightForPickerRow(index) else {
            return
        }
        HealthManager.instance.saveWeight(quantity) { result in
            do {
                try result()
                self.updateQuickActions()
            } catch {
                print(error)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        NotificationCenter.observe(HealthDataDidChangeNotification) { [weak self] notification in
            self?.updateUI()
        }
        NotificationCenter.observe(HealthPreferencesDidChangeNotification) { [weak self] notification in
            self?.updateUI()
        }
        NotificationCenter.observe(UserActivityNotification) { [weak self] notification in
            guard let userActivity = notification.object as? NSUserActivity else {
                return
            }
            guard let userInfo = userActivity.userInfo as? [String: AnyObject] else {
                return
            }
            guard let temporaryWeightInKg = userInfo["TemporaryWeightKg"] as? Double else {
                return
            }
            let weightType = HealthManager.instance.weightType
            let massUnit = HKUnit.gramUnitWithMetricPrefix(.Kilo)
            let quantity = HKQuantity(unit: massUnit, doubleValue: temporaryWeightInKg)
            let date = NSDate()
            let sample = HKQuantitySample(type: weightType, quantity: quantity, startDate: date, endDate: date)
            self?.updateToWeight(forceWeight: sample)
        }
        
        setupWeightObserver()
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
    
    deinit {
        NotificationCenter.unobserve(self)
    }
    
    func setupWeightObserver() {
        HealthManager.instance.healthStore.observe(ofType: HealthManager.instance.weightType) { result in
            do {
                let systemCompletionHandler = try result()
                self.updateUI()
                systemCompletionHandler()
            } catch {
                print(error)
            }
        }
    }
   
    func updateUI() {
        updateToWeight()
        updateQuickActions()
        updateChart()
    }

    // MARK: - Weight
    func updateToWeight(forceWeight forceWeight: HKQuantitySample? = nil) {
        
        let quantitySampleBlock: (HKQuantitySample, (() -> ())?) -> () = { quantitySample, completion in
            let quantity = quantitySample.quantity
            let massUnit = HealthManager.instance.massUnit
            let doubleValue = quantity.doubleValueForUnit(massUnit)
            guard let (_, index) = closest(self.pickerWeights.map { $0.doubleValueForUnit(massUnit) }, toValue: doubleValue) else {
                return
            }
            let massFormatterUnit = HealthManager.instance.massFormatterUnit
            self.weightLabel.text = self.weightFormatter.stringFromValue(doubleValue, unit: massFormatterUnit)
            self.weightDetailLabel.text = self.dateFormatter.stringFromDate(quantitySample.startDate)
            self.weightPickerView.reloadAllComponents()
            self.weightPickerView.selectRow(index, inComponent: 0, animated: false)
        }
        
        if let forceWeight = forceWeight {
            quantitySampleBlock(forceWeight, nil)
            return
        }
        
        HealthManager.instance.getWeight { result in
            guard let quantitySample = optionalResult(result) else {
                Async.main {
                    self.weightLabel.text = self.weightFormatter.stringFromValue(0, unit: HealthManager.instance.massFormatterUnit)
                    self.weightDetailLabel.text = "No existing historic data"
                    self.weightPickerView.selectRow(0, inComponent: 0, animated: true)
                }
                return
            }
            Async.main {
                quantitySampleBlock(quantitySample, nil)
            }
        }
    }
    
    func weightForPickerRow(index: Int) -> HKQuantity? {
        let index = weightPickerView.selectedRowInComponent(0)
        guard let quantity = pickerWeights[safe: index] else {
            return nil
        }
        return quantity
    }

    // MARK: - Quick Actions
    func updateQuickActions() {
        HealthManager.instance.getWeights { result in
            guard let quantitySamples = optionalResult(result) else {
                return
            }
            Async.userInitiated {
                let massUnit = HealthManager.instance.massUnit
                let values = quantitySamples.map { $0.quantity.doubleValueForUnit(massUnit) }

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
                let sortedValues = aggregate.sort { $0.1 > $1.1 }.map { $0.0 }
                var shortcuts = [UIApplicationShortcutItem]()
                // Take 3 most usual changes to weight
                let bestValues = sortedValues[0..<min(3, sortedValues.count)]
                if let latestSample = quantitySamples.last {
                    for value in bestValues {
                        let doubleValue = Double(value) * increment + latestSample.quantity.doubleValueForUnit(massUnit)
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
                        let latestDoubleValue = latestSample.quantity.doubleValueForUnit(massUnit)
                        shortcuts.append(self.upWeightShortcut(for: latestDoubleValue + increment))
                        shortcuts.append(self.sameWeightShortcut(for: latestSample))
                        shortcuts.append(self.downWeightShortcut(for: latestDoubleValue - increment))
                    }
                    shortcuts.append(self.customWeightShortcut(with: "Other weight"))
                } else {
                    shortcuts.append(self.customWeightShortcut(with: "Add weight"))
                }

                Async.main {
                    UIApplication.sharedApplication().shortcutItems = shortcuts
                }
            }
        }
    }

    func sameWeightShortcut(for previousSample: HKQuantitySample) -> UIApplicationShortcutItem {
        let massUnit = HealthManager.instance.massUnit
        let formatter = HealthManager.instance.massFormatterUnit
        let doubleValue = previousSample.quantity.doubleValueForUnit(massUnit)
        let weightString = weightFormatter.stringFromValue(doubleValue, unit: formatter)
        return shortcut(for: .SameWeightAsLast,
                        imageName: "Same",
                        title: weightString,
                        subtitle: "Last: " + self.dateShortFormatter.stringFromDate(previousSample.startDate),
                        value: doubleValue)
    }

    func upWeightShortcut(for doubleValue: Double) -> UIApplicationShortcutItem {
        let formatter = HealthManager.instance.massFormatterUnit
        let weightString = weightFormatter.stringFromValue(doubleValue, unit: formatter)
        return shortcut(for: .UpWeight,
                        imageName: "Up",
                        title: weightString,
                        value: doubleValue)
    }

    func downWeightShortcut(for doubleValue: Double) -> UIApplicationShortcutItem {
        let formatter = HealthManager.instance.massFormatterUnit
        let weightString = weightFormatter.stringFromValue(doubleValue, unit: formatter)
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
    func updateChart(average: CalendarUnit = .Week, range: (unit: CalendarUnit, count: Int) = (.Month, 6)) {
        chartView.userInteractionEnabled = false
        chartView.gridColor = UIColor.whiteColor().colorWithAlphaComponent(0.3)
        chartView.labelColor = UIColor.whiteColor() //.colorWithAlphaComponent(0.5)
        chartView.lineWidth = 1.5
        chartView.dotSize = 1.5
        chartView.xLabelsFormatter = {
            self.dateOnlyFormatter.stringFromDate(NSDate(timeIntervalSince1970: Double($1)))
        }

        HealthManager.instance.getWeights { result in
            guard let quantitySamples = optionalResult(result) else {
                return
            }
            Async.userInitiated {
                let massUnit = HealthManager.instance.massUnit

                guard let rangeStart = quantitySamples.last?.startDate.add(range.unit, count: -range.count) else { return }
                let rangedSamples = quantitySamples.filter { $0.startDate.isAfter(rangeStart) }

                let values: Array<(x: Double, y: Double)> = rangedSamples.map { ($0.startDate.timeIntervalSince1970, $0.quantity.doubleValueForUnit(massUnit)) }

                let individualSeries = ChartSeries(data: values)
                individualSeries.color = UIColor.whiteColor()//.colorWithAlphaComponent(0.5)
                individualSeries.line = false
                individualSeries.dots = true

                let valuesWeekly: Array<(x: Double, y: Double)>? = rangedSamples
                    .averages(average)?
                    .map { ($0.endDate.timeIntervalSince1970, $0.quantity.doubleValueForUnit(massUnit)) }
                let runningAverageSeries: ChartSeries? = valuesWeekly != nil ? ChartSeries(data: valuesWeekly!) : nil
                runningAverageSeries?.color = UIColor.whiteColor().colorWithAlphaComponent(0.6)
                runningAverageSeries?.line = true

                Async.main {
                    self.chartView.removeSeries()
                    self.chartView.addSeries(individualSeries)
                    if let runningAverageSeries = runningAverageSeries {
                        self.chartView.addSeries(runningAverageSeries)
                    }

                    self.chartView.xLabels = rangeStart.timeIntervalSince1970
                        .stride(through: NSDate().timeIntervalSince1970, by: range.unit.timeInterval)
                        .map { Float($0) }
                }

                // i-schuetz/SwiftCharts

                // ios-charts
//                var index = 0
//                let yValues = values.map { ChartDataEntry(value: $0, xIndex: index++) }
//                let set = LineChartDataSet(yVals: yValues, label: "Weight")
//
//                let lineChartData = LineChartData(xVals: xValues, dataSets: [set])
//
////                set.colors = [UIColor.whiteColor()]
//                set.colors = ChartColorTemplates.joyful()
//                set.lineWidth = 4
////                set.drawCubicEnabled = true
//
//                Async.main {
//                    self.lineChartView.data = lineChartData
//                }
            }
        }


    }
}

extension ViewController: UIPickerViewDataSource {
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return pickerWeights.count
    }
}

extension ViewController: UIPickerViewDelegate {
    
    func pickerView(pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let quantity = pickerWeights[safe: row]
        let massUnit = HealthManager.instance.massUnit
        let massFormatterUnit = HealthManager.instance.massFormatterUnit
        let weight = quantity?.doubleValueForUnit(massUnit) ?? 0
        let title = weightFormatter.stringFromValue(weight, unit: massFormatterUnit)
        let attributedTitle = NSAttributedString(string: title, attributes: [NSForegroundColorAttributeName : UIColor.whiteColor()])
        return attributedTitle
    }
    
    func pickerView(pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        guard let tempWeight = weightForPickerRow(row) else {
            return
        }
        let activityDictionary: [NSObject: AnyObject] = ["TemporaryWeight" : tempWeight]
        if let userActivity = self.userActivity {
            userActivity.addUserInfoEntriesFromDictionary(activityDictionary)
            self.userActivity?.needsSave
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
