//
//  AppConnection.swift
//  Weight
//
//  Created by Tobias Due Munk on 20/06/16.
//  Copyright © 2016 Tobias Due Munk. All rights reserved.
//

import Foundation
import WatchConnectivity
import Interstellar

class AppConnection: NSObject {
    private static let instance = AppConnection()
    let newWeightObserver = Observable<WeightViewModel>()

    private let session = WCSession.default()

    override init() {
        super.init()
        self.setup()
    }

    static func send(new weight: WeightViewModel) {
        let session = instance.session
        if #available(iOS 10, *) {
            guard session.isWatchAppInstalled && session.isComplicationEnabled else {
                return
            }
        }

        let userInfo: [String : AnyObject] = [
            Keys.newWeightKg : weight.kg,
            Keys.date : weight.date
        ]

        if #available(iOS 10, *) {
            instance.session.transferCurrentComplicationUserInfo(userInfo)
        }
    }
}

private extension AppConnection {

    func setup() {
        session.delegate = self
        session.activate()
    }
}

extension AppConnection: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: NSError?) {
        print(activationState)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : AnyObject] = [:]) {
        if
            let weight = userInfo[Keys.newWeightKg] as? Double,
            let date = userInfo[Keys.date] as? Date
        {
            let weightViewModel = WeightViewModel(weightInKg: weight, date: date)
            AppConnection.instance.newWeightObserver.update(weightViewModel)
        }
    }
}


