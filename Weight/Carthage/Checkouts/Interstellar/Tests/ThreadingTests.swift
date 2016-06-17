//
//  WarpDriveTests.swift
//  WarpDriveTests
//
//  Created by Jens Ravens on 13/10/15.
//  Copyright © 2015 nerdgeschoss GmbH. All rights reserved.
//

import Foundation
import XCTest
@testable import Interstellar

func main(_ expectation: XCTestExpectation?) {
    XCTAssertTrue(Thread.isMainThread())
    expectation?.fulfill()
}
func mainTest(_ expectation: XCTestExpectation?, _ r: Result<String>, completion:((Result<String>)->Void)) {
    XCTAssertTrue(Thread.isMainThread())
    expectation?.fulfill()
}

class ThreadingTests: XCTestCase {
    func testShouldDispatchToMainQueue() {
        let expectation = self.expectation(withDescription: "thread called")
        let queue = DispatchQueue.global(attributes: .qosDefault)
        queue.async {
            let s = Signal<String>()
            s.ensure(Thread.main)
                .subscribe { _ in main(expectation) }
            s.update("hello")
        }
        waitForExpectations(withTimeout: 0.1, handler: nil)
    }
    
    func testDispatchToSelectedQueue() {
        let expectation = self.expectation(withDescription: "thread called")
        let s = Signal<String>()
        s.ensure(Thread.background)
        .subscribe { _ in
            XCTAssertFalse(Thread.isMainThread())
            expectation.fulfill()
        }
        s.update("hello")
        waitForExpectations(withTimeout: 0.1, handler: nil)
    }
    
    func testObservable() {
        let observable = Observable<String>()
        let log: (String) -> Void = { print($0) }
        observable.flatMap(Queue.main).subscribe(log)
        
    }
}
