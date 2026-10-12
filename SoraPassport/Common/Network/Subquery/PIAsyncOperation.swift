// This file is part of the SORA network and Polkaswap app.
// SPDX-License-Identifier: BSD-4-Clause

import Foundation
import RobinHood

/// Bridges Swift concurrency into the app's existing operation graph without
/// blocking an operation-queue thread or the main queue with a semaphore.
open class PIAsyncOperation<ResultType>: BaseOperation<ResultType>, @unchecked Sendable {
    private enum State: String {
        case ready
        case executing
        case finished
    }

    // KVO can synchronously query the state properties while a transition is
    // in progress, so this must be recursive when the getters also lock.
    private let stateLock = NSRecursiveLock()
    private var state: State = .ready
    private var task: Task<Void, Never>?

    override open var isAsynchronous: Bool { true }
    override open var isReady: Bool {
        super.isReady && synchronizedState == .ready
    }
    override open var isExecuting: Bool { synchronizedState == .executing }
    override open var isFinished: Bool { synchronizedState == .finished }

    open func execute() async throws -> ResultType {
        throw PIIndexerError.invalidResponse
    }

    override open func start() {
        // `cancel()` is allowed to race OperationQueue's call to `start()`.
        // Claim the ready -> executing transition under the same lock used by
        // `finish()` so a cancelled/finished operation can never be moved
        // backwards into executing state.
        stateLock.lock()
        guard state == .ready else {
            stateLock.unlock()
            return
        }
        if isCancelled {
            transitionWithoutLock(to: .finished)
            stateLock.unlock()
            return
        }
        let configuration = configurationBlock
        configurationBlock = nil
        stateLock.unlock()

        configuration?()

        stateLock.lock()
        guard state == .ready else {
            stateLock.unlock()
            return
        }
        if isCancelled {
            transitionWithoutLock(to: .finished)
            stateLock.unlock()
            return
        }
        transitionWithoutLock(to: .executing)
        stateLock.unlock()

        let createdTask = Task { [weak self] in
            guard let self else {
                return
            }
            let completion: Result<ResultType, Error>?
            do {
                try Task.checkCancellation()
                guard !isCancelled else {
                    throw CancellationError()
                }
                let value = try await execute()
                try Task.checkCancellation()
                completion = .success(value)
            } catch is CancellationError {
                // Keep result nil, matching BaseOperation cancellation semantics.
                completion = nil
            } catch {
                completion = .failure(error)
            }
            storeCompletionIfCurrent(completion)
            finish()
        }
        stateLock.lock()
        task = createdTask
        let shouldCancel = isCancelled || state == .finished
        stateLock.unlock()
        if shouldCancel {
            createdTask.cancel()
        }
    }

    override open func cancel() {
        stateLock.lock()
        super.cancel()
        let runningTask = task
        if state != .finished {
            result = nil
        }
        stateLock.unlock()
        runningTask?.cancel()
        finish()
    }

    private var synchronizedState: State {
        stateLock.lock()
        defer { stateLock.unlock() }
        return state
    }

    private func storeCompletionIfCurrent(
        _ completion: Result<ResultType, Error>?
    ) {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard
            state == .executing,
            !isCancelled,
            let completion
        else {
            return
        }
        result = completion
    }

    private func finish() {
        stateLock.lock()
        defer { stateLock.unlock() }
        guard state != .finished else {
            return
        }
        transitionWithoutLock(to: .finished)
    }

    private func transitionWithoutLock(to newState: State) {
        let oldState = state
        willChangeValue(forKey: "is\(oldState.rawValue.capitalized)")
        willChangeValue(forKey: "is\(newState.rawValue.capitalized)")
        state = newState
        didChangeValue(forKey: "is\(newState.rawValue.capitalized)")
        didChangeValue(forKey: "is\(oldState.rawValue.capitalized)")
    }
}
