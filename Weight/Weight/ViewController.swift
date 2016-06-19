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
        updateUIObservable
            .flatMap(Queue.main)
            .debounce(0.05)
            .map { self.updateUI() }

        healthDataChange.observer.subscribe { _ in
            self.updateUIObservable.update()
        }
        healthPreferencesChange.observer.subscribe { _ in
            self.updateUIObservable.update()
        }

        userActivityChange.observer.map { notification in
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
                .error { print($0) }
        }

        setupChart()
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .lightContent
    }
    
    deinit {
        NotificationCenter.default().removeObserver(self)
    }
    
    func setupWeightObserver() {
        HealthManager.instance.healthStore.observe(ofType: HealthManager.instance.weightType)
            .then { systemCompletionHandler in
                self.updateUIObservable.update()
                systemCompletionHandler()
            }
            .error { print($0) }
    }

    func updateUI() {

        self.updateToWeight()
        self.updateQuickActions()
        self.updateChart(.week, range: Chart.Range(unit: .month, count: 6, softStart: false))
    }

    // MARK: - Weight
    func updateToWeight(forceWeight: HKQuantitySample? = nil) {
        
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
                self.weightDetailLabel.text = self.dateFormatter.string(from: quantitySample.startDate)
                self.weightPickerView.reloadAllComponents()
                self.weightPickerView.selectRow(index, inComponent: 0, animated: false)
            }
        }
        
        if let forceWeight = forceWeight {
            quantitySampleBlock(forceWeight)
            return
        }
        
        HealthManager.instance.getWeight()
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
                QuickActionsHelper.update(with: $0, weightFormatter: self.weightFormatter, dateFormatter: self.dateShortFormatter)
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
        chartView.gridColor = UIColor.white().withAlphaComponent(0.3)
        chartView.labelColor = .white()
        chartView.lineWidth = 1.5
        chartView.dotSize = 1.5
        chartView.xLabelsFormatter = { (index, value) in
            (self.dateWithOutYearFormatter ?? self.dateOnlyFormatter)
                .string(from: Date(timeIntervalSince1970: Double(value)))
        }
    }

    func updateChart(_ average: CalendarUnit = .week, range: Chart.Range) {
        HealthManager.instance.getWeights()
            .then {
                self.chartView.update(with: $0, dotColor: .white(), lineColor: UIColor.white().withAlphaComponent(0.6), average: .week, range: range)
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
