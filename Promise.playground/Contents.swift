import Foundation

enum DummyError: Error {
    case always, regular
}

var promise = Promise<Int> { promise in
    promise.fulfil(100)
    promise.reject(DummyError.regular)
    promise.cancel()
}

let firstQueue = DispatchQueue(label: "first", qos: .default, attributes: .concurrent)
let p1 = promise
    .map { result -> Promise<Int> in
        return Promise<Int>(context: firstQueue, work: { promise in
            firstQueue.asyncAfter(deadline: .now() + 4, execute: {
                promise.fulfil(1)
                promise.reject(DummyError.regular)
                promise.cancel()
            })
        })
    }
    .result(in: firstQueue) { value in print("result1 \(value)") }
    .cancelled(in: firstQueue) { print("cancelled1") }
    .catch(in: firstQueue) { error in print("reject1 \(error)") }

let secondQueue = DispatchQueue(label: "second", qos: .userInitiated, attributes: .concurrent)
let p2 = promise
    .map { result -> Promise<Int> in
        return Promise<Int>(context: secondQueue, work: { promise in
            secondQueue.asyncAfter(deadline: .now() + 2, execute: {
                promise.fulfil(2)
                promise.reject(DummyError.regular)
                promise.cancel()
            })
        })
    }
    .result(in: secondQueue) { value in print("result2 \(value)") }
    .cancelled(in: secondQueue) { print("cancelled2") }
    .catch(in: secondQueue) { error in print("reject2 \(error)") }

let thirdQueue = DispatchQueue(label: "third", qos: .userInitiated, attributes: .concurrent)
let p3 = Promise<Int>(context: thirdQueue) { promise in
    thirdQueue.asyncAfter(deadline: .now(), execute: {
        promise.fulfil(3)
        promise.reject(DummyError.regular)
        promise.cancel()
    })
}

Promise<[Int]>.merge([p1, p2, p3])
    .always { print("") }
    .catch { (error: Error) in print("_rejected: \(error)") }
    .cancelled { print("_cancelled") }
    .result { (value: [Int]) in print("_got \(value)") }
    .always { print("_always") }
