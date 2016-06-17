//
//  WarpDriveTests.swift
//  WarpDriveTests
//
//  Created by Jens Ravens on 13/10/15.
//  Copyright © 2015 nerdgeschoss GmbH. All rights reserved.
//

import Foundation
import XCTest
import Interstellar

class DelayTests: XCTestCase {
    func testShouldDispatchToMainQueue() {
        let expectation = self.expectation(withDescription: "delay called")
        Signal("test").delay(0.1).subscribe { _ in
            XCTAssertTrue(Thread.isMainThread())
            expectation.fulfill()
        }
        waitForExpectations(withTimeout: 0.2, handler: nil)
    }
    
    func testDispatchToSelectedQueue() {
        let queue = DispatchQueue.global(attributes: .qosDefault)
        let expectation = self.expectation(withDescription: "delay called")
        let s = Signal<String>()
        s.delay(0.1, queue: queue)
            .subscribe { _ in
            XCTAssertFalse(Thread.isMainThread())
            expectation.fulfill()
        }
        s.update("hello")
        waitForExpectations(withTimeout: 0.2, handler: nil)
    }
    
    func testDispatchAfterGivenTime() {
        // wait 0.2 seconds and check if action from 0.1 seconds already happened
        var value: String? = nil
        let expectation = self.expectation(withDescription: "delay called")
        Signal("test").delay(0.2).subscribe { _ in
            XCTAssertEqual(value, "value")
            expectation.fulfill()
        }
        let delayTime = DispatchTime.now() + Double(Int64(0.1 * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC)
        DispatchQueue.main.after(when: delayTime) {
            value = "value"
        }
        waitForExpectations(withTimeout: 0.2, handler: nil)
    }
}
