//
//  ComplicationController.swift
//  Watch Extension
//
//  Created by Tobias Due Munk on 21/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import ClockKit
import HealthKit

class ComplicationController: NSObject {
    
    let dateFormatter = NSDateFormatter.build(dateStyle: .MediumStyle)
    let timeFormatter = NSDateFormatter.build(timeStyle: .ShortStyle)
    let weightShortFormatter = NSMassFormatter.weightShortFormatter()
    let weightMediumFormatter = NSMassFormatter.weightMediumFormatter()
    let weightLongFormatter = NSMassFormatter.weightLongFormatter()
    let weightNoUnitFormatter = NSNumberFormatter.weightNoUnitFormatter()
    let weightNoUnitShortFormatter = NSNumberFormatter.weightNoUnitShortFormatter()
}

extension ComplicationController: CLKComplicationDataSource {
    
    // MARK: - Timeline Configuration
    
    func getSupportedTimeTravelDirectionsForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationTimeTravelDirections) -> Void) {
        handler([.None])
    }
    
//    func getTimelineStartDateForComplication(complication: CLKComplication, withHandler handler: (NSDate?) -> Void) {
//        handler(nil)
//    }
//    
    func getTimelineEndDateForComplication(complication: CLKComplication, withHandler handler: (NSDate?) -> Void) {
        let date = NSDate(timeIntervalSinceNow: 60*60*24) // A day from now
        handler(date)
    }
    
    func getPrivacyBehaviorForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.HideOnLockScreen)
    }
    
    // MARK: - Timeline Population
    
    func getCurrentTimelineEntryForComplication(complication: CLKComplication, withHandler handler: ((CLKComplicationTimelineEntry?) -> Void)) {
        // Call the handler with the current timeline entry
        let now = NSDate()
        let weight = WeightsLocalStore.instance.lastWeight?.quantity.doubleValueForUnit(HKUnit.gramUnitWithMetricPrefix(.Kilo))
        
        guard let template = templateForComplication(complication, weight: weight) else {
            return
        }
        let complicationTimelineEntry = CLKComplicationTimelineEntry(date: now, complicationTemplate: template)
        handler(complicationTimelineEntry)
    }
    
//    func getTimelineEntriesForComplication(complication: CLKComplication, beforeDate date: NSDate, limit: Int, withHandler handler: (([CLKComplicationTimelineEntry]?) -> Void)) {
//        // Call the handler with the timeline entries prior to the given date
//        handler(nil)
//    }
    
//    func getTimelineEntriesForComplication(complication: CLKComplication, afterDate date: NSDate, limit: Int, withHandler handler: (([CLKComplicationTimelineEntry]?) -> Void)) {
//        // Call the handler with the timeline entries after to the given date
//        var entries: [CLKComplicationTimelineEntry] = []
//        
//        let limit = min(limit, 10)
//        for i in 1..<limit {
//            let weight = (WeightsLocalStore.instance.lastWeight?.quantity.doubleValueForUnit(HKUnit.gramUnitWithMetricPrefix(.Kilo)) ?? 0) + Double(i)
//            let weightDate = date.dateByAddingTimeInterval(NSTimeInterval(i) * 60*45)
//            
//            guard let template = templateForComplication(complication, weight: weight, date: weightDate) else {
//                return
//            }
//            let complicationTimelineEntry = CLKComplicationTimelineEntry(date: date, complicationTemplate: template)
//            entries.append(complicationTimelineEntry)
//        }
//        handler(entries)
//    }

    // MARK: - Update Scheduling
    
    func getNextRequestedUpdateDateWithHandler(handler: (NSDate?) -> Void) {
        // Call the handler with the date when you would next like to be given the opportunity to update your complication content
        let date = NSDate(timeIntervalSinceNow: 60*60) // Every hour
        handler(date);
    }
    
    // MARK: - Placeholder Templates
    
    func getPlaceholderTemplateForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationTemplate?) -> Void) {
        // This method will be called once per supported complication, and the results will be cached
        let template = templateForComplication(complication, weight: nil)
        handler(template)
    }
}


extension ComplicationController {
    
