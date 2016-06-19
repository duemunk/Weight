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
import Interstellar


class TodayViewController: UIViewController, NCWidgetProviding {
        
    @IBOutlet weak var chartView: Chart!
    @IBOutlet weak var weightLabel: UILabel!
    @IBOutlet weak var weightDetailLabel: UILabel!

    private let weightFormatter = MassFormatter.weightMediumFormatter()
    private let dateChartFormatter = DateFormatter(template: "MMMd") ?? DateFormatter(dateStyle: .shortStyle)
    // jj for 12/24 hour, mm for minute, MMM for abbreviated word month i.e. "Jun", d for date
    private let dateLastWeightFormatter = DateFormatter(template: "jjmmMMMd") ?? DateFormatter(dateStyle: .mediumStyle)

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view from its nib.

        setupChart()
    }

    
    func widgetPerformUpdate(completionHandler: ((NCUpdateResult) -> Void)) {
        // Perform any setup necessary in order to update the view.

        updateChart(.week, range: Chart.Range(unit: .month, count: 6, softStart: true))
        updateLabels()

        // If an error is encountered, use NCUpdateResult.Failed
        // If there's no update required, use NCUpdateResult.NoData
        // If there's an update, use NCUpdateResult.NewData
        
        completionHandler(NCUpdateResult.newData)
    }
}


private extension TodayViewController {

    // MARK: Chart
    func setupChart() {
        chartView.isUserInteractionEnabled = false
        chartView.gridColor = UIColor.black().withAlphaComponent(0.1)
        chartView.labelColor = UIColor.black().withAlphaComponent(0.2)
        chartView.labelFont = UIFont.preferredFont(forTextStyle: UIFontTextStyleCaption1)
        chartView.lineWidth = 1.5
        chartView.dotSize = 1.5
        chartView.xLabelsFormatter = { (index, value) in
            self.dateChartFormatter.string(from: Date(timeIntervalSince1970: Double(value)))
        }
    }

    func updateChart(_ average: CalendarUnit = .week, range: Chart.Range) {
        HealthManager.instance.getWeights()
            .then {
                self.chartView.update(with: $0, dotColor: .black(), lineColor: UIColor.black().withAlphaComponent(0.4), average: .week, range: range)
            }
    }

    // MARK: Labels
    func updateLabels(forceWeight: HKQuantitySample? = nil) {

        let quantitySampleBlock: (HKQuantitySample) -> () = { quantitySample in
            Async.main {
                let doubleValue = quantitySample.quantity.doubleValue(for: HealthManager.instance.massUnit)
                let massFormatterUnit = HealthManager.instance.massFormatterUnit
                self.weightLabel.text = self.weightFormatter.string(fromValue: doubleValue, unit: massFormatterUnit)
                self.weightDetailLabel.text = self.dateLastWeightFormatter.string(from: quantitySample.startDate)
            }
        }

        if let forceWeight = forceWeight {
            quantitySampleBlock(forceWeight)
            return
        }

        HealthManager.instance.getWeight()
            .flatMap(Queue.main)
            .then(quantitySampleBlock)
            .error { _ in
                Async.main {
                    self.weightLabel.text = self.weightFormatter.string(fromValue: 0, unit: HealthManager.instance.massFormatterUnit)
                    self.weightDetailLabel.text = "No existing historic data"
                }
        }
    }
}
