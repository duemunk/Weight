//
//  InterfaceController.swift
//  Watch Extension
//
//  Created by Tobias Due Munk on 21/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import WatchKit
import Foundation
import ClockKit


class InterfaceController: WKInterfaceController {

    @IBOutlet var picker: WKInterfacePicker!
    @IBOutlet var dateLabel: WKInterfaceLabel!
    
    let weightFormatter = NSMassFormatter()
    let dateFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .MediumStyle
        formatter.timeStyle = .ShortStyle
        return formatter
    }()
    
    let healthManager = HealthManager()
    
    var selectedWeight: Double?
    var pickerWeights: [Double] {
        return healthManager.humanWeightOptions()
    }
    
    override func awakeWithContext(context: AnyObject?) {
        print("awakeWithContext \(context)")
        super.awakeWithContext(context)
        
        // Configure interface objects here.
        NotificationCenter.observe(HealthDataOrPreferencesDidChangeNotification) { [weak self] notification in
            dispatch_async(dispatch_get_main_queue()) {
                self?.updatePicker()
                self?.updateWeight()
                self?.updateComplications()
            }
        }
    }

    override func willActivate() {
        print("willActivate")
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        updatePicker()
        updateWeight()
        updateComplications()
    }

    override func didDeactivate() {
        print("didDeactivate")
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    @IBAction func pickerDidChange(index: Int) {
        let weight = pickerWeights[index]
        selectedWeight = weight
        print("Selected weight: \(weight)")
    }
    
    @IBAction func didTapSaveButton() {
        guard let selectedWeight = selectedWeight else {
            print("No selected weight. Couldn't save.")
            return
        }
        healthManager.saveWeight(selectedWeight) { result in
            optionalResult(result)
            self.updateWeight()
            self.updateComplications()
        }
    }

    private func updateWeight() {
        // Get latest weight
        healthManager.getWeight { result in
            dispatch_async(dispatch_get_main_queue()) {
                // Setup picker
                guard let quantitySample = optionalResult(result) else {
                    self.dateLabel.setText("Add your weight")
                    return
                }
                let quantity = quantitySample.quantity
                let doubleValue = quantity.doubleValueForUnit(self.healthManager.massUnit)
                guard let (_, index) = self.closest(self.pickerWeights, toValue: doubleValue) else {
                    return
                }
                self.updatePicker()
                self.picker.setSelectedItemIndex(index)
                self.dateLabel.setText(self.dateFormatter.stringFromDate(quantitySample.startDate))
            }
        }
    }
    
    private func updatePicker() {
        var pickerItems = [WKPickerItem]()
        for weight in pickerWeights {
            let item = WKPickerItem()
            item.title = weightFormatter.stringFromValue(weight, unit: healthManager.massFormatterUnit)
            pickerItems.append(item)
        }
        picker.setItems(pickerItems)
    }
    
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
    
    
    func updateComplications() {
        // Ping complications
        guard let complicationServer = CLKComplicationServer.sharedInstance() else {
            return
        }
        for complication in complicationServer.activeComplications {
            complicationServer.reloadTimelineForComplication(complication)
        }
    }
}


//extension CollectionType {
//    
//    func closestToValue<T: CollectionType where T.Generator.Element == Double>(value: T.Generator.Element) -> (closestValue: T, index: Int)?  {
//        guard let someValue = first else {
//            return nil
//        }
//
//        let t = self.map { $0 - value }
//
////        self.map { (element) -> T in
////            return element
////        }
////        let diffs = map { $0 - value }
////        let min = diffs.reduce(someValue, combine: <#T##(T, Self.Generator.Element) -> T#>)
//        
//        
//        return nil
//    }
//    
//}
