//
//  ViewController.swift
//  Weight
//
//  Created by Tobias Due Munk on 19/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import UIKit
import HealthKit


enum QuickActionType: String {
    case UpWeight, SameWeightAsLast, DownWeight, CustomWeight
}
let directWeightKey = "DirectWeightKey"

class ViewController: UIViewController {

    private enum UpdateType {
        case source, `default`
    }

    @IBOutlet weak var weightLabel: UILabel!
    @IBOutlet weak var weightDetailLabel: UILabel!
    @IBOutlet weak var weightPickerView: UIPickerView!
    @IBOutlet weak var chartView: Chart!
    @IBOutlet weak var saveButton: UIButton!
    
    let weightFormatter = MassFormatter.weightMediumFormatter()

    private let dateLastWeightFormatter = DateFormatter(template: "jjmmMMMd") ?? DateFormatter(dateStyle: .medium, timeStyle: .short)
    private let dateQuickActionFormatter = DateFormatter(template: "jjmmMMMd") ?? DateFormatter(dateStyle: .medium, timeStyle: .short)
    private let dateChartXLabelFormatter = DateFormatter(template: "dMMM") ?? DateFormatter(dateStyle: .medium, timeStyle: .none)
    private let chartYLabelFormatter = NumberFormatter()
    var pickerWeights: [HealthManager.WeightPoint] {
        return HealthManager.instance.humanWeightOptions()
    }
    private let healthDataChange = NotificationCenter_(name: .HealthDataDidChange)
    private let healthPreferencesChange = NotificationCenter_(name: .HealthPreferencesDidChange)
    private let userActivityChange = NotificationCenter_(name: .UserActivity)
    private let updateUIObservable = Observable<UpdateType>()

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        updateUIObservable
            .flatMap(Queue.main)
            .debounce(0.05)
            .subscribe { self.updateUI(type: $0) }

        healthDataChange.observer.subscribe { _ in
            self.updateUIObservable.update(.source)
        }
        healthPreferencesChange.observer.subscribe { _ in
            self.updateUIObservable.update(.default)
        }

        WatchConnection.instance.newWeightObserver.subscribe { weight in
            WeightsLocalStore.instance.lastWeight = weight
            self.updateUIObservable.update(.default)
        }

        userActivityChange.observer.map { notification in
            guard let userActivity = notification.object as? NSUserActivity,
                let userInfo = userActivity.userInfo as? [String: AnyObject],
                let temporaryWeight = Weight.temporaryNewWeight(from: userInfo) else {
                return
            }
            self.updateToWeight(request: .forceWeight(weight: temporaryWeight))
        }

        saveButton.tap.subscribe { _ in
            let index = self.weightPickerView.selectedRow(inComponent: 0)
            guard let weightPoint = self.weightForPickerRow(index) else {
                return
            }
            let weight = Weight(kg: weightPoint.kg, date: Date())
            HealthManager.instance.save(weight: weight)
                .next { WatchConnection.instance.send(new: $0) }
                .error { print($0) }
        }

        setupWeightObserver()

        setupChart()
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func setupWeightObserver() {
        HealthManager.instance.healthStore.observe(ofType: HealthManager.instance.weightType)
            .then { systemCompletionHandler in
                self.updateUIObservable.update(.source)
                systemCompletionHandler()
            }
            .error { print($0) }
    }

    private func updateUI(type: UpdateType) {
        self.updateToWeight(request: .source(type: type))
        self.updateQuickActions()
        self.updateChart(average: .month, range: Chart.Range(unit: .year, count: 10, softStart: true))
    }

    // MARK: - Weight
    private enum WeightRequest {
        case forceWeight(weight: Weight)
        case source(type: UpdateType)
    }

