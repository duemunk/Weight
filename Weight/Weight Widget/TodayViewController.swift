//
//  TodayViewController.swift
//  Weight Widget
//
//  Created by Tobias Due Munk on 18/06/16.
//  Copyright © 2016 Tobias Due Munk. All rights reserved.
//

import UIKit
import NotificationCenter
import HealthKit


class TodayViewController: UIViewController, NCWidgetProviding {
        
    @IBOutlet weak var chartView: Chart!
    @IBOutlet weak var weightLabel: UILabel!
    @IBOutlet weak var weightDetailLabel: UILabel!
    @IBOutlet weak var weightLabelVisualEffectView: UIVisualEffectView!
    @IBOutlet weak var weightDetailLabelVisualEffectView: UIVisualEffectView!
    @IBOutlet weak var chartVisualEffectView: UIVisualEffectView!

    fileprivate let weightFormatter = MassFormatter.weightMediumFormatter()
    fileprivate let dateChartFormatter = DateFormatter(template: "MMMd") ?? DateFormatter(dateStyle: .short)
    // jj for 12/24 hour, mm for minute, MMM for abbreviated word month i.e. "Jun", d for date
    fileprivate let dateLastWeightFormatter = DateFormatter(template: "jjmmMMMd") ?? DateFormatter(dateStyle: .medium)
    fileprivate let chartYLabelFormatter = NumberFormatter()

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view from its nib.

        weightLabelVisualEffectView.effect = UIVibrancyEffect.widgetPrimary()
        weightDetailLabelVisualEffectView.effect = UIVibrancyEffect.widgetSecondary()
        chartVisualEffectView.effect = UIVibrancyEffect.widgetSecondary()
        setupChart()
    }

    
    func widgetPerformUpdate(completionHandler: @escaping ((NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.
        updateChart(average: .week, range: Chart.Range(unit: .month, count: 2, softStart: true))
            .next{ completionHandler(.newData) }
        updateLabels()
    }
}


private extension TodayViewController {

    // MARK: Chart
    func setupChart() {
        chartView.isUserInteractionEnabled = false
        chartView.gridColor = UIColor.gray.withAlphaComponent(0.1)
        chartView.labelFont = UIFont.preferredFont(forTextStyle: .caption1)
        chartView.lineWidth = 1.5
        chartView.dotSize = 3
        chartView.yLabelsOnRightSide = false
        chartView.xLabelsFormatter = { (index, value) in
            self.dateChartFormatter.string(from: Date(timeIntervalSince1970: Double(value)))
        }
        chartView.yLabelsFormatter = chartView.weightLabelsFormatter(numberFormatter: chartYLabelFormatter)
    }

    @discardableResult
    func updateChart(average: CalendarUnit = .week, range: Chart.Range) -> Observable<Result<Void>> {
        return HealthManager.instance.getWeights()
            .then {
                self.chartView.update(with: $0, dotColor: .black, lineColor: UIColor.black.withAlphaComponent(0.3), average: average, range: range)
            }
    }

    // MARK: Labels
    @discardableResult
    func updateLabels(forceWeight: Weight? = nil) -> Observable<Result<Void>> {

        let observer = Observable<Result<Void>>()
        let quantitySampleBlock: (Weight) -> () = { weight in
            Async.main {
                let weightViewModel = WeightViewModel(weight: weight, massUnit: HealthManager.instance.massUnit)
                self.weightLabel.text = self.weightFormatter.string(fromValue: weightViewModel.userValue(), unit: weightViewModel.formatterUnit)
                self.weightDetailLabel.text = self.dateLastWeightFormatter.string(from: weightViewModel.weight.date)
                observer.update(.success())
            }
        }

        if let forceWeight = forceWeight {
            quantitySampleBlock(forceWeight)
            return Observable(.success())
        }

        HealthManager.instance.getWeight(forceSource: false)
            .flatMap(Queue.main)
            .then(quantitySampleBlock)
            .error { _ in
                Async.main {
                    self.weightLabel.text = self.weightFormatter.string(fromValue: 0, unit: HealthManager.instance.massFormatterUnit)
                    self.weightDetailLabel.text = "No existing historic data"
                    observer.update(.success())
                }
        }
        return observer
    }
}
