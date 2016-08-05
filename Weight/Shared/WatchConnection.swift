//
//  WatchConnection.swift
//  Weight
//
//  Created by Tobias Due Munk on 20/06/16.
//  Copyright © 2016 Tobias Due Munk. All rights reserved.
//

import Foundation
import WatchConnectivity
import Interstellar

class WatchConnection: NSObject {
    static let instance = WatchConnection()
    let newWeightObserver = Observable<Weight>()

    private let session = WCSession.default()

    override init() {
        super.init()
        self.setup()
    }

    func send(new weight: Weight) {
//        if #available(iOS 10, *) {
//            guard session.isWatchAppInstalled && session.isComplicationEnabled else {
//                return
//            }
//        }

//        if #available(iOS 10, *) {
//            let ss = instance.session.transferCurrentComplicationUserInfo(userInfo)
//        }

        session.sendMessage(weight.newWeightUserInfo, replyHandler: nil) { error in
            print(error)
        }
    }
}


private extension WatchConnection {

    func setup() {
        session.delegate = self
        session.activate()
    }
}


extension WatchConnection: WCSessionDelegate {

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print(activationState)
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String : AnyObject] = [:]) {
        if let Weight = Weight.newWeight(from: userInfo) {
            newWeightObserver.update(Weight)
        }
    }
}

@available(iOS 10, *)
extension WatchConnection { // : WCSessionDelegate addition methods on iOS
    func sessionDidBecomeInactive(_ session: WCSession) {
        print("Inactive")
    }

    func sessionDidDeactivate(_ session: WCSession) {
        print("Did deactivate")
    }
}

