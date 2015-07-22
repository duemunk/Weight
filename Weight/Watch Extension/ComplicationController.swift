//
//  ComplicationController.swift
//  Watch Extension
//
//  Created by Tobias Due Munk on 21/07/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import ClockKit

class ComplicationController: NSObject {
    
    let dateFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
//        formatter.dateStyle = .ShortStyle
        formatter.timeStyle = .ShortStyle
        return formatter
    }()
    let timeFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.dateStyle = .MediumStyle
//        formatter.timeStyle = .ShortStyle
        return formatter
    }()
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
//    func getTimelineEndDateForComplication(complication: CLKComplication, withHandler handler: (NSDate?) -> Void) {
//        handler(nil)
//    }
    
    func getPrivacyBehaviorForComplication(complication: CLKComplication, withHandler handler: (CLKComplicationPrivacyBehavior) -> Void) {
        handler(.HideOnLockScreen)
    }
    
    // MARK: - Timeline Population
    
    func getCurrentTimelineEntryForComplication(complication: CLKComplication, withHandler handler: ((CLKComplicationTimelineEntry?) -> Void)) {
        // Call the handler with the current timeline entry
        let now = NSDate()
        
        guard let template = templateForComplication(complication, weight: 70.7) else {
            return
        }
        let complicationTimelineEntry = CLKComplicationTimelineEntry(date: now, complicationTemplate: template)
        
        handler(complicationTimelineEntry)
    }
    
//    func getTimelineEntriesForComplication(complication: CLKComplication, beforeDate date: NSDate, limit: Int, withHandler handler: (([CLKComplicationTimelineEntry]?) -> Void)) {
//        // Call the handler with the timeline entries prior to the given date
//        handler(nil)
//    }
//    
//    func getTimelineEntriesForComplication(complication: CLKComplication, afterDate date: NSDate, limit: Int, withHandler handler: (([CLKComplicationTimelineEntry]?) -> Void)) {
//        // Call the handler with the timeline entries after to the given date
//        handler(nil)
//    }
//    
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
    
    func templateForComplication(complication: CLKComplication, weight: Double?, date: NSDate = NSDate()) -> CLKComplicationTemplate? {
        let weightText = weight == nil ? "-- []" : "70.7 kg"
        let shortWeightText = weight == nil ? "--" : "70.7"
        let dateText = dateFormatter.stringFromDate(date)
        let timeText = timeFormatter.stringFromDate(date)
        let template: CLKComplicationTemplate = {
            switch complication.family {
            case .ModularSmall:
                let template = CLKComplicationTemplateModularSmallSimpleText()
                template.textProvider = CLKSimpleTextProvider(text: weightText, shortText: shortWeightText)
                return template
            case .ModularLarge:
                let template = CLKComplicationTemplateModularLargeStandardBody()
                template.headerTextProvider = CLKSimpleTextProvider(text: weightText)
                template.body1TextProvider = CLKSimpleTextProvider(text: dateText)
                template.body2TextProvider = CLKSimpleTextProvider(text: timeText)
                return template
            case .UtilitarianSmall:
                let template = CLKComplicationTemplateUtilitarianSmallFlat()
                template.textProvider = CLKSimpleTextProvider(text: weightText, shortText: shortWeightText)
                return template
            case .UtilitarianLarge:
                let template = CLKComplicationTemplateUtilitarianLargeFlat()
                template.textProvider = CLKSimpleTextProvider(text: weightText, shortText: shortWeightText)
                return template
            case .CircularSmall:
                let template = CLKComplicationTemplateCircularSmallSimpleText()
                template.textProvider = CLKSimpleTextProvider(text: weightText, shortText: shortWeightText)
                return template
            }
        }()
        return template
    }
}
