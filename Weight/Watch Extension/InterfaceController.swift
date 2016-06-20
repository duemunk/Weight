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
import Interstellar


class InterfaceController: WKInterfaceController {

    @IBOutlet var picker: WKInterfacePicker!
    @IBOutlet var dateLabel: WKInterfaceLabel!
    @IBOutlet var loaderImage: WKInterfaceImage!
    @IBOutlet var saveButton: WKInterfaceButton!
    
//    var loader: Loader?

    let weightFormatter = MassFormatter.weightMediumFormatter()
    private let dateLastWeightFormatter = DateFormatter(template: "jjmmMMMd") ?? DateFormatter(dateStyle: .mediumStyle, timeStyle: .shortStyle)
    
    var selectedWeight: HealthManager.WeightPoint?
    var pickerWeights: [HealthManager.WeightPoint] {
        return HealthManager.instance.humanWeightOptions()
    }
    
    override func awake(withContext context: AnyObject?) {
        print("awakeWithContext \(context)")
        super.awake(withContext: context)

        // Configure interface objects here.
        self.updatePicker()
            .subscribe { _ in
                self.updateWeightAssumingPicker(forceSource: true)
        }

        WatchConnection.instance.newWeightObserver
            .subscribe { weight in
                WeightsLocalStore.instance.lastWeight = weight
                self.updateWeightAssumingPicker(forceSource: false)
            }

//        setTitle("Weight")

        NotificationCenter.default().addObserver(forName: .HealthDataDidChange, object: nil, queue: nil) { [weak self] notification in
            Async.main {
                self?.updateWeightAssumingPicker(forceSource: true)
            }
        }

        NotificationCenter.default().addObserver(forName: .HealthPreferencesDidChange, object: nil, queue: nil) { [weak self] notification in
            Async.main {
                self?.updatePicker()
                    .subscribe { _ in
                        self?.updateWeightAssumingPicker(forceSource: false)
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
        let activityDictionary: [NSObject: AnyObject] = [
            Keys.temporaryWeightKg : tempWeight.kg,
            Keys.temporaryWeightDescription : "\(tempWeight)"]
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
        let weight = Weight(kg: selectedWeight.kg, date: Date())
        HealthManager.instance.save(weight: weight)
            .then { _ in
                WKInterfaceDevice.current().play(.success)
                self.updatePicker() // Update to
                    .subscribe { _ in
                        self.updateWeightAssumingPicker(forceSource: true)
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

    func updateWeightAssumingPicker(forceSource: Bool) {
        updateLabelsAndPickerPosition(forceSource: forceSource)
            .subscribe {
                self.updateComplications()
            }
    }

    func updateLabelsAndPickerPosition(forceSource: Bool) -> Observable<Void> { //  = WeightsLocalStore.instance.lastWeight
        let observable = Observable<Void>()

        // Get latest weight
        HealthManager.instance.getWeight(forceSource: forceSource)
            .then { weight in
                guard let (_, index) = self.pickerWeights.map({ $0.kg }).closestToElement(weight.kg) else {
                    observable.update()
                    return
                }
                Async.main {
                    // Setup picker
                    self.dateLabel.setText(self.dateLastWeightFormatter.string(from: weight.date))
                    // Weight
                    self.picker.setSelectedItemIndex(index)
                    observable.update()
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
    func updatePicker() -> Observable<Void> {
        return Observable<Void>((), options: [.Once])
            .flatMap(Queue.background)
            .flatMap { (_: Void) -> Observable<[WKPickerItem]> in
                var pickerItems = [WKPickerItem]()
                let massUnit = HealthManager.instance.massUnit
                for weightPoint in self.pickerWeights {
                    let item = WKPickerItem()
                    let weight = Weight(kg: weightPoint.kg, date: Date())
                    let weightViewModel = WeightViewModel(weight: weight, massUnit: HealthManager.instance.massUnit)
                    item.title = self.weightFormatter.string(fromValue: weightViewModel.userValue(), unit: weightViewModel.formatterUnit)
                    if let referenceWeight = WeightsLocalStore.instance.lastWeight {
                        let diffWeight = Weight(kg: weight.kg - referenceWeight.kg, date: Date())
                        let diffWeightValue = diffWeight.hkQuantitySample.quantity.doubleValue(for: massUnit)
                        let diffWeightViewModel = WeightViewModel(weight: diffWeight, massUnit: HealthManager.instance.massUnit)
                        let diffString = self.weightFormatter.string(fromValue: abs(diffWeightViewModel.userValue()), unit: diffWeightViewModel.formatterUnit)
                        switch diffWeightValue {
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
