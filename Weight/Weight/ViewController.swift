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
    
    let healthManager = HealthManager()
    
    @IBAction func didTapSaveButton(sender: AnyObject) {
        let intRow = Double(weightPickerView.selectedRowInComponent(0))
        let decimalRow = Double(weightPickerView.selectedRowInComponent(1))
        let doubleValue = intRow + decimalRow / 10
        healthManager.saveWeight(doubleValue) { result in
            do {
                try result()
            } catch {
                print(error)
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        NotificationCenter.observe(HealthDataOrPreferencesDidChangeNotification) { [weak self] notification in
            self?.updateUI()
        }
        
        setupWeightObserver()
    }
    
    deinit {
        NotificationCenter.unobserve(self)
    }
    
    
    
    func setupWeightObserver() {
        healthManager.healthStore.observe(ofType: healthManager.weightType) { result in
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
        healthManager.getWeight { result in
            guard let quantitySample = optionalResult(result) else {
                dispatch_async(dispatch_get_main_queue()) {
                    self.weightLabel.text = self.weightFormatter.stringFromValue(0, unit: self.healthManager.massFormatterUnit)
                    self.weightDetailLabel.text = "No existing historic data"
                    self.weightPickerView.selectRow(0, inComponent: 0, animated: true)
                    self.weightPickerView.selectRow(0, inComponent: 1, animated: true)
                }
                return
            }
            let quantity = quantitySample.quantity
            let doubleValue = quantity.doubleValueForUnit(self.healthManager.massUnit)
            let intRow = Int(floor(doubleValue))
            let decimalRow = Int(round((doubleValue % 1) * 10))
            dispatch_async(dispatch_get_main_queue()) {
                self.weightLabel.text = self.weightFormatter.stringFromValue(doubleValue, unit: self.healthManager.massFormatterUnit)
                self.weightDetailLabel.text = self.dateFormatter.stringFromDate(quantitySample.startDate)
                self.weightPickerView.selectRow(intRow, inComponent: 0, animated: true)
                self.weightPickerView.selectRow(decimalRow, inComponent: 1, animated: true)
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