    private func updateToWeight(request: WeightRequest) {

        let quantitySampleBlock: (Weight) -> () = { weight in
            Async.main {
                assert(Thread.isMainThread)
                let massUnit = HealthManager.instance.massUnit
                guard let (_, index) = closest(self.pickerWeights.map { $0.kg }, toValue: weight.kg) else {
                    return
                }
                let weightViewModel = WeightViewModel(weight: weight, massUnit: massUnit)
                self.weightLabel.text = self.weightFormatter.string(fromValue: weightViewModel.userValue(), unit: weightViewModel.formatterUnit)
                self.weightDetailLabel.text = self.dateLastWeightFormatter.string(from: weightViewModel.weight.date)
                self.weightPickerView.reloadAllComponents()
                self.weightPickerView.selectRow(index, inComponent: 0, animated: false)
            }
        }

        switch request {
        case .forceWeight(let weight):
            quantitySampleBlock(weight)
        case .source(let type):
            HealthManager.instance.getWeight(forceSource: .source == type)
                .flatMap(Queue.main)
                .next(quantitySampleBlock)
                .error {
                    print($0)
                    assert(Thread.isMainThread)
                    self.weightLabel.text = self.weightFormatter.string(fromValue: 0, unit: HealthManager.instance.massFormatterUnit)
                    self.weightDetailLabel.text = "No existing historic data"
                    self.weightPickerView.selectRow(0, inComponent: 0, animated: true)
            }
        }
    }
    
    func weightForPickerRow(_ index: Int) -> HealthManager.WeightPoint? {
        let index = weightPickerView.selectedRow(inComponent: 0)
        guard let weight = pickerWeights[safe: index] else {
            return nil
        }
        return weight
    }

    // MARK: - Quick Actions
    func updateQuickActions() {
        HealthManager.instance.getWeights()
            .flatMap(Queue.background)
            .then {
                QuickActionsHelper.update(with: $0, weightFormatter: self.weightFormatter, dateFormatter: self.dateQuickActionFormatter)
            }
            .flatMap(Queue.main)
            .next { shortcuts in
                Async.main {
                    assert(Thread.isMainThread)
                    UIApplication.shared.shortcutItems = shortcuts
                }
            }
    }


    // MARK: - Chart
    func setupChart() {
        chartView.isUserInteractionEnabled = false
        chartView.gridColor = .lightGray
        chartView.labelColor = .lightGray
        chartView.lineWidth = 2
        chartView.gridLineWidth = 1
        chartView.axesLineWidth = 1
        chartView.dotSize = 3
        chartView.labelFont = UIFont.boldSystemFont(ofSize: 12)
        chartView.xLabelsFormatter = { (index, value) in
            self.dateChartXLabelFormatter
                .string(from: Date(timeIntervalSince1970: Double(value)))
        }
        chartView.yLabelsFormatter = chartView.weightLabelsFormatter(numberFormatter: chartYLabelFormatter)
    }

    func updateChart(average: CalendarUnit = .week, range: Chart.Range) {
        HealthManager.instance.getWeights()
            .then {
                self.chartView.update(with: $0, dotColor: .black, lineColor: UIColor.black.withAlphaComponent(0.3), average: average, range: range)
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
    
    func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
        let weightPoint = pickerWeights[row]
        let weight = Weight(kg: weightPoint.kg, date: Date())
        let weightViewModel = WeightViewModel(weight: weight, massUnit: HealthManager.instance.massUnit)

        let title = weightFormatter.string(fromValue: weightViewModel.userValue(), unit: weightViewModel.formatterUnit)
        let attributedTitle = NSAttributedString(string: title, attributes: [
            NSForegroundColorAttributeName : UIColor.black,
            NSFontAttributeName : UIFont.boldSystemFont(ofSize: 27)
            ])
        return attributedTitle
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        guard let tempWeight = weightForPickerRow(row) else {
            return
        }
        let activityDictionary: [NSObject: AnyObject] = [
            Keys.temporaryWeightKg : tempWeight.kg,
            Keys.date : Date()
        ]
        if self.userActivity != nil {
            self.userActivity?.addUserInfoEntries(from: activityDictionary)
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
