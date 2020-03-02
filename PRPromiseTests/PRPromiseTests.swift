//
//  PRPromiseTests.swift
//  PRPromiseTests
//
//  Created by Roman Kyrylenko on 10/17/18.
//  Copyright © 2018 Roman Kyrylenko. All rights reserved.
//

import XCTest
import PRPromise

final class PRPromiseTests: XCTestCase {
    
    func test_constructor_withValue_shouldHaveValue() {
        let sut = Promise(value: 100)
        
        XCTAssertNotNil(sut.value)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.isRejected)
        XCTAssertTrue(sut.isFulfilled)
        XCTAssertFalse(sut.isCancelled)
        XCTAssertFalse(sut.isPending)
    }
    
    func test_constructor_withError_shouldHaveError() {
        let sut = Promise<Int>(error: GenericError())
        
        XCTAssertNil(sut.value)
        XCTAssertNotNil(sut.error)
        XCTAssertTrue(sut.isRejected)
        XCTAssertFalse(sut.isFulfilled)
        XCTAssertFalse(sut.isCancelled)
        XCTAssertFalse(sut.isPending)
    }
    
    func test_constructor_withoutArguments_shouldntHaveAnyValue() {
        let sut = Promise<Int>()
        
        XCTAssertNil(sut.value)
        XCTAssertNil(sut.error)
        XCTAssertFalse(sut.isFulfilled)
        XCTAssertFalse(sut.isRejected)
        XCTAssertFalse(sut.isCancelled)
        XCTAssertTrue(sut.isPending)
    }
    
    func test_workingClosure_whenSuccedeed_shouldComplete() {
        let completionExpectation = expectation(description: "Promise Completion")
        let sut = Promise<Int> { promise in
            promise.fulfil(205)
            completionExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 0.1) { _ in
            XCTAssertEqual(sut.value!, 205)
            XCTAssertNil(sut.error)
        }
    }
    
    func test_workingClosure_whenFailed_shouldComplete() {
        let completionExpectation = expectation(description: "Promise Completion")
        let error = GenericError()
        let sut = Promise<Int> { promise in
            promise.reject(error)
            completionExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 0.1) { _ in
            XCTAssertEqual(sut.error! as! GenericError, error)
            XCTAssertNil(sut.value)
        }
    }
    
    func test_workingClosure_whenCancelled_shouldComplete() {
        let completionExpectation = expectation(description: "Promise Completion")
        let sut = Promise<Int> { promise in
            promise.cancel()
            completionExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 0.1) { _ in
            XCTAssertNil(sut.error)
            XCTAssertNil(sut.value)
            XCTAssertTrue(sut.isCancelled)
        }
    }
    
    func test_completePromise_attemptToUpdate_shouldIgnore() {
        let completionExpectation = expectation(description: "Promise Completion")
        let sut = Promise<Int> { promise in
            promise.fulfil(205)
            promise.fulfil(2)
            promise.reject(GenericError())
            promise.cancel()
            completionExpectation.fulfill()
        }
        
        waitForExpectations(timeout: 0.1) { _ in
            XCTAssertEqual(sut.value!, 205)
            XCTAssertNil(sut.error)
        }
    }
}

struct GenericError: Error, Equatable { private let id: UInt32 = arc4random() }
