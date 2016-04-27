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
import HealthKit
import Interstellar


class InterfaceController: WKInterfaceController {

    @IBOutlet var picker: WKInterfacePicker!
    @IBOutlet var dateLabel: WKInterfaceLabel!
    @IBOutlet var loaderImage: WKInterfaceImage!
    @IBOutlet var saveButton: WKInterfaceButton!
    
//    var loader: Loader?

    let weightFormatter = NSMassFormatter.weightMediumFormatter()
    let dateFormatter = NSDateFormatter(dateStyle: .MediumStyle, timeStyle: .ShortStyle)
    
    var selectedWeight: HKQuantity?
    var pickerWeights: [HKQuantity] {
        return HealthManager.instance.humanWeightOptions()
    }
    
    override func awakeWithContext(context: AnyObject?) {
        print("awakeWithContext \(context)")
        super.awakeWithContext(context)
        
//        loader = Loader(controller: self, interfaceImages: [loaderImage])
        
        // Configure interface objects here.
        updatePicker()
        
//        setTitle("Weight")
        
        NotificationCenter.observe(HealthDataDidChangeNotification) { [weak self] notification in
            Async.main {
                self?.updateWeight().subscribe { _ in
                    self?.updateComplications()
                }
            }
        }
        NotificationCenter.observe(HealthPreferencesDidChangeNotification) { [weak self] notification in
            Async.main {
                self?.updatePicker()
                self?.updateWeight().subscribe { _ in
                    self?.updateComplications()
                }
            }
        }
    }

    override func willActivate() {
        print("willActivate")
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
        
        self.updateWeight().subscribe { _ in
            self.updateComplications()
        }
//        loader?.startAnimating()
        
//        picker.setHidden(true)
//        dateLabel.setHidden(true)
//        saveButton.setHidden(true)
        
//        Async.background {
//            tic()
//            self.updatePicker()
//            self.updateWeight {
//                self.updateComplications()
//            }
//            toc()
//            Async.main() {
//                self.loader?.stopAnimating()
//                self.picker.setHidden(false)
//                self.dateLabel.setHidden(false)
//                self.saveButton.setHidden(false)
//                self.loader?.stopAnimating()
//                self.loaderImage.setHidden(true)
//            }
//        }
    }

    override func didDeactivate() {
        print("didDeactivate")
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    @IBAction func pickerDidChange(index: Int) {
        let weight = pickerWeights[safe: index]
        selectedWeight = weight
        print("Selected weight: \(weight)")
        // Click
//        WKInterfaceDevice.currentDevice().playHaptic(.Click)
        // User activity
        guard let tempWeight = weight else { return }
        
        let activityType = "dk.developmunk.Weight.updatingWeight"
        let unit = HKUnit.gramUnitWithMetricPrefix(.Kilo)
        let value = tempWeight.doubleValueForUnit(unit)
        let activityDictionary: [NSObject: AnyObject] = [
            "TemporaryWeightKg" : value,
            "TemporaryWeightDescription": "\(tempWeight)"]
        updateUserActivity(activityType, userInfo: activityDictionary, webpageURL: nil)
    }
    
    @IBAction func didTapSaveButton() {
        guard let selectedWeight = selectedWeight else {
            print("No selected weight. Couldn't save.")
            WKInterfaceDevice.currentDevice().playHaptic(.Failure)
            return
        }
//        NSProcessInfo.processInfo().performExpiringActivityWithReason("Make sure weight is stored, even though user went away from app") { expired in
//          guard expired == false else { return }
            HealthManager.instance.saveWeight(selectedWeight) { result in
                do {
                    let sample = try result()
                    WKInterfaceDevice.currentDevice().playHaptic(.Success)
                    self.updatePicker(referenceWeight: sample) // Update to
                    self.updateWeight().subscribe { _ in
                        self.updateComplications()
                    }
                } catch {
                    print("Couldn't save weight: \(error)")
                    WKInterfaceDevice.currentDevice().playHaptic(.Failure)
                }
            }
//        }
    }

    private func updateWeight(forceWeight forceWeight: HKQuantitySample? = nil) -> Observable<Int> { //  = WeightsLocalStore.instance.lastWeight
        let observable = Observable<Int>()

        let quantitySampleBlock: (HKQuantitySample) -> () = { quantitySample in
            // Date
            self.dateLabel.setText(self.dateFormatter.stringFromDate(quantitySample.startDate))
            // Weight
            let quantity = quantitySample.quantity
            let massUnit = HealthManager.instance.massUnit
            let doubleValue = quantity.doubleValueForUnit(massUnit)
            guard let (_, index) = self.pickerWeights.map({ $0.doubleValueForUnit(massUnit) }).closestToElement(doubleValue) else {
                observable.update(0)
                return
            }
            self.picker.setSelectedItemIndex(index)
            observable.update(0)
        }
        
        if let forceWeight = forceWeight {
            quantitySampleBlock(forceWeight)
            return observable
        }
        // Get latest weight
        HealthManager.instance.getWeight { result in
            Async.main {
                // Setup picker
                guard let quantitySample = optionalResult(result) else {
                    self.dateLabel.setText("Add your weight")
                    observable.update(0)
                    return
                }
                quantitySampleBlock(quantitySample)
            }
        }
        return observable
    }
    
    private func updatePicker(referenceWeight referenceWeightQuantitySample: HKQuantitySample? = WeightsLocalStore.instance.lastWeight) {
        
        var pickerItems = [WKPickerItem]()
        let massUnit = HealthManager.instance.massUnit
        let massFormatterUnit = HealthManager.instance.massFormatterUnit
        for weightQuantity in pickerWeights {
            let item = WKPickerItem()
            let weight = weightQuantity.doubleValueForUnit(massUnit)
            item.title = weightFormatter.stringFromValue(weight, unit: massFormatterUnit)
            if let referenceWeightQuantity = referenceWeightQuantitySample?.quantity {
                let referenceWeight = referenceWeightQuantity.doubleValueForUnit(massUnit)
                let diffWeight = weight - referenceWeight
                let diffString = weightFormatter.stringFromValue(abs(diffWeight), unit: massFormatterUnit)
                switch diffWeight {
                    case 0: item.caption = "="
                    case let d where d > 0: item.caption = "+" + diffString
                    case let d where d < 0: item.caption = "-" + diffString
                    default: item.caption = diffString
                }
            }
            pickerItems.append(item)
        }
        picker.setItems(pickerItems)
    }
    
    func updateComplications() {
        // Ping complications
        let complicationServer = CLKComplicationServer.sharedInstance()
        guard let activeComplications = complicationServer.activeComplications else {
            return
        }
        for complication in activeComplications {
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


extension Array where Element: FloatingPointType {
    
    func closestToElement(element: Element) -> (Element, Array.Index)? {
        let diffs = map { abs($0 - element) }
        guard let someDiffValue = diffs.first else {
            return nil
        }
        let minimumDiff = diffs.reduce(someDiffValue) { min($0, $1) }
        guard let index = diffs.indexOf(minimumDiff) else {
            return nil
        }
        return (self[index], index)
    }
}




var date = NSDate()
func tic() {
    date = NSDate()
    print("Tic: ", date)
}
func toc() {
    print("Toc:", -date.timeIntervalSinceNow)
}
