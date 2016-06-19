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

    let weightFormatter = MassFormatter.weightMediumFormatter()
    private let dateLastWeightFormatter = DateFormatter(template: "jjmmMMMd") ?? DateFormatter(dateStyle: .mediumStyle, timeStyle: .shortStyle)
    
    var selectedWeight: HKQuantity?
    var pickerWeights: [HKQuantity] {
        return HealthManager.instance.humanWeightOptions()
    }
    
    override func awake(withContext context: AnyObject?) {
        print("awakeWithContext \(context)")
        super.awake(withContext: context)

        // Configure interface objects here.
        self.updatePicker()
            .subscribe { _ in
                self.updateWeightAssumingPicker()
        }

//        setTitle("Weight")

        NotificationCenter.default().addObserver(forName: .HealthDataDidChange, object: nil, queue: nil) { [weak self] notification in
            Async.main {
                self?.updateWeightAssumingPicker()
            }
        }

        NotificationCenter.default().addObserver(forName: .HealthPreferencesDidChange, object: nil, queue: nil) { [weak self] notification in
            Async.main {
                self?.updatePicker()
                    .subscribe { _ in
                        self?.updateWeightAssumingPicker()
                    }
            }
        }
    }

    override func willActivate() {
        print("willActivate")
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()

//        loaderImage.setHidden(false)
//        loader?.startAnimating()
//        picker.setHidden(true)
//        dateLabel.setHidden(true)
//        saveButton.setHidden(true)
    }

    override func didDeactivate() {
        print("didDeactivate")
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
    
    @IBAction func pickerDidChange(_ index: Int) {
        let weight = pickerWeights[safe: index]
        selectedWeight = weight
        print("Selected weight: \(weight)")
        // Click
//        WKInterfaceDevice.currentDevice().playHaptic(.Click)
        // User activity
        guard let tempWeight = weight else { return }
        
        let activityType = "dk.developmunk.Weight.updatingWeight"
        let unit = HKUnit.gramUnit(with: .kilo)
        let value = tempWeight.doubleValue(for: unit)
        let activityDictionary: [NSObject: AnyObject] = [
            "TemporaryWeightKg" : value,
            "TemporaryWeightDescription": "\(tempWeight)"]
        updateUserActivity(activityType, userInfo: activityDictionary, webpageURL: nil)
    }
    
    @IBAction func didTapSaveButton() {
        guard let selectedWeight = selectedWeight else {
            print("No selected weight. Couldn't save.")
            WKInterfaceDevice.current().play(.failure)
            return
        }
//        NSProcessInfo.processInfo().performExpiringActivityWithReason("Make sure weight is stored, even though user went away from app") { expired in
//          guard expired == false else { return }
        HealthManager.instance.saveWeight(selectedWeight)
            .then {
                WKInterfaceDevice.current().play(.success)
                self.updatePicker(referenceWeight: $0) // Update to
                    .subscribe { _ in
                        self.updateWeightAssumingPicker()
                    }
            }
            .error {
                print("Couldn't save weight: \($0)")
                WKInterfaceDevice.current().play(.failure)
            }


//        }
    }
}

private extension InterfaceController {

    func updateWeightAssumingPicker() {
        self.updateLabelsAndPickerPosition()
            .subscribe {
                self.updateComplications()
            }
    }

    func updateLabelsAndPickerPosition(forceWeight: HKQuantitySample? = nil) -> Observable<Void> { //  = WeightsLocalStore.instance.lastWeight
        let observable = Observable<Void>()

        let quantitySampleBlock: (HKQuantitySample) -> () = { quantitySample in
            // Date
            self.dateLabel.setText(self.dateLastWeightFormatter.string(from: quantitySample.startDate))
            // Weight
            let quantity = quantitySample.quantity
            let massUnit = HealthManager.instance.massUnit
            let doubleValue = quantity.doubleValue(for: massUnit)
            guard let (_, index) = self.pickerWeights.map({ $0.doubleValue(for: massUnit) }).closestToElement(doubleValue) else {
                observable.update()
                return
            }
            self.picker.setSelectedItemIndex(index)
            observable.update()
        }
        
        if let forceWeight = forceWeight {
            quantitySampleBlock(forceWeight)
            return observable
        }
        // Get latest weight
        HealthManager.instance.getWeight()
            .then { sample in
                Async.main {
                    // Setup picker
                    quantitySampleBlock(sample)
                }
            }
            .error {
                print($0)
                Async.main {
                    self.dateLabel.setText("Add your weight")
                    observable.update()
                }
            }
        return observable
    }

    @discardableResult
    func updatePicker(referenceWeight referenceWeightQuantitySample: HKQuantitySample? = WeightsLocalStore.instance.lastWeight) -> Observable<Void> {
        return Observable<Void>((), options: [.Once])
            .flatMap(Queue.background)
            .flatMap { (_: Void) -> Observable<[WKPickerItem]> in
                var pickerItems = [WKPickerItem]()
                let massUnit = HealthManager.instance.massUnit
                let massFormatterUnit = HealthManager.instance.massFormatterUnit
                for weightQuantity in self.pickerWeights {
                    let item = WKPickerItem()
                    let weight = weightQuantity.doubleValue(for: massUnit)
                    item.title = self.weightFormatter.string(fromValue: weight, unit: massFormatterUnit)
                    if let referenceWeightQuantity = referenceWeightQuantitySample?.quantity {
                        let referenceWeight = referenceWeightQuantity.doubleValue(for: massUnit)
                        let diffWeight = weight - referenceWeight
                        let diffString = self.weightFormatter.string(fromValue: abs(diffWeight), unit: massFormatterUnit)
                        switch diffWeight {
                            case 0: item.caption = "="
                            case let d where d > 0: item.caption = "+" + diffString
                            case let d where d < 0: item.caption = "-" + diffString
                            default: item.caption = diffString
                        }
                    }
                    pickerItems.append(item)
                }
                return Observable(pickerItems)
            }
            .flatMap(Queue.main)
            .flatMap { (pickerItems) -> Observable<Void> in
                self.picker.setItems(pickerItems)
                return Observable()
            }
    }
    
    func updateComplications() {
        // Ping complications
        let complicationServer = CLKComplicationServer.sharedInstance()
        guard let activeComplications = complicationServer.activeComplications else {
            return
        }
        for complication in activeComplications {
            complicationServer.reloadTimeline(for: complication)
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


extension Array where Element: FloatingPoint {
    
    func closestToElement(_ element: Element) -> (Element, Array.Index)? {
        let diffs = map { abs($0 - element) }

        guard let minimumDiff = diffs.min() else { return nil }
//        guard let someDiffValue = diffs.first else { return nil }
//        let minimumDiff = diffs.reduce(someDiffValue) {
//            return min($0, $1)
//        }
        guard let index = diffs.index(of: minimumDiff) else {
            return nil
        }
        return (self[index], index)
    }
}




var date = Date()
func tic() {
    date = Date()
    print("Tic: ", date)
}
func toc() {
    print("Toc:", -date.timeIntervalSinceNow)
}
