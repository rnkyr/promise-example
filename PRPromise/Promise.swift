//
//  Promise.swift
//  PRPromise
//
//  Created by Roman Kyrylenko on 10/17/18.
//  Copyright © 2018 Roman Kyrylenko. All rights reserved.
//

import Foundation

public protocol ExecutionContext {
    
    func execute(_ work: @escaping () -> Void)
}

extension DispatchQueue: ExecutionContext {
    
    public static let placeholder = DispatchQueue.global(qos: .userInitiated)
    
    public func execute(_ work: @escaping () -> Void) {
        async(execute: work)
    }
}

public final class Promise<T> {
    
    public typealias Fulfil = (T) -> Void
    public typealias Reject = (Error) -> Void
    public typealias Cancel = () -> Void
    
    private enum State<T> {
        
        case pending, fulfilled(T), rejected(Error), cancelled
        
        var isPending: Bool {
            switch self {
            case .pending: return true
            default: return false
            }
        }
        
        var isCancelled: Bool {
            switch self {
            case .cancelled: return true
            default: return false
            }
        }
        
        var value: T? {
            switch self {
            case .fulfilled(let value): return value
            default: return nil
            }
        }
        
        var error: Error? {
            switch self {
            case .rejected(let error): return error
            default: return nil
            }
        }
    }
    
    private struct Callbacks<T> {
        
        let onFulfilled: (T) -> Void
        let onRejected: Reject
        let onCancelled: Cancel
        let context: ExecutionContext
        
        func fulfil(_ value: T) {
            context.execute { self.onFulfilled(value) }
        }
        
        func reject(_ error: Error) {
            context.execute { self.onRejected(error) }
        }
        
        func cancel() {
            context.execute { self.onCancelled() }
        }
    }
    
    private let lockQueue = DispatchQueue(label: "pr_isolation_queue", qos: .userInitiated)
    private var state: State<T>
    private var callbacks: [Callbacks<T>] = []
    
    // MARK: - Public API
    
    public static func cancelled<P>() -> Promise<P> {
        let promise = Promise<P>()
        promise.cancel()
        
        return promise
    }
    
    public init() {
        state = .pending
    }
    
    public init(value: T) {
        state = .fulfilled(value)
    }
    
    public init(error: Error) {
        state = .rejected(error)
    }
    
    public convenience init(context: ExecutionContext = DispatchQueue.placeholder, work: @escaping (_ promise: Promise<T>) throws -> Void) {
        self.init()
        context.execute {
            do {
                try work(self)
            } catch {
                self.reject(error)
            }
        }
    }
    
    public var isPending: Bool { return !isFulfilled && !isRejected && !isCancelled }
    public var isFulfilled: Bool { return value != nil }
    public var isRejected: Bool { return error != nil }
    public var isCancelled: Bool { return lockQueue.sync { return self.state.isCancelled } }
    public var value: T? { return lockQueue.sync { return self.state.value } }
    public var error: Error? { return lockQueue.sync { return self.state.error } }
    
    public func reject(_ error: Error) {
        updateState(.rejected(error))
    }
    
    public func fulfil(_ value: T) {
        updateState(.fulfilled(value))
    }
    
    public func cancel() {
        updateState(.cancelled)
    }
    
    @discardableResult
    public func then(in context: ExecutionContext = DispatchQueue.placeholder, _ onFulfilled: @escaping Fulfil, _ onRejected: @escaping Reject, _ onCancelled: @escaping Cancel) -> Promise<T> {
        addCallbacks(in: context, onFulfilled: onFulfilled, onRejected: onRejected, onCancelled: onCancelled)
        
        return self
    }
    
    @discardableResult
    public func result(in context: ExecutionContext = DispatchQueue.placeholder, _ onFulfilled: @escaping Fulfil) -> Promise<T> {
        return then(in: context, onFulfilled, { _ in }, cancel)
    }
    
    @discardableResult
    public func `catch`(in context: ExecutionContext = DispatchQueue.placeholder, _ onRejected: @escaping Reject) -> Promise<T> {
        return then(in: context, { _ in }, onRejected, cancel)
    }
    
    @discardableResult
    public func cancelled(in context: ExecutionContext = DispatchQueue.placeholder, _ onCancelled: @escaping Cancel) -> Promise<T> {
        return then(in: context, { _ in }, { _ in }, onCancelled)
    }
    
    @discardableResult
    public func map<P>(in context: ExecutionContext = DispatchQueue.placeholder, _ onFulfilled: @escaping (T) throws -> Promise<P>) -> Promise<P> {
        return Promise<P> { promise in
            self.addCallbacks(
                in: context,
                onFulfilled: { value in
                    do {
                        try onFulfilled(value).then(in: context, promise.fulfil, promise.reject, promise.cancel)
                    } catch {
                        promise.reject(error)
                    }
                },
                onRejected: promise.reject,
                onCancelled: promise.cancel
            )
        }
    }
    
    @discardableResult
    public func always(in context: ExecutionContext = DispatchQueue.placeholder, _ onComplete: @escaping () -> Void) -> Promise<T> {
        return then(in: context, { _ in onComplete() }, { _ in onComplete() }, { onComplete() })
    }
    
    public func recover(_ recovery: @escaping (Error) throws -> Promise<T>) -> Promise<T> {
        return Promise { promise in
            self.result(promise.fulfil).cancelled(promise.cancel)
                .catch { error in do { try recovery(error).then(promise.fulfil, promise.reject, promise.cancel) } catch { promise.reject(error) } }
        }
    }
    
    public static func merge<P>(_ promises: [Promise<P>]) -> Promise<[P]> {
        return Promise<[P]> { promise in
            guard !promises.isEmpty else { promise.fulfil([]); return }
            for singlePromise in promises {
                singlePromise
                    .catch(promise.reject).cancelled(promise.cancel)
                    .result { value in
                        if !promises.contains(where: { $0.isRejected || $0.isPending }) {
                            promise.fulfil(promises.compactMap { $0.value })
                        }
                }
            }
        }
    }
    
    // MARK: - Private API
    
    private func updateState(_ state: State<T>) {
        guard self.isPending else {
            return
        }
        
        lockQueue.async(flags: .barrier) {
            self.state = state
        }
        fireCallbacksIfCompleted()
    }
    
    private func addCallbacks(in context: ExecutionContext, onFulfilled: @escaping Fulfil, onRejected: @escaping Reject, onCancelled: @escaping Cancel) {
        let callback = Callbacks(onFulfilled: onFulfilled, onRejected: onRejected, onCancelled: onCancelled, context: context)
        lockQueue.async(flags: .barrier) {
            self.callbacks.append(callback)
        }
        fireCallbacksIfCompleted()
    }
    
    private func fireCallbacksIfCompleted() {
        lockQueue.async(flags: .barrier) {
            guard !self.state.isPending else {
                return
            }
            
            self.callbacks.forEach { callback in
                switch self.state {
                case .fulfilled(let value): callback.fulfil(value)
                case .rejected(let error): callback.reject(error)
                case .cancelled: callback.cancel()
                case .pending: break
                }
            }
            self.callbacks.removeAll()
        }
    }
}
