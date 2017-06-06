//
//  ChartHelper.swift
//  Weight
//
//  Created by Tobias Due Munk on 19/06/16.
//  Copyright © 2016 Tobias Due Munk. All rights reserved.
//

import UIKit


extension Chart {

    struct Range {
        let unit: CalendarUnit
        let count: Int
        let softStart: Bool
    }

    enum ChartError: Error {
        case noContent
        case dateError
    }

    func weightLabelsFormatter(numberFormatter: NumberFormatter) -> (Int, Float, Float?) -> String { // TODO: (labelIndex: Int, labelValue: Float, yIncrement: Float?)
        return { (index, value, yIncrement) in
            let formatter = numberFormatter
            let fractionDigits: Int = {
                if let yIncrement = yIncrement {
                    var fraction: Float = 0
                    while round(yIncrement*pow(10, fraction)) != yIncrement*pow(10, fraction) {
                        fraction += 1
                    }
                    return Int(fraction)
                }
                return 0
            }()
            formatter.maximumFractionDigits = fractionDigits
            formatter.minimumFractionDigits = fractionDigits
            return formatter.string(from: value as NSNumber) ?? "\(value)"
        }
    }

    func update(with quantitySamples: [Weight], dotColor: UIColor, lineColor: UIColor, average: CalendarUnit = .week, range: Range) {
        Observable<[Weight]>(quantitySamples)
            .flatMap(Queue.background)
            .flatMap { (samples: [Weight]) -> Observable<Result<(individualSeries: ChartSeries, runningAverageSeries: ChartSeries?, startDate: Date)>> in
                guard let first = samples.first else {
                    return Observable(.error(ChartError.noContent))
                }
                guard let hardStartDate = Date().add(range.unit, count: -range.count) else {
                    return Observable(.error(ChartError.dateError))
                }

                let startDate: Date = {
                    if range.softStart {
                        let softStartDate = first.date
                        return hardStartDate < softStartDate ? softStartDate : hardStartDate
                    } else {
                        return hardStartDate
                    }
                }()

                let rangedSamples = quantitySamples.filter { $0.date >= startDate }

                let massUnit = HealthManager.instance.massUnit
                let values: Array<(x: Double, y: Double)> = rangedSamples.map { ($0.date.timeIntervalSince1970, $0.hkQuantitySample.quantity.doubleValue(for: massUnit)) }

                let individualSeries = ChartSeries(data: values)
                individualSeries.color = dotColor
                individualSeries.line = false
                individualSeries.dots = true

                let valuesWeekly: Array<(x: Double, y: Double)>? = rangedSamples
                    .averages(average)?
                    .map { (
                        $0.date.timeIntervalSince1970,
                        WeightViewModel(weight: $0, massUnit: massUnit).userValue()
                        )
                    }
                let runningAverageSeries: ChartSeries? = valuesWeekly != nil ? ChartSeries(data: valuesWeekly!) : nil
                runningAverageSeries?.color = lineColor
                runningAverageSeries?.line = true

                return Observable(.success((individualSeries: individualSeries, runningAverageSeries: runningAverageSeries, startDate: startDate)))
            }
            .flatMap(Queue.main)
            .next { (__val:(ChartSeries, ChartSeries?, Date)) in let (individualSeries,runningAverageSeries,startDate) = __val; 
                Async.main {
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