    func templateForComplication(complication: CLKComplication, weight weightInKiloGrams: Double?, emptyWeight: String = "##", date: NSDate = NSDate()) -> CLKComplicationTemplate? {
        let userMassUnit = HealthManager.instance.massUnit
        let userMassFormatterUnit = HealthManager.instance.massFormatterUnit
        let userWeight: Double? = {
            guard let weight = weightInKiloGrams else {
                return nil
            }
            return HKQuantity(unit: HKUnit.gramUnitWithMetricPrefix(.Kilo), doubleValue: weight).doubleValueForUnit(userMassUnit)
        }()
        
        let weightText = userWeight == nil ? "No weight" : weightMediumFormatter.stringFromValue(userWeight ?? 0, unit: userMassFormatterUnit)
        let shortWeightText = userWeight == nil ? emptyWeight : weightShortFormatter.stringFromValue(userWeight ?? 0, unit: userMassFormatterUnit)
        let weightNoUnitText = userWeight == nil ? emptyWeight : weightNoUnitFormatter.stringFromNumber(userWeight ?? 0) ?? emptyWeight
        let weightNoUnitShortText = userWeight == nil ? emptyWeight : weightNoUnitShortFormatter.stringFromNumber(userWeight ?? 0) ?? emptyWeight
        let weightUnitText = weightMediumFormatter.unitStringFromValue(userWeight ?? 0, unit: userMassFormatterUnit)
        let tintColor = UIColor(red: 200/255, green: 109/255, blue: 215/255, alpha: 0.8)
//        let tintColor = UIColor(red: 222/255, green: 127/255, blue: 255/255, alpha: 1)
//        let tintColor = UIColor(red: 237/255, green: 185/255, blue: 255/255, alpha: 1)
        let template: CLKComplicationTemplate = {
            switch complication.family {
            case .ModularSmall:
                let template = CLKComplicationTemplate.Modular.Small.stackText()
                template.line1TextProvider = CLKSimpleTextProvider(text: weightNoUnitText, shortText: weightNoUnitShortText)
                template.line2TextProvider = CLKSimpleTextProvider(text: weightUnitText)
                template.highlightLine2 = true
                template.tintColor = tintColor
                return template
            case .ModularLarge:
                let template = CLKComplicationTemplate.Modular.Large.standardBody()
                template.headerTextProvider = CLKSimpleTextProvider(text: weightText)
                template.body1TextProvider = CLKTimeTextProvider(date: date) // Time
                template.body2TextProvider = CLKDateTextProvider(date: date, units: [.Month, .Day, .Year]) // Date
//                template.tintColor = .whiteColor()
//                template.body1TextProvider.tintColor = tintColor.colorWithAlphaComponent(0.5)
//                template.body2TextProvider?.tintColor = tintColor.colorWithAlphaComponent(0.8)
                return template
            case .UtilitarianSmall:
                let template = CLKComplicationTemplate.Utilitarian.Small.flat()
                template.textProvider = CLKSimpleTextProvider(text: weightText, shortText: shortWeightText)
                return template
            case .UtilitarianLarge:
                let template = CLKComplicationTemplate.Utilitarian.Large.flat()
                template.textProvider = CLKSimpleTextProvider(text: weightText, shortText: shortWeightText)
                return template
            case .CircularSmall:
                let template = CLKComplicationTemplate.Circular.Small.stackText()
                template.line1TextProvider = CLKSimpleTextProvider(text: weightNoUnitText, shortText: weightNoUnitShortText)
                template.line2TextProvider = CLKSimpleTextProvider(text: weightUnitText)
                return template
            }
        }()
        template.tintColor = tintColor
        return template
    }
}


protocol ComplicationTemplateType {}
protocol ComplicationTemplateTypeSubType {}
//protocol ComplicationTemplateTypeStackText {
//    static func stackText<T: ComplicationTemplateStackText>() -> T
//}
protocol ComplicationTemplateStackText {
    var line1TextProvider: CLKTextProvider { get set }
    var line2TextProvider: CLKTextProvider { get set }
}
extension CLKComplicationTemplateModularSmallStackText: ComplicationTemplateStackText {}
extension CLKComplicationTemplateCircularSmallStackText: ComplicationTemplateStackText {}

extension CLKComplicationTemplate {

    struct Modular: ComplicationTemplateType {
        /**
            Square
            Size: 1/3 of width of watch face
            Watch faces: 
        */
        struct Small: ComplicationTemplateTypeSubType {
            /** 
                Single line of text
            */
            static func simpleText() -> CLKComplicationTemplateModularSmallSimpleText {
                return CLKComplicationTemplateModularSmallSimpleText()
            }
            /**
                An image
            */
            static func simpleImage() -> CLKComplicationTemplateModularSmallSimpleImage {
                return CLKComplicationTemplateModularSmallSimpleImage()
            }
            /**
                A very short single line text inside a progress ring
            */
            static func ringText() -> CLKComplicationTemplateModularSmallRingText {
                return CLKComplicationTemplateModularSmallRingText()
            }
            /**
                An tiny image inside a progress ring
            */
            static func ringImage() -> CLKComplicationTemplateModularSmallRingImage {
                return CLKComplicationTemplateModularSmallRingImage()
            }
            /**
                Two separate lines of text
            */
            static func stackText() -> CLKComplicationTemplateModularSmallStackText {
                return CLKComplicationTemplateModularSmallStackText()
            }
            /**
                Image on top of a single line of text
            */
            static func stackImage() -> CLKComplicationTemplateModularSmallStackImage {
                return CLKComplicationTemplateModularSmallStackImage()
            }
            /**
                A table of 2x2, with each cell containing a very short line of text.
            */
            static func columnsText() -> CLKComplicationTemplateModularSmallColumnsText {
                return CLKComplicationTemplateModularSmallColumnsText()
            }
        }
        /**
            Big in center of watch face. 
            Size: Three line-heights tall and spans the entire width of the watch face.
        */
        struct Large: ComplicationTemplateTypeSubType {
            /** 
                A table of 3x2, with each cell containing a single line of text. Each line in the first row can has an optional image
            */
            static func columns() -> CLKComplicationTemplateModularLargeColumns {
                return CLKComplicationTemplateModularLargeColumns()
            }
            /**
                Three separate lines of text. The first line has optional image and the 2nd line wraps to the 3rd, if the a 3rd line isn't provided.
            */
            static func standardBody() -> CLKComplicationTemplateModularLargeStandardBody {
                return CLKComplicationTemplateModularLargeStandardBody()
            }
            /**
                A header with an optional image and a table of 2x2, with each cell containing a very short line of text.
            */
            static func table() -> CLKComplicationTemplateModularLargeTable {
                return CLKComplicationTemplateModularLargeTable()
            }
            /*
                Two separate lines of text. The 2nd line has large double height text.
            */
            static func tallBody() -> CLKComplicationTemplateModularLargeTallBody {
                return CLKComplicationTemplateModularLargeTallBody()
            }
        }
    }
    
