//
//  ChartHelper.swift
//  Weight
//
//  Created by Tobias Due Munk on 19/06/16.
//  Copyright © 2016 Tobias Due Munk. All rights reserved.
//

import UIKit
import HealthKit
import Interstellar


extension Chart {

    struct Range {
        let unit: CalendarUnit
        let count: Int
        let softStart: Bool
    }

    enum Error: ErrorProtocol {
        case noContent
        case dateError
    }

    func update(with quantitySamples: [HKQuantitySample], dotColor: UIColor, lineColor: UIColor, average: CalendarUnit = .week, range: Range) {
        Observable<[HKQuantitySample]>(quantitySamples)
            .flatMap(Queue.background)
            .flatMap { (samples: [HKQuantitySample]) -> Observable<Result<(individualSeries: ChartSeries, runningAverageSeries: ChartSeries?, startDate: Date)>> in
                guard let first = samples.first else {
                    return Observable(.error(Error.noContent))
                }
                guard let hardStartDate = Date().add(range.unit, count: -range.count) else {
                    return Observable(.error(Error.dateError))
                }

                let startDate: Date = {
                    if range.softStart {
                        let softStartDate = first.startDate
                        return hardStartDate < softStartDate ? softStartDate : hardStartDate
                    } else {
                        return hardStartDate
                    }
                }()

                let rangedSamples = quantitySamples.filter { $0.startDate >= startDate }

                let massUnit = HealthManager.instance.massUnit
                let values: Array<(x: Double, y: Double)> = rangedSamples.map { ($0.startDate.timeIntervalSince1970, $0.quantity.doubleValue(for: massUnit)) }

                let individualSeries = ChartSeries(data: values)
                individualSeries.color = dotColor
                individualSeries.line = false
                individualSeries.dots = true

                let valuesWeekly: Array<(x: Double, y: Double)>? = rangedSamples
                    .averages(average)?
                    .map { ($0.endDate.timeIntervalSince1970, $0.quantity.doubleValue(for: massUnit)) }
                let runningAverageSeries: ChartSeries? = valuesWeekly != nil ? ChartSeries(data: valuesWeekly!) : nil
                runningAverageSeries?.color = lineColor
                runningAverageSeries?.line = true

                return Observable(.success((individualSeries: individualSeries, runningAverageSeries: runningAverageSeries, startDate: startDate)))
            }
            .flatMap(Queue.main)
            .next { (individualSeries: ChartSeries, runningAverageSeries: ChartSeries?, startDate: Date) in
                Async.main {
                    assert(Thread.isMainThread())
                    self.removeSeries()
                    self.addSeries(individualSeries)
                    if let runningAverageSeries = runningAverageSeries {
                        self.addSeries(runningAverageSeries)
                    }
                    self.xLabels = stride(from: startDate.timeIntervalSince1970, through: Date().timeIntervalSince1970, by: range.unit.timeInterval)
                        .map(Float.init)
                }
            }

    }
}