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


public extension Observable {
    /**
     Creates a new signal that mirrors the original signal but is delayed by x seconds. If no queue is specified, the new signal will call it's observers and transforms on the main queue.
     */
    public func delay(_ seconds: TimeInterval, queue: DispatchQueue = .main) -> Observable<T> {
        let signal = Observable<T>()
        subscribe { result in
            queue.after(when: DispatchTime.now() + seconds) {
                signal.update(result)
            }
        }
        return signal
    }
}


private var ObserverableUpdateCalledHandle: UInt8 = 0
extension Observable {
    internal var lastCalled: Date? {
        get {
            if let handle = objc_getAssociatedObject(self, &ObserverableUpdateCalledHandle) as? Date {
                return handle
            } else {
                return nil
            }
        }
        set {
            objc_setAssociatedObject(self, &ObserverableUpdateCalledHandle, newValue, .OBJC_ASSOCIATION_COPY_NONATOMIC)
        }
    }

    /**
     Creates a new signal that is only firing once per specified time interval. The last
     call to update will always be delivered (although it might be delayed up to the
     specified amount of seconds).
     */
    public func debounce(_ seconds: TimeInterval) -> Observable<T> {
        let observer = Observable<T>()

        subscribe { value in
            let currentTime = Date()
            func updateIfNeeded(_ observer: Observable<T>) -> (T) -> Void {
                return { value in
                    let timeSinceLastCall = observer.lastCalled?.timeIntervalSinceNow
                    if timeSinceLastCall == nil || timeSinceLastCall <= -seconds {
                        // no update before or update outside of debounce window
                        observer.lastCalled = Date()
                        observer.update(value)
                    } else {
                        // skip result if there was a newer result
                        if currentTime.compare(observer.lastCalled!) == .orderedDescending {
                            let s = Observable<T>()
                            s.delay(seconds - timeSinceLastCall!).subscribe(updateIfNeeded(observer))
                            s.update(value)
                        }
                    }
                }
            }
            updateIfNeeded(observer)(value)
        }

        return observer
    }
}

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

    private let dateLastWeightFormatter = DateFormatter(template: "jjmmMMMd") ?? DateFormatter(dateStyle: .mediumStyle, timeStyle: .shortStyle)
    private let dateQuickActionFormatter = DateFormatter(template: "jjmmMMMd") ?? DateFormatter(dateStyle: .mediumStyle, timeStyle: .shortStyle)
    private let dateChartXLabelFormatter = DateFormatter(template: "dMMM") ?? DateFormatter(dateStyle: .mediumStyle, timeStyle: .noStyle)
    private let chartYLabelFormatter = NumberFormatter()
    var pickerWeights: [HKQuantity] {
        return HealthManager.instance.humanWeightOptions()
    }
    private let healthDataChange = NotificationCenter_(name: .HealthDataDidChange)
    private let healthPreferencesChange = NotificationCenter_(name: .HealthPreferencesDidChange)
    private let userActivityChange = NotificationCenter_(name: .UserActivity)
    private let updateUIObservable = Observable<UpdateType>()

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
            WeightsLocalStore.instance.lastWeight = weight.hkQuantitySample
            self.updateUIObservable.update(.default)
        }

        userActivityChange.observer.map { notification in
            guard let
                userActivity = notification.object as? NSUserActivity,
                userInfo = userActivity.userInfo as? [String: AnyObject],
                temporaryWeight = Weight.temporaryNewWeight(from: userInfo) else {
                return
            }
            self.updateToWeight(request: .forceWeight(weight: temporaryWeight))
        }

        saveButton.tap.subscribe { _ in
            let index = self.weightPickerView.selectedRow(inComponent: 0)
            guard let quantity = self.weightForPickerRow(index) else {
                return
            }
            HealthManager.instance.saveWeight(quantity)
                .next { WatchConnection.instance.send(new: $0.weight) }
                .error { print($0) }
        }

        setupWeightObserver()

        setupChart()
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .default
    }
    
    deinit {
        NotificationCenter.default().removeObserver(self)
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
        self.updateChart(.week, range: Chart.Range(unit: .month, count: 6, softStart: true))
    }

    // MARK: - Weight
    private enum WeightRequest {
        case forceWeight(weight: Weight)
        case source(type: UpdateType)
    }

    private func updateToWeight(request: WeightRequest) {

        let quantitySampleBlock: (HKQuantitySample) -> () = { quantitySample in
            Async.main {
                assert(Thread.isMainThread())
                let quantity = quantitySample.quantity
                let massUnit = HealthManager.instance.massUnit
                let doubleValue = quantity.doubleValue(for: massUnit)
                guard let (_, index) = closest(self.pickerWeights.map { $0.doubleValue(for: massUnit) }, toValue: doubleValue) else {
                    return
                }
                let massFormatterUnit = HealthManager.instance.massFormatterUnit
                self.weightLabel.text = self.weightFormatter.string(fromValue: doubleValue, unit: massFormatterUnit)
                self.weightDetailLabel.text = self.dateLastWeightFormatter.string(from: quantitySample.startDate)
                self.weightPickerView.reloadAllComponents()
                self.weightPickerView.selectRow(index, inComponent: 0, animated: false)
            }
        }

        switch request {
        case .forceWeight(let weight):
            quantitySampleBlock(weight.hkQuantitySample)
        case .source(let type):
            HealthManager.instance.getWeight(forceSource: .source == type)
                .flatMap(Queue.main)
                .next(quantitySampleBlock)
                .error {
                    print($0)
                    assert(Thread.isMainThread())
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
            .then {
                QuickActionsHelper.update(with: $0, weightFormatter: self.weightFormatter, dateFormatter: self.dateQuickActionFormatter)
            }
            .flatMap(Queue.main)
            .next { shortcuts in
                Async.main {
                    assert(Thread.isMainThread())
                    UIApplication.shared().shortcutItems = shortcuts
                }
            }
    }


    // MARK: - Chart
    func setupChart() {
        chartView.isUserInteractionEnabled = false
        chartView.gridColor = .lightGray()
        chartView.labelColor = .lightGray()
        chartView.lineWidth = 2
        chartView.gridLineWidth = 1
        chartView.axesLineWidth = 1
        chartView.dotSize = 3
        chartView.labelFont = UIFont.boldSystemFont(ofSize: 12)
        chartView.xLabelsFormatter = { (index, value) in
            self.dateChartXLabelFormatter
                .string(from: Date(timeIntervalSince1970: Double(value)))
        }
        chartView.yLabelsFormatter = { (index, value, yIncrement) in
            let formatter = self.chartYLabelFormatter
            let fractionDigits: Int = {
                if let yIncrement = yIncrement {
                    var fraction: Float = 0
                    while round(yIncrement*pow(10, fraction)) != yIncrement*pow(10, fraction) {
                        fraction += 1
                    }
                    return Int(fraction)
                }
                return 0
            }()
            formatter.maximumFractionDigits = fractionDigits
            formatter.minimumFractionDigits = fractionDigits
            return formatter.string(from: value) ?? "\(value)"
        }
    }

    func updateChart(_ average: CalendarUnit = .week, range: Chart.Range) {
        HealthManager.instance.getWeights()
            .then {
                self.chartView.update(with: $0, dotColor: .black(), lineColor: UIColor.black().withAlphaComponent(0.3), average: .week, range: range)
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
        let attributedTitle = AttributedString(string: title, attributes: [
            NSForegroundColorAttributeName : UIColor.black(),
            NSFontAttributeName : UIFont.boldSystemFont(ofSize: 27)
            ])
        return attributedTitle
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        guard let tempWeight = weightForPickerRow(row) else {
            return
        }
        let activityDictionary: [NSObject: AnyObject] = [
            Keys.temporaryWeightKg : tempWeight,
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