    struct Utilitarian: ComplicationTemplateType {
        /**
            Either a single line of text spanning half the width of the watch face _or_ square image/ring.
            Watch faces: Utility, Simple, Chronograph
        */
        struct Small: ComplicationTemplateTypeSubType {
            /**
                An optional image followed by a single line of text spanning half the width of the watch face.
            */
            static func flat() -> CLKComplicationTemplateUtilitarianSmallFlat {
                return CLKComplicationTemplateUtilitarianSmallFlat()
            }
            /**
                An tiny image inside a progress ring
            */
            static func ringImage() -> CLKComplicationTemplateUtilitarianSmallRingImage {
                return CLKComplicationTemplateUtilitarianSmallRingImage()
            }
            /**
                A very short single line text inside a progress ring
            */
            static func ringText() -> CLKComplicationTemplateUtilitarianSmallRingText {
                return CLKComplicationTemplateUtilitarianSmallRingText()
            }
            /**
                An image
            */
            static func square() -> CLKComplicationTemplateUtilitarianSmallSquare {
                return CLKComplicationTemplateUtilitarianSmallSquare()
            }
        }
        
        /**
            A single line-height tall of text spanning entire width of the watch face
        */
        struct Large: ComplicationTemplateTypeSubType {
            /**
                Single line of text spanning entire width of the watch face
            */
            static func flat() -> CLKComplicationTemplateUtilitarianLargeFlat {
                return CLKComplicationTemplateUtilitarianLargeFlat()
            }
        }
    }

    struct Circular: ComplicationTemplateType {
        /**
            Square. 
            Either has a circular non-opaque background fill _or_ progress ring around content.
            Watch faces: Color
        */
        struct Small: ComplicationTemplateTypeSubType {
            /**
                A single line of text inside a circle with non-opaque background
            */
            static func simpleText() -> CLKComplicationTemplateCircularSmallSimpleText {
                return CLKComplicationTemplateCircularSmallSimpleText()
            }
            /**
                An image inside a circle with non-opaque background
            */
            static func simpleImage() -> CLKComplicationTemplateCircularSmallSimpleImage {
                return CLKComplicationTemplateCircularSmallSimpleImage()
            }
            /**
                A very short single line text inside a progress ring
            */
            static func ringText() -> CLKComplicationTemplateCircularSmallRingText {
                return CLKComplicationTemplateCircularSmallRingText()
            }
            /**
                An tiny image inside a progress ring
            */
            static func ringImage() -> CLKComplicationTemplateCircularSmallRingImage {
                return CLKComplicationTemplateCircularSmallRingImage()
            }
            /**
                Two separate lines of text
            */
            static func stackText() -> CLKComplicationTemplateCircularSmallStackText {
                return CLKComplicationTemplateCircularSmallStackText()
            }
            /**
                Image on top of a single line of text
            */
            static func stackImage() -> CLKComplicationTemplateCircularSmallStackImage {
                return CLKComplicationTemplateCircularSmallStackImage()
            }
        }
    }
    
    class func subType(forFamily family: CLKComplicationFamily) -> ComplicationTemplateTypeSubType.Type {
        switch family {
        case .ModularSmall: return CLKComplicationTemplate.Modular.Small.self
        case .ModularLarge: return CLKComplicationTemplate.Modular.Large.self
        case .UtilitarianSmall: return CLKComplicationTemplate.Utilitarian.Small.self
        case .UtilitarianLarge: return CLKComplicationTemplate.Utilitarian.Small.self
        case .CircularSmall: return CLKComplicationTemplate.Circular.Small.self
        }
    }
}


