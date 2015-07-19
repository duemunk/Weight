//
//  ViewController.swift
//  Weight
//
//  Created by Tobias Due Munk on 19/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import UIKit
import HealthKit

class ViewController: UIViewController {

    @IBOutlet weak var weightLabel: UILabel!
    @IBOutlet weak var weightDetailLabel: UILabel!
    @IBOutlet weak var weightPickerView: UIPickerView!
    
    let weightFormatter = NSMassFormatter()
    let dateFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .MediumStyle
        formatter.timeStyle = .ShortStyle
        return formatter
    }()
    
    let weightType = HKObjectType.quantityTypeForIdentifier(HKQuantityTypeIdentifierBodyMass)
    var massUnit: HKUnit = .gramUnitWithMetricPrefix(.Kilo)  // Default to [kg]
    var massFormatterUnit = HKUnit.massFormatterUnitFromUnit(.gramUnitWithMetricPrefix(.Kilo))
    
    let healthStore = HKHealthStore()
    
    @IBAction func didTapSaveButton(sender: AnyObject) {
        guard let weightType = weightType else {
            return
        }
        guard weightType.isCompatibleWithUnit(massUnit) else {
            print("WeightType is not compatible with unit \(massUnit)")
            return
        }
        let intRow = Double(weightPickerView.selectedRowInComponent(0))
        let decimalRow = Double(weightPickerView.selectedRowInComponent(1))
        let doubleValue = intRow + decimalRow / 10
        let quantity = HKQuantity(unit: massUnit, doubleValue: doubleValue)
        let date = NSDate()
        let weightSample = HKQuantitySample(type: weightType, quantity: quantity, startDate: date, endDate: date)
        healthStore.saveObject(weightSample) { success, error in
            if let error = error {
                print(error)
                return
            }
            guard success else {
                print("Couldn't get authorization request")
                return
            }
            print("Yay, stored \(weightSample) to HealthKit!")
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        if !HKHealthStore.isHealthDataAvailable() {
            print("No Health data available")
        }
        
        checkHealthKitAuthorization()
        
        updateUserPreferredUnits() {
            self.updateUI()
        }
        
        NotificationCenter.observe(HKUserPreferencesDidChangeNotification) { [weak self] notification in
            self?.updateUserPreferredUnits() {
                self?.updateUI()
            }
        }
        
        setupWeightObserver()
    }
    
    deinit {
        NotificationCenter.unobserve(self)
    }
    
    func checkHealthKitAuthorization() {
        guard let weightType = weightType else {
            print("No weightType")
            return
        }
        
        switch healthStore.authorizationStatusForType(weightType) {
            case .SharingDenied:
                print("HealthKit access denied")
                return
            case .NotDetermined:
                print("HealthKit access undetermined")
                return
            case .SharingAuthorized:
                break
        }
        
        healthStore.requestAuthorizationToShareTypes([weightType], readTypes: [weightType]) { success, error in
            if let error = error {
                print(error)
                return
            }
            guard success else {
                print("Couldn't get authorization request")
                return
            }
            self.updateUserPreferredUnits {
                self.updateUI()
            }
        }
    }
    
    func setupWeightObserver() {
        guard let weightType = weightType else {
            print("No weightType")
            return
        }
        
        healthStore.observe(ofType: weightType) { result in
            do {
                let systemCompletionHandler = try result()
                self.updateUI()
                systemCompletionHandler()
            } catch {
                print(error)
            }
        }
    }
    
    func updateUserPreferredUnits(completion: () -> ()) {
        guard let weightType = weightType else {
            print("No weightType")
            return
        }
        
        let types: Set<HKQuantityType> = [weightType]
        healthStore.preferredUnits(forQuantityTypes: types) { result in
            do {
                let units = try result()
                guard let massUnit = units[weightType] else {
                    print("Couldn't parse preferred units")
                    return
                }
                self.massUnit = massUnit
                self.massFormatterUnit = HKUnit.massFormatterUnitFromUnit(self.massUnit)
            } catch {
                print("Couldn't get preferred units")
            }
            defer {
                dispatch_async(dispatch_get_main_queue()) {
                    completion()
                }
            }
        }
    }
    
   
    func updateUI() {
        guard let weightType = weightType else {
            print("No weightType")
            return
        }
        
        healthStore.mostRecentSample(ofType: weightType) { result in
            do {
                let sample = try result()
                guard let quantitySample = sample as? HKQuantitySample else {
                    print("Not of type HKQuantitySample")
                    return
                }
                let quantity = quantitySample.quantity
                let doubleValue = quantity.doubleValueForUnit(self.massUnit)
                let intRow = Int(floor(doubleValue))
                let decimalRow = Int(round((doubleValue % 1) * 10))
                dispatch_async(dispatch_get_main_queue()) {
                    self.weightLabel.text = self.weightFormatter.stringFromValue(doubleValue, unit: self.massFormatterUnit)
                    self.weightDetailLabel.text = self.dateFormatter.stringFromDate(quantitySample.startDate)
                    self.weightPickerView.selectRow(intRow, inComponent: 0, animated: true)
                    self.weightPickerView.selectRow(decimalRow, inComponent: 1, animated: true)
                }
            } catch {
                print(error)
            }
        }
    }
}

extension ViewController: UIPickerViewDataSource {
    
    func numberOfComponentsInPickerView(pickerView: UIPickerView) -> Int {
        return 2
    }
    
    func pickerView(pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        switch component {
            case 0: return 300
            case 1: return 10
            default: return 0
        }
    }
}

extension ViewController: UIPickerViewDelegate {
    
    func pickerView(pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        switch component {
            case 0: return "\(row)"
            case 1: return "\(row)"
            case _: return nil
        }
    }
}

